**Keeper Expansion Plan**

The Keeper expansion should be implemented as three linked capabilities:

1. concept-set generation
2. profile extraction from OMOP CDM
3. patient-row adjudication

The end-to-end workflow should be:

1. user provides a clinical event of interest
2. `/flows/keeper_concept_sets_generate` generates Keeper input concept sets
3. user reviews and approves those concept sets
4. `/flows/keeper_profiles_generate` extracts Keeper-style patient review rows from OMOP CDM using the approved concept sets
5. `/flows/phenotype_validation_review` evaluates one or more sanitized review rows with the LLM

This keeps the architecture aligned with Keeper’s actual separation between concept-set generation, profile construction, and case review.

**Flows**
`/flows/keeper_concept_sets_generate`
- Purpose: generate Keeper input concept sets equivalent to Keeper’s `generateKeeperConceptSets()`.
- Input:
  - `phenotype`
  - optional domain subset
  - provider overrides for vocabulary search and Phoebe
  - tuning controls like search limits and min record count
- Output:
  - flat Keeper-style concept table with:
    - `conceptId`
    - `conceptName`
    - `vocabularyId`
    - `conceptSetName`
    - `target`
  - structured `keeper_concept_sets`
  - diagnostics per domain and per step
- LLM use: yes
- Patient data: none

`/flows/keeper_profiles_generate`
- Purpose: generate Keeper-style patient review rows from OMOP CDM using approved concept sets, analogous to Keeper’s `generateKeeper()`.
- Input:
  - OMOP connection/config reference
  - cohort source/table details
  - cohort definition id and/or sampled person ids
  - approved `keeper_concept_sets`
  - sampling controls
  - descendant inclusion flag
- Output:
  - Keeper review rows suitable for downstream review
  - optional table-oriented output for CSV/UI consumption
  - extraction metadata and counts
- LLM use: no
- Patient data: yes, but only deterministic local processing

`/flows/phenotype_validation_review`
- Purpose: adjudicate whether a sanitized patient review row supports the event of interest.
- Input:
  - `disease_name`
  - one or more Keeper review rows
- Output:
  - `label`
  - `rationale`
  - diagnostics
- LLM use: yes
- Patient data: sanitized only

**MCP Tools**
Prompt/config tools:
- `keeper_concept_set_bundle`
- `keeper_prompt_bundle`
- `keeper_build_prompt`
- `keeper_parse_response`

Vocabulary/provider tools:
- `vocab_search_standard`
- `phoebe_related_concepts`
- `vocab_filter_standard_concepts`
- `vocab_remove_descendants`
- `vocab_add_nonchildren`
- `vocab_fetch_concepts`

Profile extraction tools:
- `keeper_profile_extract`
- `keeper_profile_to_rows`
- `keeper_sanitize_profile_row`

`keeper_profile_extract` is the key new deterministic MCP tool. It should use `OMOP_Alchemy` as the primary OMOP CDM access layer. This tool should query the cohort/sample and construct review evidence across Keeper-relevant categories using approved concept sets. It should not involve the LLM.

**Use of OMOP_Alchemy**
All OMOP-backed MCP tools should use `OMOP_Alchemy` first, especially for:
- `Concept`
- `Concept_Ancestor`
- `Concept_Relationship`
- `Condition_Occurrence`
- `Condition_Era`
- `Drug_Era`
- `Procedure_Occurrence`
- `Measurement`
- `Death`
- `Person`
- `Visit_Occurrence`
- `Observation_Period`
- `Cohort`
- `CDM_Source`

This should be wrapped in a small internal DB/session utility module inside Study Agent so MCP tools can consistently:
- create engines/sessions
- resolve schema/table configuration
- run common OMOP lookups
- normalize outputs

Hecate or other external search services should remain optional provider layers for vector search and Phoebe-like recommendations. Returned concept IDs should be validated and enriched against local OMOP vocabulary using `OMOP_Alchemy`.

**Keeper Domain Model**
Study Agent should mirror Keeper’s concept-set generation categories, not downstream review fields. The canonical concept-set categories are:
- `doi`
- `alternativeDiagnosis`
- `symptoms`
- `drugs`
- `diagnosticProcedures`
- `measurements`
- `treatmentProcedures`
- `complications`

The review rows extracted later may populate fields such as presentation, prior disease, prior drugs, post disease, post drugs, and death. Those are profile-extraction outputs, not separate concept-generation domains.

**PHI-Safe Data Boundaries**
This must be a hard architectural rule:

No raw row-level patient data containing direct or indirect PII/PHI may ever be sent to an LLM.

The boundary should be:
- concept-set generation: no patient data involved
- profile extraction: patient data allowed, deterministic local processing only
- validation review: sanitized rows only

Required behavior:
- raw extracted review rows may exist only inside deterministic MCP processing or local persisted outputs
- any LLM-facing path must pass through a fail-closed sanitization gate
- `keeper_build_prompt` must only accept sanitized row payloads
- if sanitization fails, the row must not be sent to the LLM

The sanitization policy should explicitly strip or transform:
- person ids
- visit ids
- MRNs and account numbers
- exact dates/timestamps
- addresses and locations
- provider/site identifiers if sensitive
- exact ages where bucketing is required
- free-text fields that may contain identifiers

Allowed LLM payloads should be limited to review-safe abstractions such as:
- age bucket
- generalized visit context
- concept names
- relative timing if needed
- scrubbed measurement summaries

**Audit And Governance**
This should be treated as a first-class requirement for organizations using cloud/commercial LLMs.

For every outbound LLM call, Study Agent should record:
- initiating user or service identity
- timestamp
- flow name and version
- MCP tool/template versions used
- model, provider, and endpoint
- whether the call was local/self-hosted or external/cloud
- sanitization status and sanitization tool/version
- policy decision: allowed or blocked
- hash of sanitized prompt payload
- hash of model response
- dataset/cohort/concept-set artifact identifiers

It must not log:
- raw unsanitized patient rows
- secrets
- direct identifiers

Recommended audit modes:
- `strict_metadata_only`
- `sealed_payload_logging`

Recommended governance controls:
- provider allowlist
- outbound egress policy
- configurable retention for audit records
- reproducibility via config snapshot and template version capture
- optional approval workflow before external callouts

**Implementation Phases**
1. Prompt/config foundation
- add Keeper concept-set prompt assets under `mcp_server/prompts/keeper_concept_sets/`
- add domain config file matching Keeper prompt-set structure

2. Vocabulary/provider tooling
- implement normalized vocab/Phoebe MCP tools
- support `hecate_api` first
- add `generic_search_api` and DB-backed fallback modes

3. OMOP DB access layer
- add internal Study Agent session/config wrapper around `OMOP_Alchemy`

4. Concept-set generation
- implement `/flows/keeper_concept_sets_generate`
- add domain-level tests and one smoke path

5. Profile extraction
- implement `keeper_profile_extract`
- implement `/flows/keeper_profiles_generate`
- ensure no LLM use in this flow

6. Sanitization hardening
- formalize `keeper_sanitize_profile_row`
- enforce sanitized-only prompt building

7. Integrated case review
- update `phenotype_validation_review` to support one or more sanitized Keeper rows
- add smoke test for:
  - concept sets generate
  - profiles generate
  - phenotype validation review

8. Audit/governance layer
- add ACP-side LLM audit logging
- add metadata capture for sanitization and outbound egress

**Summary**
The correct Study Agent design is:

- `keeper_concept_sets_generate` produces approved concept sets
- `keeper_profiles_generate` uses those concept sets plus OMOP CDM data to build review rows
- `phenotype_validation_review` evaluates sanitized rows only
- `OMOP_Alchemy` is the primary OMOP access layer
- all LLM egress is sanitized, auditable, and policy-controlled

The next concrete step should be to define the JSON interfaces for:
- `/flows/keeper_concept_sets_generate`
- `/flows/keeper_profiles_generate`
- the `keeper_profile_row` schema
- the audit metadata envelope for outbound LLM calls
