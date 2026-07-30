---
title: Add data
description: The technical flow used by the manage service to add a published data endpoint.
---

## Purpose

The add-data flow creates the configuration needed to collect and process a published endpoint.

The manage service coordinates the request, displays processing results and prepares configuration. The async request backend performs the longer-running conversion, transformation and entity-assignment work.

## Inputs

The flow uses:

- the dataset and collection
- the providing organisation
- the endpoint URL
- the documentation URL
- optional source-to-specification column mappings
- the config repository branch used for assessment and confirmation

These values can be supplied from the Jira request created by Check and Provide.

## Request and processing flow

| Stage | Technical behaviour |
| --- | --- |
| Request initialisation | The Flask application validates the submitted parameters and stores the working state in the user session |
| Reference lookup | Service modules retrieve dataset fields, provisioned organisations, existing endpoints and platform entities |
| Baseline | The service records the config branch state against which the request is assessed |
| Async processing | The application submits an async `add_data` request containing the endpoint and selected configuration |
| Polling and results | The application retrieves the completed request and response details from the async request backend |
| Confirmation | The application triggers the config repository workflow using the completed request identifier and selected endpoint retirements |

## Processing results

The async request backend returns converted rows, transformed rows, issue logs and a pipeline summary.

The manage service uses these results to render:

| Result | Purpose |
| --- | --- |
| Converted data | Shows source records after conversion into a processable format |
| Transformed data | Shows records after dataset transformation rules have been applied |
| Issue log | Reports validation and transformation issues |
| Provision comparison | Compares the resource with platform entities and groups records as new, changed, matching or platform-only |
| Configuration preview | Shows the configuration changes that can be written after confirmation |

For spatial datasets, response geometry is rendered on a map. The service can also check whether the submitted endpoint appears on the data owner's documentation page.

## Service boundaries

The manage service owns parameter validation, request coordination, result presentation and confirmation.

The async request backend owns conversion, transformation, comparison and proposed entity assignment. The config repository workflow owns writing the confirmed configuration. The data pipelines later read that configuration and process the endpoint.

## Related documentation

- [Add-data configuration workflow](https://github.com/digital-land/config-manager/blob/main/docs/datamanager/github-add.md)
- [Adding data operational guidance](/data-operations-manual/Tutorials/Adding-Data/)
