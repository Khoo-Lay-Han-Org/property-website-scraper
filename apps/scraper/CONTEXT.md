# Ingest

Fetching advertisements from the property portals and turning them into normalised
payloads the workspace can accept. This context knows nothing about contacts, deals or
follow-ups — it knows about pages, parsing and provenance.

## Language

**Portal**:
A third-party property marketplace advertisements are fetched from — mudah, PropertyGuru, iProperty, EdgeProp. Shared with the workspace context.
_Avoid_: website, site, source

**Advertisement**:
One published ad on one Portal, identified by that Portal's own advertisement identifier. This context deals only in Advertisements; deciding which real-world unit an Advertisement describes is the workspace's job, not ours.
_Avoid_: listing, property, ad post

**Scrape Target**:
A standing instruction about what to fetch from a Portal — which search, which area, how many pages deep. Configuration, not code.
_Avoid_: job config, search config

**Fetch**:
One HTTP request and its response. A single Fetch of a search results page yields many Advertisements.
_Avoid_: request, hit, call

**Raw Payload**:
The unparsed body of a Fetch, kept so a parsing bug can be re-run against what was actually served rather than against what we wish had been served.
_Avoid_: response body, HTML dump, cache

**Scrape Run**:
One execution of the scrape across its Scrape Targets, and the operational record of how it went. Not part of the domain graph — it is a log.
_Avoid_: job, batch, crawl

**Fetcher**:
The half that gets bytes — plain HTTP for the portals that allow it, a real browser for the ones that do not. Chosen per Portal and independent of parsing.
_Avoid_: client, downloader, crawler

**Adapter**:
The half that turns one Portal's Raw Payload into normalised Advertisements. One Adapter per Portal, and the only place a Portal's quirks are allowed to live.
_Avoid_: parser, extractor, scraper

**Normalised Advertisement**:
What an Adapter emits and the workspace accepts — a Portal's advertisement expressed in shared vocabulary, with prices in sen and identifiers cleaned. The contract between the two contexts.
_Avoid_: DTO, payload, record
