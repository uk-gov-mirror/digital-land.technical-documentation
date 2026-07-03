---
title: Provision Quality
---

## What is provision quality?

**Provision quality** describes *who provides data for each dataset on the platform, and how good that data is*. It answers questions like: how many organisations feed a dataset, are they the authoritative source for their data or not, and which datasets or organisations have gaps.

It is produced by a nightly pipeline task (`provision-quality`) that writes three related tables as [Delta Lake](https://delta.io/) tables (Parquet) into the platform's `parquet-datasets` S3 bucket — the same output pattern as the [task table](./Tasks.md). From there they are surfaced to the serving database so the [digital-land.info](https://www.planning.data.gov.uk) front-end can show a provider/quality breakdown on each dataset page.


## Two lenses: providers and owners

The core subtlety is that an organisation can relate to a dataset in **two different ways**, and they don't always line up:

- **Provider** — an organisation that *submits* data. It has an active **endpoint** feeding the dataset (a non-empty `endpoint` in `source` / `source_pipeline`). *"Who feeds data in."*
- **Owner** — an organisation that *owns entities* on the platform, recorded by the `organisation_entity` field on each entity. *"Who owns the records that are actually there."*

These usually overlap, but the mismatches are exactly what this work makes visible. For example, when a national body does a bulk upload ("seeding") of conservation areas on behalf of many councils:

- the **provider** is the national body (it holds the endpoint), but
- the **owners** are the individual councils (the entities are attributed to them).

Conversely, a council may **own** entities (loaded historically or seeded on its behalf) while no longer **submitting** anything itself.

## Authoritative vs some

Within a dataset, each entity carries a `quality` value that tells us whether the data came from the right place:

- **`authoritative`** — the data is from the organisation that is the authoritative source for it (a council's own conservation-area data, owned by that council).
- **`some`** — the data is present but *not* from the authoritative source (for example, seeded by another body).

An organisation's provision quality for a dataset is `authoritative` if it owns at least one authoritative entity, otherwise `some`.

## The three tables

Everything derives from a single base grain — **provision** = one `(dataset, organisation)` pair — which is then rolled up two ways.

### 1. `provision_quality` (base)

One row per `(dataset, organisation)`. A row exists for **any organisation that has an active endpoint *or* owns entities** for the dataset — i.e. both lenses combined. Nothing is dropped; flag columns record what each row *is*, so downstream consumers can filter (e.g. to only formally-designated providers) as needed.

| Column | Description |
|---|---|
| `dataset` | The dataset (e.g. `conservation-area`) |
| `organisation` | The organisation reference (e.g. `local-authority:ADU`) |
| `organisation_name` | Human-readable organisation name |
| `has_active_endpoint` | `true` if the org submits data via a non-empty endpoint (provider lens) |
| `owns_entities` | `true` if the org owns at least one entity (owner lens) |
| `is_designated_provider` | `true` if the org has an allocated entity range in `entity-organisation.csv` for this dataset — i.e. this `(dataset, org)` is a *formally designated provision* |
| `quality` | `authoritative` or `some` |
| `entity_count` | Number of entities owned by the org (or seeded on its behalf, for seeders with no directly-owned entities) |
| `quality_score` | *Reserved — empty in v1* |

The `is_designated_provider` flag is what distinguishes formally-provisioned data from data that is simply *present* in the system (Owen's "endpoints/data that doesn't belong to a provision"). Both are retained; the flag lets the front-end include or exclude the latter without recomputation.

### 2. `dataset_quality` (rollup per dataset)

One row per dataset, aggregated from `provision_quality`.

| Column | Description |
|---|---|
| `dataset` | The dataset |
| `authoritative_organisations` | Count of orgs classified `authoritative` for this dataset |
| `some_organisations` | Count of orgs classified `some` |
| `total_organisations` | Total contributing organisations |
| `total_entities` | Total entities in the dataset |
| `quality_score` | *Reserved — empty in v1* |

This is the natural extension of the existing "N data providers" figure shown on dataset pages today (the `publisher_count` on `dataset_publication`). The provider-vs-owner split is available by filtering `provision_quality` on the flag columns; `dataset_quality` gives the headline counts.

### 3. `organisation_quality` (rollup per organisation)

One row per organisation, aggregated from `provision_quality` **across all datasets**. This view did not exist in the original analysis.

| Column | Description |
|---|---|
| `organisation` | The organisation reference |
| `organisation_name` | Human-readable organisation name |
| `authoritative_datasets` | Number of datasets the org provides authoritatively |
| `some_datasets` | Number of datasets the org provides at `some` quality |
| `total_datasets` | Total datasets the org contributes to |
| `total_entities_owned` | Total entities owned across all datasets |
| `quality_score` | *Reserved — empty in v1* |

## How the classification works

The classification logic is reused from the original Data Design analysis. In outline, per dataset:

1. **Providers** are the organisations with a non-empty endpoint in `source` ⋈ `source_pipeline`.
2. **Owners and quality** come from each dataset's `entity` table — `organisation_entity` (who owns each entity) and `quality` (`authoritative` / `some`).
3. **Designated provisions** come from `entity-organisation.csv` — the organisations allocated an entity range for the dataset.
4. **Seeder detection** uses `lookup.csv`: an active organisation that seeded entities it does not own (and is not the designated provider) is credited as a `some`-quality contributor. To avoid crediting dissolved/reorganised bodies with stale lookup entries, local-authority-type organisations must have seeded entities for **more than one** owner to count; other org types need at least one.
5. **Active organisations only** — organisations with an `end_date` in the `organisation` table are excluded from `some`-quality seeder classification.

> **Deviation from the original analysis (deliberate):** the prototype *dropped* two categories of row — designated providers whose data has stalled (`some`-only with an allocated range), and `some` providers with zero seeded entities. In line with the "keep all data, flag it" approach, `provision_quality` **retains** these rows and distinguishes them via the flag columns and `entity_count`, rather than removing them. Consumers filter as needed.

## Where it runs

`provision-quality` is a new task in the [build-digital-land-builder DAG](https://github.com/digital-land/airflow-dags/blob/main/dags/digital_land_builder.py), running nightly.

- **It runs in parallel with `build-digital-land-builder`.** All of its inputs live in the `collection-data` S3 bucket (see [Data sources](#data-sources)), independent of the built `digital-land.sqlite3`, so it does not need to wait for the build. Like `assemble-tasks`, it can hang off `configure-dag` and run alongside both the build and the `digital-land-postgres-loader`. This keeps it off the critical path to the 8am publish deadline.
- **The single task writes both outputs itself** — the Delta tables to S3 *and* the rows to serving Postgres — rather than splitting the Postgres load into a separate DAG step. Everything the pipeline does for these tables lives in one place, so it can be followed through end to end.
- It is implemented in **Python** using **[Polars](https://pola.rs/)**. At this data scale plain Python is sufficient; 
- The CloudFront cache **must be invalidated after this task completes** 

### Data sources

The productionised task reads everything from the **`collection-data` S3 bucket** — it does **not** hit Datasette or GitHub-raw at runtime (avoiding both the Datasette load and the GitHub rate-limiting seen in overnight runs), and it does **not** depend on the built `digital-land.sqlite3`.

| Data | Source |
|---|---|
| Provider mapping — `endpoint`, `organisation`, dataset(s), `end_date` | Each collection's `collection/source.csv`, globbed across `s3://{env}-collection-data/*-collection/collection/source.csv`. The `pipelines` column carries the dataset(s) an endpoint serves — the same information as Datasette's `source` ⋈ `source_pipeline`. |
| `organisation` — names, entity IDs, active/inactive (`end_date`) | `s3://{env}-collection-data/organisation-collection/dataset/organisation.csv` |
| `entity` (with `organisation_entity`, `quality`), per dataset | The per-dataset `{dataset}.sqlite3` in `s3://{env}-collection-data/{collection}-collection/dataset/` |
| `entity-organisation.csv`, `lookup.csv`, per collection | `s3://{env}-collection-data/config/pipeline/{collection}/` |

Because all of these are per-collection outputs already present in `collection-data` when this DAG runs, the task has no dependency on the build step — hence it can run in parallel with it.

> **Entity source — sqlite for v1, Delta/parquet later.** The entity + quality read is the task's dominant cost (the big datasets — title-boundary, listed-building — have millions of entities), and the per-dataset sqlites carry geometry inline, so the whole file is downloaded even though only three columns are needed. A columnar entity table would be far cheaper. For v1 we read the **sqlites**, because they are the only source that currently exists for every dataset — the `parquet-datasets` bucket holds entity tables for just the handful of datasets already migrated to the PySpark pipeline. Once the collection pipelines are fully on PySpark and emit per-dataset Delta tables (`dataset=<name>/`-partitioned), the entity read switches to those. To keep that switch cheap, the entity read is isolated behind a single loader function so it can be swapped without touching the classification logic.

### Output

The task writes **both** of its outputs itself, in the one task:

1. **Delta Lake tables (Parquet)** to the platform's Parquet datasets bucket — `s3://{env}-parquet-datasets/{table}/`, one each for `provision_quality`, `dataset_quality`, and `organisation_quality`. This mirrors how the [task table](./Tasks.md) is produced by the `assemble-tasks` pipeline: the Delta table is the canonical, re-queryable artifact. This is the primary output.
2. **Serving Postgres** — the same three tables are written to the serving database, alongside `dataset_publication`, so [digital-land.info](https://www.planning.data.gov.uk) can serve them on dataset pages. The `total_organisations` figure in `dataset_quality` should reconcile with the existing `publisher_count` on `dataset_publication`.

Both writes happen inside the `provision-quality` task rather than being split across separate DAG steps, so everything the pipeline does for these tables can be read in one place.

### Cache invalidation

The dataset pages that serve these tables sit behind CloudFront, so the cache must be invalidated once the new data is written. So invalidate-cloudfront-cache task will run immediatly after provision-quality task to ensure this data is available even if it takes longer than build-digital-land-builder

## Worked example: conservation area

Using the seeding scenario above, three representative rows in `provision_quality` for `conservation-area`:

| organisation | has_active_endpoint | owns_entities | is_designated_provider | quality | entity_count |
|---|---|---|---|---|---|
| Adur DC | ✅ | ✅ | ✅ | authoritative | 50 |
| Lewes DC | ❌ | ✅ | ✅ | some | 30 |
| Historic England | ✅ | ❌ | ❌ | some | 3 |

- **Adur** submits its own data and owns authoritative entities — the healthy case.
- **Lewes** never submitted, but owns 30 entities seeded on its behalf, so `some` quality.
- **Historic England** holds the endpoint and seeded data, but owns no entities itself — a provider that is not an owner.

`dataset_quality` for `conservation-area` then rolls these (and all other orgs) up into authoritative / some / total organisation counts; `organisation_quality` rolls the same rows up per organisation across every dataset each org touches.
