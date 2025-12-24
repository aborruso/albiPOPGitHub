# Change: Add Terre del Reno municipal feed

## Why
Users need an AlboPOP RSS feed for Comune di Terre del Reno, which follows the same publication pattern as `c_l109`.

## What Changes
- Add a new municipality scraper folder and script based on `c_l109`, tailored to Terre del Reno metadata and base URL, in the special-case folder `cdtdr/`.
- Publish the generated feed under `docs/cdtdr/feed.xml`.

## Impact
- Affected specs: `municipal-feed`
- Affected code: new `cdtdr/` folder, `docs/cdtdr/feed.xml`
