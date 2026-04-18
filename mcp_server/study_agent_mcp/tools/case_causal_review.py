from __future__ import annotations

import json
import os
from typing import Any, Dict, Iterable, List, Tuple

from ._common import with_meta
from ._review_row import normalize_domain, sanitize_case_causal_review_row, sanitize_text

_CACHE: Dict[str, Dict[str, Any]] = {}


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
    }
    _CACHE["case_causal_review"] = payload
    return payload


def _clean_optional_text(value: Any) -> str:
    text = sanitize_text(str(value or ""))
    return "" if text == "None" else text


def _build_prompt_payload(
    adverse_event_name: str,
    sanitized_row: Dict[str, Any],
    source_type: str,
    allowed_domains: Iterable[str] | None = None,
) -> Dict[str, Any]:
    normalized_allowed = [normalize_domain(domain) for domain in (allowed_domains or []) if normalize_domain(domain)]
    observed = sanitized_row.get("observed_items_by_domain") or {}
    if normalized_allowed:
        observed = {domain: items for domain, items in observed.items() if domain in normalized_allowed}
    return {
        "task": "case_causal_review",
        "adverse_event_name": adverse_event_name,
        "source_type": source_type,
        "allowed_domains": normalized_allowed,
        "review_row": {
            "observed_items_by_domain": observed,
            "context": sanitized_row.get("context") or {},
            "domains": list(observed.keys()),
            "observed_item_count": sum(len(items or []) for items in observed.values()),
        },
    }


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


def _build_observed_index(sanitized_row: Dict[str, Any]) -> Tuple[Dict[Tuple[str, str], Dict[str, Any]], Dict[Tuple[str, str], List[Dict[str, Any]]]]:
    by_id: Dict[Tuple[str, str], Dict[str, Any]] = {}
    by_label: Dict[Tuple[str, str], List[Dict[str, Any]]] = {}
    observed = sanitized_row.get("observed_items_by_domain") or {}
    for domain, items in observed.items():
        normalized_domain = normalize_domain(domain)
        for item in items or []:
            source_record_id = str(item.get("source_record_id") or "")
            label = str(item.get("label") or "")
            if source_record_id:
                by_id[(normalized_domain, source_record_id)] = item
            if label:
                by_label.setdefault((normalized_domain, label.lower()), []).append(item)
    return by_id, by_label


def _resolve_observed_item(
    domain: str,
    candidate: Dict[str, Any],
    observed_by_id: Dict[Tuple[str, str], Dict[str, Any]],
    observed_by_label: Dict[Tuple[str, str], List[Dict[str, Any]]],
) -> Dict[str, Any] | None:
    source_record_id = _clean_optional_text(candidate.get("source_record_id"))
    label = _clean_optional_text(candidate.get("label"))
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
    observed_by_id, observed_by_label = _build_observed_index(sanitized_row)
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
            observed_item = _resolve_observed_item(domain, raw_item, observed_by_id, observed_by_label)
            if observed_item is None:
                dropped_unobserved += 1
                continue

            observed_id = str(observed_item.get("source_record_id") or "")
            if observed_id in seen_ids:
                continue
            seen_ids.add(observed_id)

            why = _clean_optional_text(raw_item.get("why_it_may_contribute") or raw_item.get("why"))
            normalized_items.append(
                {
                    "domain": domain,
                    "label": observed_item.get("label") or "",
                    "source_record_id": observed_id,
                    "why_it_may_contribute": why or "Observed in the supplied row and judged potentially contributory.",
                    "confidence": _normalize_confidence(raw_item.get("confidence")),
                    "rank": _normalize_rank(raw_item.get("rank"), idx),
                }
            )
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
                "source_type": source_type or "canonical review row",
            },
        )
        return with_meta(payload, "case_causal_review_prompt_bundle")

    @mcp.tool(name="case_causal_review_sanitize_row")
    def case_causal_review_sanitize_row_tool(
        review_row: Dict[str, Any],
        allowed_domains: List[str] | None = None,
    ) -> Dict[str, Any]:
        result = sanitize_case_causal_review_row(review_row, allowed_domains=allowed_domains or [])
        return with_meta(result, "case_causal_review_sanitize_row")

    @mcp.tool(name="case_causal_review_build_prompt")
    def case_causal_review_build_prompt_tool(
        adverse_event_name: str,
        sanitized_row: Dict[str, Any],
        source_type: str,
        allowed_domains: List[str] | None = None,
    ) -> Dict[str, Any]:
        payload = _build_prompt_payload(
            adverse_event_name=adverse_event_name,
            sanitized_row=sanitized_row,
            source_type=source_type,
            allowed_domains=allowed_domains or [],
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
        narrative = _clean_optional_text(parsed.get("narrative"))
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
