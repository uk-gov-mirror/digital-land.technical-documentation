---
title: Manage service
description: A high-level technical overview of the service used to add and configure data on the Planning Data platform.
---

## What the manage service does

The manage service helps data managers create and maintain the configuration that data pipelines use to add data to the Planning Data platform. It sits between data submitted through Check and Provide and the pipelines that process that data.

> The Add data flow creates the initial configuration that the pipeline uses to collect, process and add new entities from a provided endpoint. If an overnight pipeline run cannot automatically assign an entity number to a record, it reports an `unknown entity` issue. The Assign entities flow is then used to update the lookup configuration for those unresolved records, allowing a later pipeline run to add them to the platform.

The service supports two main flows:

- [Add data](add-data/) creates the initial endpoint and processing configuration used by the data pipeline.
- [Assign entities](assign-entities/) updates the entity lookup configuration for records that the pipeline reported as `unknown entity`.

The manage service coordinates these flows without performing all processing itself. Longer-running transformation, comparison and entity-assignment work is delegated to the async request backend.

## Who uses the manage service

The manage service is primarily used by data managers and data operations teams responsible for adding data to the platform.

Developers and support teams may also use the service when investigating configuration, processing or integration problems.

## Technical overview

The manage service is a server-rendered web application. It provides the user interface and coordinates requests between data managers, shared Planning Data services and GitHub.

| Area | Technology or approach |
| --- | --- |
| Application | Python 3.10 and the Flask web framework |
| Application structure | Flask blueprints separate the main service areas and flows |
| Web pages | Server-rendered Jinja templates using GOV.UK Frontend and shared Digital Land frontend components |
| Data storage | PostgreSQL, accessed through SQLAlchemy |
| Database changes | Flask-Migrate and Alembic migrations |
| Authentication | GitHub OAuth, restricted to members of the Digital Land GitHub organisation |
| Longer-running processing | Delegated to the async request backend rather than performed entirely in a web request |
| Packaging | A Docker container containing the Python application and compiled frontend assets |
| Delivery | GitHub Actions runs tests, builds the container image and publishes it to Amazon Elastic Container Registry in the `eu-west-2` AWS region |

The repository supports development, staging and production service environments. The infrastructure that runs the published container is managed separately from the application repository.

## Application responsibilities

The Flask application:

- presents the add-data and assign-entities flows
- stores service state and request metadata in PostgreSQL
- retrieves dataset, organisation, endpoint and entity information from Planning Data services
- sends processing requests to the async request backend
- displays processing results and configuration previews
- authenticates users through GitHub
- triggers the GitHub workflow that writes confirmed configuration changes

This separation keeps the web application focused on user interaction and orchestration. Shared processing services perform the longer-running data transformation, comparison and entity-assignment work.

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

## Main integrations

| Service or repository | Integration |
| --- | --- |
| [Async request backend](https://github.com/digital-land/async-request-backend) | Checks and transforms submitted resources, compares records and assigns entity numbers |
| [Planning Data website and API](https://www.planning.data.gov.uk/) | Provides dataset and existing entity information and publishes processed data |
| Datasette | Provides platform and configuration reference data |
| [Specification](https://github.com/digital-land/specification) | Defines datasets, fields and provision rules |
| GitHub API | Provides authentication and starts configuration workflows |
| [Config repository](https://github.com/digital-land/config) | Stores endpoint, entity and processing configuration |

## How configuration reaches the platform

After a data manager confirms a preview, the manage service starts a GitHub workflow that writes the approved configuration to the config repository.

The configuration records:

- the endpoint from which the data pipelines should fetch the data
- the entity ranges assigned to records in the resource
- the collection and processing information needed for the dataset

The data pipelines read this configuration, fetch the data from the endpoint, process it and add the data to the Planning Data platform.

## Detailed documentation

The following pages in the manage service repository contain implementation-level detail:

- [Data-management architecture](https://github.com/digital-land/config-manager/blob/main/docs/datamanager/architecture.md)
- [Add-data configuration workflow](https://github.com/digital-land/config-manager/blob/main/docs/datamanager/github-add.md)

Related technical documentation:

- [Data pipeline architecture](/architecture-and-infrastructure/data-pipeline-architecture/)
