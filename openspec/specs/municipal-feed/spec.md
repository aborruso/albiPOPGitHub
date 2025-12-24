# Capability: municipal-feed

## Purpose
Provide RSS feeds for Italian municipal bulletin boards (albi pretori), published via GitHub Pages under the `docs/` directory.

## Requirements

### Requirement: Municipality feed script
Each municipality SHALL have a runnable script that generates its RSS feed into the appropriate `docs/` output folder for that municipality.

#### Scenario: Manual run
- **WHEN** a contributor runs the municipality script locally
- **THEN** the feed file is generated under the municipality output folder in `docs/`

### Requirement: Feed location
Each municipality feed SHALL be published as `docs/<feed-id>/feed.xml`, where `<feed-id>` matches the municipality folder identifier used in the repository.

#### Scenario: Published feed path
- **WHEN** the feed generation completes
- **THEN** the resulting feed is available at `docs/<feed-id>/feed.xml`

### Requirement: RSS structure
Each feed SHALL be a well-formed RSS XML document containing a single `channel` element.

#### Scenario: XML validation
- **WHEN** the feed file is validated with an XML parser
- **THEN** it is well-formed and contains a `channel` element

### Requirement: Channel metadata
Each feed channel SHALL include the following elements populated with municipality metadata:
- `title`, `description`, `link`, and `docs`
- `atom:link` with `rel="self"` and `type="application/rss+xml"`
- `category` elements for AlboPOP metadata domains: `type`, `municipality`, `province`, `region`, `latitude`, `longitude`, `country`, `name`, `uid`

#### Scenario: Metadata present
- **WHEN** a feed is generated
- **THEN** the channel contains the required metadata elements with values for that municipality

### Requirement: Feed items
Each feed SHALL contain items representing bulletin board publications with, at minimum, `title`, `link`, `pubDate`, and `guid`.

#### Scenario: Item fields present
- **WHEN** a publication is included in the feed
- **THEN** its item includes `title`, `link`, `pubDate`, and `guid`

### Requirement: Absolute links
Each item `link` and `guid` SHALL be an absolute URL.

#### Scenario: Link normalization
- **WHEN** the source provides relative URLs
- **THEN** the generator converts them into absolute URLs in the feed

### Requirement: Date format
Each item `pubDate` SHALL be formatted in RFC 822 (RSS-compatible) date format.

#### Scenario: Date formatting
- **WHEN** a publication date is parsed
- **THEN** the `pubDate` field is emitted in RFC 822 format

### Requirement: XML escaping
Feed titles and other text fields SHALL be XML-escaped to avoid invalid characters (`&`, `<`, `>`, `'`, `"`).

#### Scenario: Title escaping
- **WHEN** a publication title contains XML-sensitive characters
- **THEN** those characters are escaped in the feed output

### Requirement: Pagination support
The scraping logic SHALL support pagination when the source bulletin board exposes multiple pages of results.

#### Scenario: Multiple pages
- **WHEN** a source exposes multiple pages
- **THEN** the generator collects items across pages before building the feed
