# Testing

This repo uses lightweight CLI smoke tests for the ACP and MCP layers. Keep these steps in sync as the interfaces evolve.

## Install (required before tests)

Install the repo in editable mode so the CLI entrypoints are on your PATH and changes take effect immediately:

```bash
pip install -e .
```

Editable mode means Python imports the local source tree directly. You do not need to reinstall after edits; just re-run the commands. Manage this per environment (venv/conda) and remove with `pip uninstall study-agent` if needed.

## Test output verbosity

Use pytest's built-in verbosity:

```bash
pytest -v
```

Or enable per-test progress lines via environment variable:

```bash
STUDY_AGENT_PYTEST_PROGRESS=1 pytest
```

You can also set `PYTEST_OPTS` and `doit` will pass it through:

```bash
PYTEST_OPTS="-vv -rA -s" doit run_all_tests
```

## ACP/MCP test groups

- `pytest -m acp` covers ACP flow tests (including phenotype flow).
- `pytest -m mcp` covers MCP tool tests (including prompt bundles and search weights).

## Task runner (doit)

List tasks:

```bash
doit list
```

Common tasks but see `doit list` for the most current set:

```bash
doit install
doit test_unit
doit test_core
doit test_acp
doit test_all
```

Task dependencies:

- `test_unit` depends on `test_core` and `test_acp`

## ACP smoke test (core fallback)

Start the ACP shim with core fallback enabled:

```bash
STUDY_AGENT_ALLOW_CORE_FALLBACK=1 study-agent-acp
```

In another shell:

```bash
curl -s http://127.0.0.1:8765/health
curl -s http://127.0.0.1:8765/tools
curl -s -X POST http://127.0.0.1:8765/tools/call \
  -H 'Content-Type: application/json' \
  -d '{"name":"cohort_lint","arguments":{"cohort":{"PrimaryCriteria":{"ObservationWindow":{"PriorDays":0}}}}}'
```

### PowerShell (Windows) equivalents

Notes:
- PowerShell aliases `curl` to `Invoke-WebRequest`. Use `curl.exe` for real curl, or use `Invoke-RestMethod` below.
- Use here-strings to keep JSON readable.

Start ACP with verbose logging (server + LLM):

```powershell
$env:STUDY_AGENT_ALLOW_CORE_FALLBACK = "1"
$env:STUDY_AGENT_DEBUG = "1"
$env:LLM_LOG = "1"
study-agent-acp
```

If you launch from outside the repo root, set `STUDY_AGENT_BASE_DIR` so relative paths (index, banner, outputs) resolve correctly:

```powershell
$env:STUDY_AGENT_BASE_DIR = "C:\path\to\OHDSI-Study-Agent"
```

Windows note: ACP defaults MCP to oneshot mode on Windows to avoid stdio lockups. You can also set it explicitly:

```powershell
$env:STUDY_AGENT_MCP_ONESHOT = "1"
```

ACP uses a threaded HTTP server by default. To disable threading:

```powershell
$env:STUDY_AGENT_THREADING = "0"
```

Health/tools checks:

```powershell
curl.exe -s http://127.0.0.1:8765/health
curl.exe -s http://127.0.0.1:8765/tools
curl.exe -s http://127.0.0.1:8765/services
```

Tool call (Invoke-RestMethod):

```powershell
$body = @'
{"name":"cohort_lint","arguments":{"cohort":{"PrimaryCriteria":{"ObservationWindow":{"PriorDays":0}}}}}
'@

Invoke-RestMethod `
  -Method Post `
  -Uri http://127.0.0.1:8765/tools/call `
  -Headers @{ "Content-Type" = "application/json" } `
  -Body $body
```

Tool call (curl.exe):

```powershell
$body = @'
{"name":"cohort_lint","arguments":{"cohort":{"PrimaryCriteria":{"ObservationWindow":{"PriorDays":0}}}}}
'@

curl.exe -s -X POST http://127.0.0.1:8765/tools/call `
  -H "Content-Type: application/json" `
  -d $body
```

## ACP smoke test (MCP-backed)

Start ACP with an MCP tool server:

```bash
STUDY_AGENT_MCP_COMMAND=study-agent-mcp STUDY_AGENT_MCP_ARGS="" study-agent-acp
```

This uses stdio MCP mode. If you use HTTP MCP, do not set `STUDY_AGENT_MCP_COMMAND`.

HTTP MCP mode (recommended for cross-platform stability):

```bash
export MCP_TRANSPORT=http
export MCP_HOST=127.0.0.1
export MCP_PORT=8790
export MCP_PATH=/mcp
study-agent-mcp
```

Then in a second shell:

```bash
export STUDY_AGENT_MCP_URL="http://127.0.0.1:8790/mcp"
study-agent-acp
```

Note: `STUDY_AGENT_MCP_URL` must include the port (e.g. `:8790`).
When set, ACP uses HTTP and ignores `STUDY_AGENT_MCP_COMMAND`.

PowerShell (Windows) MCP HTTP mode:

```powershell
$env:MCP_TRANSPORT = "http"
$env:MCP_HOST = "127.0.0.1"
$env:MCP_PORT = "8790"
$env:MCP_PATH = "/mcp"
study-agent-mcp
```

Then in a second PowerShell:

```powershell
$env:STUDY_AGENT_MCP_URL = "http://127.0.0.1:8790/mcp"
study-agent-acp
```

Health check (PowerShell):

```powershell
Invoke-RestMethod -Uri http://127.0.0.1:8765/health
```

Windows logging (redirect stdout/stderr to files):

```powershell
study-agent-mcp 1> mcp.out.log 2> mcp.err.log
study-agent-acp 1> acp.out.log 2> acp.err.log
```

Or using `Start-Process`:

```powershell
Start-Process study-agent-mcp -RedirectStandardOutput mcp.out.log -RedirectStandardError mcp.err.log
Start-Process study-agent-acp -RedirectStandardOutput acp.out.log -RedirectStandardError acp.err.log
```

Recommended MCP environment (use absolute paths for stability):

```bash
export PHENOTYPE_INDEX_DIR="/absolute/path/to/phenotype_index"
export EMBED_URL="http://localhost:3000/ollama/api/embed"
export EMBED_MODEL="qwen3-embedding:4b"
```

Optional host/port override:

```bash
STUDY_AGENT_HOST=0.0.0.0 STUDY_AGENT_PORT=9000 study-agent-acp
```

Then run the same curl commands as above.

Health check now includes MCP index preflight details under `mcp_index`:

```bash
curl -s http://127.0.0.1:8765/health
```

## ACP phenotype flow (MCP + LLM)

Ensure MCP is running and set LLM env vars for an OpenAI-compatible endpoint:

```bash
export LLM_API_URL="http://localhost:3000/api/chat/completions"
export LLM_API_KEY="..."
export LLM_MODEL="gemma3:4b"
export LLM_DRY_RUN=0
export LLM_USE_RESPONSES=0
export LLM_LOG=1
export LLM_TIMEOUT=300
export STUDY_AGENT_MCP_TIMEOUT=240
export ACP_TIMEOUT=360
export EMBED_TIMEOUT=120
export LLM_CANDIDATE_LIMIT=5
export LLM_RECOMMENDATION_MAX_RESULTS=3
```

`LLM_LOG=1` enables verbose LLM logging to ACP stdout (config, prompt, raw response).
For OpenWebUI using `/api/chat/completions`, keep `LLM_USE_RESPONSES=0` (the Responses API schema is not supported and can yield empty outputs).
Recommended timeout ladder: `ACP_TIMEOUT > LLM_TIMEOUT > STUDY_AGENT_MCP_TIMEOUT`.

Then call:

```bash
curl -s -X POST http://127.0.0.1:8765/flows/phenotype_recommendation \
  -H 'Content-Type: application/json' \
  -d '{"study_intent":"Identify clinical risk factors for older adult patients who experience an adverse event of acute gastro-intenstinal (GI) bleeding", "top_k":20, "max_results":10,"candidate_limit":10}'
```

Expected recommendation responses now include `llm_used`, `llm_status`, `fallback_reason`, `fallback_mode`, and `diagnostics`. If the LLM path fails to parse or validate, ACP still returns `status: ok` with an explicit machine-readable fallback reason instead of silently degrading.

## Timeout calibration

Use the automated calibration task to derive environment-specific starting values for `EMBED_TIMEOUT`, `STUDY_AGENT_MCP_TIMEOUT`, `LLM_TIMEOUT`, and `ACP_TIMEOUT`:

```bash
doit calibrate_timeouts
```

What it does:

- starts MCP and ACP if they are not already running
- warms up and samples `phenotype_intent_split`, `phenotype_recommendation_advice`, and `phenotype_recommendation`
- tests multiple recommendation prompt sizes using `TIMEOUT_CALIBRATION_CANDIDATE_LIMITS` (default `3,5,8`)
- uses ACP diagnostics plus MCP embedding debug logs to recommend timeouts with safety margins

Useful overrides:

```bash
export TIMEOUT_CALIBRATION_RUNS=3
export TIMEOUT_CALIBRATION_CANDIDATE_LIMITS=3,5,8
export TIMEOUT_CALIBRATION_ENV_PATH=/tmp/study_agent_timeout_recommendations.env
export TIMEOUT_CALIBRATION_JSON_PATH=/tmp/study_agent_timeout_recommendations.json
doit calibrate_timeouts
```

Outputs:

- `.env` fragment with recommended timeout values
- JSON summary with observed p95 timings, fallback statuses, and per-run details

Interpretation notes:

- If the calibration run reports repeated `llm_status != ok`, fix LLM parsing/compatibility first rather than only raising timeouts.
- If larger `candidate_limit` values sharply increase latency, prefer a smaller `LLM_CANDIDATE_LIMIT` before increasing `LLM_TIMEOUT`.
- Treat the generated values as good starting points for that environment, not universal maxima.

Phenotype intent split (target/outcome statements):

```bash
curl -s -X POST http://127.0.0.1:8765/flows/phenotype_intent_split \
  -H 'Content-Type: application/json' \
  -d '{"study_intent":"Identify clinical risk factors for older adult patients who experience an adverse event of acute gastro-intenstinal (GI) bleeding"}'
```

PowerShell (Windows) equivalent:

```powershell
$body = @{
  study_intent = "Identify clinical risk factors for older adult patients who experience an adverse event of acute gastro-intenstinal (GI) bleeding"
} | ConvertTo-Json

Invoke-RestMethod `
  -Method Post `
  -Uri http://127.0.0.1:8765/flows/phenotype_intent_split `
  -Headers @{ "Content-Type" = "application/json" } `
  -Body $body `
  -TimeoutSec 180
```

## ACP flow examples (MCP-backed)

Phenotype improvements:

```bash
curl -s -X POST http://127.0.0.1:8765/flows/phenotype_improvements \
  -H 'Content-Type: application/json' \
  -d '{"protocol_text":"Example protocol text","cohorts":[{"id":1,"name":"Example"}],"characterization_previews":[]}'
```

Using file paths:

```bash
curl -s -X POST http://127.0.0.1:8765/flows/phenotype_improvements \
  -H 'Content-Type: application/json' \
  -d '{"protocol_path":"demo/protocol.md","cohort_paths":["demo/1197_Acute_gastrointestinal_bleeding.json"]}'
```

Concept sets review:

```bash
curl -s -X POST http://127.0.0.1:8765/flows/concept_sets_review \
  -H 'Content-Type: application/json' \
  -d '{"concept_set":{"items":[]},"study_intent":"Example intent"}'
```

Cohort critique (general design):

```bash
curl -s -X POST http://127.0.0.1:8765/flows/cohort_critique_general_design \
  -H 'Content-Type: application/json' \
  -d '{"cohort":{"PrimaryCriteria":{}}}'
```

Using file paths:

```bash
curl -s -X POST http://127.0.0.1:8765/flows/concept_sets_review \
  -H 'Content-Type: application/json' \
  -d '{"concept_set_path":"demo/concept_set.json","study_intent":"Example intent"}'

curl -s -X POST http://127.0.0.1:8765/flows/cohort_critique_general_design \
  -H 'Content-Type: application/json' \
  -d '{"cohort_path":"demo/cohort_definition.json"}'
```

Phenotype validation review (single patient):

```bash
curl -s -X POST http://127.0.0.1:8765/flows/phenotype_validation_review \
  -H 'Content-Type: application/json' \
  -d '{"disease_name":"Gastrointestinal bleeding","keeper_row":{"age":44,"gender":"Male","visitContext":"Inpatient Visit","presentation":"Gastrointestinal hemorrhage","priorDisease":"Peptic ulcer","symptoms":"","comorbidities":"","priorDrugs":"celecoxib","priorTreatmentProcedures":"","diagnosticProcedures":"","measurements":"","alternativeDiagnosis":"","afterDisease":"","afterDrugs":"Naproxen","afterTreatmentProcedures":""}}'
```

Keeper concept sets generate:

```For the ACP/MCP using Hecate

export VOCAB_SEARCH_PROVIDER=hecate_api
export VOCAB_SEARCH_URL="https://hecate.pantheon-hds.com/api/search_standard"
export PHOEBE_PROVIDER=hecate_api
export PHOEBE_URL_TEMPLATE="https://hecate.pantheon-hds.com/api/concepts/{concept_id}/phoebe"
```

Then...
```bash
curl -s -X POST http://127.0.0.1:8765/flows/keeper_concept_sets_generate \
  -H 'Content-Type: application/json' \
  -d '{"phenotype":"Gastrointestinal bleeding","domain_keys":["doi","alternativeDiagnosis","symptoms"],"candidate_limit":10,"include_diagnostics":true}'
```

```bash
curl -s -X POST http://127.0.0.1:8765/tools/call \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "keeper_concept_set_bundle",
    "arguments": {
      "phenotype": "Gastrointestinal bleeding",
      "domain_key": "doi",
      "target": "Disease of interest"
    }
  }'
```

```bash
curl -s -X POST http://127.0.0.1:8765/tools/call \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "vocab_search_standard",
    "arguments": {
      "query": "gastrointestinal hemorrhage",
      "domains": ["Condition"],
      "concept_classes": [],
      "limit": 5,
      "provider": "hecate_api"
    }
  }'
```

```bash
curl -s -X POST http://127.0.0.1:8765/tools/call   -H 'Content-Type: application/json'   -d '{
    "name": "phoebe_related_concepts",
    "arguments": {
      "concept_ids": [192671],
      "relationship_ids": [],
      "provider": "hecate_api"
    }
  }' | python -m json.tool
```

```For the ACP/MCP using a local embedding API and Pheobe by database connection

export VOCAB_SEARCH_PROVIDER=generic_search_api
export VOCAB_SEARCH_URL="VOCAB_SEARCH_URL="http://127.0.0.1:30080/search"
export PHOEBE_PROVIDER=
export PHOEBE_URL_TEMPLATE=

curl -s -X POST http://127.0.0.1:8765/tools/call   -H 'Content-Type: application/json'   -d '{
    "name": "vocab_search_standard",
    "arguments": {
      "query": "Instruction: retrieve the concepts most related to the query. Query: intracranial hemmhorage",
      "domains": ["Condition"],
      "concept_classes": [],
      "limit": 5,
      "provider": "generic_search_api"
    }
  }'


------------

PHOEBE_PROVIDER=db
# URL encoded pword
VOCAB_DB_ENGINE='postgresql://rdb20:T7y7ZWdL%21%40@localhost:6433/cem' 
VOCAB_DATABASE_SCHEMA=vocabulary
PHOEBE_DB_TABLE=concept_recommended
VOCAB_CONCEPT_TABLE=concept

curl -s -X POST http://127.0.0.1:8765/tools/call   -H 'Content-Type: application/json'   -d '{
    "name": "phoebe_related_concepts",
    "arguments": {
      "concept_ids": [192671],
      "relationship_ids": ["Patient context"],
      "provider": "db"
    }
  }'


## Phenotype flow smoke test (ACP + MCP)

Run the Python smoke test via `doit`:

```bash
doit smoke_phenotype_flow
```

If you want `doit` to spin up MCP over HTTP automatically, set:

```bash
export STUDY_AGENT_MCP_URL="http://127.0.0.1:8790/mcp"
export STUDY_AGENT_MCP_MANAGED=1
export MCP_START_TIMEOUT=3
```

Note: the smoke tasks set `ACP_URL` internally per flow. Avoid exporting a global `ACP_URL` unless you intend to override the target flow.

## Concept sets review smoke test

```bash
doit smoke_concept_sets_review_flow
```

## Cohort critique smoke test

```bash
doit smoke_cohort_critique_flow
```

## Phenotype validation review smoke test

```bash
doit smoke_phenotype_validation_review_flow
```

## Keeper concept sets generate smoke test

```bash
doit smoke_keeper_concept_sets_generate_flow
```

## MCP smoke test (import)

```bash
python -c "import study_agent_mcp; print('mcp import ok')"
```

## MCP probe (index + search)

This checks index paths and runs a simple search, without ACP.

```bash
python mcp_server/scripts/mcp_probe.py --query "acute GI bleed in hospitalized patients" --top-k 5
```

PowerShell (Windows) equivalent:

```powershell
python mcp_server/scripts/mcp_probe.py --query "acute GI bleed in hospitalized patients" --top-k 5
```

Print and sort environment variables (PowerShell):

```powershell
Get-ChildItem Env: | Sort-Object Name
```

## Service listing

Use the `/services` endpoint (or the helper task) to list ACP services:

```bash
doit list_services
```

## Stop server

Press `Ctrl+C` in the terminal running `study-agent-acp` to stop the server.
