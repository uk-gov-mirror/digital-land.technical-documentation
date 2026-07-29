---
title: Assign entities
description: The technical flow used to update entity configuration for records that a pipeline could not resolve.
---

## Purpose

The assign-entities flow updates the configuration for records in already-added data that an overnight pipeline run was unable to resolve.

During pipeline processing, the lookup phase tries to find an entity number using the record's prefix, reference, organisation and configured lookup rules. If it cannot find a matching entity, it records an `unknown entity` issue and cannot add that record as a Planning Data entity.

The assign-entities flow processes these unresolved records, assigns entity numbers and updates the lookup configuration that connects each source reference to a stable Planning Data entity number. A later pipeline run can then resolve the records and add the new entities to the platform.

## Inputs

The flow uses:

- the dataset and collection
- the collected resource hash
- the providing organisation
- the config repository branch
- any entity references excluded by the data manager
- any duplicate redirects selected or generated during processing

## Request and processing flow

Assign entities is not a separate async request type. The manage service creates an async `add_data` request for an existing resource.

| Component | Responsibility |
| --- | --- |
| Manage service | Selects the resource, validates inputs, captures user selections and submits the async request |
| Async request backend | Transforms the resource, compares it with platform entities, assigns entity numbers and generates duplicate redirects |
| Planning Data API | Supplies existing entities used for comparison |
| Config repository workflow | Writes confirmed lookup, entity-organisation and redirect configuration |

The manage service can submit a replacement async request when entity or duplicate selections change. This keeps processing and number assignment in the shared backend rather than reproducing those rules in the web application.

## Entity comparison

Processing categorises resource records as:

| Category | Meaning |
| --- | --- |
| New | The reference is not already represented by an entity on the platform |
| Changed | The entity exists but one or more transformed values differ |
| Matching | The entity exists and the transformed data matches |
| Platform only | The entity is on the platform but not in the submitted resource |

Only eligible new records are selected for entity assignment. Possible duplicates can also produce redirects from an old entity number to the entity that should represent the record.

## Post-assignment checks

After entity numbers have been proposed, the manage service displays:

- transformed records with their assignment status
- new lookup rows
- entity-organisation rows
- possible duplicate candidates
- generated entity redirects
- processing and validation issues

This review checks the proposed assignments and exposes errors that are only visible after entity assignment, before the resulting configuration is written. Processing can then be checked again to confirm that the previously unresolved records no longer produce `unknown entity` issues.

## Service boundaries

The manage service coordinates the flow and displays its results. It does not calculate entity number ranges or generate redirect rows itself; those responsibilities belong to the async request backend.

The config repository stores the updated mappings. A later pipeline run reads those mappings, resolves the previously unknown records and adds the new entities to the platform.
