import pytest

from study_agent_acp import server as acp_server
from study_agent_acp.mcp_client import StdioMCPClient
from study_agent_acp.agent import StudyAgent
from study_agent_acp.llm_client import LLMCallResult


@pytest.mark.acp
def test_acp_shutdown_closes_mcp_client():
    class FakeServer:
        def serve_forever(self) -> None:
            raise RuntimeError("stop")

    class FakeMCPClient:
        def __init__(self) -> None:
            self.closed = False

        def close(self) -> None:
            self.closed = True

    fake_server = FakeServer()
    fake_client = FakeMCPClient()

    try:
        acp_server._serve(fake_server, fake_client)
    except RuntimeError:
        pass

    assert fake_client.closed is True


@pytest.mark.acp
def test_mcp_health_check_success():
    class Portal:
        def call(self, func, *args, **kwargs):
            return func(*args, **kwargs)

    class Client:
        def __init__(self):
            self._portal = Portal()
            self._session = True

        def _ensure_session(self):
            return None

        def _ping(self):
            return {"ok": True}

        health_check = StdioMCPClient.health_check

    client = Client()
    assert client.health_check() == {"ok": True}


@pytest.mark.acp
def test_resolve_mcp_url_from_env(monkeypatch):
    monkeypatch.delenv("STUDY_AGENT_MCP_URL", raising=False)
    monkeypatch.setenv("MCP_TRANSPORT", "http")
    monkeypatch.setenv("MCP_HOST", "127.0.0.1")
    monkeypatch.setenv("MCP_PORT", "8790")
    monkeypatch.setenv("MCP_PATH", "/mcp")

    assert acp_server._resolve_mcp_url_from_env() == "http://127.0.0.1:8790/mcp"


@pytest.mark.acp
def test_resolve_mcp_url_from_env_prefers_explicit(monkeypatch):
    monkeypatch.setenv("STUDY_AGENT_MCP_URL", "http://example.test:9999/custom")
    monkeypatch.setenv("MCP_TRANSPORT", "http")
    monkeypatch.setenv("MCP_HOST", "127.0.0.1")
    monkeypatch.setenv("MCP_PORT", "8790")
    monkeypatch.setenv("MCP_PATH", "/mcp")

    assert acp_server._resolve_mcp_url_from_env() == "http://example.test:9999/custom"


@pytest.mark.acp
def test_health_reports_mcp_not_configured():
    handler = acp_server.ACPRequestHandler.__new__(acp_server.ACPRequestHandler)
    handler.path = "/health"
    handler.headers = {}
    handler.debug = False
    handler.agent = StudyAgent(mcp_client=None)
    handler.mcp_client = None
    handler.wfile = None
    handler.rfile = None

    captured = {}

    def fake_write_json(_handler, status, payload):
        captured["status"] = status
        captured["payload"] = payload

    original = acp_server._write_json
    acp_server._write_json = fake_write_json
    try:
        handler.do_GET()
    finally:
        acp_server._write_json = original

    assert captured["status"] == 200
    assert captured["payload"] == {
        "status": "ok",
        "mcp": {"ok": False, "configured": False, "error": "mcp_not_configured"},
        "mcp_index": {"skipped": True, "reason": "mcp_not_configured"},
    }


class StubMCPClient:
    def __init__(self) -> None:
        self.calls = []

    def list_tools(self):
        return []

    def call_tool(self, name, arguments):
        self.calls.append((name, arguments))
        if name == "phenotype_improvements":
            return {"plan": "ok", "phenotype_improvements": []}
        if name == "phenotype_prompt_bundle":
            return {"overview": "overview", "spec": "spec", "output_schema": {"type": "object"}}
        if name == "phenotype_recommendation_advice":
            return {"overview": "overview", "spec": "spec", "output_schema": {"type": "object"}}
        if name == "phenotype_intent_split":
            return {"overview": "overview", "spec": "spec", "output_schema": {"type": "object"}}
        if name == "lint_prompt_bundle":
            return {"overview": "overview", "spec": "spec", "output_schema": {"type": "object"}}
        if name == "keeper_sanitize_row":
            return {"sanitized_row": {"age_bucket": "40-44", "gender": "Male"}}
        if name == "keeper_prompt_bundle":
            return {
                "overview": "overview",
                "spec": "spec",
                "output_schema": {"type": "object"},
                "system_prompt": "system",
            }
        if name == "keeper_build_prompt":
            return {"prompt": "main"}
        if name == "keeper_parse_response":
            return {"label": "yes", "rationale": "ok"}
        if name == "keeper_concept_set_bundle":
            if arguments.get("domain_key"):
                domain_key = arguments["domain_key"]
                return {
                    "task": "keeper_concept_sets_generate",
                    "overview": "overview",
                    "domain": {
                        "parameterName": domain_key,
                        "domains": ["Condition"],
                        "conceptClasses": [],
                    },
                    "spec_generate_terms": "spec terms",
                    "spec_filter_concepts": "spec filter",
                    "output_schema_generate_terms": {"type": "object"},
                    "output_schema_filter_concepts": {"type": "object"},
                    "term_generation_prompt": f"generate {domain_key}",
                    "concept_filter_prompt": f"filter {domain_key}",
                }
            return {
                "task": "keeper_concept_sets_generate",
                "domains": [
                    {"parameterName": "doi"},
                    {"parameterName": "alternativeDiagnosis"},
                    {"parameterName": "symptoms"},
                ],
            }
        if name == "vocab_search_standard":
            term = arguments["query"]
            if "Mallory" in term:
                return {
                    "error": "vocab_search_provider_unconfigured",
                    "concepts": [],
                    "count": 0,
                }
            if "Gastrointestinal bleeding" in term or "hemorrhage" in term:
                return {
                    "concepts": [
                        {
                            "conceptId": 100,
                            "conceptName": "Gastrointestinal hemorrhage",
                            "vocabularyId": "SNOMED",
                            "domainId": "Condition",
                            "conceptClassId": "Clinical Finding",
                            "standardConcept": "S",
                            "recordCount": 50000,
                        }
                    ],
                    "count": 1,
                }
            if "abdominal pain" in term:
                return {
                    "concepts": [
                        {
                            "conceptId": 200,
                            "conceptName": "Abdominal pain",
                            "vocabularyId": "SNOMED",
                            "domainId": "Condition",
                            "conceptClassId": "Clinical Finding",
                            "standardConcept": "S",
                            "recordCount": 75000,
                        }
                    ],
                    "count": 1,
                }
            return {"concepts": [], "count": 0}
        if name == "vocab_filter_standard_concepts":
            return {"concepts": arguments.get("concepts", []), "count": len(arguments.get("concepts", []))}
        if name == "vocab_fetch_concepts":
            concepts = arguments.get("concepts", [])
            selected = set(arguments.get("concept_ids", []))
            return {
                "concepts": [concept for concept in concepts if concept.get("conceptId") in selected],
                "count": len([concept for concept in concepts if concept.get("conceptId") in selected]),
            }
        if name == "vocab_remove_descendants":
            return {"concepts": arguments.get("concepts", []), "count": len(arguments.get("concepts", []))}
        if name == "phoebe_related_concepts":
            return {"error": "phoebe_provider_unconfigured", "concepts": [], "count": 0}
        if name == "vocab_add_nonchildren":
            concepts = list(arguments.get("concepts", [])) + list(arguments.get("new_concepts", []))
            return {"concepts": concepts, "count": len(concepts)}
        if name == "propose_concept_set_diff":
            return {"plan": "ok", "findings": [], "patches": [], "actions": [], "risk_notes": []}
        if name == "cohort_lint":
            return {"plan": "ok", "findings": [], "patches": [], "actions": [], "risk_notes": []}
        raise ValueError("unexpected tool")


@pytest.mark.acp
def test_flow_phenotype_improvements_calls_tool(monkeypatch):
    import study_agent_acp.agent as agent_module

    def fake_llm(prompt):
        return {"phenotype_improvements": []}

    monkeypatch.setattr(agent_module, "call_llm", fake_llm)
    agent = StudyAgent(mcp_client=StubMCPClient())
    result = agent.run_phenotype_improvements_flow(
        protocol_text="protocol",
        cohorts=[{"id": 1}, {"id": 2}],
        characterization_previews=[],
    )
    assert result["status"] == "ok"
    assert result["tool"] == "phenotype_improvements"
    assert result["cohort_count"] == 1


@pytest.mark.acp
def test_flow_concept_sets_review_calls_tool(monkeypatch):
    import study_agent_acp.agent as agent_module

    def fake_llm(prompt):
        return {"findings": [], "patches": [], "risk_notes": [], "actions": []}

    monkeypatch.setattr(agent_module, "call_llm", fake_llm)
    agent = StudyAgent(mcp_client=StubMCPClient())
    result = agent.run_concept_sets_review_flow(
        concept_set={"items": []},
        study_intent="intent",
    )
    assert result["status"] == "ok"
    assert result["tool"] == "propose_concept_set_diff"


@pytest.mark.acp
def test_flow_cohort_critique_calls_tool(monkeypatch):
    import study_agent_acp.agent as agent_module

    def fake_llm(prompt):
        return {"findings": [], "patches": [], "risk_notes": []}

    monkeypatch.setattr(agent_module, "call_llm", fake_llm)
    agent = StudyAgent(mcp_client=StubMCPClient())
    result = agent.run_cohort_critique_general_design_flow(cohort={"PrimaryCriteria": {}})
    assert result["status"] == "ok"
    assert result["tool"] == "cohort_lint"


@pytest.mark.acp
def test_flow_phenotype_validation_review(monkeypatch):
    import study_agent_acp.agent as agent_module

    def fake_llm(prompt):
        return {"label": "yes", "rationale": "ok"}

    monkeypatch.setattr(agent_module, "call_llm", fake_llm)
    agent = StudyAgent(mcp_client=StubMCPClient())
    result = agent.run_phenotype_validation_review_flow(
        keeper_row={"age": 44, "gender": "Male"},
        disease_name="GI bleed",
    )
    assert result["status"] == "ok"
    assert result["full_result"]["label"] == "yes"


@pytest.mark.acp
def test_flow_keeper_concept_sets_generate(monkeypatch):
    import study_agent_acp.agent as agent_module

    calls = {"count": 0}

    def fake_llm(prompt, required_keys=None):
        calls["count"] += 1
        if calls["count"] == 1:
            return {"terms": ["Gastrointestinal bleeding", "hemorrhage"]}
        if calls["count"] == 2:
            return {"conceptId": [100]}
        if calls["count"] == 3:
            return {"conceptId": [100]}
        if calls["count"] == 4:
            return {"terms": ["Mallory-Weiss tear", "Peptic ulcer disease"]}
        if calls["count"] == 5:
            return {"conceptId": []}
        if calls["count"] == 6:
            return {"conceptId": []}
        if calls["count"] == 7:
            return {"terms": ["abdominal pain"]}
        if calls["count"] == 8:
            return {"conceptId": [200]}
        if calls["count"] == 9:
            return {"conceptId": [200]}
        if required_keys == ["terms"]:
            return {"terms": []}
        return {"conceptId": []}

    monkeypatch.setattr(agent_module, "call_llm", fake_llm)
    agent = StudyAgent(mcp_client=StubMCPClient())
    result = agent.run_keeper_concept_sets_generate_flow(
        phenotype="Gastrointestinal bleeding",
        include_diagnostics=True,
    )
    assert result["status"] == "ok"
    assert result["phenotype"] == "Gastrointestinal bleeding"
    assert len(result["concept_sets"]) == 2
    assert {item["conceptSetName"] for item in result["concept_sets"]} == {"doi", "symptoms"}
    assert any(domain["domain_key"] == "alternativeDiagnosis" for domain in result["domains"])
    assert result["diagnostics"]["domain_runs"][0]["domain_key"] == "doi"


@pytest.mark.acp
def test_flow_keeper_concept_sets_generate_salvages_concepts_array_schema(monkeypatch):
    import study_agent_acp.agent as agent_module

    calls = {"count": 0}

    def fake_llm(prompt, required_keys=None):
        calls["count"] += 1
        if calls["count"] == 1:
            return {"terms": ["Gastrointestinal bleeding", "hemorrhage"]}
        if calls["count"] == 2:
            return {
                "concepts": [
                    {"concept_id": 100, "concept_name": "Gastrointestinal hemorrhage"},
                ]
            }
        if calls["count"] == 3:
            return {
                "concepts": [
                    {"concept_id": 100, "concept_name": "Gastrointestinal hemorrhage"},
                ]
            }
        return {"conceptId": []}

    monkeypatch.setattr(agent_module, "call_llm", fake_llm)
    agent = StudyAgent(mcp_client=StubMCPClient())
    result = agent.run_keeper_concept_sets_generate_flow(
        phenotype="Gastrointestinal bleeding",
        domain_keys=["doi"],
        include_diagnostics=True,
    )
    assert result["status"] == "ok"
    assert len(result["concept_sets"]) == 1
    assert result["concept_sets"][0]["conceptId"] == 100
    run = result["diagnostics"]["domain_runs"][0]
    assert run["llm_filter_initial_salvage_mode"] == "concepts_array"
    assert run["llm_filter_final_salvage_mode"] == "concepts_array"


@pytest.mark.acp
def test_extract_keeper_concept_ids_handles_scalar_and_top_level_array():
    from study_agent_acp.agent import StudyAgent
    from study_agent_acp.llm_client import LLMCallResult

    agent = StudyAgent(mcp_client=StubMCPClient())

    scalar_ids, scalar_mode = agent._extract_keeper_concept_ids(
        LLMCallResult(status="ok", parsed_content={"conceptId": "439847"})
    )
    assert scalar_ids == [439847]
    assert scalar_mode == "scalar_conceptId"

    array_ids, array_mode = agent._extract_keeper_concept_ids(
        LLMCallResult(
            status="ok",
            parsed_content=[
                {"conceptId": "42872434"},
                {"concept_id": "439847"},
            ],
        )
    )
    assert array_ids == [42872434, 439847]
    assert array_mode == "top_level_array"


@pytest.mark.acp
def test_flow_phenotype_recommendation_advice(monkeypatch):
    import study_agent_acp.agent as agent_module

    captured = {}

    def fake_llm(prompt):
        captured["prompt"] = prompt
        return {
            "plan": "plan",
            "advice": "Refine intent",
            "next_steps": ["step1"],
            "questions": ["question1"],
        }

    monkeypatch.setattr(agent_module, "call_llm", fake_llm)
    agent = StudyAgent(mcp_client=StubMCPClient())
    result = agent.run_phenotype_recommendation_advice_flow(
        study_intent="Intent text",
    )
    assert result["status"] == "ok"
    assert result["llm_used"] is True
    assert result["llm_status"] == "ok"
    assert result["advice"]["advice"] == "Refine intent"
    assert "Intent text" in captured.get("prompt", "")


@pytest.mark.acp
def test_flow_phenotype_recommendation_advice_parse_failure(monkeypatch):
    import study_agent_acp.agent as agent_module

    def fake_llm(prompt, required_keys=None):
        return LLMCallResult(
            status="json_parse_failed",
            error="json_parse_failed",
            parse_stage="chat_completions_content:json_brace_extract",
            request_mode="chat_completions",
        )

    monkeypatch.setattr(agent_module, "call_llm", fake_llm)
    agent = StudyAgent(mcp_client=StubMCPClient())
    result = agent.run_phenotype_recommendation_advice_flow(
        study_intent="Intent text",
    )
    assert result["status"] == "ok"
    assert result["llm_used"] is False
    assert result["llm_status"] == "json_parse_failed"
    assert result["fallback_reason"] == "llm_json_parse_failed"
    assert result["fallback_mode"] == "stub"
    assert result["advice"]["mode"] == "stub"


@pytest.mark.acp
def test_flow_phenotype_recommendation_advice_missing_intent():
    agent = StudyAgent(mcp_client=StubMCPClient())
    result = agent.run_phenotype_recommendation_advice_flow(study_intent="")
    assert result["status"] == "error"
    assert result["error"] == "missing study_intent"


@pytest.mark.acp
def test_flow_phenotype_recommendation_advice_prompt_bundle_error(monkeypatch):
    import study_agent_acp.agent as agent_module

    def fake_llm(prompt):
        return {"advice": "unused"}

    monkeypatch.setattr(agent_module, "call_llm", fake_llm)

    class BadMCPClient(StubMCPClient):
        def call_tool(self, name, arguments):
            if name == "phenotype_recommendation_advice":
                return {"error": "bad prompt"}
            return super().call_tool(name, arguments)

    agent = StudyAgent(mcp_client=BadMCPClient())
    result = agent.run_phenotype_recommendation_advice_flow(
        study_intent="Intent text",
    )
    assert result["status"] == "error"
    assert result["error"] == "phenotype_recommendation_advice_prompt_failed"


@pytest.mark.acp
def test_flow_phenotype_intent_split(monkeypatch):
    import study_agent_acp.agent as agent_module

    captured = {}

    def fake_llm(prompt):
        captured["prompt"] = prompt
        return {
            "plan": "plan",
            "target_statement": "Target cohort",
            "outcome_statement": "Outcome cohort",
            "rationale": "Rationale",
            "questions": ["question1"],
        }

    monkeypatch.setattr(agent_module, "call_llm", fake_llm)
    agent = StudyAgent(mcp_client=StubMCPClient())
    result = agent.run_phenotype_intent_split_flow(
        study_intent="Intent text",
    )
    assert result["status"] == "ok"
    assert result["llm_used"] is True
    assert result["llm_status"] == "ok"
    assert result["intent_split"]["target_statement"] == "Target cohort"
    assert "Intent text" in captured.get("prompt", "")


@pytest.mark.acp
def test_flow_phenotype_intent_split_schema_mismatch(monkeypatch):
    import study_agent_acp.agent as agent_module

    def fake_llm(prompt, required_keys=None):
        return LLMCallResult(
            status="schema_mismatch",
            parsed_content={"target_statement": "Target only"},
            parse_stage="chat_completions_content:schema",
            error="missing_required_keys:outcome_statement,rationale",
            missing_keys=["outcome_statement", "rationale"],
            schema_valid=False,
            request_mode="chat_completions",
        )

    monkeypatch.setattr(agent_module, "call_llm", fake_llm)
    agent = StudyAgent(mcp_client=StubMCPClient())
    result = agent.run_phenotype_intent_split_flow(
        study_intent="Intent text",
    )
    assert result["status"] == "error"
    assert result["error"] == "llm_unavailable"
    assert result["diagnostics"]["llm_status"] == "schema_mismatch"
    assert result["diagnostics"]["llm_missing_keys"] == ["outcome_statement", "rationale"]


@pytest.mark.acp
def test_flow_phenotype_intent_split_missing_intent():
    agent = StudyAgent(mcp_client=StubMCPClient())
    result = agent.run_phenotype_intent_split_flow(study_intent="")
    assert result["status"] == "error"
    assert result["error"] == "missing study_intent"


@pytest.mark.acp
def test_flow_phenotype_intent_split_prompt_bundle_error(monkeypatch):
    import study_agent_acp.agent as agent_module

    def fake_llm(prompt):
        return {"target_statement": "unused"}

    monkeypatch.setattr(agent_module, "call_llm", fake_llm)

    class BadMCPClient(StubMCPClient):
        def call_tool(self, name, arguments):
            if name == "phenotype_intent_split":
                return {"error": "bad prompt"}
            return super().call_tool(name, arguments)

    agent = StudyAgent(mcp_client=BadMCPClient())
    result = agent.run_phenotype_intent_split_flow(
        study_intent="Intent text",
    )
    assert result["status"] == "error"
    assert result["error"] == "phenotype_intent_split_prompt_failed"
