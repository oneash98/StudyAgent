from __future__ import annotations

import json
import os
import re
from typing import Any, Dict, Optional

from ._common import with_meta


_CACHE: Optional[Dict[str, Any]] = None

_INSTRUCTION_TEMPLATE = """<Instruction>
From the provided <Text>, extract the key information and update the
<Current Analysis Specifications> JSON to configure a population-level
estimation study using the OMOP-CDM.
Leave any settings at their default values if they are not specified in the <Text>.
Refer to the fields and value types provided in the <Analysis Specifications Template>
and do not add any additional fields.
For each top-level analytic section that you may modify
(getDbCohortMethodDataArgs, createStudyPopArgs, propensityScoreAdjustment, fitOutcomeModelArgs),
provide a brief rationale and a confidence rating (high | medium | low).
Follow the <Output Style> exactly.
</Instruction>"""

_OUTPUT_STYLE_TEMPLATE = """<Output Style>
Return exactly one fenced JSON block with the shape:
```json
{
  "specifications": { ... full updated Theseus spec ... },
  "sectionRationales": {
    "getDbCohortMethodDataArgs":  { "rationale": "...", "confidence": "high|medium|low" },
    "createStudyPopArgs":         { "rationale": "...", "confidence": "high|medium|low" },
    "propensityScoreAdjustment":  { "rationale": "...", "confidence": "high|medium|low" },
    "fitOutcomeModelArgs":        { "rationale": "...", "confidence": "high|medium|low" }
  }
}
```
No text outside the fenced block.
</Output Style>"""


def _template_path() -> str:
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.abspath(os.path.join(here, "..", "..", "..", "theseus", "customAtlasTemplate_v1.3.0_annotated.txt"))


def _strip_c_comments(text: str) -> str:
    return re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)


def _build_bundle() -> Dict[str, Any]:
    with open(_template_path(), "r", encoding="utf-8") as handle:
        annotated = handle.read()
    stripped = _strip_c_comments(annotated)
    defaults_spec = json.loads(stripped)
    return {
        "instruction_template": _INSTRUCTION_TEMPLATE,
        "output_style_template": _OUTPUT_STYLE_TEMPLATE,
        "annotated_template": annotated,
        "defaults_spec": defaults_spec,
        "schema_version": "v1.3.0",
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
