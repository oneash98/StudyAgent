from __future__ import annotations

import json
import os
from typing import Any, Dict, Iterable, List, Tuple

from ._common import with_meta
from ._review_row import (
    case_review_optional_tools,
    clean_optional_text,
    normalize_domain,
    normalize_subrole,
    sanitize_case_causal_review_row,
)
from ._service_client import post_json_service

_CACHE: Dict[str, Dict[str, Any]] = {}
_ALLOWED_PROVIDER_STATUSES = {"ok", "not_found", "unsupported"}


def _prompt_dir() -> str:
    return os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "prompts", "case_causal_review"))


def _load_text(path: str) -> str:
    with open(path, "r", encoding="utf-8") as handle:
        return handle.read().strip()


def _load_json(path: str) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def _render_template(template: str, values: Dict[str, Any]) -> str:
    return template.format_map({key: str(value) for key, value in values.items()})


def _load_bundle() -> Dict[str, Any]:
    cached = _CACHE.get("case_causal_review")
    if cached is not None:
        return cached
    base = _prompt_dir()
    payload = {
        "task": "case_causal_review",
        "overview": _load_text(os.path.join(base, "overview_case_causal_review.md")),
        "spec": _load_text(os.path.join(base, "spec_case_causal_review.md")),
        "output_schema": _load_json(os.path.join(base, "output_schema_case_causal_review.json")),
        "system_prompt_template": _load_text(os.path.join(base, "system_prompt_case_causal_review.md")),
        "available_tools": case_review_optional_tools(),
    }
    _CACHE["case_causal_review"] = payload
    return payload


def _compact_item(item: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "domain": item.get("domain") or "",
        "label": item.get("label") or "",
        "source_record_id": item.get("source_record_id") or "",
        "source_kind": item.get("source_kind") or "",
        "subrole": item.get("subrole") or "",
        "why_observed": item.get("why_observed") or "",
        "annotations": item.get("annotations") or {},
    }


def _build_prompt_payload(
    adverse_event_name: str,
    sanitized_row: Dict[str, Any],
    source_type: str,
    allowed_domains: Iterable[str] | None = None,
    enrichment: Dict[str, Any] | None = None,
) -> Dict[str, Any]:
    normalized_allowed = [normalize_domain(domain) for domain in (allowed_domains or []) if normalize_domain(domain)]
    candidate_items = list(sanitized_row.get("candidate_items") or [])
    context_items = list(sanitized_row.get("context_items") or [])
    if normalized_allowed:
        candidate_items = [item for item in candidate_items if item.get("domain") in normalized_allowed]
        context_items = [item for item in context_items if item.get("domain") in normalized_allowed]

    annotations = dict(sanitized_row.get("annotations") or {})
    lightweight_annotations = {
        "concept_set_id": annotations.get("concept_set_id"),
        "concept_set_version": annotations.get("concept_set_version"),
        "concept_set_available_domains": annotations.get("concept_set_available_domains") or [],
    }

    tool_hints = dict(sanitized_row.get("tool_hints") or {})
    payload = {
        "task": "case_causal_review",
        "adverse_event_name": adverse_event_name,
        "source_type": source_type,
        "allowed_domains": normalized_allowed,
        "case_row": {
            "case_id": sanitized_row.get("case_id") or "",
            "case_summary": sanitized_row.get("case_summary") or "",
            "index_event": sanitized_row.get("index_event") or {},
            "candidate_items": [_compact_item(item) for item in candidate_items],
            "context_items": [_compact_item(item) for item in context_items],
            "case_metadata": sanitized_row.get("case_metadata") or {},
            "annotations": lightweight_annotations,
            "tool_hints": tool_hints,
        },
    }
    if enrichment:
        payload["enrichment"] = enrichment
    return payload


def _coerce_json_object(value: Any) -> Tuple[Dict[str, Any], str]:
    if isinstance(value, dict):
        return value, "dict"
    text = str(value or "").strip()
    if not text:
        return {}, "empty"
    if text.startswith("```"):
        text = text.strip("`")
        if text.startswith("json"):
            text = text[4:].strip()
    try:
        parsed = json.loads(text)
        if isinstance(parsed, dict):
            return parsed, "json"
    except Exception:
        pass
    start = text.find("{")
    end = text.rfind("}")
    if start >= 0 and end > start:
        try:
            parsed = json.loads(text[start : end + 1])
            if isinstance(parsed, dict):
                return parsed, "json_brace_extract"
        except Exception:
            pass
    return {}, "unparsed"


def _normalize_confidence(value: Any) -> str:
    if isinstance(value, (int, float)):
        numeric = float(value)
        if numeric >= 0.8:
            return "high"
        if numeric >= 0.4:
            return "medium"
        return "low"
    text = str(value or "").strip().lower()
    mapping = {
        "high": "high",
        "medium": "medium",
        "med": "medium",
        "moderate": "medium",
        "low": "low",
        "strong": "high",
        "weak": "low",
    }
    return mapping.get(text, "medium")


def _normalize_rank(value: Any, fallback: int) -> int:
    try:
        parsed = int(value)
        return parsed if parsed > 0 else fallback
    except (TypeError, ValueError):
        return fallback


def _normalize_candidate_role(value: Any, observed_item: Dict[str, Any]) -> str:
    candidate_role = normalize_subrole(value, observed_item.get("subrole") or "contextual_factor")
    return "" if candidate_role == "index_event" else candidate_role


def _build_candidate_index(
    sanitized_row: Dict[str, Any],
) -> Tuple[Dict[Tuple[str, str], Dict[str, Any]], Dict[Tuple[str, str], List[Dict[str, Any]]]]:
    by_id: Dict[Tuple[str, str], Dict[str, Any]] = {}
    by_label: Dict[Tuple[str, str], List[Dict[str, Any]]] = {}
    for item in sanitized_row.get("candidate_items") or []:
        domain = normalize_domain(item.get("domain"))
        source_record_id = str(item.get("source_record_id") or "")
        label = str(item.get("label") or "")
        if domain and source_record_id:
            by_id[(domain, source_record_id)] = item
        if domain and label:
            by_label.setdefault((domain, label.lower()), []).append(item)
    return by_id, by_label


def _resolve_candidate(
    domain: str,
    candidate: Dict[str, Any],
    observed_by_id: Dict[Tuple[str, str], Dict[str, Any]],
    observed_by_label: Dict[Tuple[str, str], List[Dict[str, Any]]],
) -> Dict[str, Any] | None:
    source_record_id = clean_optional_text(candidate.get("source_record_id"))
    label = clean_optional_text(candidate.get("label"))
    if source_record_id:
        observed = observed_by_id.get((domain, source_record_id))
        if observed is not None:
            return observed
    if label:
        observed_matches = observed_by_label.get((domain, label.lower())) or []
        if len(observed_matches) == 1:
            return observed_matches[0]
    return None


def _normalize_candidates_by_domain(
    parsed: Dict[str, Any],
    sanitized_row: Dict[str, Any],
    allowed_domains: Iterable[str] | None = None,
) -> Tuple[Dict[str, List[Dict[str, Any]]], Dict[str, Any]]:
    allowed = {normalize_domain(domain) for domain in (allowed_domains or []) if normalize_domain(domain)}
    observed_by_id, observed_by_label = _build_candidate_index(sanitized_row)
    raw = parsed.get("candidates_by_domain")
    if not isinstance(raw, dict):
        raw = {}

    candidates_by_domain: Dict[str, List[Dict[str, Any]]] = {}
    dropped_unobserved = 0
    dropped_invalid = 0
    kept = 0

    for raw_domain, raw_items in raw.items():
        domain = normalize_domain(raw_domain)
        if not domain or (allowed and domain not in allowed):
            continue
        if not isinstance(raw_items, list):
            dropped_invalid += 1
            continue

        seen_ids = set()
        normalized_items: List[Dict[str, Any]] = []
        for idx, raw_item in enumerate(raw_items, start=1):
            if not isinstance(raw_item, dict):
                dropped_invalid += 1
                continue
            observed_item = _resolve_candidate(domain, raw_item, observed_by_id, observed_by_label)
            if observed_item is None:
                dropped_unobserved += 1
                continue

            observed_id = str(observed_item.get("source_record_id") or "")
            if observed_id in seen_ids:
                continue
            seen_ids.add(observed_id)

            item = {
                "domain": domain,
                "label": observed_item.get("label") or "",
                "source_record_id": observed_id,
                "why_it_may_contribute": clean_optional_text(raw_item.get("why_it_may_contribute") or raw_item.get("why"))
                or "Observed in the supplied case row and judged potentially contributory.",
                "confidence": _normalize_confidence(raw_item.get("confidence")),
                "rank": _normalize_rank(raw_item.get("rank"), idx),
            }
            candidate_role = _normalize_candidate_role(raw_item.get("candidate_role"), observed_item)
            evidence_basis = clean_optional_text(raw_item.get("evidence_basis"))
            if candidate_role:
                item["candidate_role"] = candidate_role
            if evidence_basis:
                item["evidence_basis"] = evidence_basis
            normalized_items.append(item)
            kept += 1

        if normalized_items:
            normalized_items.sort(key=lambda item: (item.get("rank", 9999), item.get("label", "")))
            for rank, item in enumerate(normalized_items, start=1):
                item["rank"] = rank
            candidates_by_domain[domain] = normalized_items

    diagnostics = {
        "kept_candidate_count": kept,
        "dropped_unobserved_count": dropped_unobserved,
        "dropped_invalid_count": dropped_invalid,
        "output_domains": list(candidates_by_domain.keys()),
    }
    return candidates_by_domain, diagnostics


def _call_pv_copilot(tool_name: str, path: str, payload: Dict[str, Any]) -> Dict[str, Any]:
    return post_json_service(
        tool_name=tool_name,
        service_prefix="PV_COPILOT",
        path=path,
        payload=payload,
        allowed_statuses=_ALLOWED_PROVIDER_STATUSES,
        require_auth=False,
    )


def _optional_int(value: Any, default: int | None = None) -> int | None:
    if value in (None, ""):
        return default
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _annotation_value(*values: Any) -> Any:
    for value in values:
        if value not in (None, "", [], {}):
            return value
    return None


def _apply_legacy_outcome_mapping(payload: Dict[str, Any], adverse_event_concept_id: int | None) -> None:
    if adverse_event_concept_id is None:
        return
    payload["adverse_event_concept_id"] = adverse_event_concept_id
    payload["outcome_concept_id"] = adverse_event_concept_id


def register(mcp: object) -> None:
    @mcp.tool(name="case_causal_review_prompt_bundle")
    def case_causal_review_prompt_bundle_tool(
        adverse_event_name: str = "",
        source_type: str = "",
    ) -> Dict[str, Any]:
        payload = dict(_load_bundle())
        payload["system_prompt"] = _render_template(
            payload.get("system_prompt_template", ""),
            {
                "adverse_event_name": adverse_event_name or "the adverse event",
                "source_type": source_type or "canonical case row",
            },
        )
        return with_meta(payload, "case_causal_review_prompt_bundle")

    @mcp.tool(name="case_causal_review_sanitize_row")
    def case_causal_review_sanitize_row_tool(
        case_row: Dict[str, Any],
        allowed_domains: List[str] | None = None,
    ) -> Dict[str, Any]:
        result = sanitize_case_causal_review_row(case_row, allowed_domains=allowed_domains or [])
        return with_meta(result, "case_causal_review_sanitize_row")

    @mcp.tool(name="get_case_review_concept_set_domain")
    def get_case_review_concept_set_domain_tool(
        concept_set_id: str,
        concept_set_version: int | None,
        domain_name: str,
        limit: int | None = None,
    ) -> Dict[str, Any]:
        payload = {
            "concept_set_id": concept_set_id,
            "concept_set_version": concept_set_version,
            "domain_name": domain_name,
        }
        if limit is not None:
            payload["limit"] = int(limit)
        return _call_pv_copilot(
            "get_case_review_concept_set_domain",
            "/api/case-review-tools/concept-set-domain",
            payload,
        )

    @mcp.tool(name="get_case_review_drug_signal_details")
    def get_case_review_drug_signal_details_tool(
        source_type: str,
        adverse_event_name: str,
        source_record_id: str,
        adverse_event_concept_id: int | None = None,
        adverse_event_meddra_id: str = "",
        ingredient_concept_id: int | None = None,
        ingred_rxcui: str = "",
        case_id: str = "",
        report_lookup_key: Any = None,
    ) -> Dict[str, Any]:
        payload = {
            "source_type": source_type,
            "adverse_event_name": adverse_event_name,
            "source_record_id": source_record_id,
        }
        if case_id:
            payload["case_id"] = case_id
        if report_lookup_key not in (None, "", [], {}):
            payload["report_lookup_key"] = report_lookup_key
        if ingredient_concept_id is not None:
            payload["ingredient_concept_id"] = ingredient_concept_id
        if ingred_rxcui:
            payload["ingred_rxcui"] = ingred_rxcui
        if adverse_event_meddra_id:
            payload["adverse_event_meddra_id"] = adverse_event_meddra_id
        _apply_legacy_outcome_mapping(payload, adverse_event_concept_id)
        return _call_pv_copilot(
            "get_case_review_drug_signal_details",
            "/api/case-review-tools/drug-signal-details",
            payload,
        )

    @mcp.tool(name="get_case_review_drug_label_details")
    def get_case_review_drug_label_details_tool(
        source_type: str,
        adverse_event_name: str,
        source_record_id: str,
        adverse_event_concept_id: int | None = None,
        adverse_event_meddra_id: str = "",
        ingredient_concept_id: int | None = None,
        ingred_rxcui: str = "",
        case_id: str = "",
        report_lookup_key: Any = None,
        mention_limit: int | None = None,
    ) -> Dict[str, Any]:
        payload = {
            "source_type": source_type,
            "adverse_event_name": adverse_event_name,
            "source_record_id": source_record_id,
        }
        if case_id:
            payload["case_id"] = case_id
        _apply_legacy_outcome_mapping(payload, adverse_event_concept_id)
        if adverse_event_meddra_id:
            payload["adverse_event_meddra_id"] = adverse_event_meddra_id
        if ingredient_concept_id is not None:
            payload["ingredient_concept_id"] = ingredient_concept_id
        if ingred_rxcui:
            payload["ingred_rxcui"] = ingred_rxcui
        if report_lookup_key not in (None, "", [], {}):
            payload["report_lookup_key"] = report_lookup_key
        if mention_limit is not None:
            payload["mention_limit"] = int(mention_limit)
        return _call_pv_copilot(
            "get_case_review_drug_label_details",
            "/api/case-review-tools/drug-label-details",
            payload,
        )

    @mcp.tool(name="get_case_review_report_literature_stub")
    def get_case_review_report_literature_stub_tool(
        source_type: str,
        case_id: str,
        report_lookup_key: Any = None,
    ) -> Dict[str, Any]:
        payload = {
            "source_type": source_type,
            "case_id": case_id,
        }
        if report_lookup_key not in (None, "", [], {}):
            payload["report_lookup_key"] = report_lookup_key
        return _call_pv_copilot(
            "get_case_review_report_literature_stub",
            "/api/case-review-tools/report-literature-stub",
            payload,
        )

    @mcp.tool(name="case_causal_review_build_prompt")
    def case_causal_review_build_prompt_tool(
        adverse_event_name: str,
        sanitized_row: Dict[str, Any],
        source_type: str,
        allowed_domains: List[str] | None = None,
        enrichment: Dict[str, Any] | None = None,
    ) -> Dict[str, Any]:
        payload = _build_prompt_payload(
            adverse_event_name=adverse_event_name,
            sanitized_row=sanitized_row,
            source_type=source_type,
            allowed_domains=allowed_domains or [],
            enrichment=enrichment or {},
        )
        prompt = json.dumps(payload, ensure_ascii=True, indent=2, sort_keys=True)
        return with_meta({"prompt": prompt, "prompt_payload": payload}, "case_causal_review_build_prompt")

    @mcp.tool(name="case_causal_review_parse_response")
    def case_causal_review_parse_response_tool(
        llm_output: Any,
        sanitized_row: Dict[str, Any],
        allowed_domains: List[str] | None = None,
    ) -> Dict[str, Any]:
        parsed, parse_mode = _coerce_json_object(llm_output)
        candidates_by_domain, diagnostics = _normalize_candidates_by_domain(
            parsed,
            sanitized_row,
            allowed_domains=allowed_domains or [],
        )
        narrative = clean_optional_text(parsed.get("narrative"))
        merged_diagnostics = parsed.get("diagnostics") if isinstance(parsed.get("diagnostics"), dict) else {}
        merged_diagnostics = dict(merged_diagnostics)
        merged_diagnostics.update(diagnostics)
        merged_diagnostics["parse_mode"] = parse_mode
        merged_diagnostics["allowed_domains_applied"] = [
            normalize_domain(domain) for domain in (allowed_domains or []) if normalize_domain(domain)
        ]
        return with_meta(
            {
                "candidates_by_domain": candidates_by_domain,
                "narrative": narrative,
                "mode": "case_causal_review",
                "diagnostics": merged_diagnostics,
            },
            "case_causal_review_parse_response",
        )

    return None
