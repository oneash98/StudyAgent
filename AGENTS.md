# Repository Guidelines

## Project Structure & Module Organization
`core/study_agent_core/` contains shared validation, models, and deterministic business logic. `acp_agent/study_agent_acp/` hosts the ACP orchestration server and demo shell. `mcp_server/study_agent_mcp/` exposes MCP tools, prompts, and retrieval/indexing code. `tests/` holds Python unit and smoke tests, while `scripts/` contains support scripts and R-based workflow checks. Documentation lives in `docs/`, demo payloads in `demo/`, sample indexes under `data/`, and the R package shell in `R/OHDSIAssistant/`.

## Build, Test, and Development Commands
Install editable packages first:

```bash
pip install -e .
```

Common development commands:

```bash
doit list          # list available tasks
doit test_core     # run core-marked pytest tests
doit test_acp      # run ACP-marked pytest tests
doit test_mcp      # run MCP-marked pytest tests
doit test_all      # run the full Python test suite
pytest -v          # direct pytest run with verbose output
study-agent-mcp    # start the MCP server
study-agent-acp    # start the ACP server
```

Use `PYTEST_OPTS="-vv -rA -s"` to pass extra pytest flags through `doit`.

## Coding Style & Naming Conventions
Follow existing Python style: 4-space indentation, `snake_case` for functions/modules, `PascalCase` for Pydantic models, and short docstrings or comments only when the logic is not obvious. Keep shared logic in `core/` when both ACP and MCP need it. Prefer small, deterministic helpers over embedding policy inside request handlers. Match existing JSON field names exactly, including camelCase fields that mirror external payloads.

## Testing Guidelines
Tests use `pytest` with markers declared in `pytest.ini`: `core`, `acp`, and `mcp`. Name files `test_*.py`; reserve `*_smoke_test.py` for workflow smoke coverage. Add or update tests with every behavior change, especially around flow fallbacks, tool registration, and sanitization. For end-to-end validation, use the smoke tasks documented in `docs/TESTING.md`.

## Commit & Pull Request Guidelines
Recent history favors short, imperative commit subjects such as `Update video link in README.md` or `file location clean up`. Keep subjects concise and specific to one change. PRs should describe the workflow impact, list test coverage run locally, link any related issue, and include request/response examples or screenshots when UI or API behavior changes.

## Security & Configuration Tips
Use `.env.example`, `environment.yml`, and `compose.yaml` as starting points for local setup. Never commit secrets or raw patient-level data. LLM-facing flows must preserve the repo’s fail-closed sanitization approach described in `README.md` and `docs/TESTING.md`.

## Subagent Usage
This repository defines custom Codex subagents under `.codex/agents/`.
The main agent may spawn these subagents proactively when they would materially improve correctness, speed, or clarity, even if the user did not explicitly name a specific subagent.

Use the smallest number of subagents needed for the task, and keep responsibilities separated.
Do not spawn subagents for trivial single-file edits or straightforward answers that can be completed faster locally.

### Available Subagents
- `worker`
  - Primary implementation agent for direct code edits, focused fixes, and test updates. Handles code changes only, not README/docs or other documentation work.
- `reviewer`
  - Read-only reviewer for plan validation, implementation guidance, and final risk review.
- `codebase_analyst`
  - Structure and dependency analyst that may document existing implemented structures, reusable patterns, and future reuse points, but must not modify application code.
- `test_debugger`
  - Read-only testing and debugging agent that runs checks, analyzes failures, and recommends the next fix.
- `documentation_writer`
  - Documentation agent for `README.md`, `docs/`, `.codex/`, and related project docs.

### When To Spawn
- Spawn `reviewer` before implementation when a task has ambiguous design choices, cross-package impact, sanitization risk, or non-obvious regression risk.
- Spawn `reviewer` again after implementation for a read-only correctness and test coverage review when the change is substantial.
- Spawn `codebase_analyst` when work spans multiple directories and the team would benefit from a map of ownership boundaries, reusable modules, existing patterns, or dependency relationships.
- Spawn `worker` when the task is implementation-heavy and there is clear bounded code ownership for the change.
- Spawn `test_debugger` after meaningful code changes, when tests fail, or when behavior is unclear and reproduction plus failure analysis would help choose the next edit.
- Spawn `documentation_writer` when behavior, workflows, setup, or exposed interfaces changed and docs should be updated to match the implemented state.

### Recommended Default Workflow
- For non-trivial tasks, consider `reviewer` first for plan sanity checking.
- If the task touches multiple subsystems such as `core/`, `acp_agent/`, and `mcp_server/`, use `codebase_analyst` to map relevant paths and reuse opportunities before editing.
- Use `worker` for the actual code change.
- Use `test_debugger` for targeted verification and failure diagnosis.
- Use `documentation_writer` for any user-facing or developer-facing documentation changes.
- Re-run `reviewer` for a final read-only pass when the task carries correctness, safety, or regression risk.

### Repository-Specific Guidance
- Prefer `worker` for edits inside one clear module or one bounded feature slice.
- Prefer `codebase_analyst` before editing when deciding whether shared logic belongs in `core/study_agent_core/` versus ACP-specific or MCP-specific modules, or when documenting structure and reuse guidance for future work.
- Prefer `reviewer` for changes affecting sanitization, tool registration, flow fallbacks, request/response contracts, or cross-boundary behavior between ACP and MCP.
- Prefer `test_debugger` for failures involving pytest markers (`core`, `acp`, `mcp`), smoke coverage, shell flows, or regressions that need precise reproduction steps.
- Prefer `documentation_writer` when updating service descriptions, testing instructions, setup steps, or workflow docs so that documentation reflects actual implemented behavior rather than roadmap intent.
