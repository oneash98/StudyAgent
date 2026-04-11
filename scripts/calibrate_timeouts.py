#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any, Dict, List

REPO_ROOT = Path(__file__).resolve().parents[1]
ACP_PACKAGE_ROOT = REPO_ROOT / "acp_agent"
if str(ACP_PACKAGE_ROOT) not in sys.path:
    sys.path.insert(0, str(ACP_PACKAGE_ROOT))

from study_agent_acp.timeout_calibration import (  # noqa: E402
    calibrate_timeout_recommendations,
    parse_embed_debug_seconds,
    render_env_fragment,
)

ACP_BASE_URL = os.getenv("ACP_BASE_URL", "http://127.0.0.1:8765")
ACP_TIMEOUT = int(os.getenv("ACP_TIMEOUT", "360"))
CALIBRATION_RUNS = int(os.getenv("TIMEOUT_CALIBRATION_RUNS", "3"))
LLM_CANDIDATE_LIMITS = [
    int(part.strip())
    for part in os.getenv("TIMEOUT_CALIBRATION_CANDIDATE_LIMITS", "3,5,8").split(",")
    if part.strip()
]
OUTPUT_ENV_PATH = os.getenv("TIMEOUT_CALIBRATION_ENV_PATH", "/tmp/study_agent_timeout_recommendations.env")
OUTPUT_JSON_PATH = os.getenv("TIMEOUT_CALIBRATION_JSON_PATH", "/tmp/study_agent_timeout_recommendations.json")
MCP_STDOUT_PATH = os.getenv("MCP_STDOUT", "/tmp/study_agent_mcp_stdout.log")

STUDY_INTENT = (
    "Study intent: Identify clinical risk factors for older adult patients who experience "
    "an adverse event of acute gastro-intenstinal (GI) bleeding. The GI bleed has to be "
    "detected in the hospital setting. Risk factors can include concomitant medications "
    "or chronic and acute conditions."
)


def _post_flow(path: str, payload: Dict[str, Any]) -> Dict[str, Any]:
    body = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(f"{ACP_BASE_URL}{path}", data=body, method="POST")
    request.add_header("Content-Type", "application/json")
    start = time.time()
    with urllib.request.urlopen(request, timeout=ACP_TIMEOUT) as response:
        raw = response.read().decode("utf-8")
    wall_seconds = time.time() - start
    data = json.loads(raw)
    data["wall_seconds"] = round(wall_seconds, 3)
    return data


def _run_calibration() -> List[Dict[str, Any]]:
    runs: List[Dict[str, Any]] = []
    for _ in range(CALIBRATION_RUNS):
        result = _post_flow("/flows/phenotype_intent_split", {"study_intent": STUDY_INTENT})
        runs.append({"flow": "phenotype_intent_split", **result})
    for _ in range(CALIBRATION_RUNS):
        result = _post_flow("/flows/phenotype_recommendation_advice", {"study_intent": STUDY_INTENT})
        runs.append({"flow": "phenotype_recommendation_advice", **result})
    for candidate_limit in LLM_CANDIDATE_LIMITS:
        for _ in range(CALIBRATION_RUNS):
            result = _post_flow(
                "/flows/phenotype_recommendation",
                {
                    "study_intent": STUDY_INTENT,
                    "top_k": max(20, candidate_limit),
                    "max_results": int(os.getenv("LLM_RECOMMENDATION_MAX_RESULTS", "3")),
                    "candidate_limit": candidate_limit,
                },
            )
            runs.append(
                {
                    "flow": "phenotype_recommendation",
                    "candidate_limit": candidate_limit,
                    **result,
                }
            )
    return runs


def main() -> int:
    try:
        runs = _run_calibration()
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        print(raw, file=sys.stderr)
        return 1
    except Exception as exc:
        print(f"Calibration failed: {exc}", file=sys.stderr)
        return 1

    embed_seconds: List[float] = []
    mcp_stdout = Path(MCP_STDOUT_PATH)
    if mcp_stdout.exists():
        embed_seconds = parse_embed_debug_seconds(mcp_stdout.read_text(encoding="utf-8"))

    calibration = calibrate_timeout_recommendations(runs, embed_seconds=embed_seconds)
    calibration["runs"] = runs
    calibration["candidate_limits_tested"] = LLM_CANDIDATE_LIMITS
    calibration["run_count_per_flow"] = CALIBRATION_RUNS

    Path(OUTPUT_JSON_PATH).write_text(json.dumps(calibration, indent=2), encoding="utf-8")
    Path(OUTPUT_ENV_PATH).write_text(render_env_fragment(calibration), encoding="utf-8")

    print(json.dumps(calibration, indent=2))
    print(f"Wrote env recommendations to {OUTPUT_ENV_PATH}")
    print(f"Wrote calibration details to {OUTPUT_JSON_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
