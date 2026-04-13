from __future__ import annotations

import json
import os
from typing import Any, Dict, List

import yaml

from ._common import with_meta

_CACHE: Dict[str, Any] = {}


def _prompt_dir() -> str:
    return os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "prompts", "keeper_concept_sets"))


def _load_text(path: str) -> str:
    with open(path, "r", encoding="utf-8") as handle:
        return handle.read().strip()


def _load_json(path: str) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def _load_yaml(path: str) -> Any:
    with open(path, "r", encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def _render_template(template: str, values: Dict[str, Any]) -> str:
    return template.format_map({key: str(value) for key, value in values.items()})


def _normalize_concept(concept: Dict[str, Any]) -> Dict[str, Any]:
    concept_id = concept.get("conceptId", concept.get("concept_id"))
    if concept_id in (None, ""):
        return {}
    try:
        concept_id = int(concept_id)
    except (TypeError, ValueError):
        return {}
    record_count = concept.get("recordCount", concept.get("record_count"))
    if record_count in ("", None):
        record_count = None
    elif isinstance(record_count, str):
        try:
            record_count = int(record_count)
        except ValueError:
            record_count = None
    score = concept.get("score")
    if score in ("", None):
        score = None
    elif isinstance(score, str):
        try:
            score = float(score)
        except ValueError:
            score = None
    return {
        "conceptId": concept_id,
        "conceptName": str(concept.get("conceptName", concept.get("concept_name", "")) or ""),
        "vocabularyId": str(concept.get("vocabularyId", concept.get("vocabulary_id", "")) or ""),
        "domainId": str(concept.get("domainId", concept.get("domain_id", "")) or ""),
        "conceptClassId": str(concept.get("conceptClassId", concept.get("concept_class_id", "")) or ""),
        "standardConcept": str(concept.get("standardConcept", concept.get("standard_concept", "")) or ""),
        "recordCount": record_count,
        "score": score,
        "relationshipId": str(concept.get("relationshipId", concept.get("relationship_id", "")) or ""),
        "sourceConceptId": concept.get("sourceConceptId", concept.get("source_concept_id")),
        "sourceTerm": str(concept.get("sourceTerm", concept.get("source_term", "")) or ""),
        "sourceStage": str(concept.get("sourceStage", concept.get("source_stage", "")) or ""),
    }


def _dedupe_concepts(concepts: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    seen = set()
    deduped = []
    for concept in concepts:
        normalized = _normalize_concept(concept)
        concept_id = normalized.get("conceptId")
        if not concept_id or concept_id in seen:
            continue
        seen.add(concept_id)
        deduped.append(normalized)
    return deduped


def _load_bundle() -> Dict[str, Any]:
    cached = _CACHE.get("bundle")
    if cached is not None:
        return cached
    base = _prompt_dir()
    payload = {
        "task": "keeper_concept_sets_generate",
        "overview": _load_text(os.path.join(base, "overview_keeper_concept_sets.md")),
        "spec_generate_terms": _load_text(os.path.join(base, "spec_keeper_generate_terms.md")),
        "spec_filter_concepts": _load_text(os.path.join(base, "spec_keeper_filter_concepts.md")),
        "output_schema_generate_terms": _load_json(
            os.path.join(base, "output_schema_keeper_generate_terms.json")
        ),
        "output_schema_filter_concepts": _load_json(
            os.path.join(base, "output_schema_keeper_filter_concepts.json")
        ),
        "domains": _load_yaml(os.path.join(base, "domains_keeper_concept_sets.yaml")) or [],
    }
    _CACHE["bundle"] = payload
    return payload


def _domain_map() -> Dict[str, Dict[str, Any]]:
    payload = _load_bundle()
    return {
        str(entry.get("parameterName")): entry
        for entry in payload.get("domains", [])
        if isinstance(entry, dict) and entry.get("parameterName")
    }


def _provider_value(explicit: str, env_name: str) -> str:
    value = (explicit or os.getenv(env_name, "")).strip()
    return value


def register(mcp: object) -> None:
    @mcp.tool(name="keeper_concept_set_bundle")
    def keeper_concept_set_bundle_tool(
        phenotype: str,
        domain_key: str = "",
        target: str = "Disease of interest",
    ) -> Dict[str, Any]:
        bundle = dict(_load_bundle())
        domains = _domain_map()
        if not domain_key:
            bundle["phenotype"] = phenotype
            bundle["target"] = target
            return with_meta(bundle, "keeper_concept_set_bundle")
        domain = domains.get(domain_key)
        if domain is None:
            return with_meta({"error": f"unsupported domain_key {domain_key}"}, "keeper_concept_set_bundle")
        payload = {
            "task": bundle["task"],
            "overview": bundle["overview"],
            "phenotype": phenotype,
            "target": target,
            "domain": domain,
            "spec_generate_terms": bundle["spec_generate_terms"],
            "spec_filter_concepts": bundle["spec_filter_concepts"],
            "output_schema_generate_terms": bundle["output_schema_generate_terms"],
            "output_schema_filter_concepts": bundle["output_schema_filter_concepts"],
            "term_generation_prompt": _render_template(
                str(domain.get("systemPromptTerms", "") or ""),
                {"phenotype": phenotype, "target": target},
            ),
            "concept_filter_prompt": _render_template(
                str(domain.get("systemPromptRemoveNonRelevant", "") or ""),
                {"phenotype": phenotype, "target": target},
            ),
        }
        return with_meta(payload, "keeper_concept_set_bundle")

    @mcp.tool(name="vocab_search_standard")
    def vocab_search_standard_tool(
        query: str,
        domains: List[str] | None = None,
        concept_classes: List[str] | None = None,
        limit: int = 20,
        provider: str = "",
        results: List[Dict[str, Any]] | None = None,
    ) -> Dict[str, Any]:
        del query
        del limit
        concepts = _dedupe_concepts(results or [])
        if concepts:
            filtered = [
                concept
                for concept in concepts
                if (not domains or concept.get("domainId") in domains)
                and (not concept_classes or concept.get("conceptClassId") in concept_classes)
            ]
            return with_meta(
                {"concepts": filtered, "count": len(filtered), "provider": provider or "inline_results"},
                "vocab_search_standard",
            )
        selected_provider = _provider_value(provider, "VOCAB_SEARCH_PROVIDER")
        if not selected_provider:
            return with_meta(
                {"error": "vocab_search_provider_unconfigured", "concepts": [], "count": 0},
                "vocab_search_standard",
            )
        if selected_provider == "none":
            return with_meta({"concepts": [], "count": 0, "provider": selected_provider}, "vocab_search_standard")
        return with_meta(
            {
                "error": "vocab_search_provider_not_implemented",
                "provider": selected_provider,
                "concepts": [],
                "count": 0,
            },
            "vocab_search_standard",
        )

    @mcp.tool(name="phoebe_related_concepts")
    def phoebe_related_concepts_tool(
        concept_ids: List[int],
        relationship_ids: List[str] | None = None,
        provider: str = "",
        related_concepts: List[Dict[str, Any]] | None = None,
    ) -> Dict[str, Any]:
        del concept_ids
        relationships = set(relationship_ids or [])
        concepts = _dedupe_concepts(related_concepts or [])
        if concepts:
            if relationships:
                concepts = [concept for concept in concepts if concept.get("relationshipId") in relationships]
            return with_meta(
                {"concepts": concepts, "count": len(concepts), "provider": provider or "inline_results"},
                "phoebe_related_concepts",
            )
        selected_provider = _provider_value(provider, "PHOEBE_PROVIDER")
        if not selected_provider:
            return with_meta(
                {"error": "phoebe_provider_unconfigured", "concepts": [], "count": 0},
                "phoebe_related_concepts",
            )
        if selected_provider == "none":
            return with_meta({"concepts": [], "count": 0, "provider": selected_provider}, "phoebe_related_concepts")
        return with_meta(
            {
                "error": "phoebe_provider_not_implemented",
                "provider": selected_provider,
                "concepts": [],
                "count": 0,
            },
            "phoebe_related_concepts",
        )

    @mcp.tool(name="vocab_filter_standard_concepts")
    def vocab_filter_standard_concepts_tool(
        concepts: List[Dict[str, Any]],
        domains: List[str] | None = None,
        concept_classes: List[str] | None = None,
    ) -> Dict[str, Any]:
        filtered = []
        for concept in _dedupe_concepts(concepts):
            standard = concept.get("standardConcept")
            if standard and standard not in ("S", "C"):
                continue
            if domains and concept.get("domainId") not in domains:
                continue
            if concept_classes and concept.get("conceptClassId") not in concept_classes:
                continue
            filtered.append(concept)
        return with_meta({"concepts": filtered, "count": len(filtered)}, "vocab_filter_standard_concepts")

    @mcp.tool(name="vocab_remove_descendants")
    def vocab_remove_descendants_tool(
        concepts: List[Dict[str, Any]],
        ancestor_pairs: List[Dict[str, Any]] | None = None,
    ) -> Dict[str, Any]:
        normalized = _dedupe_concepts(concepts)
        selected_ids = {concept["conceptId"] for concept in normalized}
        descendants_to_drop = set()
        for pair in ancestor_pairs or []:
            ancestor_id = pair.get("ancestor_concept_id", pair.get("ancestorConceptId"))
            descendant_id = pair.get("descendant_concept_id", pair.get("descendantConceptId"))
            if ancestor_id in selected_ids and descendant_id in selected_ids and ancestor_id != descendant_id:
                descendants_to_drop.add(descendant_id)
        kept = [concept for concept in normalized if concept["conceptId"] not in descendants_to_drop]
        return with_meta(
            {
                "concepts": kept,
                "count": len(kept),
                "removed_concept_ids": sorted(descendants_to_drop),
            },
            "vocab_remove_descendants",
        )

    @mcp.tool(name="vocab_add_nonchildren")
    def vocab_add_nonchildren_tool(
        concepts: List[Dict[str, Any]],
        new_concepts: List[Dict[str, Any]],
        ancestor_pairs: List[Dict[str, Any]] | None = None,
    ) -> Dict[str, Any]:
        base = _dedupe_concepts(concepts)
        base_ids = {concept["conceptId"] for concept in base}
        descendants_to_skip = set()
        for pair in ancestor_pairs or []:
            ancestor_id = pair.get("ancestor_concept_id", pair.get("ancestorConceptId"))
            descendant_id = pair.get("descendant_concept_id", pair.get("descendantConceptId"))
            if ancestor_id in base_ids and descendant_id != ancestor_id:
                descendants_to_skip.add(descendant_id)
        merged = list(base)
        seen = set(base_ids)
        for concept in _dedupe_concepts(new_concepts):
            concept_id = concept["conceptId"]
            if concept_id in seen or concept_id in descendants_to_skip:
                continue
            seen.add(concept_id)
            merged.append(concept)
        return with_meta({"concepts": merged, "count": len(merged)}, "vocab_add_nonchildren")

    @mcp.tool(name="vocab_fetch_concepts")
    def vocab_fetch_concepts_tool(
        concept_ids: List[int],
        concepts: List[Dict[str, Any]] | None = None,
    ) -> Dict[str, Any]:
        if concepts:
            by_id = {concept["conceptId"]: concept for concept in _dedupe_concepts(concepts)}
            found = [by_id[concept_id] for concept_id in concept_ids if concept_id in by_id]
            missing = [concept_id for concept_id in concept_ids if concept_id not in by_id]
            return with_meta(
                {"concepts": found, "count": len(found), "missing_concept_ids": missing},
                "vocab_fetch_concepts",
            )
        return with_meta(
            {"error": "vocab_fetch_concepts_not_implemented", "concepts": [], "count": 0},
            "vocab_fetch_concepts",
        )

    return None
