# n8n

The transitional ingest layer. n8n is currently the only thing that writes to the
database; `docs/architecture/01-stack.md` §8 records the constraints on whatever
replaces it, and SQ-2 leaves the retirement date open.

## Running it

Credentials live in the **repository-root `.env`**, not in this directory, so the
`--env-file` flag is mandatory — without it every `${VAR}` in the compose file
resolves to an empty string and the containers start unauthenticated:

```sh
cd infra/n8n
docker compose --env-file ../../.env up -d
```

Editor at <http://localhost:5678>. To check interpolation without starting
anything:

```sh
docker compose --env-file ../../.env config
```

## What is here

| Path | What it is |
|---|---|
| `docker-compose.yml` | n8n 2.31.7 plus the matching external task-runners sidecar. Project name pinned to `property-workspace`; the `n8n_data` volume is `external: true` and is **not** created by this file |
| `n8n-task-runners.jsonc` | Mounted into the runners container at `/etc/n8n-task-runners.jsonc` |
| `local-files/` | Bind-mounted to `/files` inside n8n. Git-ignored — contents are local working files, not versioned |
| `workflows/main.json` | Export of the live workflow (Ollama chat model chain) |
| `workflows/chat-agent.json` | Export of the langchain chat-trigger workflow |

**The exports are point-in-time snapshots, not a deploy mechanism.** Nothing reads
them on startup; they are versioned so the workflow logic is reviewable in diffs
and recoverable if the `n8n_data` volume is lost. Re-export by hand after
meaningful changes.

## Ollama

Commented out in the compose file. `OLLAMA_BASE_URL` is read from the root `.env`
and points at whatever host is serving it; if Ollama is uncommented here, that
variable must use the Compose service name rather than `localhost`.
