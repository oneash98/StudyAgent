import pytest

from study_agent_core.theseus_validation import THESEUS_TOP_LEVEL_KEYS, validate_theseus_spec
from study_agent_mcp.tools import cohort_methods_prompt_bundle


class DummyMCP:
    def __init__(self) -> None:
        self.tools: dict = {}

    def tool(self, name: str):
        def decorator(fn):
            self.tools[name] = fn
            return fn

        return decorator


@pytest.mark.mcp
def test_bundle_returns_expected_keys() -> None:
    mcp = DummyMCP()
    cohort_methods_prompt_bundle.register(mcp)
    fn = mcp.tools["cohort_methods_prompt_bundle"]
    payload = fn()
    assert "instruction_template" in payload
    assert "output_style_template" in payload
    assert "annotated_template" in payload
    assert "defaults_spec" in payload
    assert payload["schema_version"] == "v1.3.0"


@pytest.mark.mcp
def test_annotated_template_loads_original_file() -> None:
    mcp = DummyMCP()
    cohort_methods_prompt_bundle.register(mcp)
    fn = mcp.tools["cohort_methods_prompt_bundle"]
    payload = fn()
    assert "customAtlasTemplate" not in payload["annotated_template"]  # no filename leak
    assert "/* ATLAS Cohort ID */" in payload["annotated_template"]
    assert "fitOutcomeModelArgs" in payload["annotated_template"]


@pytest.mark.mcp
def test_defaults_spec_is_comment_stripped_valid_json() -> None:
    mcp = DummyMCP()
    cohort_methods_prompt_bundle.register(mcp)
    fn = mcp.tools["cohort_methods_prompt_bundle"]
    payload = fn()
    defaults = payload["defaults_spec"]
    assert isinstance(defaults, dict)
    for key in THESEUS_TOP_LEVEL_KEYS:
        assert key in defaults, f"missing key in defaults_spec: {key}"
    ok, missing = validate_theseus_spec(defaults)
    assert ok is True, f"defaults_spec failed top-level validation: {missing}"


@pytest.mark.mcp
def test_bundle_is_cached() -> None:
    mcp = DummyMCP()
    cohort_methods_prompt_bundle.register(mcp)
    fn = mcp.tools["cohort_methods_prompt_bundle"]
    a = fn()
    b = fn()
    assert a is b  # same object identity means cached
