## Environment

export EMBED_MODEL=bedrock:amazon.titan-embed-text-v2:0
export EMBED_API_KEY=none
export EMBED_URL=http://127.0.0.1:8000/v1/embeddings
export EMBED_TIMEOUT=60
export LLM_API_KEY=none
export LLM_API_URL=http://127.0.0.1:8000/api/chat/completions
export LLM_MODEL=bedrock:us.anthropic.claude-sonnet-4-6
export LLM_TIMEOUT=120
export LLM_USE_RESPONSES=0
export VOCAB_SEARCH_PROVIDER=hecate_api
export VOCAB_SEARCH_URL="https://hecate.pantheon-hds.com/api/search_standard"

export PHOEBE_PROVIDER=db
export PHOEBE_RELATIONSHIP_IDS="Lexical via source,Patient context"
export PHOEBE_MAX_CONCEPTS_PER_RELATIONSHIP=10
export PHOEBE_MAX_CONCEPTS=20

export export OMOP_DB_ENGINE='postgresql://****:****@localhost:6432/gsph_pace'
export VOCAB_DATABASE_SCHEMA=vocabulary
export PHOEBE_DB_TABLE=concept_recommended
export VOCAB_CONCEPT_TABLE=concept

## Embedding preparation using the bedrock-hosted  model

python mcp_server/scripts/build_phenotype_index.py \
  --metadata-csv /ai-agent/HadesProject/OHDSI-Study-Agent/data/Cohorts.csv \
  --definitions-dir /ai-agent/HadesProject/OHDSI-Study-Agent/data/cohorts \
  --output-dir /ai-agent/HadesProject/OHDSI-Study-Agent/data/phenotype_index \
  --build-dense

## First run, small sample
1) test search for suggested phenotype definition
export PHENOTYPE_INDEX_DIR=/ai-agent/HadesProject/OHDSI-Study-Agent/data/phenotype_index/
curl -s -X POST http://127.0.0.1:8765/flows/phenotype_recommendation   -H 'Content-Type: application/json'   -d '{"study_intent":"Identify patients who experience an adverse event of intracranial bleeding", "top_k":20, "max_results":10,"candidate_limit":10}' | python -m json.tool

2) Obtain the concept sets for alternative diagnoses for intracranial bleeding

```
curl -s -X POST http://127.0.0.1:8765/flows/keeper_concept_sets_generate   -H 'Content-Type: application/json'   -d '{"phenotype":"Intracranial bleeding","domain_keys":["alternativeDiagnosis"],"candidate_limit":10,"include_diagnostics":true}'   > /tmp/keeper_concept_sets.json

jq '.concept_sets' /tmp/keeper_concept_sets.json > /tmp/keeper_concept_sets_only.json

CONCEPT_SETS_JSON="$(cat /tmp/keeper_concept_sets_only.json)"
```


3)  after loading the suggested phenotype from step 1 into Atlas and setting the CONCEPT_SETS_JSON variable in the last step, check that this returns a result and that the information in the result matches the Atlas patient profile

```
curl -s -X POST http://127.0.0.1:8765/flows/keeper_profiles_generate   -H 'Content-Type: application/json'   -d "{
    \"cdm_database_schema\": \"cdm_pace_cases\",
    \"cohort_database_schema\": \"webapi_results_cases\",
    \"cohort_table\": \"cohort\",
    \"cohort_definition_id\": 217,
    \"sample_size\": 5,
    \"person_ids\": [\"8444311562\"],
    \"phenotype_name\": \"Intracranial bleeding\",
    \"use_descendants\": true,
    \"remove_pii\": true,
    \"keeper_concept_sets\": $CONCEPT_SETS_JSON
  }" | python -m json.tool
```

4)  sample of 5

```
curl -s -X POST http://127.0.0.1:8765/flows/keeper_profiles_generate \
  -H 'Content-Type: application/json' \
  -d "{
    \"cdm_database_schema\": \"cdm_pace_cases\",
    \"cohort_database_schema\": \"webapi_results_cases\",
    \"cohort_table\": \"cohort\",
    \"cohort_definition_id\": 217,
    \"sample_size\": 5,
    \"phenotype_name\": \"Intracranial bleeding\",
    \"use_descendants\": true,
    \"remove_pii\": true,
    \"keeper_concept_sets\": $CONCEPT_SETS_JSON
  }" | python -m json.tool
```

## a more expansive sample and full workflow

1) build concepts across several keeper concept categories and save to a file

```
curl -s -X POST http://127.0.0.1:8765/flows/keeper_concept_sets_generate \
  -H 'Content-Type: application/json' \
  -d '{
    "phenotype": "Intracranial bleeding",
    "domain_keys": ["doi", "alternativeDiagnosis", "symptoms", "drugs", "diagnosticProcedures", "measurements"],
    "candidate_limit": 10,
    "include_diagnostics": true
  }' > /tmp/keeper_concept_sets_full.json
```

2) If this runs, move the keeper_concept_sets_full.json to sandbox in this folder and then run  `keeper_profiles_generate`. That is the first flow that consumes the generated `concept_sets` and tests whether they work against your cohort/CDM data.

```
jq '{
  cdm_database_schema: "cdm_pace_cases",
  cohort_database_schema: "webapi_results_cases",
  cohort_table: "cohort",
  cohort_definition_id: 217,
  sample_size: 5,
  phenotype_name: "Intracranial bleeding",
  use_descendants: true,
  remove_pii: true,
  keeper_concept_sets: .concept_sets
}' ./sandbox/keeper_concept_sets_full.json > ./sandbox/keeper_profiles_payload.json

curl -s -X POST http://127.0.0.1:8765/flows/keeper_profiles_generate \
  -H 'Content-Type: application/json' \
  --data-binary @./sandbox/keeper_profiles_payload.json | python -m json.tool
```


3) Save the JSON portion of the output from the command above to ./sandbox/sample-keeper-profiles.json. Then, use `jq` to grab one `rows[]` entry and build the next payload.

```bash
jq '.rows[0]' ./sandbox/sample-keeper-profiles.json
```

To send it directly to `phenotype_validation_review`, build another payload file:

```bash
jq '{
  disease_name: "Intracranial bleeding",
  keeper_row: .rows[0]
}' ./sandbox/sample-keeper-profiles.json > ./sandbox/phenotype_validation_payload.json
```

Then post it:

```bash
curl -s -X POST http://127.0.0.1:8765/flows/phenotype_validation_review \
  -H 'Content-Type: application/json' \
  --data-binary @./sandbox/phenotype_validation_payload.json | python -m json.tool
```

4) You can change the row number above to create a new profile and rerun phenotype_validation_review
