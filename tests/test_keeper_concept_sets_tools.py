import pytest

from study_agent_mcp.tools import keeper_concept_sets


class DummyMCP:
    def __init__(self) -> None:
        self.tools = {}

    def tool(self, name: str):
        def decorator(fn):
            self.tools[name] = fn
            return fn

        return decorator


def _registered_tools():
    mcp = DummyMCP()
    keeper_concept_sets.register(mcp)
    return mcp.tools


@pytest.mark.mcp
def test_keeper_concept_set_bundle_renders_domain_prompt() -> None:
    tools = _registered_tools()
    result = tools["keeper_concept_set_bundle"](
        phenotype="Gastrointestinal bleeding",
        domain_key="doi",
    )

    assert result["task"] == "keeper_concept_sets_generate"
    assert result["domain"]["parameterName"] == "doi"
    assert "Gastrointestinal bleeding" in result["term_generation_prompt"]
    assert result["output_schema_generate_terms"]["title"] == "keeper_generate_terms_output"


@pytest.mark.mcp
def test_vocab_filter_standard_concepts_filters_domain_class_and_nonstandard() -> None:
    tools = _registered_tools()
    result = tools["vocab_filter_standard_concepts"](
        concepts=[
            {
                "conceptId": 1,
                "conceptName": "A",
                "domainId": "Condition",
                "conceptClassId": "Clinical Finding",
                "standardConcept": "S",
            },
            {
                "conceptId": 2,
                "conceptName": "B",
                "domainId": "Drug",
                "conceptClassId": "Ingredient",
                "standardConcept": "S",
            },
            {
                "conceptId": 3,
                "conceptName": "C",
                "domainId": "Condition",
                "conceptClassId": "Clinical Finding",
                "standardConcept": "N",
            },
        ],
        domains=["Condition"],
        concept_classes=["Clinical Finding"],
    )

    assert result["count"] == 1
    assert result["concepts"][0]["conceptId"] == 1


@pytest.mark.mcp
def test_vocab_remove_descendants_drops_selected_children() -> None:
    tools = _registered_tools()
    result = tools["vocab_remove_descendants"](
        concepts=[
            {"conceptId": 10, "conceptName": "Parent"},
            {"conceptId": 11, "conceptName": "Child"},
        ],
        ancestor_pairs=[{"ancestorConceptId": 10, "descendantConceptId": 11}],
    )

    assert result["count"] == 1
    assert result["removed_concept_ids"] == [11]
    assert result["concepts"][0]["conceptId"] == 10


@pytest.mark.mcp
def test_vocab_add_nonchildren_merges_and_skips_descendants() -> None:
    tools = _registered_tools()
    result = tools["vocab_add_nonchildren"](
        concepts=[{"conceptId": 10, "conceptName": "Parent"}],
        new_concepts=[
            {"conceptId": 11, "conceptName": "Child"},
            {"conceptId": 12, "conceptName": "Sibling"},
        ],
        ancestor_pairs=[{"ancestorConceptId": 10, "descendantConceptId": 11}],
    )

    assert result["count"] == 2
    assert [item["conceptId"] for item in result["concepts"]] == [10, 12]


@pytest.mark.mcp
def test_vocab_search_standard_reports_unconfigured_provider() -> None:
    tools = _registered_tools()
    result = tools["vocab_search_standard"](
        query="GI bleed",
        domains=["Condition"],
        concept_classes=[],
        limit=5,
    )

    assert result["error"] == "vocab_search_provider_unconfigured"
    assert result["count"] == 0


@pytest.mark.mcp
def test_phoebe_related_concepts_reports_unconfigured_provider() -> None:
    tools = _registered_tools()
    result = tools["phoebe_related_concepts"](
        concept_ids=[1, 2],
    )

    assert result["error"] == "phoebe_provider_unconfigured"
    assert result["count"] == 0
