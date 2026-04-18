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
        "rank": 1
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
- Rank only observed candidate items present in the supplied review row.
- Evaluate each candidate using these elements of the Bradford Hill criteria (in no particular order) to assess if observed association is likely to be causal in epidemiology: temporality, plausibility, coherence, experiment (e.g., dechallenge/rechallenge), and analogy.
- Do not invent new structured candidates, domains, or source_record_ids.
- The ranking unit is the individual observed item, not the domain.
- Multiple plausible contributors may be returned; do not force a single winner.
- Use sparse output. Omit empty domains.
- Narrative may discuss uncertainty or alternatives, but structured candidates must remain grounded in supplied observed items.

Constraints:
- JSON only; no markdown/fences.
- Keep output < 16 KB.
