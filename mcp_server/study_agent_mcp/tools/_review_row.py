from __future__ import annotations

import json
import re
from typing import Any, Dict, Iterable, List, Tuple

_EMAIL_RE = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
_URL_RE = re.compile(r"https?://\S+")
_IP_RE = re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b")
_PHONE_RE = re.compile(r"\b\+?\d{1,2}[\s.-]?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}\b")
_DATE_RE = re.compile(r"\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b|\b\d{4}-\d{1,2}-\d{1,2}\b")
_ZIP_RE = re.compile(r"\b\d{5}(?:-\d{4})?\b")
_DAY_RE = re.compile(r"\(day[^)]*\)", re.IGNORECASE)

_PHI_KEYS = {
    "name",
    "full_name",
    "first_name",
    "last_name",
    "middle_name",
    "address",
    "street",
    "city",
    "county",
    "zip",
    "zipcode",
    "email",
    "phone",
    "fax",
    "ssn",
    "social_security",
    "medical_record_number",
    "mrn",
    "account_number",
    "health_plan_beneficiary_number",
    "certificate_number",
    "license_number",
    "vehicle_id",
    "device_id",
    "url",
    "ip_address",
    "biometric_id",
    "photo",
    "personid",
    "person_id",
    "visit_id",
    "visitid",
    "birth_date",
    "admission_date",
    "discharge_date",
    "death_date",
}

_CASE_ITEM_TEXT_FIELDS = (
    "label",
    "why_observed",
    "detail",
    "evidence",
    "when",
    "value",
    "category",
    "status",
    "note",
)

_CASE_CONTEXT_CANDIDATE_KEYS = (
    "context",
    "case_context",
    "case_summary",
    "event_context",
    "event_summary",
    "narrative_context",
    "notes",
    "metadata",
)


def bucket_age(age: Any) -> str:
    try:
        age_val = float(age)
    except (TypeError, ValueError):
        return "unknown"
    if age_val >= 85:
        return "85+"
    bucket = int(age_val // 5) * 5
    return f"{bucket}-{bucket+4}"


def sanitize_text(text: str) -> str:
    if not text:
        return "None"
    value = str(text).strip()
    if not value:
        return "None"
    value = _EMAIL_RE.sub("[REDACTED_EMAIL]", value)
    value = _URL_RE.sub("[REDACTED_URL]", value)
    value = _IP_RE.sub("[REDACTED_IP]", value)
    value = _PHONE_RE.sub("[REDACTED_PHONE]", value)
    value = _DATE_RE.sub("[REDACTED_DATE]", value)
    value = _ZIP_RE.sub("[REDACTED_ZIP]", value)
    value = _DAY_RE.sub("(prior)", value)
    return value


def phi_detected(text: str) -> bool:
    if not text:
        return False
    value = str(text)
    return bool(
        _EMAIL_RE.search(value)
        or _URL_RE.search(value)
        or _IP_RE.search(value)
        or _PHONE_RE.search(value)
        or _DATE_RE.search(value)
    )


def has_phi_keys(row: Dict[str, Any]) -> bool:
    for key, value in row.items():
        if key is None:
            continue
        key_norm = str(key).lower()
        if key_norm in _PHI_KEYS and value not in (None, "", [], {}):
            return True
    return False


def sanitize_keeper_row(row: Dict[str, Any]) -> Dict[str, Any]:
    sanitized = {}
    sanitized["age_bucket"] = bucket_age(row.get("age"))
    sanitized["gender"] = sanitize_text(str(row.get("gender") or row.get("sex") or "unknown"))
    sanitized["visit_context"] = sanitize_text(str(row.get("visitContext") or row.get("visits") or "unknown"))
    sanitized["presentation"] = sanitize_text(str(row.get("presentation") or "None"))
    sanitized["prior_disease"] = sanitize_text(str(row.get("priorDisease") or "None"))
    sanitized["symptoms"] = sanitize_text(str(row.get("symptoms") or "None"))
    sanitized["comorbidities"] = sanitize_text(str(row.get("comorbidities") or "None"))
    sanitized["prior_drugs"] = sanitize_text(str(row.get("priorDrugs") or "None"))
    sanitized["prior_treatments"] = sanitize_text(str(row.get("priorTreatmentProcedures") or "None"))
    sanitized["diagnostic_procedures"] = sanitize_text(str(row.get("diagnosticProcedures") or "None"))
    sanitized["measurements"] = sanitize_text(str(row.get("measurements") or "None"))
    sanitized["alternative_diagnosis"] = sanitize_text(
        str(row.get("alternativeDiagnosis") or row.get("alternativeDiagnoses") or "None")
    )
    sanitized["after_disease"] = sanitize_text(str(row.get("afterDisease") or row.get("postDisease") or "None"))
    sanitized["after_drugs"] = sanitize_text(str(row.get("afterDrugs") or row.get("postDrugs") or "None"))
    sanitized["after_treatments"] = sanitize_text(
        str(row.get("afterTreatmentProcedures") or row.get("postTreatmentProcedures") or "None")
    )
    sanitized["death"] = sanitize_text(str(row.get("death") or "None"))
    return sanitized


def normalize_domain(value: Any) -> str:
    return re.sub(r"[^a-z0-9]+", "_", str(value or "").strip().lower()).strip("_")


def sanitize_scalar(value: Any) -> Any:
    if value is None:
        return None
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return value
    return sanitize_text(str(value))


def sanitize_nested(value: Any, depth: int = 0) -> Any:
    if depth > 4:
        return sanitize_text(json.dumps(value, ensure_ascii=True, sort_keys=True))
    if isinstance(value, dict):
        sanitized: Dict[str, Any] = {}
        for key, inner in value.items():
            sanitized[sanitize_text(str(key))] = sanitize_nested(inner, depth + 1)
        return sanitized
    if isinstance(value, list):
        return [sanitize_nested(item, depth + 1) for item in value[:50]]
    return sanitize_scalar(value)


def collect_phi_issues(value: Any, path: str = "review_row") -> List[str]:
    issues: List[str] = []
    if isinstance(value, dict):
        for key, inner in value.items():
            key_text = str(key or "")
            key_path = f"{path}.{key_text}" if path else key_text
            if key_text.lower() in _PHI_KEYS and inner not in (None, "", [], {}):
                issues.append(f"phi_key:{key_path}")
            issues.extend(collect_phi_issues(inner, key_path))
        return issues
    if isinstance(value, list):
        for idx, inner in enumerate(value):
            issues.extend(collect_phi_issues(inner, f"{path}[{idx}]"))
        return issues
    if phi_detected(str(value or "")):
        issues.append(f"phi_pattern:{path}")
    return issues


def _coerce_items(items: Any, fallback_domain: str = "") -> List[Dict[str, Any]]:
    if not isinstance(items, list):
        return []
    coerced: List[Dict[str, Any]] = []
    for item in items:
        if not isinstance(item, dict):
            continue
        candidate = dict(item)
        if fallback_domain and not candidate.get("domain"):
            candidate["domain"] = fallback_domain
        coerced.append(candidate)
    return coerced


def extract_case_items(review_row: Dict[str, Any]) -> Tuple[Dict[str, List[Dict[str, Any]]], str]:
    if isinstance(review_row.get("observed_items"), list):
        observed: Dict[str, List[Dict[str, Any]]] = {}
        for item in _coerce_items(review_row.get("observed_items")):
            domain = normalize_domain(item.get("domain"))
            if not domain:
                continue
            observed.setdefault(domain, []).append(item)
        return observed, "observed_items"

    for key in ("items_by_domain", "candidates_by_domain", "observed_items_by_domain", "domains"):
        raw = review_row.get(key)
        if not isinstance(raw, dict):
            continue
        observed = {}
        for domain_name, domain_items in raw.items():
            domain = normalize_domain(domain_name)
            if not domain:
                continue
            observed[domain] = _coerce_items(domain_items, fallback_domain=domain)
        return observed, key

    return {}, "missing"


def extract_case_context(review_row: Dict[str, Any]) -> Dict[str, Any]:
    context: Dict[str, Any] = {}
    for key, value in review_row.items():
        if key in {"observed_items", "items_by_domain", "candidates_by_domain", "observed_items_by_domain", "domains"}:
            continue
        if key in _CASE_CONTEXT_CANDIDATE_KEYS:
            context[str(key)] = sanitize_nested(value)
    if context:
        return context

    fallback: Dict[str, Any] = {}
    for key, value in review_row.items():
        if key in {"observed_items", "items_by_domain", "candidates_by_domain", "observed_items_by_domain", "domains"}:
            continue
        if isinstance(value, (str, int, float, bool, list, dict)):
            fallback[str(key)] = sanitize_nested(value)
    return fallback


def sanitize_case_causal_review_row(
    review_row: Dict[str, Any],
    allowed_domains: Iterable[str] | None = None,
) -> Dict[str, Any]:
    if not isinstance(review_row, dict):
        return {"error": "review_row_must_be_object"}

    issues = collect_phi_issues(review_row)
    if issues:
        return {
            "error": "unsafe_review_row",
            "diagnostics": {"sanitization_status": "rejected", "issues": issues[:20]},
        }

    allowed = {normalize_domain(domain) for domain in (allowed_domains or []) if normalize_domain(domain)}
    observed_items, source_container = extract_case_items(review_row)
    if not observed_items:
        return {
            "error": "invalid_review_row_shape",
            "diagnostics": {
                "sanitization_status": "rejected",
                "reason": "missing_observed_items",
                "accepted_containers": [
                    "observed_items",
                    "items_by_domain",
                    "candidates_by_domain",
                    "observed_items_by_domain",
                    "domains",
                ],
            },
        }

    sanitized_by_domain: Dict[str, List[Dict[str, Any]]] = {}
    total_items = 0
    for domain, items in observed_items.items():
        if allowed and domain not in allowed:
            continue
        sanitized_items: List[Dict[str, Any]] = []
        for idx, item in enumerate(items, start=1):
            label = sanitize_text(str(item.get("label") or item.get("name") or item.get("term") or ""))
            source_record_id = sanitize_text(str(item.get("source_record_id") or item.get("id") or ""))
            if label in ("", "None") or source_record_id in ("", "None"):
                return {
                    "error": "invalid_review_row_shape",
                    "diagnostics": {
                        "sanitization_status": "rejected",
                        "reason": "observed_items_require_label_and_source_record_id",
                        "domain": domain,
                        "item_index": idx,
                    },
                }

            sanitized_item = {
                "domain": domain,
                "label": label,
                "source_record_id": source_record_id,
            }
            for field_name in _CASE_ITEM_TEXT_FIELDS:
                if field_name in item and field_name not in sanitized_item:
                    sanitized_item[field_name] = sanitize_text(str(item.get(field_name) or ""))
            sanitized_items.append(sanitized_item)

        if sanitized_items:
            total_items += len(sanitized_items)
            sanitized_by_domain[domain] = sanitized_items

    if not sanitized_by_domain:
        return {
            "error": "no_observed_items_in_allowed_domains",
            "diagnostics": {
                "sanitization_status": "rejected",
                "allowed_domains": sorted(allowed),
                "observed_domains": sorted(observed_items),
            },
        }

    sanitized = {
        "observed_items_by_domain": sanitized_by_domain,
        "context": extract_case_context(review_row),
        "domains": list(sanitized_by_domain.keys()),
        "observed_item_count": total_items,
    }
    diagnostics = {
        "sanitization_status": "ok",
        "source_container": source_container,
        "allowed_domains_applied": sorted(allowed),
        "observed_domains": list(sanitized_by_domain.keys()),
        "observed_item_count": total_items,
    }
    return {"sanitized_row": sanitized, "diagnostics": diagnostics}
