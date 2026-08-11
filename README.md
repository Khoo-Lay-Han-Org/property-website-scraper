# property-website-scraper

A single Malaysian property agent's working tool: **the book** (own mandates, contacts, interactions, follow-up queue) and **the feed** (listings scraped from mudah.my, PropertyGuru, iProperty and EdgeProp).

> **Status: design-stage.** The V1 schema and the stack are decided and documented; almost no application code exists yet. n8n is currently the only thing that writes to the database.

## Documentation

| Document | What is in it |
|---|---|
| [`DATABASE_SCHEMA.md`](DATABASE_SCHEMA.md) | Index for the data layer. Eight authoritative chapters under [`docs/database/`](docs/database/) — access patterns, entities, integrity, operations, decisions |
| [`docs/architecture/01-stack.md`](docs/architecture/01-stack.md) | Language, runtime and framework decision — TypeScript for the application spine, Python for the AI/ML layer |

Where the index and a chapter disagree, the chapter is right.
