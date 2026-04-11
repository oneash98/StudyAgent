# study-agent ACP agent
Orchestrates user interaction and calls MCP tools. No direct data plane access unless explicitly required.

## ACP Server Configuration

- `STUDY_AGENT_HOST` (default `127.0.0.1`)
- `STUDY_AGENT_PORT` (default `8765`)
- Shutdown: Prefer stopping the ACP process (SIGINT/SIGTERM) so the MCP subprocess is closed cleanly. Killing the MCP directly can leave defunct processes.

## LLM Configuration (OpenAI-compatible)

Set these environment variables to enable LLM calls from ACP:

- `LLM_API_URL` (default `http://localhost:3000/api/chat/completions`)
- `LLM_API_KEY` (required)
- `LLM_MODEL` (default `agentstudyassistant`)
- `LLM_TIMEOUT` (default `300`)
- `LLM_LOG` (default `0`)
- `LLM_DRY_RUN` (default `0`)
- `LLM_USE_RESPONSES` (default `0`, use OpenAI Responses API payload/parse instead of Chat Completions; unrelated to MCP tool use)
- `LLM_CANDIDATE_LIMIT` (default `5`)
- `LLM_RECOMMENDATION_TOP_K` (default `20`)
- `LLM_RECOMMENDATION_MAX_RESULTS` (default `3`)
- `STUDY_AGENT_MCP_TIMEOUT` (default `240`)
- `EMBED_TIMEOUT` (default `120`)

Recommended timeout ladder for constrained deployments:

- `ACP_TIMEOUT > LLM_TIMEOUT > STUDY_AGENT_MCP_TIMEOUT`
- Recommended starting point: `ACP_TIMEOUT=360`, `LLM_TIMEOUT=300`, `STUDY_AGENT_MCP_TIMEOUT=240`

ACP recommendation flows now expose explicit diagnostics and fallback metadata including `llm_status`, `llm_duration_seconds`, `llm_parse_stage`, `llm_schema_valid`, `fallback_reason`, and `fallback_mode`.

To estimate environment-specific starting values instead of relying only on defaults, run `doit calibrate_timeouts`. It writes a recommended timeout env fragment and a JSON timing summary based on repeated ACP smoke-flow samples.

See `docs/TESTING.md` for CLI smoke tests.
