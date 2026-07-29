---
title: Manage service
description: A high-level overview of the service used to manage data on the Planning Data platform.
---

## What the manage service does

The manage service helps data managers add data to the Planning Data platform. It supports the work needed after a data owner has checked and provided their data and a Jira request has been created for the data management team.

Data owners include local planning authorities (LPAs) and other local authorities that are responsible for publishing planning and housing data.

It provides guided journeys for work that would otherwise require people to understand and edit several configuration files by hand. In particular, it helps users:

- add a new source of data
- update an existing source of data
- map source columns to Planning Data fields
- inspect the results of processing that data
- compare submitted data with data already on the platform
- decide which new records should become Planning Data entities
- review possible duplicates
- retire an endpoint that has been replaced
- prepare reviewed configuration changes

The manage service supports decisions made by a person. It does not replace the underlying data specifications, automatically decide whether every change is correct, or publish data directly to the public platform.

## Who uses the manage service

The manage service is primarily used by data managers and data operations teams responsible for adding data to the platform.

Other internal roles may use or support the service when managing dataset requests, investigating problems or working on configuration and pipelines. These include delivery managers, support teams and developers.

## Technical overview

The manage service is a server-rendered web application. It provides the user interface and coordinates requests between data managers, shared Planning Data services and GitHub.

| Area | Technology or approach |
| --- | --- |
| Application | Python 3.10 and the Flask web framework |
| Application structure | Flask blueprints separate the main service areas and user journeys |
| Web pages | Server-rendered Jinja templates using GOV.UK Frontend and shared Digital Land frontend components |
| Data storage | PostgreSQL, accessed through SQLAlchemy |
| Database changes | Flask-Migrate and Alembic migrations |
| Authentication | GitHub OAuth, restricted to members of the Digital Land GitHub organisation |
| Longer-running processing | Delegated to the async request backend rather than performed entirely in the web request |
| Packaging | A Docker container containing the Python application and compiled frontend assets |
| Delivery | GitHub Actions runs tests, builds the container image and publishes it to Amazon Elastic Container Registry in the `eu-west-2` AWS region |

The repository supports development, staging and production service environments. The infrastructure that runs the published container is managed separately from the application repository.

### Application responsibilities

The Flask application:

- presents the add-data and assign-entities journeys
- stores service state and request metadata in PostgreSQL
- retrieves dataset, organisation, endpoint and entity information from Planning Data services
- sends processing requests to the async request backend
- displays processing results and configuration previews
- authenticates users through GitHub
- triggers the GitHub workflow that writes confirmed configuration changes

This separation keeps the web application focused on user journeys and coordination. Shared processing services perform the longer-running data transformation and entity-assignment work.

### Main integrations

The manage service communicates with:

- the async request backend for checking and processing submitted resources
- the Planning Data website and API for datasets and existing entities
- Datasette for platform and configuration reference data
- the specification repository for dataset and field definitions
- the GitHub API for authentication and configuration workflows
- the config repository, through a GitHub workflow, for confirmed endpoint and entity configuration

## System context

Data owners use Check and Provide to validate and submit a published endpoint. That submission creates a Jira request containing the dataset, organisation, endpoint and documentation details needed by the data management team.

<div class="manage-service-flow" role="region" aria-label="Flow showing how an endpoint moves from data owners through the manage service to the Planning Data platform" tabindex="0">
<pre>
┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐
│   <strong><u>Data owners</u></strong>    │   │ <strong><u>Check and Provide</u></strong>│   │   <strong><u>Jira request</u></strong>   │   │   <strong><u>Data manager</u></strong>   │
│                  │   │                  │   │                  │   │                  │
│ Publish endpoint │──▶│ Check and submit │──▶│ Record endpoint  │──▶│ Review request   │
└──────────────────┘   └──────────────────┘   └──────────────────┘   └────────┬─────────┘
                                                                              │
                                                                              ▼
┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐
│ <strong><u>Config repository</u></strong>│   │   <strong><u>Data manager</u></strong>   │   │  <strong><u>Async backend</u></strong>   │   │ <strong><u>Manage service</u></strong>   │
│                  │   │                  │   │                  │   │                  │
│ Store endpoint   │◀──│ Review and       │◀──│ Process data and │◀──│ Add endpoint     │
│ and entity ranges│   │ confirm preview  │   │ produce preview  │   │ details          │
└────────┬─────────┘   └──────────────────┘   └──────────────────┘   └──────────────────┘
         │
         ▼
┌──────────────────┐   ┌──────────────────────┐
│  <strong><u>Data pipelines</u></strong>  │   │ <strong><u>Planning Data</u></strong>        │
│                  │   │                      │
│ Read config and  │──▶│ platform             │
│ process the data │   │ Make data available  │
└──────────────────┘   └──────────────────────┘
</pre>
</div>

The manage service orchestrates this flow but does not run the main collection pipelines or publish data itself.

## Core service flows

### Add data

The add-data flow creates or updates the configuration for a published endpoint.

| Stage | Technical behaviour |
| --- | --- |
| Request initialisation | The Flask application validates the dataset, organisation, endpoint and documentation parameters and stores the working state in the user session |
| Reference lookup | Service modules retrieve dataset fields, provisioned organisations, existing endpoints and platform entities |
| Processing | The application creates an async `add_data` request containing the endpoint and selected configuration |
| Result presentation | The application reads the async response and renders converted data, transformed data, issues, entity comparisons and proposed configuration |
| Confirmation | The application triggers the config repository workflow with the completed request identifier and any selected endpoint retirements |

The generated configuration can include endpoint, source, column mapping, entity lookup and entity-organisation records. It can also end-date an endpoint that is being replaced.

### Assign entities

The assign-entities flow reuses the async `add_data` processing path for a resource that has already been collected but contains records without entity numbers.

The manage service supplies the dataset, collection, resource and user selections to the async request backend. The backend performs the comparison, assigns entity numbers and generates any duplicate redirects. The manage service renders the results and passes the confirmed request to the same config repository workflow used by the add-data flow.

This boundary is important: the manage service coordinates entity assignment, but entity number generation and duplicate calculation belong to the shared processing service.

## Processing results and previews

The async request backend returns response details and a pipeline summary. The manage service converts these into several technical views:

| Result | Purpose |
| --- | --- |
| Converted data | Shows the source records after conversion into a processable format |
| Transformed data | Shows records after dataset transformation rules have been applied |
| Issue log | Reports validation and transformation issues returned by processing |
| Provision comparison | Compares the resource with platform entities and groups records as new, changed, matching or platform-only |
| Configuration preview | Shows the endpoint, source, column, lookup, entity-organisation and retirement changes that can be written to configuration |

For spatial datasets, response geometry is also rendered on a map. The manage service additionally checks whether the submitted endpoint appears on the data owner's documentation page.

## How confirmed data reaches the platform

When a data manager confirms that the preview is right, the manage service prepares the configuration needed to add the data. This configuration is stored in the [config repository](https://github.com/digital-land/config).

The configuration records:

- the endpoint from which the data pipelines should fetch the data
- the entity ranges assigned to the entities found in the resource
- the collection and processing information needed for the dataset

The data pipelines read this configuration, fetch the data from the endpoint, process it and add the new data to the Planning Data platform.

## Inputs and outputs

| Area | Main inputs | Main outputs |
| --- | --- | --- |
| Add data | Jira request, dataset, organisation, endpoint URL, documentation URL and any field mappings | Checks, comparison results, proposed endpoint and source configuration, proposed entity mappings and a configuration change |
| Assign entities | Dataset, collected resource and the user's entity and duplicate selections | Final entity selections, proposed entity and organisation mappings, duplicate redirects where relevant, and a configuration change |
| Reference information | Planning Data specifications, organisations, existing endpoints, resources and entities | Names, choices, comparisons and validation shown to the user |

The final output of the manage service is normally a reviewed change to configuration. Publishing that configuration, running the data pipelines and serving the resulting data are responsibilities of other parts of the platform.

## Key terms

| Term | Meaning |
| --- | --- |
| Dataset | A collection of related planning data, such as conservation areas or plan timetables |
| Endpoint | The web address from which the platform collects a dataset |
| Configuration | Instructions describing what data to collect, where to collect it and how to process it |
| Pipeline | The automated process that collects, transforms and prepares data for publication |
| Entity | A stable Planning Data record representing a real-world thing |

## Responsibilities and boundaries

### The manage service is responsible for

- authenticated, guided journeys for data management work
- collecting the choices required for an assessment
- supporting column mapping to Planning Data fields
- showing processing results in a form that can be reviewed
- comparing submitted records with entities already on the platform
- supporting entity and duplicate decisions
- preparing the retirement of replaced endpoints
- showing a preview before a user confirms a change
- starting the approved configuration-change workflow
- preventing a known stale assessment from being applied

### The manage service is not responsible for

- defining planning data specifications
- receiving the provider-facing submission journey
- doing all data transformation or entity matching itself
- replacing human review of data and configuration
- merging configuration changes without the agreed review process
- scheduling and running the main collection pipelines
- publishing or serving data through the public Planning Data website and API

## Dependencies

| Service, repository or data | Why the manage service depends on it |
| --- | --- |
| [config-manager](https://github.com/digital-land/config-manager) | Contains the manage service application and its detailed documentation |
| [async-request-backend](https://github.com/digital-land/async-request-backend) | Carries out longer-running data assessment and processing requests |
| [config](https://github.com/digital-land/config) | Stores the endpoint, assigned entity ranges and other configuration needed to collect and process the added data |
| [specification](https://github.com/digital-land/specification) | Defines datasets, fields and provision rules used to guide and validate choices |
| [digital-land-python](https://github.com/digital-land/digital-land-python) | Provides shared data-processing behaviour used across the platform |
| [Planning Data website and API](https://www.planning.data.gov.uk/) | Supplies reference information about datasets and entities and publishes processed data |
| [Submit](https://github.com/digital-land/submit) | Contains the Check and Provide service used by data owners |
| Jira | Records a Check and Provide submission as a request for the data management team |
| GitHub | Provides the reviewed, auditable workflow for configuration changes |

## Detailed documentation

The following pages in the manage service repository contain implementation-level detail:

- [Data-management architecture](https://github.com/digital-land/config-manager/blob/main/docs/datamanager/architecture.md)
- [Add-data configuration workflow](https://github.com/digital-land/config-manager/blob/main/docs/datamanager/github-add.md)

Related service and operational guidance:

- [Check and Provide journey](https://github.com/digital-land/submit/blob/main/docs/check-and-submit-journey.md)
- [Adding data operational guidance](/data-operations-manual/Tutorials/Adding-Data/)
- [Assigning entities operational guidance](/data-operations-manual/How-To-Guides/Maintaining/Assign-entities/)
- [Data pipeline architecture](/architecture-and-infrastructure/data-pipeline-architecture/)
