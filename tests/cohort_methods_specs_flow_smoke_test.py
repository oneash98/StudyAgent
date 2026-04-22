"""Live ACP + MCP smoke test for the cohort methods specs flow.

Requires the ACP server to be running at http://127.0.0.1:8765 with MCP reachable
and LLM credentials configured. Invoked by `doit smoke_cohort_methods_specs_recommend_flow`.
"""
from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request


URL = "http://127.0.0.1:8765/flows/cohort_methods_specifications_recommendation"

REQUEST_BODY = {
    "analytic_settings_description": (
        "Compare sitagliptin new users vs glipizide new users for acute myocardial "
        "infarction. Use a 365-day washout, intent-to-treat follow-up, 1:1 propensity "
        "score matching on standardized logit with a caliper of 0.2, and a Cox model."
    ),
    "study_intent": "Comparative effectiveness study on CV outcomes.",
    "cohort_definitions": {
        "targetCohort":     {"id": 1001, "name": "Sitagliptin new users"},
        "comparatorCohort": {"id": 1002, "name": "Glipizide new users"},
        "outcomeCohort":    [{"id": 2001, "name": "Acute MI"}],
    },
    "negative_control_concept_set": {"id": 9001, "name": "Standard negative controls"},
    "covariate_selection": {"conceptsToInclude": [], "conceptsToExclude": []},
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
    print("failed_sections:", result.get("diagnostics", {}).get("failed_sections"))
    for section, entry in (result.get("sectionRationales") or {}).items():
        print(f"  {section}: {entry.get('confidence')}  {entry.get('rationale')}")

    assert result.get("status") in {"ok", "schema_validation_error", "llm_parse_error"}, result
    spec = result.get("specifications") or {}
    assert spec.get("cohortDefinitions", {}).get("targetCohort", {}).get("id") == 1001, (
        "client target cohort ID must be preserved"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
