---
title: Config repository automated data tests
---

Every push to the `config` repository triggers [`.github/workflows/test.yml`](https://github.com/digital-land/config/blob/main/.github/workflows/test.yml), which runs `make test`. This is the only workflow that runs on every push/commit — everything else in `.github/workflows` is either manually triggered (`workflow_dispatch`) or scheduled (`cron`)/dispatched from another system.

`make test` runs three pytest suites (`test-unit`, `test-integration`, `test-acceptance`). This page covers **`test-acceptance`** — `pytest tests/acceptance/test_config_dataset.py` — as these are the tests that validate the config data itself (the CSV files under `pipeline/` and `collection/`). The unit and integration suites test the `add-data` and `batch-assign` Python scripts rather than config data, and aren't covered here.

If a test fails, the PR/branch will show a failing check in GitHub. The assertion message lists exactly which rows/entities failed and why, with clickable links back to the offending line in the CSV (when run in CI on a branch).

> **NOTE!**
> These tests only check the _shape and internal consistency_ of the config data (datatypes, uniqueness, ranges, cross-file consistency). They do not check whether the data is _semantically_ correct against a live upstream source — see [Configure and run expectations](Configure-and-run-expectations.md) for that.

## How the tests work

Each test loads a set of **rules** and runs them through `CsvCheckpoint`, from [`digital_land.expectations.checkpoints.csv`](https://github.com/digital-land/digital-land-python/blob/main/digital_land/expectations/checkpoints/csv.py). Each rule names an **operation** (a function in [`digital_land.expectations.operations.csv`](https://github.com/digital-land/digital-land-python/blob/main/digital_land/expectations/operations/csv.py)) plus the parameters for that operation. If any rule fails, the whole test fails and the assertion message includes every failing rule's details.

### General checks applied to (almost) every config CSV

Most of the tests below call a shared helper, `_build_all_csv_rules`, before running their own specific rules. This applies to every column.csv, combine.csv, concat.csv, default.csv, default-value.csv, endpoint.csv, expect.csv, filter.csv, old-entity.csv, old-resource.csv, patch.csv, skip.csv, source.csv, transform.csv, lookup.csv, and entity-organisation.csv file across every dataset:

- **No blank rows** — a row can't be entirely empty.
- **Every column must be registered in the specification** — if a CSV has a column name that isn't a recognised field in the [specification](https://github.com/digital-land/specification), the test fails immediately (this usually means a typo in a header, or a new field that hasn't been added to the specification yet).
- **Column values must match their declared datatype** — each field in the specification has a datatype (`integer`, `decimal`, `flag`, `latitude`, `longitude`, `curie`, `curie-list`, `json`, `date`, `datetime`, `pattern`, `multipolygon`, `point`, `url`), and every value in that column is checked against it (e.g. a `latitude` column must contain valid latitude values, a `url` column must match a URL pattern).

## The tests

### `test_lookup`

Runs against every `lookup.csv`. Checks:

- **"lookup entities are within organisation ranges"** — for each row, the `entity` must fall within the `entity-minimum`/`entity-maximum` range recorded for the same `organisation` in that dataset's `entity-organisation.csv`.
  - Rows are skipped (not checked) if `organisation` is blank, is `government-organisation:D1342`, or belongs to an organisation with an `end_date` set (fetched live from [datasette](https://datasette.planning.data.gov.uk/digital-land)).
  - For `conservation-area` specifically, `local-authority:GLA`, `government-organisation:D1342` and `government-organisation:PB1164` (Historic England) are also excluded — HE is deliberately recorded against conservation-area entities alongside the owning local authority, so it isn't expected to match a single organisation's range.
- The general CSV checks described above.

> **NOTE!**
> A large proportion of historic `lookup.csv` rows (particularly for `listed-building`) have a blank `organisation` field, which means this check silently skips them — see [config issue #2673](https://github.com/digital-land/config/issues/2673) for background. Newly added data via the Manage Service always sets `organisation`, so this mostly affects older/legacy entries.

### `test_entity_belongs_to_single_organisation`

Runs against every `lookup.csv`. Checks that no single `entity` is recorded against more than one distinct `organisation` within the same file (ignoring rows with a blank `organisation`).

- `conservation-area` rows are excluded, since it's normal for a conservation-area entity to be recorded twice — once against the owning local authority and once against Historic England (`government-organisation:PB1164`).
- The failure message names the specific `prefix`(es) involved for each conflicting entity, since one `lookup.csv` can contain several prefixes (e.g. `local-plan`'s lookup.csv also contains `plan-timetable`, `minerals-plan`, `waste-plan`, etc.) — this makes it clear which underlying collection actually has the conflict, rather than just the top-level dataset name.
- This does not attempt to determine which organisation is _correct_ — it only flags that more than one is recorded. Working out the correct organisation typically requires checking which endpoint/source the entity's data actually came from, which isn't information this test has access to.

### Generic CSV structure tests

The following tests are all identical in behaviour — each just runs the [general CSV checks](#general-checks-applied-to-almost-every-config-csv) against its named file, for every dataset that has one:

| Test                     | File checked        |
| ------------------------ | ------------------- |
| `test_column_csv`        | `column.csv`        |
| `test_combine_csv`       | `combine.csv`       |
| `test_concat_csv`        | `concat.csv`        |
| `test_default_csv`       | `default.csv`       |
| `test_default_value_csv` | `default-value.csv` |
| `test_endpoint_csv`      | `endpoint.csv`      |
| `test_expect_csv`        | `expect.csv`        |
| `test_filter_csv`        | `filter.csv`        |
| `test_old_entity_csv`    | `old-entity.csv`    |
| `test_old_resource_csv`  | `old-resource.csv`  |
| `test_patch_csv`         | `patch.csv`         |
| `test_skip_csv`          | `skip.csv`          |
| `test_source_csv`        | `source.csv`        |
| `test_transform_csv`     | `transform.csv`     |

### `test_old_entity`

Runs against every `old-entity.csv`, in addition to the general CSV checks. Checks:

- **"old-entity values are unique"** — the same `old-entity` value can't appear twice in the same file.
- **"old-entity statuses only contains 301 or 410"** — the `status` column must only ever be `301` (permanent redirect, i.e. merged into another entity) or `410` (gone, i.e. retired).

### `test_entity_organisation`

Runs against every `entity-organisation.csv`, in addition to the general CSV checks. Checks:

- **"entity-minimum and entity-maximum ranges do not overlap"** — no two rows for the same dataset can declare overlapping entity ID ranges, since each range should map unambiguously to one organisation.

> **NOTE!**
> This test normalises line endings (CRLF → LF) and strips trailing empty columns before running, so it isn't affected by how the file happens to be saved.

## Running the tests locally

From the `config` repo root:

\`\`\`
pip install -r requirements.txt
pytest tests/acceptance/test_config_dataset.py
\`\`\`

To run a single test, or a single dataset's parametrised case:

\`\`\`
pytest tests/acceptance/test_config_dataset.py -k test_lookup
pytest "tests/acceptance/test_config_dataset.py::test_lookup[pipeline/listed-building]"
\`\`\`
