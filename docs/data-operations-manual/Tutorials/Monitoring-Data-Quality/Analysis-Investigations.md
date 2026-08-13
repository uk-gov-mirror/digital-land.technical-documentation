---
title: Data quality analysis and investigations
---

# Data quality investigations

Record of one-off data quality investigations carried out using the [jupyter-analysis](https://github.com/digital-land/jupyter-analysis) repository. Each entry below summarises the problem, what was tried, the results, and what came of it. Full notebooks, code and detailed notes are linked from each section.

---

## Conservation area partial-match duplicate resolution

**Problem statement**

The `duplicate_geometry_check` expectation flags conservation area entity pairs whose geometries overlap significantly, feeding the ["Duplicate Conservation Area" Power BI report](https://app.powerbi.com/links/fKdIw4fwzX?ctid=bf346810-9c7d-43de-a872-24a2ef3995a8&pbi_source=linkShare&bookmarkGuid=57c04f9e-ef27-4231-8de1-9abccc3957b5). Complete matches (>95% overlap both ways) have an established fix — redirect via `old-entity.csv` — but partial ("single") matches are harder: some are true duplicates with a slightly different boundary, others are genuinely separate entities that happen to overlap (e.g. one conservation area nested inside another). Which is which, and how do we decide automatically? See [digital-land/config#2021](https://github.com/digital-land/config/issues/2021).

**Approach**

Worked through case studies: the same-LPA case (Dorset, repeatedly flagged), the different-LPA case (Hillingdon vs. Buckinghamshire), and a pattern where Historic England had submitted more recent data than the LPA itself (Bromley) — normally LPA data is treated as authoritative over HE, so this needed a judgement call rather than a fixed rule.

**Results**

For the same-LPA case: when two entities share an LPA, have similar names, and one geometry is >95% contained within the other, it's reliably a smaller-CA-within-a-larger-CA situation, not a duplicate — keep both. Dorset's Underhill and Weston conservation areas were the clearest example. The different-LPA cases didn't yield a single clean rule; each needed individual inspection (in the Hillingdon/Buckinghamshire case, the smaller geography turned out to be the same CA submitted only up to the submitting LPA's own boundary).

**Outcome**

The clearest, safest-to-automate pattern — Historic England (a national seeding source) duplicating a boundary an LPA has already submitted — was built into an automated `old-entity.csv` redirect script, [`deduplicate-ca-geogs.py`](https://github.com/digital-land/config/blob/main/.github/scripts/deduplicate-ca-geogs.py) ([digital-land/config#2239](https://github.com/digital-land/config/pull/2239), refined in [#2371](https://github.com/digital-land/config/pull/2371) and [#2384](https://github.com/digital-land/config/pull/2384)). It only ever redirects Historic England's entity onto the LPA/ODP entity, never the reverse, and only when: it's a complete match, or a single match with >85% name similarity. HE entities matching more than one LPA entity are retired (`410`) rather than auto-redirected, and any resulting redirect chains are consolidated to their final destination. The same-LPA "keep separate" rule and the general cross-LPA cases from the analysis remain manual judgement calls, not automated by this script.

📓 [analysis/2026-02_ca_partial_match_dedup](https://github.com/digital-land/jupyter-analysis/tree/main/analysis/2026-02_ca_partial_match_dedup)

---

## Entity counts across the pipeline

**Problem statement**

Are entity counts consistent across the data pipeline — from the transformed resource stage through to the published platform — for the ODP datasets (`article-4-direction-area`, `conservation-area`, `listed-building-outline`, `tree`, `tree-preservation-zone`)?

**Approach**

Compared entity/line counts across three stages: transformed resource CSVs, `reporting_historic_endpoints` and `dataset_resource` (both from Datasette), and the published Planning platform. An initial pass compared platform data directly against backend pipeline data, which turned out to be the wrong comparison (platform data is pruned/filtered before publication, so mismatches there don't indicate a real problem). The corrected approach compared like-for-like within the backend pipeline only, deduplicating resources first to avoid inflated counts.

**Results**

Backend pipeline counts (`reporting_historic_endpoints` vs. transformed resources) were fully consistent: 291 matches to 8 mismatches at resource level, and the 8 mismatches were all `NaN` vs. 0 (empty resources, not a real discrepancy). Aggregated to LPA level, there were 0 mismatches.

**Outcome**

Confirmed the backend pipeline is internally coherent for these datasets. The final comparison notebook (platform vs. `dataset_resource`/`reporting_historic_endpoints`, across all five ODP datasets) became the precursor to a daily automated report, now run from the `reporting-task` repository via [`dataset_resource_vs_platform_report.py`](https://github.com/digital-land/reporting-task/blob/main/src/dataset_resource_vs_platform_report.py). It publishes two CSVs nightly:

- [`dataset_resource_odp_detailed_counts.csv`](https://files.planning.data.gov.uk/reporting/dataset_resource_odp_detailed_counts.csv)
- [`dataset_resource_vs_platform_odp_summary.csv`](https://files.planning.data.gov.uk/reporting/dataset_resource_vs_platform_odp_summary.csv)

📓 [analysis/2026-03_entity_counts_check](https://github.com/digital-land/jupyter-analysis/tree/main/analysis/2026-03_entity_counts_check)

---

## Barnet boundary overlaps

**Problem statement**

Barnet Council raised several concerns in one go: geometries from neighbouring LPAs appearing to overlap into Barnet's boundary (most notably Enfield's Trent Park conservation area against Barnet's own Monken Hadley), a Camden-submitted listed building outline sitting entirely within Barnet rather than Camden, and — separately — a suspicion that the polygons served by the Planning Data platform didn't match the extents in their own endpoint, raising the question of whether geometries are being simplified somewhere in the pipeline. See [digital-land/config#2461](https://github.com/digital-land/config/issues/2461).

**Approach**

Investigated three things in turn: whether Trent Park and Monken Hadley are genuinely distinct conservation areas or the same area duplicated across two LPAs' submissions; whether the Camden listed building (entity `42115855`) legitimately sits inside Barnet's boundary; and, more systematically, which geometries from Barnet's six neighbouring LPAs (Brent, Camden, Enfield, Haringey, Harrow, Hertsmere) overlap into Barnet's boundary at all, across conservation-area, article-4-direction-area and listed-building-outline.

**Results**

Trent Park and Monken Hadley are genuinely separate conservation areas — the overlap traced back to Enfield's own Trent Park geometry not matching the boundary in their appraisal document, a data quality issue on Enfield's side rather than a platform bug. The Camden listed building was confirmed to correctly sit within Barnet's boundary — again a case for the submitting LPA to reconcile, not a processing error. The systematic check found 17 entities from neighbouring LPAs overlapping into Barnet's boundary, the majority minor and consistent with resolution/digitising differences rather than genuine duplicates.

**Outcome**

The `duplicate_geometry_check` expectation was extended with a new `any_match` label ([digital-land-python#520](https://github.com/digital-land/digital-land-python/pull/520)), so overlaps between neighbouring LPAs' geometries — like Trent Park/Monken Hadley — are now caught even when they don't meet the existing complete/single-match thresholds. Barnet's question about whether geometries are simplified before publishing led directly to opening [digital-land/config#2497](https://github.com/digital-land/config/issues/2497), investigated separately below.

📓 [analysis/2026-04_barnet_boundary_overlaps](https://github.com/digital-land/jupyter-analysis/tree/main/analysis/2026-04_barnet_boundary_overlaps)

---

## Simplified geometry investigation

**Problem statement**

Barnet Council flagged that their submitted conservation area boundaries looked different on the Planning platform compared to their raw source data. Why does geometry submitted by LPAs change shape through the pipeline, and is that change appropriate?

**Approach**

Used the Totteridge conservation area as a case study, comparing Barnet's raw GeoPackage against the geometry in Datasette and on the platform. Walked through each stage of the pipeline's WKT transformation (`wkt.py`) manually — precision round-trip, simplification, coordinate grid snapping, validity fixes — measuring vertex count and boundary area deviation at each step. Repeated the check across other LPAs and dataset types (Barking & Dagenham listed building outlines, Liverpool article 4 directions, Leeds TPOs) and tested alternative parameter values for precision and simplification tolerance. See [geometry processes](/data-operations-manual/Explanation/Key-Concepts/Geometry-processes) for the full step-by-step breakdown of the pipeline and the Barnet case study figures.

**Results**

The pipeline's transformation was confirmed to run correctly and consistently (0.7 mm² symmetric difference between the manual replication and the actual pipeline output). Simplification was found to be the dominant source of change: it removes ~80% of vertices and introduces ~1000 m² of cumulative deviation for complex boundaries. Removing simplification entirely dropped the difference from raw to under 1 m² (negligible rounding), replicated across multiple conservation areas. Increasing coordinate precision alone did not help, since the coordinate grid-snapping step discards the extra precision unless made correspondingly finer.

**Outcome**

Recommended reducing the simplify tolerance from `5e-6` to `1e-6` (~0.1 m on the ground), which cuts boundary distortion by ~70% while keeping ~65% vertex reduction. Longer-term option identified: make simplification conditional on geometry validity, so already-valid WGS84 submissions (like Barnet's) aren't simplified at all. This recommendation was adopted — see [ADR 25](/architecture-and-infrastructure/architecture-decision-records/#25.-reduce-geometry-simplification-tolerance-from-0.000005-to-0.000001) for the decision record.

📓 [analysis/2026-04_simplified_geometry](https://github.com/digital-land/jupyter-analysis/tree/main/analysis/2026-04_simplified_geometry)

---

## Entities misattributed to the wrong organisation

**Problem statement**

Follow-up to [digital-land/config#2651](https://github.com/digital-land/config/issues/2651), which found `brownfield-land` entity ranges misattributed to the wrong council (e.g. Wokingham instead of Woking). Are there other entities across the platform with the same bug pattern — flagged `quality=some`, attributed to one local body, but actually submitted by a different one?

**Approach**

The obvious check — comparing an entity's `organisation_entity` against the range assignment in `entity-organisation.csv` — doesn't work, because the pipeline always force-overwrites `organisation_entity` to match the range file regardless of who actually submitted the data. Instead, traced each entity's real submitting organisation via its resource lineage (`fact` → `fact_resource` → `log` → `endpoint` → `source`), which is independent of `organisation_entity`, and diffed that against current attribution. Validated against the four known-bad entities from the original ticket before running platform-wide. Filtered out three legitimate look-alike patterns that resemble misattribution at the single-entity level: national seeding by a central government organisation, regional aggregation by a non-government body on behalf of many LPAs, and local government reorganisation succession.

**Results**

446 confirmed misattributions across all datasets with a `quality=some` entity owned by a local authority, national park authority, or development corporation. These included the two original ticket examples (Wokingham → Woking: 77 entities; Cheshire West & Chester → Cheshire East: 7) plus new discoveries, most notably Northumberland National Park Authority → Northumberland County Council (231 entities in `listed-building-outline`) — a case with no active endpoint registered for that dataset, so it would be invisible to any check that starts from active providers.

**Outcome**

Full population of flagged entities written to `data/flagged_entities_full_population_with_provenance.csv`, sorted with confirmed misattributions first. These are been investigated and corrected as part of https://github.com/digital-land/config/issues/2770

📓 [analysis/2026-07_correct_organisations_of_entities](https://github.com/digital-land/jupyter-analysis/tree/main/analysis/2026-07_correct_organisations_of_entities)

---

## ODP `name` field quality

**Problem statement**

How "weird" is the `name` field across the ODP geography datasets (`article-4-direction-area`, `conservation-area`, `listed-building-outline`, `tree-preservation-zone`, `tree`) — exact duplicates, blank/missing values, bare reference codes standing in for a description, and repeated boilerplate/placeholder text?

**Approach**

Built reusable checks (duplicate names, code-like names, missing names, top n-grams) and ran them across all five datasets. A follow-up pass narrowed to `tree`, `tree-preservation-zone` and `listed-building-outline`, moving from "does this look weird" to "is this actually against guidance": classifying `tree`/`tree-preservation-zone` names against ODP guidance (name can be a description, the reference, an address, or blank), and cross-referencing `listed-building-outline` names against their linked `listed-building` record.

**Results**

Name quality varies sharply by dataset — duplicate names ranged from 16.4% (`conservation-area`) to 70.1% (`tree`), with `tree` and `tree-preservation-zone` the worst affected (61–70% duplicated, ~1 in 5 rows blank). Applying the ODP guidance-based classification showed many apparent "bare-code" names in `tree`/`tree-preservation-zone` are actually legitimate reference/TPO reuse, not a real quality problem. For `listed-building-outline`, only ~51% of rows linking to a `listed-building` record had an exact name match, though many mismatches are just extra locating detail appended by the LBO source, not an error. Placeholder strings (`"No name for this Entry"`, `"No given name"`) were each traced to a single organisation's habit, and in 844 of 845 cases a proper name was available one join away via the linked `listed-building` record.

**Outcome**

- New expectation raised for duplicate names, across all five datasets.
- New expectation raised: LBO name doesn't match its linked `listed-building` record, and is a specific placeholder string (`listed-building-outline` only).
- New issue raised: names that look like bare codes (`article-4-direction-area`, `conservation-area`, `listed-building-outline`).

📓 [analysis/2026-08_odp_name_analysis](https://github.com/digital-land/jupyter-analysis/tree/main/analysis/2026-08_odp_name_analysis)
