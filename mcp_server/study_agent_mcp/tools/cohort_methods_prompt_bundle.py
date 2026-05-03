from __future__ import annotations

import json
import os
from typing import Any, Dict, Optional

from ._common import with_meta


_CACHE: Optional[Dict[str, Any]] = None

_INSTRUCTION_TEMPLATE = """<Instruction>
From the provided <Text>, extract the key information and update the
<Analysis Specifications Template> JSON to configure a population-level
estimation study using the OMOP-CDM.
Leave any settings at their default values if they are not specified in the <Text>.
Refer to the fields and value types provided in the <Analysis Specifications Template>
and do not add any additional fields.
For each fields, refer to <JSON Fields Descriptions> to ensure accurate mapping of the relevant information from <Text> to the corresponding JSON structure.
For each analytic settings section used by the R shell
(study_population, time_at_risk, propensity_score_adjustment, outcome_model),
provide a brief rationale and a confidence rating (high | medium | low).
Follow the <Output Style> exactly.
</Instruction>"""

_OUTPUT_STYLE_TEMPLATE = """<Output Style>
Return exactly one fenced JSON block with the shape:
```json
{
  "specifications": { ... full updated cmAnalysis spec ... },
  "sectionRationales": {
    "study_population":             { "rationale": "...", "confidence": "high|medium|low" },
    "time_at_risk":                 { "rationale": "...", "confidence": "high|medium|low" },
    "propensity_score_adjustment":  { "rationale": "...", "confidence": "high|medium|low" },
    "outcome_model":                { "rationale": "...", "confidence": "high|medium|low" }
  }
}
```
No text outside the fenced block.
</Output Style>"""


def _prompt_dir() -> str:
    return os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "..", "prompts", "cohort_methods")
    )


def _analysis_template_path() -> str:
    return os.path.join(_prompt_dir(), "cmAnalysis_template.json")


def _field_descriptions_path() -> str:
    return os.path.join(_prompt_dir(), "CM_ANALYSIS_TEMPLATE.md")


def _load_text(path: str) -> str:
    with open(path, "r", encoding="utf-8") as handle:
        return handle.read().strip()


def _load_json(path: str) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def _load_field_descriptions() -> str:
    text = _load_text(_field_descriptions_path())
    marker = "## Top-Level Shape"
    idx = text.find(marker)
    if idx == -1:
        raise ValueError(f"missing field description marker: {marker}")
    return text[idx:].strip()


def _build_bundle() -> Dict[str, Any]:
    defaults_spec = _load_json(_analysis_template_path())
    analysis_template = json.dumps(defaults_spec, indent=2)
    return {
        "instruction_template": _INSTRUCTION_TEMPLATE,
        "output_style_template": _OUTPUT_STYLE_TEMPLATE,
        "annotated_template": analysis_template,
        "analysis_specifications_template": analysis_template,
        "json_field_descriptions": _load_field_descriptions(),
        "defaults_spec": defaults_spec,
        "schema_version": "v1.4.0",
    }


def register(mcp: object) -> None:
    global _CACHE

    @mcp.tool(name="cohort_methods_prompt_bundle")
    def cohort_methods_prompt_bundle_tool() -> Dict[str, Any]:
        global _CACHE
        if _CACHE is None:
            _CACHE = _build_bundle()
        return with_meta(_CACHE, "cohort_methods_prompt_bundle")

    return None
