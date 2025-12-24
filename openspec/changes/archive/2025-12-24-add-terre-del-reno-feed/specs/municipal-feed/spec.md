## ADDED Requirements
### Requirement: Terre del Reno feed
The system SHALL publish an AlboPOP RSS feed for Comune di Terre del Reno under `docs/cdtdr/feed.xml`.

#### Scenario: Feed generation
- **WHEN** the Terre del Reno scraper runs successfully
- **THEN** a well-formed RSS feed is generated at `docs/cdtdr/feed.xml`
