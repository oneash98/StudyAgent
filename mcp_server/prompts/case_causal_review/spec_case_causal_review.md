Tool: case_causal_review
Output contract:
{
  "candidates_by_domain": {
    "<domain>": [
      {
        "domain": "string",
        "label": "string",
        "source_record_id": "string",
        "why_it_may_contribute": "string <=400 chars",
        "confidence": "low|medium|high",
        "rank": 1,
        "candidate_role": "optional string",
        "evidence_basis": "optional string <=300 chars"
      }
    ]
  },
  "narrative": "string <=1200 chars",
  "mode": "case_causal_review",
  "diagnostics": {}
}

### HEURISTICS/RULES
For `case_causal_review`
- Assume the adverse event already occurred; do not return yes/no/unknown adjudication.
- `candidate_items` are the only structured ranking universe.
- `context_items` and `case_metadata` may influence reasoning but must not be ranked unless the same observed item is also present in `candidate_items`.
- `index_event` is the selected event of interest and must never be ranked as a cause.
- Use subroles as hints, not as final adjudications.
- Do not invent new structured candidates, domains, or source_record_ids.
- Multiple plausible contributors may be returned; do not force a single winner.
- Tool usage is optional. Use optional enrichment selectively and concisely when it is present.
- Prefer normalized identifiers over names when both are available.
- Ignore `not_found`, `unsupported`, or `unavailable` tool results as non-fatal.
- Narrative may discuss uncertainty or unobserved alternatives, but structured candidates must remain grounded in observed candidate items.

Constraints:
- JSON only; no markdown/fences.
- Keep output < 16 KB.
