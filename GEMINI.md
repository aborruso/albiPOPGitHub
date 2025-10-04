# AlbiPOPGitHub Project Analysis

This document provides a comprehensive overview of the AlbiPOPGitHub project, intended to be used as instructional context for future interactions.

## Project Overview

AlbiPOPGitHub is a data scraping and aggregation project designed to collect and standardize public notices (*albo pretorio*) from the websites of various Italian municipalities. The primary goal is to make these notices easily accessible and searchable by converting them into a consistent RSS feed format.

The project is structured as a collection of individual scraper modules, each tailored to a specific municipality's website. These modules are located in directories prefixed with `c_`. The scrapers extract the relevant data, transform it into a standardized format, and then generate an RSS feed.

A key feature of this project is its integration with the Internet Archive's Wayback Machine. The project archives the source websites, ensuring the long-term availability and verifiability of the public notices, even if the original websites are no longer accessible.

For some feeds, the project uses the `rsspls` tool to generate RSS feeds from web pages. This tool is documented in `risorse/docs/rsspls.md`. An example of its use can be found in `c_a965/c_a965.sh`.

### Key Components

*   **Scraper Modules (`c_*` directories):** Each directory contains the logic for scraping a specific municipality's website. This can be a shell script, a Node.js script using Puppeteer for dynamic sites, or a combination of tools.
*   **`docs` Directory:** This directory serves as the public-facing output of the project. It hosts the generated RSS feeds for each municipality.
*   **`risorse` Directory:** Contains shared resources, such as the RSS feed template (`feedTemplate.xml`) and the list of websites to be archived (`listArchive.yml`).
*   **`webarchive` Directory:** Contains the scripts responsible for archiving the source websites to the Internet Archive.
*   **`bin` Directory:** Contains various binaries used by the scrapers, such as `mlr` and `scrape`.

## Building and Running

The project does not have a single build process. Instead, each scraper module is executed independently. The primary workflow is managed by GitHub Actions, as defined in the `.github/workflows` directory.

### Running a Scraper

To run a specific scraper, you would typically execute the main script within its corresponding `c_` directory. For example, to run the scraper for Aci Castello:

```bash
./c_a026/c_a026.sh
```

### Archiving

The archiving process is handled by the `webarchive/webarchive.sh` script. This script reads the list of URLs from `risorse/listArchive.yml` and uses the Internet Archive API to save them. This process requires an API key, which is stored in a local `conflocale` file (not checked into version control).

## Development Conventions

*   **Modularity:** Each municipality has its own dedicated scraper module, promoting separation of concerns and making it easier to add new municipalities or update existing scrapers.
*   **Data Transformation:** The project uses a combination of command-line tools for data transformation, including `xmlstarlet`, `jq`, and `mlr` (Miller). This allows for a flexible and powerful data processing pipeline.
*   **RSS Standardization:** All scrapers produce a standardized RSS feed based on the `risorse/feedTemplate.xml` template. This ensures that the output is consistent across all municipalities.
*   **Archiving:** The project emphasizes data preservation by archiving the source websites to the Internet Archive.
*   **Automation:** The project is designed to be run automatically, likely via scheduled jobs (e.g., GitHub Actions), to keep the RSS feeds up-to-date.
