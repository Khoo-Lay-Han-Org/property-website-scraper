# Context Map

Two contexts, and they do not speak the same language. The ingest context's model of
the world is *advertisements published on portals*. The workspace context's model is
*units, people and money*. The ingest contract is where one becomes the other.

## Contexts

- [Workspace](./apps/web/CONTEXT.md) — the agent's own book and the scraped feed they browse: properties, contacts, deals, follow-ups
- [Ingest](./apps/scraper/CONTEXT.md) — fetching and parsing portal advertisements into normalised payloads

## Relationships

- **Ingest → Workspace**: Ingest submits normalised advertisement payloads to the workspace over HTTP. It never writes the database itself. That submission is the only translation point between the two languages, and the workspace owns every write.
- **Shared vocabulary**: Portal, Advertisement, and the portal's own advertisement identifier. Nothing else crosses the boundary — Contact, Deal and Follow-up are workspace-only, and Fetch, Adapter and Scrape Run are ingest-only.
