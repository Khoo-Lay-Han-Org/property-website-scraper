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

Prerequisites are PHP, Composer, Docker and [`mise`](https://mise.jdx.dev):

```sh
brew install mise php@8.4 composer
just setup     # toolchain, both apps, git hooks
just           # list every recipe
```

`mise.toml` pins Node, pnpm, Python, uv, `just`, lefthook and gitleaks, so those versions come from one file rather than from whatever each contributor happens to have installed. Add `eval "$(mise activate zsh)"` to your shell profile to pick them up on `cd`, or prefix commands with `mise exec --`.

PHP is the exception and stays a Homebrew prerequisite: every mise backend for it compiles from source, which takes longer than the rest of the toolchain combined. `apps/web/composer.json` requires `^8.4`, so a mismatch surfaces at `composer install`.

`just` is a thin wrapper over each app's own tooling — composer scripts and uv — so it never needs to know what a gate does, only where to run it. Working directly in `apps/web` or `apps/scraper` remains equivalent.

| Recipe | What it does |
|---|---|
| `just dev` | Laravel serve + Vite + queue + log tail |
| `just check` | Everything CI runs, both apps, in CI's order — the pre-push check |
| `just test` | Test suites only, no linters |
| `just types` | Type checkers only — larastan on PHP, `ty` on Python |
| `just fmt` | Every formatter and autofixer across both apps |
| `just artisan <cmd>` | An artisan command, without the `cd` |
| `just n8n-up` / `n8n-down` / `n8n-logs` | n8n compose stack, with the mandatory `--env-file` already applied |

n8n reads its credentials from the repository-root `.env`; see [`infra/n8n/README.md`](infra/n8n/README.md).

### Gates

`lefthook` runs formatters only on staged files — ruff, pint, eslint, prettier. Everything that can fail slowly is CI's job (`.github/workflows/tests.yml`), and `just check` reproduces it locally:

| Layer | Gates |
|---|---|
| `apps/web` | pint, eslint, prettier, svelte-check, larastan level 7, rector, peck, pest — 100% type coverage, 90% line coverage |
| `apps/scraper` | ruff lint, ruff format, [`ty`](https://github.com/astral-sh/ty), pytest with coverage |

Coverage on the Python side is measured but not yet enforced: `src/pw` is scaffolding, so the floor in `pyproject.toml` stays at 0 until the scraper lands (SD-7/SQ-6).

## Documentation

| Document | What is in it |
|---|---|
| [`docs/DATABASE_SCHEMA.md`](docs/DATABASE_SCHEMA.md) | Index for the data layer. Eight authoritative chapters under [`docs/database/`](docs/database/) — access patterns, entities, integrity, operations, decisions |
| [`docs/architecture/01-stack.md`](docs/architecture/01-stack.md) | Language, runtime and framework decision — **Svelte + Laravel/PHP + Python** for AI/ML |

Where the index and a chapter disagree, the chapter is right.
