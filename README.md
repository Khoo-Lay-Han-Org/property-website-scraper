# property-website-scraper

A single Malaysian property agent's working tool: **the book** (own mandates, contacts, interactions, follow-up queue) and **the feed** (listings scraped from mudah.my, PropertyGuru, iProperty and EdgeProp).

> **Status: design-stage.** The V1 schema and the stack are decided and documented; almost no application code exists yet. n8n is currently the only thing that writes to the database.

## Layout

```
apps/
  web/         Laravel 13 + Inertia 3 + Svelte 5 — the application spine
    resources/js/    the Svelte layer: Inertia pages, shadcn-svelte components
  scraper/     Python — AI/ML and, conditionally, the scraper (SD-7/SQ-6)
infra/
  n8n/         the transitional ingest layer
docs/          the schema and architecture records
```

Two deployables, three languages. The frontend is **not** a separate service: Inertia serves Svelte components from `apps/web/resources/js` as static assets built by Vite, so no Node runs in production (SD-2).

## Setup

**Laravel** — needs PHP 8.4, Composer and pnpm:

```sh
cd apps/web
composer setup     # install, .env, key, migrate, pnpm install, build
composer dev       # serve + vite + queue + logs
```

**Python** — needs [uv](https://docs.astral.sh/uv/):

```sh
cd apps/scraper
uv sync --extra dev
uv run pytest
```

**n8n** — credentials come from the repository-root `.env`, so the `--env-file` flag is mandatory:

```sh
cd infra/n8n
docker compose --env-file ../../.env up -d
```

See [`infra/n8n/README.md`](infra/n8n/README.md).

**Git hooks** — ruff, pint, eslint and prettier on staged files:

```sh
brew install lefthook
lefthook install
```

## Documentation

| Document | What is in it |
|---|---|
| [`docs/DATABASE_SCHEMA.md`](docs/DATABASE_SCHEMA.md) | Index for the data layer. Eight authoritative chapters under [`docs/database/`](docs/database/) — access patterns, entities, integrity, operations, decisions |
| [`docs/architecture/01-stack.md`](docs/architecture/01-stack.md) | Language, runtime and framework decision — **Svelte + Laravel/PHP + Python** for AI/ML |

Where the index and a chapter disagree, the chapter is right.
