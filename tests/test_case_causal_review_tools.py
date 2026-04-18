import pytest

from study_agent_mcp.tools import case_causal_review


class DummyMCP:
    def __init__(self) -> None:
        self.tools = {}

    def tool(self, name: str):
        def decorator(fn):
            self.tools[name] = fn
            return fn

        return decorator


@pytest.mark.mcp
def test_case_causal_review_sanitize_row_filters_domains() -> None:
    mcp = DummyMCP()
    case_causal_review.register(mcp)
    fn = mcp.tools["case_causal_review_sanitize_row"]
    payload = fn(
        {
            "observed_items": [
                {"domain": "Drug Exposures", "label": "Warfarin", "source_record_id": "drug-1"},
                {"domain": "Labs", "label": "INR 4.2", "source_record_id": "lab-1"},
            ],
            "case_summary": "Event after treatment",
        },
        ["drug_exposures"],
    )
    assert payload["sanitized_row"]["domains"] == ["drug_exposures"]
    assert payload["sanitized_row"]["observed_item_count"] == 1


@pytest.mark.mcp
def test_case_causal_review_sanitize_row_rejects_phi() -> None:
    mcp = DummyMCP()
    case_causal_review.register(mcp)
    fn = mcp.tools["case_causal_review_sanitize_row"]
    payload = fn(
        {
            "observed_items": [
                {"domain": "drugs", "label": "Warfarin", "source_record_id": "drug-1"},
            ],
            "birth_date": "2020-01-01",
        },
        [],
    )
    assert payload["error"] == "unsafe_review_row"


@pytest.mark.mcp
def test_case_causal_review_parse_response_drops_unobserved_candidates() -> None:
    mcp = DummyMCP()
    case_causal_review.register(mcp)
    fn = mcp.tools["case_causal_review_parse_response"]
    payload = fn(
        {
            "candidates_by_domain": {
                "drug_exposures": [
                    {
                        "domain": "drug_exposures",
                        "label": "Warfarin",
                        "source_record_id": "drug-1",
                        "why_it_may_contribute": "Bleeding risk",
                        "confidence": "high",
                        "rank": 2,
                    },
                    {
                        "domain": "drug_exposures",
                        "label": "Ibuprofen",
                        "source_record_id": "drug-99",
                        "why_it_may_contribute": "Not observed",
                        "confidence": "low",
                        "rank": 1,
                    },
                ]
            },
            "narrative": "Observed anticoagulation is a plausible contributor.",
            "mode": "case_causal_review",
            "diagnostics": {},
        },
        {
            "observed_items_by_domain": {
                "drug_exposures": [
                    {"domain": "drug_exposures", "label": "Warfarin", "source_record_id": "drug-1"}
                ]
            }
        },
        ["drug_exposures"],
    )
    kept = payload["candidates_by_domain"]["drug_exposures"]
    assert len(kept) == 1
    assert kept[0]["label"] == "Warfarin"
    assert kept[0]["rank"] == 1
    assert payload["diagnostics"]["dropped_unobserved_count"] == 1
