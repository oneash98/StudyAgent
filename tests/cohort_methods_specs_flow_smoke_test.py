"""Live ACP + MCP smoke test for the cohort methods specs flow.

Requires the ACP server to be running at http://127.0.0.1:8765 with MCP
reachable and LLM credentials configured. Invoked by
`doit smoke_cohort_methods_specs_recommend_flow`.
"""
from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request


URL = "http://127.0.0.1:8765/flows/cohort_methods_specifications_recommendation"

DESCRIPTION = (
    "Compare sitagliptin new users vs glipizide new users for acute myocardial "
    "infarction. Use a 365-day washout, intent-to-treat follow-up, 1:1 propensity "
    "score matching on standardized logit with a caliper of 0.2, and a Cox model."
)

REQUEST_BODY = {
    "analytic_settings_description": DESCRIPTION,
    "study_description": DESCRIPTION,
    "study_intent": "Comparative effectiveness study on CV outcomes.",
    "target_cohort_id": 1001,
    "comparator_cohort_id": 1002,
    "outcome_cohort_ids": [2001],
    "comparison_label": "Sitagliptin vs Glipizide",
    "defaults_snapshot": {
        "profile_name": "smoke-test",
        "input_method": "typed_text",
    },
}


def main() -> int:
    req = urllib.request.Request(
        URL,
        data=json.dumps(REQUEST_BODY).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=240) as resp:
            body = resp.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        print(f"HTTPError {exc.code}: {exc.read().decode('utf-8', errors='replace')}")
        return 2

    result = json.loads(body)
    print("status:", result.get("status"))
    rec = result.get("recommendation") or {}
    print("recommendation.status:", rec.get("status"))
    print("profile_name:", rec.get("profile_name"))
    print("failed_sections:", result.get("diagnostics", {}).get("failed_sections"))
    for section, entry in (result.get("section_rationales") or {}).items():
        print(f"  {section}: {entry.get('confidence')}  {entry.get('rationale')}")

    assert result.get("status") in {"ok", "schema_validation_error", "llm_parse_error"}, result
    assert rec.get("raw_description"), "recommendation.raw_description must be non-empty"
    theseus = result.get("theseus_specifications") or {}
    assert theseus.get("cohortDefinitions", {}).get("targetCohort", {}).get("id") == 1001, (
        "client target cohort ID must be preserved in theseus_specifications"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
