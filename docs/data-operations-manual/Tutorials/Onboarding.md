---
title: Onboarding
---

> NOTE  
> This is currently a Work In Progress 

## The programme and what it's doing

* [Planning data handbook](https://docs.google.com/document/d/1PoAUktKj80qOTvI4BB3qZkZdwpiGEq_woEfrIdwg2Ac/edit?tab=t.0), (and not fully ported [online version](https://handbook.planning.data.gov.uk/))

## The platform and different services

### Planning data site

[https://www.planning.data.gov.uk](https://www.planning.data.gov.uk)


* Explore the planning data site, can you see what datasets we currently publish?
* Can you use the search functionality to search for particular data in a particular area?
* Read the API docs and see how they reflect the way the searches work
* Click the facts button on an entity page to see how data provenance is recorded

### Data design 

[https://design.planning.data.gov.uk/](https://design.planning.data.gov.uk/)

* Read the documentation of the [design process](https://design.planning.data.gov.uk/data-design-process), does the way the data design team work make sense?
* Explore the planning consideration backlog, look at some considerations in detail - particularly following through to the github discussion and the links to the dataset on the platform
* Take note of the different stages considerations are at, can you work out what stage means we should have data on the platform?

### Submit service: Guidance

[https://www.planning.data.gov.uk/guidance/](https://www.planning.data.gov.uk/guidance/)

* Does the guidance structure help make sense of the journey that data providers go on?
* Read some of the data specification guidance (e.g. [article-4-direction](https://www.planning.data.gov.uk/guidance/specifications/article-4-direction)), does it match the data you saw live on the platform?
* Have a look at the [technical specification](https://digital-land.github.io/specification/specification/article-4-direction/) too, does the data model diagram help make sense of how datasets are connected?

### Submit service: LPA dashboard

[https://submit.planning.data.gov.uk/organisations](https://submit.planning.data.gov.uk/organisations)


* Explore the dashboard pages for some different organisations, can you find one with a lot of issues?
* Explore some of the issues that are displayed to data providers, do they make sense and do you understand how they would resolve them?
* Follow the journey/tasks for a dataset that hasn't been added yet, can you see how it signposts to different parts of the service?

### Submit service: Check

* Can you run some data through the Check service to see how results are displayed to data providers?


## The data model and pipeline

### Pipeline
* Read the [pipeline processes](../../Explanation/Key-Concepts/pipeline-processes) and [pipeline configuration](../../Explanation/Key-Concepts/pipeline-configuration) pages.
* Read the [blog post on the data model](https://digital-land.github.io/blog-post/storing-and-updating-data/)
* Check out the [config repo](https://github.com/digital-land/config/) - can you find the endpoint URL for a dataset you're interested in and download the unprocessed data from a provider?
* Take a look at some of the recent commits to see the sorts of changes that happen.

### Specification

* Read the [specification guidance page](../../Explanation/Key-Concepts/specification).
* Take a look around the [specification repo](https://github.com/digital-land/specification/), particularly individual dataset files (e.g. [article-4-direction.md](https://github.com/digital-land/specification/blob/main/content/dataset/article-4-direction.md?plain=1)) - can you work out what sort of processes some of these fields might control?

### datasette

The [Following the data flow tutorial](../Following-the-data-flow) tutorial uses a new endpoint to demonstrate some different datasette tables, run through it.

### digital-land-python



## The data management team and our processes

### Processes

#### Adding data
* Read the [operational procedures guide](../../Explanation/Operational-Procedures), it should help to start to make sense of the data lifecycle.

#### Data quality
* Read the following pages:
    * [Data quality needs](../../Explanation/Key-Concepts/Data-Quality/Data-quality-1-needs)
    * [Data quality framework](../../Explanation/Key-Concepts/Data-Quality/Data-quality-2-framework)



### Tools and setup

#### Meetings, access and admin
* Follow the key tasks of the [onboarding Trello card](https://trello.com/c/bONeNXuA/144-template-onboarding-ticket) [note - is this still live?? Looks fairly up to date.. but not sure about access (ironically..)]

#### Environment
* You'll want to run any code in a standalone environment. You should be able to get an environment set up by cloning the repo you need and running `make init` which will install any packages needed in the environment. But before doing that you may need to install some other software on your machine. See the [development how to guides](../../../development/how-to-guides/) for how to do this, you may need wsl if you're on a windows laptop, and you'll want to use venv or a similar environment management tool to create new environments.

#### git
* You'll need to be given access to the digital-land organisation.
* If you're new to git, follow the github [start your journey](https://docs.github.com/en/get-started/start-your-journey) process on their docs, particularly the "Hello World" section.
* Once you've got access to digital-land, you may want to [configure ssh](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/checking-for-existing-ssh-keys) - this will mean you don't need to authenticate for every push.
* 

#### config
* Clone the config repo and get a virtual environment running
* Run `make makerules` then `make init` 

#### jupyter-analysis
* Clone the [jupyter-analysis](https://github.com/digital-land/jupyter-analysis) repo and run `make init` in a virtual environment
* Try running a notebook (for example, [map_conservation_area_duplicates](https://github.com/digital-land/jupyter-analysis/blob/main/reports/find_conservation_area_duplicates/map_conservation_area_duplicates.ipynb))