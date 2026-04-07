import os
from typing import Any, Dict, List, Optional, Protocol

from study_agent_core.models import (
    CohortLintInput,
    ConceptSetDiffInput,
    PhenotypeIntentSplitInput,
    PhenotypeImprovementsInput,
    PhenotypeRecommendationAdviceInput,
    PhenotypeRecommendationsInput,
)
from study_agent_core.tools import (
    cohort_lint,
    phenotype_intent_split,
    phenotype_improvements,
    phenotype_recommendation_advice,
    phenotype_recommendations,
    propose_concept_set_diff,
)
from .llm_client import (
    LLMCallResult,
    build_intent_split_prompt,
    build_advice_prompt,
    build_improvements_prompt,
    build_keeper_prompt,
    build_lint_prompt,
    build_prompt,
    call_llm,
    coerce_llm_call_result,
    llm_result_payload,
)


class MCPClient(Protocol):
    def list_tools(self) -> List[Dict[str, Any]]:
        ...

    def call_tool(self, name: str, arguments: Dict[str, Any]) -> Dict[str, Any]:
        ...


class StudyAgent:
    def __init__(
        self,
        mcp_client: Optional[MCPClient] = None,
        allow_core_fallback: bool = True,
        confirmation_required_tools: Optional[List[str]] = None,
    ) -> None:
        self._mcp_client = mcp_client
        self._allow_core_fallback = allow_core_fallback
        self._confirmation_required = set(confirmation_required_tools or [])

        self._core_tools = {
            "propose_concept_set_diff": propose_concept_set_diff,
            "cohort_lint": cohort_lint,
            "phenotype_recommendations": phenotype_recommendations,
            "phenotype_recommendation_advice": phenotype_recommendation_advice,
            "phenotype_improvements": phenotype_improvements,
            "phenotype_intent_split": phenotype_intent_split,
        }

        self._schemas = {
            "propose_concept_set_diff": ConceptSetDiffInput.model_json_schema(),
            "cohort_lint": CohortLintInput.model_json_schema(),
            "phenotype_recommendations": PhenotypeRecommendationsInput.model_json_schema(),
            "phenotype_recommendation_advice": PhenotypeRecommendationAdviceInput.model_json_schema(),
            "phenotype_improvements": PhenotypeImprovementsInput.model_json_schema(),
            "phenotype_intent_split": PhenotypeIntentSplitInput.model_json_schema(),
        }

    def _debug_enabled(self) -> bool:
        return os.getenv("STUDY_AGENT_DEBUG", "0") == "1"

    def _log_debug(self, message: str) -> None:
        if self._debug_enabled():
            print(f"ACP DEBUG > {message}")

    def _llm_diagnostics(self, result: Optional[LLMCallResult]) -> Dict[str, Any]:
        if result is None:
            return {
                "llm_status": "disabled",
                "llm_duration_seconds": 0.0,
                "llm_error": "llm_result_missing",
                "llm_parse_stage": None,
                "llm_schema_valid": False,
            }
        diagnostics = {
            "llm_status": result.status,
            "llm_duration_seconds": result.duration_seconds,
            "llm_error": result.error,
            "llm_parse_stage": result.parse_stage,
            "llm_schema_valid": bool(result.schema_valid) if result.schema_valid is not None else result.status == "ok",
            "llm_request_mode": result.request_mode,
        }
        if result.missing_keys:
            diagnostics["llm_missing_keys"] = result.missing_keys
        if os.getenv("LLM_LOG_RESPONSE", "0") == "1":
            diagnostics["llm_raw_response"] = result.raw_response
            diagnostics["llm_content_text"] = result.content_text
        return diagnostics

    def _fallback_reason_for_llm(self, result: Optional[LLMCallResult]) -> str:
        if result is None:
            return "llm_empty_result"
        mapping = {
            "timeout": "llm_timeout",
            "http_error": "llm_http_error",
            "transport_error": "llm_transport_error",
            "json_parse_failed": "llm_json_parse_failed",
            "schema_mismatch": "llm_schema_mismatch",
            "disabled": "llm_disabled",
        }
        return mapping.get(result.status, "llm_empty_result")

    def _call_llm(self, prompt: str, required_keys: Optional[List[str]] = None) -> LLMCallResult:
        try:
            return coerce_llm_call_result(call_llm(prompt, required_keys=required_keys))
        except TypeError:
            return coerce_llm_call_result(call_llm(prompt))

    def list_tools(self) -> List[Dict[str, Any]]:
        if self._mcp_client is not None:
            return self._mcp_client.list_tools()

        return [
            {
                "name": name,
                "description": "Core tool (fallback when MCP is unavailable).",
                "input_schema": schema,
            }
            for name, schema in self._schemas.items()
        ]

    def call_tool(self, name: str, arguments: Dict[str, Any], confirm: bool = False) -> Dict[str, Any]:
        if name in self._confirmation_required and not confirm:
            return {
                "status": "needs_confirmation",
                "tool": name,
                "warnings": ["Tool execution requires confirmation."],
            }

        if self._mcp_client is not None:
            try:
                result = self._mcp_client.call_tool(name, arguments)
                normalized = self._normalize_result(result)
                return self._wrap_result(name, normalized, warnings=[])
            except Exception as exc:
                return {
                    "status": "error",
                    "tool": name,
                    "warnings": [f"MCP tool call failed: {exc}"],
                }

        if not self._allow_core_fallback:
            return {
                "status": "error",
                "tool": name,
                "warnings": ["MCP client unavailable and core fallback disabled."],
            }

        if name not in self._core_tools:
            return {
                "status": "error",
                "tool": name,
                "warnings": ["Unknown tool name."],
            }

        try:
            result = self._core_tools[name](**arguments)
            normalized = self._normalize_result(result)
            return self._wrap_result(name, normalized, warnings=["Used core fallback (no MCP client)."])
        except Exception as exc:
            return {
                "status": "error",
                "tool": name,
                "warnings": [f"Core tool call failed: {exc}"],
            }

    def run_phenotype_recommendation_flow(
        self,
        study_intent: str,
        top_k: Optional[int] = None,
        max_results: Optional[int] = None,
        candidate_limit: Optional[int] = None,
        candidate_offset: Optional[int] = None,
    ) -> Dict[str, Any]:
        if not study_intent:
            return {"status": "error", "error": "missing study_intent"}
        if self._mcp_client is None:
            return {"status": "error", "error": "MCP client unavailable"}
        if top_k is None:
            top_k = int(os.getenv("LLM_RECOMMENDATION_TOP_K", "20"))
        if max_results is None:
            max_results = int(os.getenv("LLM_RECOMMENDATION_MAX_RESULTS", "3"))

        search_args = {"query": study_intent, "top_k": top_k}
        if candidate_offset is not None:
            search_args["offset"] = int(candidate_offset)

        self._log_debug(f"phenotype_recommendation: phenotype_search start top_k={top_k} offset={candidate_offset or 0}")
        search_result = self.call_tool(
            name="phenotype_search",
            arguments=search_args,
        )
        self._log_debug(f"phenotype_recommendation: phenotype_search end status={search_result.get('status')}")
        if search_result.get("status") != "ok":
            return {
                "status": "error",
                "error": "phenotype_search_failed",
                "details": search_result,
            }

        full = search_result.get("full_result") or {}
        if full.get("error"):
            payload = {
                "status": "error",
                "error": full.get("error"),
                "details": full,
            }
            if full.get("error") == "phenotype_index_unavailable":
                payload["hint"] = (
                    "Set PHENOTYPE_INDEX_DIR to the phenotype_index directory "
                    "(prefer an absolute path) and verify catalog.jsonl exists."
                )
            return payload
        if "results" not in full and full.get("content"):
            return {
                "status": "error",
                "error": "phenotype_search_failed",
                "details": full,
            }
        all_candidates = full.get("results") or []
        if candidate_limit is None:
            candidate_limit = int(os.getenv("LLM_CANDIDATE_LIMIT", "5"))
        pre_truncation_count = len(all_candidates)
        candidates = all_candidates
        if candidate_limit > 0:
            candidates = candidates[:candidate_limit]
        self._log_debug(
            "phenotype_recommendation: candidate counts "
            f"before={pre_truncation_count} after={len(candidates)} limit={candidate_limit}"
        )

        self._log_debug("phenotype_recommendation: prompt bundle fetch start")
        prompt_bundle = self.call_tool(
            name="phenotype_prompt_bundle",
            arguments={"task": "phenotype_recommendations"},
        )
        self._log_debug(f"phenotype_recommendation: prompt bundle fetch end status={prompt_bundle.get('status')}")
        prompt_full = prompt_bundle.get("full_result") or {}
        if prompt_bundle.get("status") != "ok" or prompt_full.get("error"):
            return {
                "status": "error",
                "error": "phenotype_prompt_bundle_failed",
                "details": prompt_bundle,
            }

        prompt = build_prompt(
            overview=prompt_full.get("overview", ""),
            spec=prompt_full.get("spec", ""),
            output_schema=prompt_full.get("output_schema", {}),
            study_intent=study_intent,
            candidates=candidates,
            max_results=max_results,
        )
        self._log_debug(
            f"phenotype_recommendation: llm start prompt_chars={len(prompt)} candidate_count={len(candidates)}"
        )
        llm_result = self._call_llm(prompt, required_keys=["plan", "phenotype_recommendations"])
        self._log_debug(
            "phenotype_recommendation: llm end "
            f"status={llm_result.status} seconds={llm_result.duration_seconds:.2f} parse_stage={llm_result.parse_stage}"
        )
        catalog_rows = []
        for row in candidates:
            if not isinstance(row, dict):
                continue
            catalog_rows.append(
                {
                    "cohortId": row.get("cohortId"),
                    "cohortName": row.get("name") or "",
                    "short_description": row.get("short_description"),
                }
            )
        llm_payload = llm_result_payload(llm_result)

        core_result = phenotype_recommendations(
            protocol_text=study_intent,
            catalog_rows=catalog_rows,
            max_results=max_results,
            llm_result=llm_payload,
        )
        llm_used = llm_payload is not None
        fallback_reason = None if llm_used else self._fallback_reason_for_llm(llm_result)
        fallback_mode = None if llm_used else core_result.get("mode")
        if fallback_reason:
            self._log_debug(f"phenotype_recommendation: fallback chosen reason={fallback_reason} mode={fallback_mode}")

        return {
            "status": "ok",
            "search": full,
            "llm_used": llm_used,
            "llm_status": llm_result.status,
            "fallback_reason": fallback_reason,
            "fallback_mode": fallback_mode,
            "candidate_limit": candidate_limit,
            "candidate_offset": candidate_offset or 0,
            "candidate_count": len(candidates),
            "candidate_count_before_truncation": pre_truncation_count,
            "prompt_length_chars": len(prompt),
            "recommendations": core_result,
            "diagnostics": self._llm_diagnostics(llm_result),
        }

    def run_phenotype_recommendation_advice_flow(
        self,
        study_intent: str,
    ) -> Dict[str, Any]:
        if not study_intent:
            return {"status": "error", "error": "missing study_intent"}
        if self._mcp_client is None:
            return {"status": "error", "error": "MCP client unavailable"}

        prompt_bundle = self.call_tool(
            name="phenotype_recommendation_advice",
            arguments={},
        )
        prompt_full = prompt_bundle.get("full_result") or {}
        if prompt_bundle.get("status") != "ok" or prompt_full.get("error"):
            return {
                "status": "error",
                "error": "phenotype_recommendation_advice_prompt_failed",
                "details": prompt_bundle,
            }

        prompt = build_advice_prompt(
            overview=prompt_full.get("overview", ""),
            spec=prompt_full.get("spec", ""),
            output_schema=prompt_full.get("output_schema", {}),
            study_intent=study_intent,
        )
        llm_result = self._call_llm(prompt, required_keys=["advice"])
        llm_payload = llm_result_payload(llm_result)
        core_result = phenotype_recommendation_advice(
            study_intent=study_intent,
            llm_result=llm_payload,
        )

        return {
            "status": "ok",
            "llm_used": llm_payload is not None,
            "llm_status": llm_result.status,
            "fallback_reason": None if llm_payload is not None else self._fallback_reason_for_llm(llm_result),
            "fallback_mode": None if llm_payload is not None else core_result.get("mode"),
            "advice": core_result,
            "diagnostics": self._llm_diagnostics(llm_result),
        }

    def run_phenotype_intent_split_flow(
        self,
        study_intent: str,
    ) -> Dict[str, Any]:
        if not study_intent:
            return {"status": "error", "error": "missing study_intent"}
        if self._mcp_client is None:
            return {"status": "error", "error": "MCP client unavailable"}
        prompt_bundle = self.call_tool(
            name="phenotype_intent_split",
            arguments={},
        )
        prompt_full = prompt_bundle.get("full_result") or {}
        if prompt_bundle.get("status") != "ok" or prompt_full.get("error"):
            return {
                "status": "error",
                "error": "phenotype_intent_split_prompt_failed",
                "details": prompt_bundle,
            }

        prompt = build_intent_split_prompt(
            overview=prompt_full.get("overview", ""),
            spec=prompt_full.get("spec", ""),
            output_schema=prompt_full.get("output_schema", {}),
            study_intent=study_intent,
        )
        self._log_debug("phenotype_intent_split: calling LLM")
        llm_result = self._call_llm(prompt, required_keys=["target_statement", "outcome_statement", "rationale"])
        self._log_debug(
            "phenotype_intent_split: LLM returned "
            f"status={llm_result.status} parse_stage={llm_result.parse_stage}"
        )
        llm_payload = llm_result_payload(llm_result)
        if llm_payload is None:
            return {
                "status": "error",
                "error": "llm_unavailable",
                "diagnostics": self._llm_diagnostics(llm_result),
            }
        core_result = phenotype_intent_split(
            study_intent=study_intent,
            llm_result=llm_payload,
        )

        return {
            "status": "ok",
            "llm_used": True,
            "llm_status": llm_result.status,
            "intent_split": core_result,
            "diagnostics": self._llm_diagnostics(llm_result),
        }

    def run_phenotype_improvements_flow(
        self,
        protocol_text: str,
        cohorts: List[Dict[str, Any]],
        characterization_previews: Optional[List[Dict[str, Any]]] = None,
    ) -> Dict[str, Any]:
        if self._mcp_client is None:
            return {"status": "error", "error": "MCP client unavailable"}
        prompt_bundle = self.call_tool(
            name="phenotype_prompt_bundle",
            arguments={"task": "phenotype_improvements"},
        )
        prompt_full = prompt_bundle.get("full_result") or {}
        if prompt_bundle.get("status") != "ok" or prompt_full.get("error"):
            return {
                "status": "error",
                "error": "phenotype_prompt_bundle_failed",
                "details": prompt_bundle,
            }

        if len(cohorts) > 1:
            cohorts = [cohorts[0]]
        prompt = build_improvements_prompt(
            overview=prompt_full.get("overview", ""),
            spec=prompt_full.get("spec", ""),
            output_schema=prompt_full.get("output_schema", {}),
            study_intent=protocol_text,
            cohorts=cohorts,
        )
        llm_result = coerce_llm_call_result(call_llm(prompt))
        llm_payload = llm_result_payload(llm_result)

        result = self.call_tool(
            name="phenotype_improvements",
            arguments={
                "protocol_text": protocol_text,
                "cohorts": cohorts,
                "characterization_previews": characterization_previews or [],
                "llm_result": llm_payload,
            },
        )
        if isinstance(result, dict):
            result.setdefault("llm_used", llm_payload is not None)
            result.setdefault("llm_status", llm_result.status)
            result.setdefault("diagnostics", self._llm_diagnostics(llm_result))
            result.setdefault("cohort_count", len(cohorts))
        return result

    def run_concept_sets_review_flow(
        self,
        concept_set: Any,
        study_intent: str,
    ) -> Dict[str, Any]:
        if self._mcp_client is None:
            return {"status": "error", "error": "MCP client unavailable"}
        prompt_bundle = self.call_tool(
            name="lint_prompt_bundle",
            arguments={"task": "concept_sets_review"},
        )
        prompt_full = prompt_bundle.get("full_result") or {}
        if prompt_bundle.get("status") != "ok" or prompt_full.get("error"):
            return {
                "status": "error",
                "error": "lint_prompt_bundle_failed",
                "details": prompt_bundle,
            }
        prompt = build_lint_prompt(
            overview=prompt_full.get("overview", ""),
            spec=prompt_full.get("spec", ""),
            output_schema=prompt_full.get("output_schema", {}),
            task="concept-sets-review",
            payload={"concept_set": concept_set, "study_intent": study_intent},
            max_kb=15,
        )
        llm_result = coerce_llm_call_result(call_llm(prompt))
        llm_payload = llm_result_payload(llm_result)
        result = self.call_tool(
            name="propose_concept_set_diff",
            arguments={
                "concept_set": concept_set,
                "study_intent": study_intent,
                "llm_result": llm_payload,
            },
        )
        if isinstance(result, dict):
            result.setdefault("llm_used", llm_payload is not None)
            result.setdefault("llm_status", llm_result.status)
            result.setdefault("diagnostics", self._llm_diagnostics(llm_result))
        return result

    def run_cohort_critique_general_design_flow(
        self,
        cohort: Dict[str, Any],
    ) -> Dict[str, Any]:
        if self._mcp_client is None:
            return {"status": "error", "error": "MCP client unavailable"}
        prompt_bundle = self.call_tool(
            name="phenotype_prompt_bundle",
            arguments={"task": "cohort_critique_general_design"},
        )
        prompt_full = prompt_bundle.get("full_result") or {}
        if prompt_bundle.get("status") != "ok" or prompt_full.get("error"):
            return {
                "status": "error",
                "error": "phenotype_prompt_bundle_failed",
                "details": prompt_bundle,
            }
        prompt = build_lint_prompt(
            overview=prompt_full.get("overview", ""),
            spec=prompt_full.get("spec", ""),
            output_schema=prompt_full.get("output_schema", {}),
            task="cohort-critique-general-design",
            payload={"cohort": cohort},
            max_kb=15,
        )
        llm_result = coerce_llm_call_result(call_llm(prompt))
        llm_payload = llm_result_payload(llm_result)
        result = self.call_tool(
            name="cohort_lint",
            arguments={
                "cohort": cohort,
                "llm_result": llm_payload,
            },
        )
        if isinstance(result, dict):
            result.setdefault("llm_used", llm_payload is not None)
            result.setdefault("llm_status", llm_result.status)
            result.setdefault("diagnostics", self._llm_diagnostics(llm_result))
        return result

    def run_phenotype_validation_review_flow(
        self,
        keeper_row: Dict[str, Any],
        disease_name: str,
    ) -> Dict[str, Any]:
        if self._mcp_client is None:
            return {"status": "error", "error": "MCP client unavailable"}
        if not disease_name:
            return {"status": "error", "error": "missing disease_name"}

        sanitize = self.call_tool(
            name="keeper_sanitize_row",
            arguments={"row": keeper_row},
        )
        sanitize_full = sanitize.get("full_result") or {}
        if sanitize.get("status") != "ok" or sanitize_full.get("error"):
            return {
                "status": "error",
                "error": "phi_detected",
                "details": sanitize,
            }
        sanitized_row = sanitize_full.get("sanitized_row") or {}

        prompt_bundle = self.call_tool(
            name="keeper_prompt_bundle",
            arguments={"disease_name": disease_name},
        )
        prompt_full = prompt_bundle.get("full_result") or {}
        if prompt_bundle.get("status") != "ok" or prompt_full.get("error"):
            return {
                "status": "error",
                "error": "keeper_prompt_bundle_failed",
                "details": prompt_bundle,
            }

        build_prompt = self.call_tool(
            name="keeper_build_prompt",
            arguments={"disease_name": disease_name, "sanitized_row": sanitized_row},
        )
        build_full = build_prompt.get("full_result") or {}
        if build_prompt.get("status") != "ok" or build_full.get("error"):
            return {
                "status": "error",
                "error": "keeper_build_prompt_failed",
                "details": build_prompt,
            }

        system_prompt = prompt_full.get("system_prompt") or ""
        main_prompt = build_full.get("prompt") or ""
        prompt = build_keeper_prompt(
            overview=prompt_full.get("overview", ""),
            spec=prompt_full.get("spec", ""),
            output_schema=prompt_full.get("output_schema", {}),
            system_prompt=system_prompt,
            main_prompt=main_prompt,
        )
        llm_result = coerce_llm_call_result(call_llm(prompt))
        llm_payload = llm_result_payload(llm_result)

        parsed = self.call_tool(
            name="keeper_parse_response",
            arguments={"llm_output": llm_payload},
        )
        if isinstance(parsed, dict):
            parsed.setdefault("llm_used", llm_payload is not None)
            parsed.setdefault("llm_status", llm_result.status)
            parsed.setdefault("diagnostics", self._llm_diagnostics(llm_result))
        return parsed

    def _wrap_result(self, name: str, result: Dict[str, Any], warnings: List[str]) -> Dict[str, Any]:
        safe_summary = self._safe_summary(result)
        return {
            "status": "ok",
            "tool": name,
            "warnings": warnings,
            "safe_summary": safe_summary,
            "full_result": result,
        }

    def _normalize_result(self, result: Dict[str, Any]) -> Dict[str, Any]:
        if isinstance(result, dict) and "result" in result and isinstance(result["result"], dict):
            return result["result"]
        return result

    def _safe_summary(self, result: Dict[str, Any]) -> Dict[str, Any]:
        if "error" in result:
            return {"error": result.get("error")}

        summary = {"plan": result.get("plan")}
        for key in (
            "findings",
            "patches",
            "actions",
            "risk_notes",
            "phenotype_recommendations",
            "phenotype_improvements",
        ):
            if isinstance(result.get(key), list):
                summary[f"{key}_count"] = len(result.get(key) or [])
        return summary
