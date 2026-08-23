# Task runner for the monorepo — `brew install just`, then run `just` for the list.
#
# Every recipe uses the [working-directory] attribute rather than a `cd` prefix,
# because just runs each recipe line in its own shell: a `cd` on one line would
# not carry to the next.
#
# The per-app recipes are deliberately thin wrappers over each app's own
# tooling (composer scripts, uv) rather than reimplementations of it. When a
# gate changes, it changes in composer.json or pyproject.toml, and the recipe
# keeps working. `just check` is the local equivalent of .github/workflows/tests.yml.

_default:
    @just --list --unsorted

# ---------------------------------------------------------------- setup

# Install the pinned toolchain, both apps' dependencies, and the git hooks
setup: tools setup-web setup-scraper hooks

# PHP is not among them and stays a Homebrew prerequisite — see mise.toml.

# Install every tool version pinned in mise.toml
tools:
    mise install

# Laravel: install, .env, key, migrate, pnpm install, build
[working-directory: 'apps/web']
setup-web:
    composer setup

# Python: resolve and sync the dev extra into .venv
[working-directory: 'apps/scraper']
setup-scraper:
    uv sync --extra dev

# Install the lefthook pre-commit hook (formatters on staged files)
hooks:
    lefthook install

# ---------------------------------------------------------------- develop

# Laravel dev server, Vite, queue worker and log tail together
[working-directory: 'apps/web']
dev:
    composer dev

# Laravel tinker REPL
[working-directory: 'apps/web']
tinker:
    php artisan tinker

# Run an artisan command, e.g. `just artisan migrate:status`
[working-directory: 'apps/web']
artisan *args:
    php artisan {{ args }}

# Run a command inside the scraper venv, e.g. `just uv python -c 'import pw'`
[working-directory: 'apps/scraper']
uv *args:
    uv run {{ args }}

# ---------------------------------------------------------------- gates

# Everything CI runs, in CI's order. The pre-push check.
check: check-web check-scraper

# pint, eslint, prettier, svelte-check, larastan, pest, rector, peck
[working-directory: 'apps/web']
check-web:
    composer ci:check

# ruff lint, ruff format check, ty, pytest — mirrors the scraper CI job
[working-directory: 'apps/scraper']
check-scraper:
    uv run ruff check .
    uv run ruff format --check .
    uv run ty check
    uv run pytest

# Test suites only, no linters
test: test-web test-scraper

[working-directory: 'apps/web']
test-web:
    php artisan test --compact

[working-directory: 'apps/scraper']
test-scraper:
    uv run pytest

# Type checkers only — larastan on PHP, ty on Python
types: types-web types-scraper

[working-directory: 'apps/web']
types-web:
    composer types:check

[working-directory: 'apps/scraper']
types-scraper:
    uv run ty check

# ---------------------------------------------------------------- fix

# Apply every formatter and autofixer across both apps
fmt: fmt-web fmt-scraper

[working-directory: 'apps/web']
fmt-web:
    composer lint
    pnpm run lint
    pnpm run format

[working-directory: 'apps/scraper']
fmt-scraper:
    uv run ruff check --fix .
    uv run ruff format .

# ---------------------------------------------------------------- n8n

# n8n reads its credentials from the repository-root .env, so --env-file is
# mandatory; see infra/n8n/README.md.

[working-directory: 'infra/n8n']
n8n-up:
    docker compose --env-file ../../.env up -d

[working-directory: 'infra/n8n']
n8n-down:
    docker compose --env-file ../../.env down

[working-directory: 'infra/n8n']
n8n-logs:
    docker compose --env-file ../../.env logs -f
