# TypeScript type generation — OpenAPI, the transformer, and the first-party option that outflanks both

*Architecture chapter 03. Adjudicates a challenge to **PD-1** of [Laravel packages & DX tooling](02-laravel-packages.md). [Stack decision](01-stack.md) remains authoritative for SD-2, SD-5 and SD-6, which this chapter must obey.*

| | |
|---|---|
| **Doc version** | 1.1.0 |
| **Date** | 2026-08-27 |
| **Status** | **Advisory.** Upholds PD-1's ruling on the question asked, and corrects PD-1 on three points of fact. Nothing in this chapter is implemented |
| **Owner** | Vincent Khoo (sole operator) |
| **Headline** | **The operator's guess is right, but not for the reason anyone would guess.** OpenAPI is technically capable of carrying these types — a `components`-only document with no `paths` is legal under OAS 3.1 and both leading TypeScript generators consume one, verified by execution. It loses because **not one OpenAPI generator in the PHP ecosystem models an Inertia page prop.** A full-clone grep for `inertia` across Scramble, swagger-php, `laravel-openapi` and L5-Swagger returns **zero files**. **The larger finding is not about OpenAPI at all:** `laravel/wayfinder` — already installed here — has a `next` branch that generates Inertia page props, shared data, Form Request types, Eloquent models and PHP enums, first-party and MIT, and Inertia's own TypeScript documentation points at it. It is `dev-next` with no tag, so it does not displace PD-1 today. It is the reason PD-1 should be re-read before it is executed |

---

## 1. Scope & method {#scope}

**Covers** one question, asked directly: *"How about generating the TypeScript types via an OpenAPI-compatible schema? I'm guessing no?"* — a challenge to **PD-1**, which selected `spatie/laravel-data` plus `spatie/laravel-typescript-transformer` as the answer to **SQ-5**'s data-shape half.

The chapter tests three things rather than one. Whether an OpenAPI-driven pipeline works here. Whether PD-1's own reasoning survives re-reading eight weeks later. And whether either is still the best available answer. All three came back with something.

**Non-goals.** The route half of SQ-5 (Wayfinder already closes it, and `01-stack.md` §7 says so). The schema chapters. Hosting. Whether `spatie/laravel-data` is a good DTO layer on its own terms — PD-1 §4.1 argued that and this chapter does not revisit it.

**Provenance markers** follow the convention of `01-stack.md` and `02-laravel-packages.md`: `[MEASURED]` for something observed directly, `[E]` for evidenced in the repository, `[D]` for design intent, `[ASSUMED]` for a working assumption not yet tested, and `[UNVERIFIED]` for a claim this chapter could not confirm against a primary source.

**Evidence standard, and it is stricter here than in chapter 02.** Every version, date, licence and constraint comes from `repo.packagist.org/p2/<vendor>/<package>.json` or `registry.npmjs.org/<pkg>`, read on **2026-08-26**. Every capability claim comes from the vendor's own README, documentation site, or its published source read directly from `raw.githubusercontent.com`. Repository activity comes from the GitHub API. **Two capability claims were settled by executing the tool** rather than by reading about it, and are marked as such. No blog post, article, comparison site or listicle is cited anywhere in this document, for anything.

**On the observation date.** The npm and Packagist numbers below are a snapshot. The facts that carry the decisions — that no OpenAPI generator models Inertia, that Wayfinder `next` has no tag, that Scramble's `laravel-data` support is commercial — are structural and will not move on a patch release. Re-read §3 before acting if a quarter has passed.

---

## 2. The decision {#decision}

New ID prefix **TD-\*** (type-generation decision), chosen to avoid collision with `SD-*`, `SQ-*`, `PD-*`, `PQ-*`, `AP-*`, `IG-*`, `OQ-*` and `M*` already in use `[MEASURED: grep across docs/ and the repository root @ 2026-08-26 — no prior TD-n or TQ-n]`.

| ID | Subject | Ruling |
|---|---|---|
| **TD-1** | OpenAPI as the SQ-5 answer for the workspace screens | **Declined, and the operator's guess is correct.** Not one OpenAPI generator in the PHP ecosystem has any model of an Inertia page prop, and no TypeScript generator on the other end produces a shape a Svelte page component can use directly. §4, §5 |
| **TD-2** | The technical objection people expect — "OpenAPI needs endpoints, Inertia has none" | **Half true, and the half that is false must be recorded.** A `components`-only OpenAPI document with no `paths` is legal under OAS 3.1 and is consumed correctly by both leading generators. The blocker is tooling, not the specification. §4.2, §4.3 |
| **TD-3** | `dedoc/scramble` re-examined | **Declined, on a cost PD-1 did not record.** Scramble's `spatie/laravel-data` support is **Scramble PRO — a commercial product at $99**. The MIT package ships only advertisements for it. §5.1 |
| **TD-4** | `vyuldashev/laravel-openapi` | **Declined — cannot be installed.** Latest tag v1.12.0 of **2023-05-04**; neither it nor `dev-master` declares Laravel 11, 12 or 13. §5.2 |
| **TD-5** | `zircote/swagger-php` and `darkaonline/l5-swagger` | **Declined on burden, not health.** Both are healthy; both are hand-written attributes. They convert a drift problem into a second hand-maintained source of truth, which is the failure mode SQ-5 exists to remove. §5.3 |
| **TD-6** | The TypeScript half of the pipeline | **Not the bottleneck.** `openapi-typescript` and `@hey-api/openapi-ts` both handle a paths-less document and both emit runtime-free types. If TD-9 ever fires, this is a solved sub-problem. §5.4 |
| **TD-7** | PD-1 §4.1 and §11 describe `spatie/typescript-transformer` **v2**, not the v3.3.0 PD-1's own registry table pins | **Correction to PD-1.** `config/typescript-transformer.php`, `--tag=typescript-transformer-config` and `DataTypeScriptCollector` before `DefaultCollector` do not exist in v3. §6.1 |
| **TD-8** | PD-1 §4.1's claim that Wayfinder and the transformer "do not overlap" | **Correction to PD-1 — it is now false in both directions.** Transformer v3 generates routes; Wayfinder `next` generates data shapes. §6.2, §7 |
| **TD-9** | `laravel/wayfinder` on `dev-next` | **The finding of this chapter. Do not adopt yet; do not execute PD-1 without reading §7 first.** First-party, MIT, generates exactly SQ-5's data-shape half, and Inertia's own docs point at it. It has no tagged release and a standing "the API is subject (and likely) to change" warning. §7 |
| **TD-10** | OpenAPI for the **ingest** contract (Python → Laravel) | **Adopt when that endpoint is built, not before.** This is the one place OpenAPI genuinely wins, and it is a different problem from SQ-5. §9 |
| **TD-11** | PD-2's CI drift check | **Unchanged and tool-independent.** No candidate in this chapter offers a `--check` mode; every one of them needs `generate` followed by `git diff --exit-code`. PD-2 survives whichever way TD-9 resolves. §5.5 |
| **TD-12** | `scalar/laravel` — the API reference renderer | **Not a candidate for this question, on category rather than merit.** Scalar consumes an OpenAPI document; it does not produce one and it emits no TypeScript. It sits downstream of the producer problem that decides TD-1, and inherits it whole. Its only slot here is as the reader for TD-10's ingest document, and even there it is optional. §3.4, §5.6, §9 |
| **TD-13** | `knuckleswtf/scribe` — the producer §3.1 of v1.0.0 missed | **Declined for the same structural reason as TD-1, confirmed the same way.** Healthy, MIT, Laravel 13 supported, and it does emit OpenAPI — but `grep -ril inertia` over a full clone returns **zero files**, it has no `spatie/laravel-data` awareness, and its response strategies make live HTTP calls against the routes they document. §5.6 |

---

## 3. Registry facts {#registry}

### 3.1 The PHP side — OpenAPI document generators {#producers}

`[MEASURED: repo.packagist.org/p2/<vendor>/<package>.json @ 2026-08-26]`. "L13" is the package's own declared constraint on `laravel/framework` or `illuminate/contracts`.

| Package | Version | Released | L13 | PHP | Licence | Stars / last push |
|---|---|---|---|---|---|---|
| `dedoc/scramble` | **v0.13.42** | 2026-08-21 | `^10.0\|^11.0\|^12.0\|^13.0` | ^8.1 | MIT | 2,189 / 2026-08-21 |
| `zircote/swagger-php` | **6.7.0** | 2026-08-24 | n/a — framework-agnostic | >=8.2 | **Apache-2.0** | 5,306 / 2026-08-24 |
| `darkaonline/l5-swagger` | **11.1.0** | 2026-06-12 | `^13.0 \|\| ^12.1 \|\| ^11.44` | ^8.2 | MIT | 2,931 / 2026-06-12 |
| `vyuldashev/laravel-openapi` | **v1.12.0** | **2023-05-04** | **none — tops out at `^10.0`** | ^8.0 | MIT | 461 / 2025-06-11 |
| `knuckleswtf/scribe` | **5.11.0** | 2026-06-08 | `^9.21 \|\| ^10.0 \|\| ^11.0 \|\| ^12.0 \|\| ^13.0` | >=8.1 | MIT | 2,329 / 2026-08-13 |

Two rows deserve a sentence each. **`zircote/swagger-php` is the only non-MIT candidate in this chapter** — Apache-2.0, which is permissive but is a second licence in a dependency tree that is otherwise uniformly MIT. And **`vyuldashev/laravel-openapi` is dead for this project's purposes**: its latest tag is three and a quarter years old, and even its `dev-master` branch (last pushed 2025-06-11) declares only up to `^12.0`. Composer will refuse to resolve it against `laravel/framework ^13.17` `[E: apps/web/composer.json]`. Its 41 open issues are the same signal `01-stack.md` §6.2 read off `turso/libsql`.

**`knuckleswtf/scribe` was missing from v1.0.0 of this table and is added in v1.1.0** `[MEASURED: repo.packagist.org/p2/knuckleswtf/scribe.json and api.github.com/repos/knuckleswtf/scribe @ 2026-08-27]`. It was found by reading `scalar/laravel`'s own documentation, which names it as one of three recommended producers (§3.4). It is a real candidate and a healthy one — the omission was an oversight, not a judgement. §5.6 disposes of it, and it loses to the same structural fact as every other producer here rather than to anything about its own quality. Note its dependency footprint, which is the largest of the five: it pulls `fakerphp/faker`, `nikic/php-parser`, `nunomaduro/collision`, `league/flysystem`, `ramsey/uuid`, `parsedown/parsedown`, `symfony/yaml`, `symfony/var-exporter`, `mpociot/reflection-docblock` and `shalvah/upgrader`, and requires `ext-pdo` and `ext-fileinfo` `[MEASURED @ 2026-08-27]`.

Scramble is **still 0.x after 153 releases** `[MEASURED: repo.packagist.org/p2/dedoc/scramble.json @ 2026-08-26]`. That is not an abandonment signal — it ships weekly — but a package that has declined to cut a 1.0 across three years of active development is making a statement about its API stability that is worth hearing.

### 3.2 The TypeScript side — OpenAPI consumers {#consumers}

`[MEASURED: registry.npmjs.org/<pkg> for version, release time and licence; api.npmjs.org/downloads/point/last-week/<pkg> for the download window 2026-08-18 → 2026-08-24; api.github.com/repos/<org>/<repo> for stars — all @ 2026-08-26]`

| Package | Version | Released | Licence | Weekly downloads | Stars |
|---|---|---|---|---|---|
| `openapi-typescript` | **7.13.0** | **2026-02-11** | MIT | 6,707,744 | 8,330 |
| `@hey-api/openapi-ts` | **0.99.0** | 2026-06-22 | MIT | 4,416,207 | 5,313 |
| `orval` | **8.26.0** | 2026-08-23 | MIT | 1,948,710 | 6,392 |
| `swagger-typescript-api` | **13.12.6** | 2026-07-17 | MIT | 578,456 | 4,116 |
| `json-schema-to-typescript` | **15.0.4** | **2025-01-14** | MIT | 3,390,146 | 3,336 |

**Two maintenance observations that a download count alone would hide.**

`openapi-typescript` has the highest adoption in the group and the quietest repository. Its GitHub `pushed_at` looks current, but that reflects dependency-bot traffic on non-default branches. The last commit on `main` is **2026-05-05**, a changelog-tooling version bump; the last commit touching `packages/openapi-typescript/` itself is **2026-02-27**; the last release is **2026-02-11**, six and a half months before the observation date, against 284 open issues `[MEASURED: api.github.com/repos/openapi-ts/openapi-typescript @ 2026-08-26]`. It also declares `typescript: "^5.x"` as its peer range and does not claim TypeScript 6.

`json-schema-to-typescript` has the inverse pattern — twelve substantive commits across 2026-08-01 → 2026-08-03 fixing `oneOf`/`anyOf`/`allOf` handling, but npm `latest` is still **15.0.4 of 2025-01-14**, nineteen months stale, with fixed work committed and unpublished `[MEASURED: api.github.com/repos/bcherny/json-schema-to-typescript @ 2026-08-26]`.

Neither of those is disqualifying. Both are the kind of thing that should be read off the registry before a dependency is added, which is the house standard `01-stack.md` §6.2 set and `02-laravel-packages.md` §5.6 applied.

### 3.3 The incumbent, and the option that outflanks it {#incumbent-registry}

`[MEASURED: repo.packagist.org/p2/<vendor>/<package>.json @ 2026-08-26]`

| Package | Version | Released | L13 | PHP | Licence |
|---|---|---|---|---|---|
| `spatie/laravel-data` | 4.23.0 | 2026-05-08 | `^10.0\|^11.0\|^12.0\|^13.0` | ^8.1 | MIT |
| `spatie/typescript-transformer` | 3.3.0 | 2026-06-19 | framework-agnostic | ^8.2 | MIT |
| `spatie/laravel-typescript-transformer` | 3.3.0 | 2026-06-19 | `^11.0\|^12.0\|^13.0` | ^8.2 | MIT |
| `basillangevin/laravel-data-json-schemas` | v1.3.1 | 2026-03-19 | `^10\|\|^11\|\|^12\|\|^13` | ^8.3 | MIT |
| **`laravel/wayfinder`** (tagged) | **v0.1.21** | 2026-08-04 | `^11.0\|^12.0\|^13.0` | ^8.2 | MIT |
| **`laravel/wayfinder`** (`dev-next`) | **dev-next** | **2026-08-22** | `^12.0\|^13.0` | ^8.2 | MIT |
| `laravel/ranger` (a `next` dependency) | v0.5.0 | 2026-08-21 | `^11.0\|^12.0\|^13.0` | ^8.2 | MIT |
| `laravel/surveyor` (a `next` dependency) | v0.3.0 | 2026-08-22 | `^11.0\|^12.0\|^13.0` | ^8.2 | MIT |

`laravel/wayfinder` has six branches, of which `next` was last pushed **2026-08-22 02:54 UTC** — four days before the observation date — and has **never been tagged**; its own `CHANGELOG.md` on that branch still ends at v0.1.12 of 2025-09-08 `[MEASURED: api.github.com/repos/laravel/wayfinder/branches, /releases, /commits?sha=next and raw CHANGELOG.md @ 2026-08-26]`.

**The transformer's dependency footprint is larger than PD-1 §4.1 recorded.** `spatie/typescript-transformer` 3.3.0 requires `roave/better-reflection ^6.41`, `spatie/file-system-watcher ^1.1`, `spatie/php-structure-discoverer ^2.2`, `symfony/process ^7.0|^8.0` and `phpstan/phpdoc-parser ^2.3` `[MEASURED @ 2026-08-26]`. PD-1 listed only the four `phpdocumentor/*` packages and `spatie/laravel-package-tools` that arrive via `laravel-data`. `roave/better-reflection` in particular is a substantial static-reflection engine. This does not change PD-1's ruling; it changes its price.

### 3.4 The renderer, which is a different category entirely {#renderer}

Added in v1.1.0 after `scalar/laravel` was raised directly. It is separated from §3.1 rather than added to it **because it is not a generator, and the distinction is the entire finding**.

| Package | Version | Released | L13 | PHP | Licence | Stars / last push |
|---|---|---|---|---|---|---|
| `scalar/laravel` | **0.4.0** | 2026-08-24 | `^11.0\|\|^12.0\|\|^13.0` (via `illuminate/contracts`) | ^8.2 | MIT | 74 / 2026-08-24 |

`[MEASURED: repo.packagist.org/p2/scalar/laravel.json and api.github.com/repos/scalar/laravel @ 2026-08-27]`

**Its own README states the dependency in the first paragraph of the usage section:** *"You'll need an OpenAPI (formerly Swagger) document to render your API reference. Several packages can generate one from your Laravel app"* — and then names `dedoc/scramble`, `knuckleswtf/scribe` and `vyuldashev/laravel-openapi` `[MEASURED: github.com/scalar/laravel README @ 2026-08-27]`. Two of those three are already declined in §5.1 and §5.2, and the third is declined in §5.6. Scalar therefore does not route around the producer problem; it depends on it being solved first.

**The source settles it more firmly than the README does.** The whole of `Scalar\Laravel\Document`'s public surface is `title()`, `slug()`, `url()`, `content()`, `file()`, `default()` and `toArray()` `[MEASURED: full clone of scalar/laravel @ 2026-08-27]`. Three of those seven — `url`, `content`, `file` — are three ways to *point at* a document someone else wrote. **There is no method that produces one, and no route-scanning code in `src/` at all.** The shipped config's default `url` is Scalar's own demo specification on a public CDN.

`grep -ril inertia` over a full clone returns **zero files**, the same result §4.4 reports for every producer `[MEASURED @ 2026-08-27]`.

**Two properties of the shipped configuration are worth recording before anyone installs it**, neither of which is a defect in Scalar and both of which bear on constraints this repository has already set:

- `'cdn' => 'https://cdn.jsdelivr.net/npm/@scalar/api-reference'`. The reference UI is loaded from **jsDelivr at request time**, by default. That is a third-party origin in a page Laravel serves — a different thing from SD-2's "no Node at runtime", but adjacent to it, and it would be the first external runtime asset origin in this application. It is a config value and can be repointed at a self-hosted bundle.
- `'telemetry' => true`, documented in the stub as *"Whether to send anonymous telemetry (only when the analytics plugin is loaded)"*. Default-on, conditioned on a plugin. Flagged rather than judged.

---

## 4. The crux — can OpenAPI describe an Inertia page at all? {#crux}

This is the question the whole chapter turns on, and it splits into three that have different answers.

### 4.1 What Inertia actually puts on the wire {#the-protocol}

Inertia is not "no HTTP". Every page visit is an ordinary request, and when the client sends `X-Inertia: true` with `X-Requested-With: XMLHttpRequest`, the server answers with JSON rather than HTML. The payload has a fixed envelope `[MEASURED: inertiajs.com/docs/v3/core-concepts/the-protocol @ 2026-08-26]`:

> "Only `component`, `props`, `url`, and `version` are present on every page object."

```json
{
    "component": "Event",
    "props": { "errors": {}, "event": { "id": 80, "title": "Birthday party" } },
    "url": "/events/80",
    "version": "6b16b94d7c51cbe5b1fa42aac98241d5"
}
```

The response also carries `X-Inertia: true` and `Vary: X-Inertia`, and may carry any of thirteen further optional top-level keys — `encryptHistory`, `clearHistory`, `preserveFragment`, `mergeProps`, `prependProps`, `deepMergeProps`, `matchPropsOn`, `scrollProps`, `deferredProps`, `rescuedProps`, `sharedProps`, `onceProps`, `flash` — depending on which features the response used.

**So an Inertia visit is describable in OpenAPI in the trivial sense.** `GET /dashboard`, `200`, `application/json`, schema `{component, props, url, version}`. Nothing about the protocol forbids it.

**The problem is that the only interesting part is `props`, and `props` is not keyed the way OpenAPI keys things.** OpenAPI's Paths Object "[h]olds the relative paths to the individual endpoints and their operations," and operations are keyed by HTTP method within a Path Item `[MEASURED: spec.openapis.org/oas/v3.1.1.html @ 2026-08-26]`. A response schema therefore lives at `path → method → status → media type`. Inertia's key is the **component name**, which is orthogonal: one path can render different components (a validation failure re-renders the same component, a redirect renders another entirely), and one component can be rendered from several paths. Expressing that in OpenAPI means a `oneOf` over every component schema with a `discriminator` on `component` — legal, and mapped into TypeScript as a discriminated union, but it puts the useful type at the end of an accessor like `paths['/dashboard']['get']['responses'][200]['content']['application/json']['props']` instead of somewhere a Svelte component can name.

**And most of this application's HTTP surface has no props at all.** `[MEASURED: apps/web/routes/*.php @ 2026-08-26]` — thirteen registered routes. Three are `Route::inertia()` with no controller and no props. Two are controller `Inertia::render()` calls. One is `Route::redirect()`. Four are `PATCH`/`PUT`/`DELETE` actions whose declared return type is `RedirectResponse` — a 302 with no body. **Exactly one route in the entire application returns a JSON document to a machine**, and it is `.well-known/passkey-endpoints`, which returns two route strings `[E: apps/web/routes/settings.php]`. There is no `routes/api.php`. An OpenAPI document generated from this application today would describe one discovery endpoint and a wall of redirects.

### 4.2 The specification does not object {#spec-permits}

The objection most people reach for — *OpenAPI describes endpoints, so you cannot use it without endpoints* — is **false**, and recording it as false is what makes the rest of this chapter honest.

OAS 3.1 does not mark `paths` as required on the OpenAPI Object. The specification's definition of an OpenAPI Description states that a document "MUST contain at least one `paths` field, `components` field, or `webhooks` field" `[MEASURED: spec.openapis.org/oas/v3.1.1.html @ 2026-08-26]`. **A document consisting of `openapi`, `info` and `components.schemas` alone is valid.**

`zircote/swagger-php` implements this literally, and its source says so. `src/Annotations/OpenApi.php` declares `public static $_required = ['openapi', 'info'];` — `paths` is absent — and its `validate()` carries the comment `/* paths is optional in 3.1.x */`, erroring only when paths, webhooks **and** components are all missing `[MEASURED: github.com/zircote/swagger-php src/Annotations/OpenApi.php @ 2026-08-26]`. One caveat from the same file: `DEFAULT_VERSION = self::VERSION_3_0_0`, so a paths-less document requires setting `openapi: 3.1.0` explicitly or validation fails under the 3.0 branch.

Scramble does the same thing structurally without documenting it: `src/Support/Generator/OpenApi.php` guards serialisation of `paths` behind `if (count($this->paths))`, while `components` serialises independently `[MEASURED: github.com/dedoc/scramble @ 2026-08-26]`. `[UNVERIFIED: whether a components-only Scramble document is a supported workflow. It is reachable through Scramble::ignoreDefaultRoutes(), Scramble::extendOpenApi() and Components::addSchema(), but no schema-only mode appears in the documentation navigation, so this is a structural possibility rather than a promised feature.]`

### 4.3 And the TypeScript generators handle it — verified by execution {#generators-handle-it}

This was settled by running the published binaries against a hand-written OAS 3.1 document containing `info` and `components.schemas` and no `paths` key at any level.

**`openapi-typescript` 7.13.0 — exit 0.** `[MEASURED: executed @ 2026-08-26]` It emits `export type paths = Record<string, never>;` and a populated `components` interface. This is deliberate rather than accidental: `packages/openapi-typescript/src/transform/index.ts` iterates `paths`, `webhooks`, `components` and `$defs` as four independent roots, emitting `Record<string, never>` for any that is missing `[MEASURED: raw.githubusercontent.com/openapi-ts/openapi-typescript/main/… @ 2026-08-26]`. The types land under an index — `components["schemas"]["DashboardPageProps"]` — and need aliasing to be usable, which is the pattern its own README shows.

**`@hey-api/openapi-ts` 0.99.0 — exit 0, and better output for this purpose.** `[MEASURED: executed @ 2026-08-26]` With `plugins: ['@hey-api/typescript']` it produced two files and **flat named type aliases** — `export type DashboardPageProps = { listings: Array<PropertyListing>; }` — with zero value imports, zero value exports and no runtime. Its own documentation is explicit that `types.gen.ts` "is the only file that does not impact your bundle size and runtime performance. It will get discarded during build time, unless you configured to emit runtime enums," and that "[a] type is generated for every reusable definition from your input" — definition-driven, not endpoint-driven `[MEASURED: raw.githubusercontent.com/hey-api/hey-api/main/web/src/content/docs/docs/openapi/typescript/plugins/typescript.mdx @ 2026-08-26]`. The one trapdoor is `enums`, which defaults to `false`; setting it to `'javascript'` or `'typescript'` emits runtime artefacts.

`orval` also completed, but it is client-first by design — its documented outputs are `axios-functions` (default), `react-query`, `svelte-query`, `zod` and similar, with no documented "no client" mode — and its generated clients import `axios` or a query library at runtime `[MEASURED: orval.dev configuration reference @ 2026-08-26]`. Note one flag if it is ever considered: `input.includeUnreferencedSchemas: true` exists precisely because orval otherwise prunes schemas no operation touches, which is every schema in a paths-less document.

`[UNVERIFIED: neither openapi-typescript's nor hey-api's prose documentation contains an explicit statement that `paths` is optional. The YES above rests on executing the published binaries and, for openapi-typescript, reading the guard in its own transform source. That is first-party evidence, but it is behaviour-and-source rather than a documented contract — treat paths-less support as de facto and pin the version.]`

### 4.4 So why does it still lose? {#why-it-loses}

Because the two ends work and **the middle does not exist**.

`[MEASURED: full shallow clones of dedoc/scramble (@ c5b8ad69), zircote/swagger-php, vyuldashev/laravel-openapi and DarkaOnLine/L5-Swagger, `grep -ril inertia` across each @ 2026-08-26 — **0 files in all four**]`. GitHub issue search corroborates: zero hits in three of the four repositories, and one false positive in Scramble (issue #268, "Deprecated methods error", 2023-11-01) `[MEASURED: GitHub search API @ 2026-08-26]`.

The ecosystem-wide search is equally empty. A GitHub repository search for `inertia openapi` returns **four repositories in total**, none of which is a tool — they are applications that happen to use both `[MEASURED: api.github.com/search/repositories @ 2026-08-26]`. The Inertia-adjacent type generators that do exist are not OpenAPI-based at all: `7nohe/laravel-typegen` (103 stars, last pushed 2024-09-16) and `kiwilan/typescriptable-laravel` (40 stars, 2026-04-28) both generate TypeScript directly from Laravel, bypassing OpenAPI entirely `[MEASURED @ 2026-08-26]`.

**Extended in v1.1.0.** The same clone-and-grep was run against `knuckleswtf/scribe`, a fifth producer this section did not originally cover, and against `scalar/laravel`, which is a renderer rather than a producer. **Both return zero files** `[MEASURED @ 2026-08-27]`. The count of PHP OpenAPI tools with any model of an Inertia page prop stands at **zero of five producers**, and §5.6 disposes of both.

**The conclusion is narrow and should be stated narrowly.** OpenAPI is not the wrong *format* for this data. It is a format for which no producer exists on the PHP side of this particular boundary. Adopting it means writing the producer — by hand, or by hand-annotating — which is the thing SQ-5 was trying to stop doing.

---

## 5. The OpenAPI pipeline, priced end to end {#pipeline}

### 5.1 TD-3 — `dedoc/scramble`, and the cost PD-1 did not record {#td-3}

Scramble is the strongest of the four and the one SQ-5 named. It is healthy (v0.13.42, 2026-08-21, MIT, 15 open issues), and its inference story is genuinely good. Its own documentation: *"Scramble analyzes the return type of the controller's method using **static code analysis**. To make the most correct assumption, Scramble first tries to infer the return type, and if it cannot, it uses the declared return type in the type hint"* `[MEASURED: scramble.dedoc.co/developers/how-it-works @ 2026-08-26]`. It reads `FormRequest::rules`, evaluates inline `validate()` rule arrays, and analyses `toArray()` on API resources. **Annotation burden in the common case is zero**, which is what separates it from every other row in §3.1.

**Three things stop it here, in increasing order of decisiveness.**

*It documents the wrong routes by default, and this application has none of the right ones.* `config/scramble.php` ships `'api_path' => 'api'`, and the getting-started documentation states *"By default, all routes starting with `api` are added to the documentation"* `[MEASURED: raw.githubusercontent.com/dedoc/scramble/main/config/scramble.php and scramble.dedoc.co/usage/getting-started @ 2026-08-26]`. There is no `routes/api.php` in this repository and no route under an `api` prefix `[E: apps/web/routes/ — console.php, settings.php, web.php only]`. `Scramble::routes()` can be pointed anywhere, so this is configuration rather than a blocker — but pointing it at the Inertia routes produces §4.1's wall of 302s.

*It has no model of an Inertia response.* §4.4. A controller returning `Inertia\Response` is, to Scramble, a class it has no extractor for.

***And its `spatie/laravel-data` support is a commercial product.*** This is the fact that changes the calculus, because PD-1's whole tier-1 unit is built on `laravel-data`. Scramble's own documentation: *"Scramble has Laravel Data support as a part of Scramble PRO package"* `[MEASURED: scramble.dedoc.co/packages/laravel-data @ 2026-08-26]`. The MIT package does not merely lack the feature — it ships code whose job is to detect the gap and advertise the paid product. `src/Support/ProNudge/Extensions/LaravelDataReturnTypeNudgeExtension.php` recognises a `Spatie\LaravelData\Data` return type and records a signal; `ProNudgeCollector.php` emits the string `'Scramble PRO will document these endpoints accurately.'`; `ProNudgeReporter.php` points at `https://scramble.dedoc.co/pro` `[MEASURED: dedoc/scramble source @ c5b8ad69, 2026-08-26]`. PRO is priced at **Solo $99, Team $399 (up to 15 members)**, each licence carrying "1 year of updates and perpetual lifetime license" `[MEASURED: scramble.dedoc.co/pro @ 2026-08-26]`. `[UNVERIFIED: the PRO licence type. The /pro page does not state it. Only the open-source package is confirmed MIT.]`

**`02-laravel-packages.md` §6.8 and rejected-alternative 2 reached the right verdict on Scramble and did so without this fact.** Recording it now matters for a specific reason: `01-stack.md` weighs cost nowhere, because until this row nothing in the stack had any. Scramble PRO would be the **first paid dependency in the architecture**. That deserves to be a deliberate decision rather than a discovery made halfway through an adoption.

### 5.2 TD-4 — `vyuldashev/laravel-openapi` cannot be installed {#td-4}

Two disqualifications, either sufficient.

*No Laravel 13, at any version.* Latest tag **v1.12.0 of 2023-05-04**, declaring `laravel/framework 5.8.*|^6.0|^7.0|^8.0|^9.0|^10.0`. Its `dev-master` branch, last pushed 2025-06-11 with a commit titled "Support Laravel 12", declares `^11.0|^12.0` and still not `^13.0` `[MEASURED: repo.packagist.org/p2/vyuldashev/laravel-openapi.json and ~dev.json, api.github.com/repos/vyuldashev/laravel-openapi @ 2026-08-26]`. This is the same shape of finding `02-laravel-packages.md` §6.4 recorded for `soloterm/solo`, and the same conclusion follows: Composer will refuse to resolve it.

*And it has the highest annotation burden of the four anyway.* Its own documentation: *"**Routes are not automatically added to specification.** In order to add route, you need to add `PathItem` attribute to controller class and `Operation` to particular action method"* `[MEASURED: github.com/vyuldashev/laravel-openapi docs/paths/operations.md @ 2026-08-26]`. Beyond the attributes, it wants a **separate PHP factory class per schema, response, request body and parameter set** — `src/Factories/` contains `SchemaFactory`, `ResponseFactory`, `RequestBodyFactory`, `ParametersFactory`, `SecuritySchemeFactory` and `CallbackFactory`, each with its own `make:` command, and the schema stub requires hand-building every property.

### 5.3 TD-5 — `zircote/swagger-php` and `darkaonline/l5-swagger` {#td-5}

**L5-Swagger is a wrapper and inherits every fact from swagger-php**, which its README states outright: *"This package is a **wrapper** of Swagger-php and swagger-ui adapted to work with Laravel. The actual Swagger spec is beyond the scope of this package"* `[MEASURED: github.com/DarkaOnLine/L5-Swagger README @ 2026-08-26]`. It requires `zircote/swagger-php ^6.0`, added Laravel 13 in 11.0.0 (2026-03-06), and is healthy. So the judgement is entirely about swagger-php.

**swagger-php is the most active package in §3.1 and the most expensive to use.** Everything is hand-written attributes; there is no inference from controller code at all. Its own example specification is the measure: `docs/examples/specs/api/attributes/Product.php` is **45 lines for a five-property class**, with `#[OAT\Property]` on every property, and `ProductController.php` is **126 lines for roughly four endpoints**, with one `#[OAT\Response]` per status code per operation `[MEASURED: github.com/zircote/swagger-php @ 2026-08-26]`.

**That is not merely tedious — it is the wrong direction for this problem.** SQ-5's failure mode is a value declared in two places drifting apart, with the specific example being *"a stale enum in a Svelte component produces a wrong dropdown rather than an error."* An attribute-driven OpenAPI document is a **third** declaration of the same value, maintained by hand, with no check that it matches the PHP it sits above. It would generate TypeScript faithfully from a document that had itself gone stale — and PD-1 §4.1 already articulated why that is the worst outcome available: *"a wrong type is trusted."*

It is also the only Apache-2.0 dependency this chapter would introduce.

### 5.4 TD-6 — the TypeScript half is not the bottleneck {#td-6}

Recorded briefly because it is genuinely solved, and because if TD-10 ever fires this section is the shortlist.

| Tool | Bare types only? | Runtime dependency in the shipped app? | Paths-less input? |
|---|---|---|---|
| `openapi-typescript` | **Yes — its only mode** | **No.** devDependency; emits one `.d.ts` | **Yes** `[MEASURED: executed @ 2026-08-26]` |
| `@hey-api/openapi-ts` | **Yes** — `plugins: ['@hey-api/typescript']` | **No** in types-only mode; verified zero value exports. Default config vendors client source into the output directory | **Yes** `[MEASURED: executed @ 2026-08-26]` |
| `orval` | No documented "none" client | **Yes, normally** — generated clients import `axios` or a query library | Yes, incidentally |
| `swagger-typescript-api` | **Yes — `--no-client`** | No, with that flag | **Yes** `[MEASURED: executed with `--no-client` @ 2026-08-26]` |
| `json-schema-to-typescript` | **Yes — its only mode** | **No** | n/a — consumes JSON Schema, which has no paths concept |

**SD-2 is not an obstacle here, and it is worth being precise about why**, because "no Node" is the reflex objection and it is wrong twice over. SD-2 rules that no Node runs *at runtime*; every tool above is a build-time devDependency emitting a file. More pointedly, **the incumbent already shells out to Node at generation time.** The stub `spatie/laravel-typescript-transformer` publishes sets `->formatter(PrettierFormatter::class)`, and `PrettierFormatter::format()` is exactly this `[MEASURED: raw.githubusercontent.com/spatie/typescript-transformer/main/src/Formatters/PrettierFormatter.php @ 2026-08-26]`:

```php
$process = new Process(['npx', '--yes', 'prettier', '--write', ...$files]);
```

`npx --yes` will fetch Prettier from the network if it is not already resolvable, which is a supply-chain surface PD-1 did not price. **So "the transformer avoids Node and OpenAPI would not" is not a valid argument in either direction.** Both touch Node at build time; neither touches it at runtime; SD-2 is untroubled by both. If the transformer is adopted, point the formatter at the Prettier already in `devDependencies` `[E: apps/web/package.json — prettier ^3.4.2]` rather than leaving `npx --yes` to resolve it.

### 5.5 TD-11 — the drift check is the same work whichever tool wins {#td-11}

PD-2 requires a CI check that the generated TypeScript is current. **No candidate in this chapter provides a `--check` or `--dry-run` mode.**

`typescript:transform` accepts only `--watch` and `--worker` `[MEASURED: raw.githubusercontent.com/spatie/laravel-typescript-transformer/main/src/Commands/TransformTypeScriptCommand.php @ 2026-08-26]`. `wayfinder:generate` on `next` accepts only `--path`, `--base-path`, `--app-path` and `--fresh` `[MEASURED: wayfinder next README @ 2026-08-26]`. Scramble exports with `scramble:export`.

So PD-2's mechanism — run the generator, then `git diff --exit-code` on the output directory — is correct and is **tool-independent**. PD-2 should be adopted with whichever generator wins, at the same time, for exactly the reason PD-2 §4.2 gives. The only thing that changes between candidates is the path in the `git diff` argument.

### 5.6 TD-12 and TD-13 — the renderer, and the producer that was missed {#td-12-13}

Added in v1.1.0. `scalar/laravel` was raised directly; `knuckleswtf/scribe` was found inside Scalar's own documentation while checking it.

**TD-12 — Scalar answers a question this chapter is not asking.** §3.4 establishes from source that it renders and does not produce. That makes it orthogonal to SQ-5 rather than opposed to it: it generates no TypeScript, has no view of a page prop, and cannot be placed anywhere in a PHP-to-TypeScript chain. The proposal *"use Scalar instead"* resolves, on inspection, to *"use Scramble or Scribe or `laravel-openapi`, and then look at the result in Scalar"* — which is TD-1, TD-3, TD-4 and TD-13, plus a reading UI. **It does not change the answer, and nothing in §4.4 is softened by it.**

**TD-13 — Scribe is a genuine producer, and it loses the same way.** It generates documentation by inspecting Laravel's route list, and `src/Writing/OpenAPISpecWriter.php` emits a real OpenAPI document `[MEASURED: full clone @ 2026-08-27]`. It is healthier than two of the four producers in §3.1: MIT, Laravel 13 declared, 2,329 stars, pushed thirteen days before observation.

Three findings dispose of it, and the first is the same one that decides this whole chapter:

1. **`grep -ril inertia` over a full clone returns zero files** `[MEASURED @ 2026-08-27]` — the identical result §4.4 records for Scramble, swagger-php, `laravel-openapi` and L5-Swagger. **The count of PHP OpenAPI producers with any model of an Inertia page prop remains zero, now across five packages rather than four.**
2. **No `spatie/laravel-data` awareness whatsoever.** A grep for `laravel-data`, `Spatie\LaravelData` and `spatie/laravel-data` across the clone returns nothing `[MEASURED @ 2026-08-27]`. So it does not offer the free route around §5.1's $99 that its presence in the candidate set might suggest.
3. **Its response strategies include `ResponseCalls.php`** — it captures response bodies by *making live HTTP requests against the routes it documents* `[MEASURED: src/Extracting/Strategies/Responses/ @ 2026-08-27]`. Pointed at this application's Inertia routes that records a wall of HTML pages and 302s, which is §5.1's predicted Scramble failure arriving by a different road.

Its dependency footprint (§3.1) is also the largest of the five, and it requires `ext-pdo` and `ext-fileinfo`. **Declined.** Like every other producer here, it would be a defensible choice for a conventional JSON API — see §9, where that condition is exactly what fires.

---

## 6. The incumbent re-examined {#incumbent}

PD-1 was written on 2026-08-21. Re-reading it against the same packages five days later turns up two errors of fact. Neither overturns its ruling. Both would cost the operator time if discovered during the install.

### 6.1 TD-7 — PD-1 documents transformer v2 while pinning v3 {#td-7}

PD-1 §4.1 states, citing the `laravel-data` v4 documentation:

> "For whole-application coverage, register `DataTypeScriptCollector` in `typescript-transformer.php` **before** `DefaultCollector` — the ordering is load-bearing and is the kind of detail that costs an hour if you meet it by accident."

And PD-1 §11's install block runs `php artisan vendor:publish --provider="Spatie\LaravelTypeScriptTransformer\TypeScriptTransformerServiceProvider" --tag=typescript-transformer-config`, then says to edit `config/typescript-transformer.php`.

**None of that exists in `spatie/laravel-typescript-transformer` 3.3.0 — the version PD-1's own §3.2 registry table pins.** `[MEASURED: api.github.com/repos/spatie/laravel-typescript-transformer/contents @ 2026-08-26]` The repository has **no `config/` directory at all**. There is no `typescript-transformer.php` to publish, no `collectors` array, and no `DataTypeScriptCollector` class. Those are v2 artefacts. `laravel-data`'s own documentation now carries the migration notice: *"We recently launched typescript-transformer v3 … We strongly urge you to upgrade to v3, support for v2 will be deprecated soon"* `[MEASURED: github.com/spatie/laravel-data docs/advanced-usage/typescript.md @ 2026-08-26]`.

**What v3 actually requires** `[MEASURED: repository contents and the published stub @ 2026-08-26]`: run `php artisan typescript:install`, which publishes `app/Providers/TypeScriptTransformerServiceProvider.php` from `stubs/TypeScriptTransformerServiceProvider.stub` and registers it. Configuration is a fluent builder on `TypeScriptTransformerConfigFactory`, not a config array. The published stub is:

```php
$config
    ->transformer(AttributedClassTransformer::class)
    ->transformer(EnumTransformer::class)
    ->transformDirectories(app_path())
    ->writer(new GlobalNamespaceWriter('generated.d.ts'))
    ->formatter(PrettierFormatter::class);
```

`laravel-data` support is added as an *extension*, not a collector — `->extension(new LaravelDataTypeScriptTransformerExtension())`, with optional `customLazyTypes` and `customDataCollections` arguments `[MEASURED: spatie/laravel-typescript-transformer autodocs via Context7, and src/LaravelData/LaravelDataTypeScriptTransformerExtension.php @ 2026-08-26]`. The base provider defaults the output directory to `resource_path('js/generated')`, which is **not** the `resources/js/types/` path PD-1 §11's drift-check snippet guesses at.

Two smaller consequences worth carrying. The v3 command errors with *"TypeScript Transformer is not configured. Run `php artisan typescript:install` first"* if the provider is missing, so the failure is at least loud. And the transformer's optionality handling — `Lazy` and `Optional` emitting as `lazy?: string`, which PD-1 §4.1 correctly identifies as the reason the pairing is more than a coincidence — is now the extension's job rather than the collector's. **The capability claim in PD-1 survives; only the mechanism moved.**

### 6.2 TD-8 — "they do not overlap" is now false in both directions {#td-8}

PD-1 §4.1 closes with:

> "**Interaction with Wayfinder.** They are complementary and do not overlap. Wayfinder generates typed *route* functions … the transformer generates typed *data shapes*. Together they cover both halves of SQ-5. Neither generates the other's output."

Both halves of that are now wrong.

**The transformer generates routes.** v3 ships `LaravelRouteTransformedProvider` and `LaravelControllerTransformedProvider` `[MEASURED: src/TransformedProviders/ @ 2026-08-26]`, emitting a `helpers/route.ts` with a `route()` function and a `hasRoute(name): name is keyof RouteParameters` predicate. Its 3.3.0 changelog documents fixing *"routes that share a controller"* — a bug that *"silently dropped `Route::inertia()` pages"* — and 3.2.0 documents narrowing the emitted `method` field to `'get' | 'post' | 'put' | 'patch' | 'delete'` specifically so *"the result [can be handed] to libraries like Inertia"* `[MEASURED: raw.githubusercontent.com/spatie/laravel-typescript-transformer/main/CHANGELOG.md @ 2026-08-26]`. That is squarely Wayfinder's territory.

**And Wayfinder generates data shapes** — see §7.

**This is not a defect in PD-1's judgement; it is a moving target.** But it matters practically: adopting both today means two tools emitting overlapping route helpers into one frontend, which is the "two tools disagreeing about the same file" objection PD-20 raised against `phpinsights` and `type-coverage`. If PD-1 is executed as written, disable the transformer's route providers explicitly.

---

## 7. TD-9 — `laravel/wayfinder` on `next`, which is the actual news {#td-9}

**Inertia's own TypeScript documentation points at it, by name, in the section about typing page props** `[MEASURED: inertiajs.com/docs/v3/advanced/typescript @ 2026-08-26]`:

> "The next version of [Laravel Wayfinder](https://github.com/laravel/wayfinder/tree/next) may automatically generate these types for you by analyzing your Laravel application. It generates TypeScript types for shared props, page props, form requests, and Eloquent models. This version is currently in beta."

The branch README confirms it and goes further `[MEASURED: raw.githubusercontent.com/laravel/wayfinder/next/README.md @ 2026-08-26]`. Wayfinder `next` generates TypeScript for:

> "- **Routes & Controller Actions** … - **Named Routes** … - **Form Requests** - TypeScript types derived from your validation rules
> - **Eloquent Models** - TypeScript interfaces matching your model attributes and relationships
> - **PHP Enums** - TypeScript types and constants for your enum cases
> - **Inertia.js Page Props** - Types for your Inertia page data
> - **Inertia Shared Data** - Types for data shared across all Inertia pages
> - **Broadcast Channels** … - **Broadcast Events** … - **Environment Variables** …"

Its Inertia section is unambiguous: *"Wayfinder provides first-class support for Inertia.js applications, automatically generating types for your page props and shared data."* Given an ordinary `Inertia::render('Dashboard', [...])`, it emits:

```typescript
export namespace Inertia.Pages {
    export type Dashboard = Inertia.SharedData & {
        stats: { users: number; posts: number };
        recentActivity: App.Models.Activity[];
    };
}
```

and types shared data from `HandleInertiaRequests` into `Inertia.SharedData`.

**Read that against SQ-5 word by word.** SQ-5 names *"the six `CHECK` enumerations and the `acquisition` discriminator"* as the values that will drift first — Wayfinder `next` generates PHP enums to TypeScript unions plus runtime constants, with `generate.enums` defaulting to `true`. SQ-5's failure mode is *"a stale enum in a Svelte component produces a wrong dropdown rather than an error"* — this is precisely the gap it closes. And PD-1's argument for `laravel-data` was that Form Requests and API Resources give a generator *"no single artefact a TypeScript generator can point at"*; Wayfinder `next` points at Form Requests directly, deriving types from `rules()` including nested `meta.description` keys, and at Eloquent models directly, honouring `$hidden`.

**It is first-party, MIT, from Taylor Otwell, and this repository already depends on the package** `[E: apps/web/composer.json — "laravel/wayfinder": "^0.1.14", installed v0.1.21]`. It requires `illuminate/* ^12.0|^13.0` and PHP `^8.2`, both satisfied here.

### 7.1 Why it is not the recommendation today {#not-yet}

**It has no tagged release.** Installation is `composer require laravel/wayfinder:dev-next`, per the README. Packagist confirms `dev-next` exists and was last built **2026-08-22 02:54 UTC**; the branch's own `CHANGELOG.md` has not been updated since v0.1.12 of 2025-09-08 `[MEASURED @ 2026-08-26]`. The README's standing warning is blunt: *"Wayfinder is currently in Beta, the API is subject (and likely) to change prior to the v1.0.0 release."*

**It pulls two more pre-1.0 first-party packages.** `laravel/ranger ^0.5.0` (v0.5.0, 2026-08-21) and `laravel/surveyor ^0.3.0` (v0.3.0, 2026-08-22) `[MEASURED @ 2026-08-26]`. Both were tagged within five days of the observation date, and Ranger shipped v0.3.0, v0.4.0 and v0.5.0 within three days of each other — healthy velocity, and also a moving dependency floor under a branch with no floor of its own.

**It is upgrading over itself.** The README's own "Upgrading from Previous Beta" section records that output moved from `actions/` and `routes/` to a single `resources/js/wayfinder`, that `types.ts` became `types.d.ts`, and that three CLI flags were removed in favour of config keys. This repository is on the *previous* layout `[E: apps/web/resources/js/actions/, apps/web/resources/js/routes/]`, so adopting `next` is a migration, not an upgrade.

**Two specific gaps for this repository, both marked honestly.** `[UNVERIFIED: whether Wayfinder next handles `Route::inertia()` pages. Three of this application's routes are declared that way with no controller and no props `[E: apps/web/routes/web.php, settings.php]`, and the next README's Inertia section shows only the controller `Inertia::render()` form. The transformer hit exactly this bug and fixed it in 3.3.0, which suggests it is a real class of problem rather than a hypothetical one.]` `[UNVERIFIED: whether it can type conditionally-present props. `SecurityController::edit` builds `$props` as a mutable array and adds `twoFactorEnabled` and `requiresConfirmation` only inside an `if (Features::canManageTwoFactorAuthentication())` block `[E: apps/web/app/Http/Controllers/Settings/SecurityController.php]`. Static analysis must either widen those to optional or miss them, and the README does not say which.]`

**And its `require-dev` pins `inertiajs/inertia-laravel: ^2.0`** while this repository runs `^3.0` (installed v3.3.1) `[MEASURED @ 2026-08-26; E: apps/web/composer.json]`. That is a dev-only constraint and does not block installation, but it means the branch's test suite exercises Inertia 2, not the Inertia 3 this application runs. The npm-side `@laravel/vite-plugin-wayfinder` is also at 0.1.7 of 2025-09-22, eleven months old, while the `next` README instructs removing arguments that plugin still accepts `[MEASURED: registry.npmjs.org/@laravel/vite-plugin-wayfinder @ 2026-08-26]`.

### 7.2 What the starter kit already does, which is the honest baseline {#baseline}

Worth recording because neither PD-1 nor SQ-5 mentions it, and it is the thing any generator would be replacing.

**SD-5's Svelte starter kit ships a typing convention, and it is Inertia's own first-party mechanism.** `[MEASURED: apps/web/resources/js/types/ @ 2026-08-26]` — five files: `auth.ts`, `navigation.ts`, `ui.ts`, `index.ts` and `global.d.ts`. The last one augments Inertia's config interface exactly as Inertia's documentation prescribes `[E: apps/web/resources/js/types/global.d.ts]`:

```ts
declare module '@inertiajs/core' {
    export interface InertiaConfig {
        sharedPageProps: { name: string; auth: Auth; sidebarOpen: boolean; [key: string]: unknown };
    }
}
```

Inertia documents the same `InertiaConfig` augmentation with `sharedPageProps`, `flashDataType`, `errorValueType`, `layoutProps` and `namedLayoutProps`, and documents per-page typing through a generic on `usePage()` — *"These are merged with your global `sharedPageProps`, giving you autocomplete and type checking for both"* `[MEASURED: inertiajs.com/docs/v3/advanced/typescript @ 2026-08-26]`.

**So the status quo is not "untyped".** It is *typed by hand, at exactly the seam a generator would fill*. `resources/js/types/auth.ts` declares a `User` shape mirroring the Eloquent model, `ui.ts` declares `Appearance = 'light' | 'dark' | 'system'` and a `FlashToast` union — the enum-shaped drift SQ-5 warns about, in miniature, already present in the scaffolding. That strengthens SQ-5's case rather than weakening it, and it also means whatever tool wins has a well-defined target: replace these files, keep the `InertiaConfig` augmentation, and point `sharedPageProps` at the generated shape.

---

## 8. The comparison {#comparison}

Axes chosen for a one-person project on this stack. `[E]` for repository evidence, otherwise `[MEASURED @ 2026-08-26]` per the sections cited.

| Axis | OpenAPI pipeline (Scramble → `openapi-typescript`) | PD-1 (`laravel-data` + transformer v3) | Wayfinder `next` |
|---|---|---|---|
| **Types Inertia page props?** | **No.** Zero Inertia support in any PHP generator (§4.4) | **Indirectly** — types the `Data` classes you choose to put in props; does not type the prop *bag* | **Yes, directly** — `Inertia.Pages.*` and `Inertia.SharedData` (§7) |
| **Types the six `CHECK` enums (SQ-5's first casualty)** | Only via schemas you author or a PRO licence | **Yes** — `EnumTransformer` in the default stub | **Yes** — `generate.enums` defaults `true`, plus runtime constants |
| **Types Form Requests** | Scramble reads `rules()`; the type lands in an OpenAPI operation, not a usable TS alias | No — that is not what `Data` classes are | **Yes** — derived from `rules()`, including nested keys |
| **Types Eloquent models** | No | Only if you hand-write a `Data` class per model | **Yes** — honours `$hidden` |
| **Annotation / boilerplate burden** | Scramble: near zero, but wrong target. swagger-php / L5-Swagger: **very high** (§5.3). laravel-openapi: highest, and uninstallable | **Moderate and ongoing** — one `Data` class per shape, adopted as a convention (PD-1 §4.1, PQ-1) | **Near zero** — reads code you already wrote |
| **Steps in the pipeline** | **Two** — PHP → OpenAPI → TypeScript, with an intermediate artefact whose only consumer is a generator | One | One |
| **Drift check** | `scramble:export` + `git diff`, then regenerate TS. Two artefacts to gate | `typescript:transform` + `git diff`. One artefact | `wayfinder:generate` + `git diff`. One artefact |
| **Runtime dependencies added** | **None** — all build-time (§5.4) | **None** — no migrations, no tables, no processes (PD-1 §9.4) | **None** |
| **Build-time Node** | Yes (the TS generator) | **Yes** — `PrettierFormatter` shells out to `npx --yes prettier` (§5.4) | Optional — `format.enabled` defaults `false`, and uses Biome |
| **Composer dependencies added** | Scramble + 4 transitive | 3 direct + `roave/better-reflection`, `symfony/process`, `spatie/file-system-watcher`, 4× `phpdocumentor/*`, 2× `spatie/*` (§3.3) | **Zero new direct** — already installed; but `dev-next` adds `laravel/ranger` + `laravel/surveyor` |
| **Cost in money** | **$99** if `laravel-data` shapes must be documented (§5.1) | Free | Free |
| **Licence** | MIT, or Apache-2.0 via swagger-php | MIT | MIT |
| **Maintenance risk** | Scramble: 0.x after 153 releases, single maintainer. `openapi-typescript`: `main` quiet since 2026-05-05 (§3.2) | Spatie, a company; monthly cadence; v3 is three months old and v2 is being deprecated | **Beta on an untagged branch, plus two pre-1.0 first-party deps** (§7.1) |
| **Reversibility** | High — delete a config file and a devDependency | Moderate — `Data` classes become a codebase-wide convention (PQ-1) | High — generated output is a directory |
| **What only this can do** | **Describe an HTTP contract to a non-TypeScript client** (§9) | Rich optionality semantics (`Lazy`, `Optional`), validation, casting, and one class per shape you fully control | Type the *whole* Laravel↔Inertia seam without writing a single extra class |

**Read the "steps in the pipeline" row together with the "what only this can do" row, because that is the entire argument.** OpenAPI's second step is only worth paying for when the intermediate artefact has a consumer other than the type generator. For the workspace screens it does not. For §9's ingest contract it does.

---

## 9. TD-10 — where OpenAPI genuinely wins {#openapi-wins}

**There is one, it is real, and it is already written down in this repository.**

`CONTEXT-MAP.md` defines the boundary: *"**Ingest → Workspace**: Ingest submits normalised advertisement payloads to the workspace over HTTP. It never writes the database itself. That submission is the only translation point between the two languages, and the workspace owns every write."* `[E]`

That is a machine-to-machine HTTP contract between a **Python** client and a **PHP** server. It is the exact thing OpenAPI was designed for, and it is a completely different problem from SQ-5:

- `01-stack.md` §7 caveat 1: *"A scraper posting listings still needs a conventional JSON endpoint. Inertia removes the API for **screens**, not for **machines**."*
- `01-stack.md` §6.4 order B and **SQ-1**: n8n is repointed at a Laravel HTTP endpoint before Turso Cloud is dropped. That endpoint is coming, and soon.
- **PD-7** already stages its authentication (shared secret or Sanctum, **PQ-3**).
- The Python side is already equipped to consume a schema: `apps/scraper/pyproject.toml` declares `pydantic>=2.9` and `fastapi>=0.115` `[E]`, and both speak JSON Schema and OpenAPI natively.

**Two properties make this case genuinely different from the screens case.**

*The document has a consumer that is not a type generator.* It is a contract two independently-deployed services agree on — the thing `01-stack.md` §5.2 makes load-bearing when it rules that the scraper's language is *"free"* precisely because it POSTs rather than writes. A contract that can be validated in both CI pipelines is worth more than a generated type.

*And it is one endpoint, or two.* The annotation burden that makes swagger-php intolerable across a whole application is trivial across a single ingest operation. Even §5.3's 126-lines-for-four-endpoints rate is an hour's work at this scale.

**The trigger, stated precisely: TD-10 fires when the ingest endpoint is built — i.e. when SQ-1's order-B endpoint ships.** Not before, because there is nothing to describe. Not as part of PD-1, because it is not the same decision and does not share a tool. Scope it to `routes/api.php` alone, which is also where Scramble's default `api_path` already points (§5.1), so the tool that is wrong for the screens is right for this and needs no reconfiguration to be so.

**And this is the one place `scalar/laravel` becomes useful — optional even there.** If the ingest document exists, Scalar renders it well, in one config line, at MIT, with no impact on any generated type `[MEASURED: §3.4]`. It is a reading surface for a contract between two services, which is the situation it is built for. Two caveats carry forward from §3.4: repoint `cdn` at a self-hosted bundle rather than serving jsDelivr from a Laravel route, and decide `telemetry` deliberately. **Tier 3 by `02-laravel-packages.md`'s own scale — adopt it because the document is pleasant to read, never because it advances SQ-5.** For a single-operator project whose only client is a scraper the same person wrote, an interactive reference is a convenience, not a requirement.

**And note what it does *not* license.** Adopting OpenAPI for the ingest contract does not make it the answer for the screens. `02-laravel-packages.md` rejected-alternative 2 already anticipated the adjacent version of this — *"[Scramble] becomes the right answer if SD-6's public feed ships a real JSON API"* — and that remains correct and separate. Two OpenAPI triggers now exist: the ingest endpoint (SQ-1, near) and the public feed (SD-6, far). Neither is SQ-5.

---

## 10. Recommendation {#recommendation}

**No to OpenAPI for the workspace screens, and the operator's guess is right.** Not because Inertia is undescribable — §4.2 shows the specification permits it and §4.3 shows the TypeScript generators handle it — but because **the producer does not exist**. Every OpenAPI generator in the PHP ecosystem is blind to `Inertia::render()`, and the two that could be pointed at it either want a commercial licence to see `laravel-data` shapes or want the whole document hand-written. It is two steps where one exists, and the intermediate artefact has no consumer.

**But do not execute PD-1 as written either.** Its ruling stands; its instructions do not (§6.1), its overlap analysis no longer holds (§6.2), and a first-party option that answers SQ-5 more completely than either candidate is in active beta on a branch of a package this repository already depends on (§7).

**The recommended order, and it is deliberately not "install something today".**

| Order | Action | Effort | Why here |
|---|---|---|---|
| **1** | **Correct PD-1's §4.1 and §11** to the v3 mechanism — `typescript:install`, a service provider, `LaravelDataTypeScriptTransformerExtension`, output at `resource_path('js/generated')` | ~20 min | It is wrong today and will cost an hour when met by accident. This is true regardless of how TD-9 resolves |
| **2** | **Record TD-9 against SQ-5** and re-read before PD-1 is executed | ~10 min | PD-1 §10 order 6 says to adopt "before the first domain screen ships". That moment has not arrived, and the option set changed since PD-1 was written |
| **3** | **Watch `laravel/wayfinder` for a tagged release from `next`** | recurring, ~5 min | The single condition that flips this decision. §10.1 |
| **4** | **If a screen must ship before that tag exists:** adopt PD-1 as corrected, and start with `spatie/typescript-transformer` **alone** on the enums | ~2 hours | PD-1 rejected-alternative 4 already endorses this incremental path, and it is the half SQ-5 says drifts first. It is also the half Wayfinder `next` would replace most cleanly, so it minimises rework |
| **5** | **PD-2's drift check, in the same commit as whatever generates** | ~15 min | Unchanged. `generate` then `git diff --exit-code`. Tool-independent (§5.5) |
| **6** | **TD-10 — OpenAPI for the ingest endpoint**, when SQ-1's order-B endpoint is built | ~2 hours | §9. A different decision with a different trigger |

**Nothing above is urgent, and that is the same conclusion PD-1 §10 reached for the same reason:** `app/` still holds only starter-kit scaffolding, and no domain screen exists to drift `[MEASURED: apps/web/app/ — 16 files, none of them domain code @ 2026-08-26]`. The cheapest moment to choose is still before the first screen. It has simply not passed yet, and the option set improved while it was open.

### 10.1 The conditions that flip this {#triggers}

| Trigger | Flips to | Why |
|---|---|---|
| **`laravel/wayfinder` cuts a tagged release containing the `next` feature set** | **Wayfinder over PD-1** | First-party, MIT, zero new direct dependencies, types the whole Inertia seam including page props, and Inertia's own docs endorse it. At that point PD-1's three-package unit buys DTO ergonomics — which PD-1 §4.1 itself calls *"the smaller half of the value"* |
| **SQ-1's order-B ingest endpoint is built** | **OpenAPI, scoped to that endpoint only** | §9. The document gains a consumer that is not a type generator |
| **SD-6's public feed ships a real JSON API with third-party clients** | **OpenAPI for its own sake** | Already recorded in `02-laravel-packages.md` rejected-alternative 2, and still correct |
| **A screen must ship and Wayfinder is still untagged** | **PD-1 as corrected**, transformer-first | Order 4 above |
| **`laravel-data` classes are adopted *and* an OpenAPI document is needed for them** | Re-price against **Scramble PRO at $99** | §5.1. This would be the architecture's first paid dependency and should be a decision, not a discovery |
| **A second developer joins** | Re-read all of it | `01-stack.md` rejected-alternative 1 already says shared types become load-bearing at that point, and the tolerance for a beta dependency drops |

---

## 11. Rejected alternatives {#rejected}

Following the convention of `01-stack.md` §4 and `02-laravel-packages.md` §13: approaches considered for **generating TypeScript from PHP via an OpenAPI-compatible schema**, and why each lost.

| # | Considered | Why it lost |
|---|---|---|
| 1 | **`dedoc/scramble` → `openapi-typescript`** — the shape the question actually proposes | The strongest OpenAPI option and still two steps. Scramble has **no Inertia model at all** (§4.4), defaults to `api` routes this application does not have (§5.1), and its `spatie/laravel-data` support is **commercial at $99** (§5.1). Pointed at the Inertia routes it would document a wall of 302s |
| 2 | **A hand-written `components`-only OpenAPI document, no `paths`** | The most intellectually honest version of the proposal, and the one that proves OpenAPI is not *technically* excluded — §4.2 and §4.3 confirm the spec permits it and both leading generators consume it, verified by execution. Lost because a hand-written schema document is a **third** hand-maintained declaration of every value, which is a strictly worse version of the problem SQ-5 exists to solve (§5.3). It would generate correct TypeScript from a stale document — PD-1's *"a wrong type is trusted"*, one layer removed |
| 3 | **`zircote/swagger-php` or `darkaonline/l5-swagger` attributes** | Healthiest packages in §3.1 and the highest burden — 45 lines of attributes for a five-property class (§5.3). Same "third declaration" objection as #2, plus Apache-2.0 as the only non-MIT dependency the chapter would add |
| 4 | **`vyuldashev/laravel-openapi`** | **Uninstallable.** No Laravel 11/12/13 on any branch; latest tag 2023-05-04 (§5.2). Also the highest boilerplate of the four — a factory class per schema, response, request body and parameter set |
| 5 | **`basillangevin/laravel-data-json-schemas` → `json-schema-to-typescript`** — the free route around Scramble PRO | Genuinely exists and genuinely works: v1.3.1, 2026-03-19, MIT, `^13` supported, and it is the only package found that emits bare per-class schemas with **no paths concept at all**. Listed in `laravel-data`'s own third-party page. Lost on two counts. It is **JSON Schema, not OpenAPI**, so it answers a slightly different question than the one asked. And by the house standard `01-stack.md` §6.2 set and `02-laravel-packages.md` §5.6 applied — read the registry, not the marketing page — **14 GitHub stars and ~51k lifetime downloads** are hobby-project numbers for a link in a build chain. Its downstream, `json-schema-to-typescript`, has nineteen months of unpublished fixes (§3.2). Two weak links to reach a place one strong link already reaches |
| 6 | **`xolvionl/laravel-data-openapi-generator`** — the direct `laravel-data` → OpenAPI bridge | **Abandoned.** Linked from `laravel-data`'s third-party page, but the vendor is not resolvable on Packagist at all; only forks are published, the largest at 103 total downloads. The upstream repository is 30 stars, last pushed 2024-07-08, **with no licence set** `[MEASURED @ 2026-08-26]`. An unlicensed dependency is not a candidate |
| 7 | **`orval` as the TypeScript half** | Healthy and the most actively released of §3.2 (8.26.0, three days before observation). Lost on shape: it is client-first with no documented "no client" mode, and its output imports `axios` or a query library at runtime. This application does not fetch — Inertia delivers props. A generated fetch client would be dead code |
| 8 | **Wait for a first-party Laravel OpenAPI offering** | **There is none, and the search was exhaustive.** `openapi`, `swagger`, `redoc`, `stoplight`, `scribe` and `spectral` return **zero matches across all 105 markdown files** of `laravel/docs` @ 13.x; zero across the whole of `laravel/framework` 13.x; and all **141 repositories** in the `laravel` GitHub org enumerated with eight name matches, all false positives `[MEASURED @ 2026-08-26]`. Laravel 13's **JSON:API resources** are runtime response serialisation only — the entire `Illuminate/Http/Resources/JsonApi/` directory contains **zero** occurrences of "schema", and no `toSchema()`/`openapi()` emitter exists — which corroborates PD-1 §4.1's reading of them from a different direction. The one adjacent thing that does exist, **`illuminate/json-schema`** (first published 2025-09-03), is a fluent builder emitting what its own docblock calls the *"Laravel-supported JSON Schema subset"*, whose sole documented consumer is `laravel/mcp` tool schemas. It has no route awareness and emits no OpenAPI document `[MEASURED @ 2026-08-26]`. `[UNVERIFIED: unreleased branches, unmerged PRs, private org repositories and the closed-source commercial products were not audited.]` |
| 9 | **Do nothing; keep hand-writing `resources/js/types/`** | The status quo (§7.2), and it is not as bad as "no shared types" implies — Inertia's `InertiaConfig` augmentation is a real first-party mechanism and the starter kit already uses it. Lost for SQ-5's own reason: `ui.ts` already declares `Appearance = 'light' \| 'dark' \| 'system'` and a `FlashToast` union by hand `[E]`, which is the enum-shaped drift SQ-5 predicts, present in the scaffolding before any domain code exists |
| 10 | **`scalar/laravel`** — raised directly, on 2026-08-27 | **Lost on category, not on quality.** It is a renderer. `Document`'s entire public surface is `title`/`slug`/`url`/`content`/`file`/`default`/`toArray`, of which three are ways to point at a document someone else wrote; `src/` contains no route-scanning code and no producer of any kind (§3.4). It emits no TypeScript, so it cannot answer SQ-5 even in principle, and its own README names as producers two packages already declined here (§5.1, §5.2) plus one declined at #11. `grep -ril inertia` over a full clone: **zero files**. It is a good tool aimed at a different problem, and it earns a tier-3 slot only if TD-10 fires (§9). Note before install: the shipped config loads the UI from **jsDelivr at request time** and defaults `telemetry` to true |
| 11 | **`knuckleswtf/scribe`** — the producer v1.0.0 of this chapter missed | **Declined on the chapter's central fact, not on health.** It is MIT, Laravel 13 supported, 2,329 stars and actively pushed, and `OpenAPISpecWriter.php` emits a real document — but `grep -ril inertia` over a full clone returns **zero files**, it has no `spatie/laravel-data` awareness at all, and `ResponseCalls.php` captures responses by making live HTTP requests against the documented routes, which against Inertia routes records HTML pages and 302s (§5.6). Largest dependency footprint of the five producers, and requires `ext-pdo` and `ext-fileinfo` |

---

## 12. Conflicts and corrections {#conflicts}

Recorded explicitly rather than buried, per the standing rule that a decided ruling is never silently overridden.

| Item | Bears on | Nature |
|---|---|---|
| **TD-1** — OpenAPI declined for the screens | **PD-1**, **SQ-5** | **No conflict. PD-1's ruling is upheld** on the question asked, and rejected-alternative 2 of `02-laravel-packages.md` reached the right answer. This chapter adds the evidence it lacked: zero Inertia support ecosystem-wide, and the commercial `laravel-data` licence |
| **TD-3** — Scramble PRO is $99 | **PD-1**, `01-stack.md` | **New fact, not a conflict.** `02-laravel-packages.md` rejected-alternative 2 did not record it. It would be **the first paid dependency in the architecture**, which is a category `01-stack.md` never had to weigh |
| **TD-7** — PD-1 documents transformer v2 | **PD-1 §4.1, §11** | **Direct correction.** `config/typescript-transformer.php`, `--tag=typescript-transformer-config` and `DataTypeScriptCollector` do not exist in the v3.3.0 PD-1's own §3.2 pins. The capability claim survives; the mechanism moved (§6.1). **PD-1 §11's install block will not work as written** |
| **TD-8** — the overlap claim | **PD-1 §4.1** | **Direct correction.** *"Neither generates the other's output"* is now false both ways: transformer v3 ships route providers and a `route()`/`hasRoute()` helper; Wayfinder `next` generates data shapes. If both are adopted, disable one side's route generation explicitly (§6.2) |
| **TD-9** — Wayfinder `next` | **PD-1**, **SQ-5** | **Not a conflict today — a sequencing dependency.** It has no tagged release, so it cannot be recommended. It is the most likely successor to PD-1 and **PD-1 should not be executed without reading §7** |
| **Build-time Node** | **SD-2** | **No conflict, in either direction, and the symmetry matters.** SD-2 forbids Node *at runtime*. Every candidate here is build-time only — and the incumbent's own published stub runs `npx --yes prettier` at generation time (§5.4), so "OpenAPI would introduce Node" is not an argument available to either side |
| **`scalar/laravel`'s default CDN** | **SD-2** | **Adjacent, not a conflict, and only if it is ever installed.** SD-2 forbids Node *at runtime*; Scalar ships no Node, but its stub config loads the reference UI from **jsDelivr at request time** (§3.4). That would be this application's first external runtime asset origin, which SD-2's *"frontend ships as static assets served by Laravel"* is arguably written against in spirit. It is one config value. If TD-10 fires and Scalar is adopted, repoint `cdn` at a self-hosted bundle in the same commit |
| **TD-10** — OpenAPI for ingest | `01-stack.md` §7 caveat 1, **SQ-1**, **PD-7**, `CONTEXT-MAP.md` | **No conflict — it implements them.** §7 caveat 1 already says machines need a conventional JSON endpoint; this chapter names OpenAPI as the right way to describe it and gives the trigger (§9) |
| **Transformer dependency footprint** | **PD-1 §4.1** | **Amendment.** PD-1 listed four `phpdocumentor/*` packages plus `laravel-package-tools`. v3 also pulls `roave/better-reflection ^6.41`, `symfony/process`, `spatie/file-system-watcher` and `spatie/php-structure-discoverer` (§3.3). Does not change the ruling; does change the price |

**Nothing in this chapter conflicts with any `SD-*`.** TD-1, TD-3, TD-4, TD-5, TD-6, TD-12 and TD-13 decline or defer; TD-7 and TD-8 correct facts inside PD-1 without changing its verdict; TD-9 opens a watch; TD-10 implements a caveat `01-stack.md` §7 already wrote down; TD-11 reaffirms PD-2 unchanged.

---

## 13. Open questions {#open-questions}

1. **TQ-1 — Does Wayfinder `next` reach a tagged release before the first domain screen ships?** *In force:* unknown, and it is the single condition that flips this decision (§10.1). *Blast radius:* moderate. If PD-1 is executed first and Wayfinder tags a month later, the cost is a migration plus a `laravel-data` convention adopted for a job that no longer needs it — and PQ-1 (does `laravel-data` become the convention for *all* boundary shapes?) becomes materially harder to answer. *Who answers:* Vincent, by watching `github.com/laravel/wayfinder/releases`. **This is the cheapest recurring check in the project.**

2. **TQ-2 — Does Wayfinder `next` handle `Route::inertia()` and conditionally-present props?** *In force:* `[UNVERIFIED]` on both (§7.1). Three of this application's routes use `Route::inertia()`, and `SecurityController::edit` builds its prop array conditionally `[E]`. The transformer hit and fixed exactly the first bug in 3.3.0, which suggests it is a real class of problem. *Blast radius:* low in isolation, decisive for TQ-1 — if page props for the app's actual shapes come out wrong or missing, Wayfinder is not the answer regardless of its release status. *Who answers:* whoever evaluates TQ-1, by running `wayfinder:generate` against a branch and reading the output. **Do this before, not after, the tag lands.**

3. **TQ-3 — When the ingest endpoint is built, is the OpenAPI document hand-written or Scramble-generated?** *In force:* undecided (§9). Scramble's default `api_path` already points at `api`, so it needs no reconfiguration; but at one or two operations, a hand-written document is comparably cheap and has no dependency. *Blast radius:* low, and it is contained to `routes/api.php`. *Who answers:* Vincent, alongside PQ-3 (shared secret or Sanctum), since both are decisions about the same endpoint and should be taken together. **Amended in v1.1.0:** the producer shortlist is Scramble, a hand-written document, or `knuckleswtf/scribe` — and §5.6 finding 3 is a mark against Scribe here too, since live response calls against an authenticated ingest endpoint are an awkward thing to run in CI. Whether to render the result with `scalar/laravel` is a separate and later question (§9), and answering it "no" costs nothing.

4. **TQ-4 — If PD-1 is adopted, does the transformer's route generation get disabled?** *In force:* it must be, or two tools emit route helpers into one frontend (§6.2). *Blast radius:* low but immediate — this is a configuration line in the v3 service provider, and forgetting it produces the "two tools disagreeing about one file" failure PD-20 declined `phpinsights` over. *Who answers:* Vincent, at PD-1 adoption, in the same commit.

5. **TQ-5 — Is `npx --yes prettier` an acceptable generation-time dependency?** *In force:* it is the default in the transformer's published stub (§5.4), and `--yes` will fetch from the network if Prettier is not resolvable. Prettier **is** already a devDependency here `[E: apps/web/package.json — prettier ^3.4.2]`, so the local invocation should resolve — but the default is not pinned to it. *Blast radius:* low, and it is a supply-chain rather than a correctness concern; it would run inside CI, which `composer audit` (PD-4) does not cover for npm. *Who answers:* Vincent, at PD-1 adoption — point the formatter at the local binary, or drop the formatter and let the existing `format:check` gate handle it.

---

## 14. Changelog {#changelog}

| Version | Date | Author | Change |
|---|---|---|---|
| **1.1.0** | 2026-08-27 | Vincent + Claude | Adds **TD-12** and **TD-13** in response to a follow-up naming `scalar/laravel`. **Neither changes the ruling, and the first clarifies why nothing of its kind could.** TD-12 records that Scalar is a **renderer, not a producer** — settled from source rather than from marketing: the whole public surface of `Scalar\Laravel\Document` is `title()`, `slug()`, `url()`, `content()`, `file()`, `default()` and `toArray()`, three of which are ways to point at a document written elsewhere, and `src/` holds no route-scanning code at all. Its own README opens the usage section with *"You'll need an OpenAPI (formerly Swagger) document to render your API reference"* and names `dedoc/scramble`, `knuckleswtf/scribe` and `vyuldashev/laravel-openapi` as producers — the first already declined at §5.1 over its **commercial** `laravel-data` support, the third already found **uninstallable** at §5.2. Scalar therefore sits downstream of the producer problem and inherits it whole; it emits no TypeScript and cannot occupy any position in a PHP-to-TypeScript chain. Records two properties of its shipped configuration for anyone who installs it later: the reference UI loads from **jsDelivr at request time** by default (`'cdn' => …`), which would be this application's first external runtime asset origin, and `'telemetry' => true`, documented as anonymous and gated on the analytics plugin. **TD-13 closes a genuine gap in v1.0.0's §3.1**: `knuckleswtf/scribe` — 5.11.0, 2026-06-08, MIT, Laravel 13 declared, 2,329 stars, pushed 2026-08-13 — was absent from the producer table and was found inside Scalar's own documentation. It is a real producer, `src/Writing/OpenAPISpecWriter.php` emits a real document, and it is healthier than two packages v1.0.0 did evaluate. It is declined on the same structural fact: `grep -ril inertia` over a full clone returns **zero files**, so **the count of PHP OpenAPI producers with any model of an Inertia page prop remains zero, now across five packages rather than four**; it has no `spatie/laravel-data` awareness whatsoever, so it is not a free route around §5.1's $99; and `src/Extracting/Strategies/Responses/ResponseCalls.php` captures response bodies by making **live HTTP requests against the routes it documents**, which against Inertia routes records HTML and 302s. Adds §3.4 (the renderer, separated from §3.1 deliberately, because generator-versus-renderer is the whole finding), §5.6 (both dispositions), a §9 paragraph placing Scalar as an **optional tier-3 reading surface** for the TD-10 ingest document if and when that fires, rejected alternatives 10 and 11, and an amendment to TQ-3 noting that Scribe's live response calls are a mark against it for the ingest document too. **TD-1, TD-9 and TD-10 are unchanged.** |
| **1.0.0** | 2026-08-26 | Vincent + Claude | Initial document. Answers a direct challenge to **PD-1**: *"How about generating the TypeScript types via an OpenAPI-compatible schema? I'm guessing no?"* **The guess is right and PD-1's ruling stands — but not for the expected reason, and PD-1 needs three corrections regardless.** Establishes that the common objection is false: a `components`-only OpenAPI document with **no `paths`** is legal under OAS 3.1 (whose own text requires only "at least one `paths` field, `components` field, or `webhooks` field"), `zircote/swagger-php` implements exactly that with the source comment `/* paths is optional in 3.1.x */`, and **both `openapi-typescript` 7.13.0 and `@hey-api/openapi-ts` 0.99.0 consume such a document correctly — verified by executing the published binaries, not by reading documentation**. OpenAPI loses on the producer side instead: `grep -ril inertia` across full clones of `dedoc/scramble`, `zircote/swagger-php`, `vyuldashev/laravel-openapi` and `DarkaOnLine/L5-Swagger` returns **zero files**, and a GitHub-wide repository search for `inertia openapi` returns four repositories, none of them a tool. Records the cost `02-laravel-packages.md` rejected-alternative 2 did not: **Scramble's `spatie/laravel-data` support is Scramble PRO, a commercial product at $99 solo / $399 team**, and the MIT package ships `ProNudge` extensions whose only function is to detect `laravel-data` return types and advertise it — which would make it **the architecture's first paid dependency**. Finds `vyuldashev/laravel-openapi` **uninstallable on Laravel 13** at every branch (latest tag 2023-05-04, `dev-master` tops out at `^12.0`), and both attribute-driven options (swagger-php at 45 lines for a five-property class, Apache-2.0) rejected because a hand-maintained schema is a *third* declaration of every value and would generate correct TypeScript from a stale document. **Two direct corrections to PD-1.** First, **PD-1 §4.1 and §11 describe `spatie/typescript-transformer` v2 while §3.2 pins v3.3.0** — the repository has **no `config/` directory at all**, so `config/typescript-transformer.php`, `--tag=typescript-transformer-config` and `DataTypeScriptCollector` before `DefaultCollector` do not exist; v3 uses `php artisan typescript:install`, a published `TypeScriptTransformerServiceProvider`, a fluent `TypeScriptTransformerConfigFactory`, `LaravelDataTypeScriptTransformerExtension`, and output at `resource_path('js/generated')`. Second, **PD-1's "Wayfinder and the transformer do not overlap … neither generates the other's output" is now false in both directions** — transformer v3 ships `LaravelRouteTransformedProvider`, `LaravelControllerTransformedProvider` and a `route()`/`hasRoute()` helper, while Wayfinder's `next` branch generates data shapes. **The largest finding is not about OpenAPI at all: `laravel/wayfinder` — already a dependency here at v0.1.21 — has a `next` branch generating Inertia page props, Inertia shared data, Form Request types from `rules()`, Eloquent model interfaces and PHP enum types, first-party and MIT, and Inertia's own TypeScript documentation names it as the coming answer for typing page props.** It is not recommended today: it installs as `dev-next` with no tag ever cut, its `CHANGELOG.md` still ends at v0.1.12 of 2025-09-08, it pulls two further pre-1.0 first-party packages (`laravel/ranger`, `laravel/surveyor`, both tagged within five days of the observation date), its `require-dev` pins Inertia 2 while this application runs Inertia 3, and its handling of `Route::inertia()` pages and conditionally-built prop arrays — both present in this repository — is `[UNVERIFIED]`. Also records that **SD-2 is untroubled by any candidate and cannot be used as an argument against OpenAPI**, since the incumbent's own published stub runs `npx --yes prettier` at generation time. Establishes the honest baseline neither PD-1 nor SQ-5 mentions: the starter kit **already ships a typing convention** in `resources/js/types/`, using Inertia's first-party `declare module '@inertiajs/core'` / `InertiaConfig` / `sharedPageProps` augmentation — hand-written, and already containing enum-shaped drift (`Appearance`, `FlashToast`) before any domain code exists. Names the one place OpenAPI genuinely wins — **the Python → Laravel ingest contract** that `CONTEXT-MAP.md` defines and `01-stack.md` §7 caveat 1 anticipates, where the document has a consumer that is not a type generator and the Python side already declares `pydantic` and `fastapi` — with the trigger set at SQ-1's order-B endpoint and the scope capped at `routes/api.php`. Confirms **no first-party Laravel OpenAPI offering exists**: zero matches across all 105 files of `laravel/docs` @ 13.x, zero across `laravel/framework` 13.x, and all 141 `laravel` org repositories enumerated with no true hit; Laravel 13's JSON:API resources are runtime serialisation only, with zero occurrences of "schema" in the entire `Http/Resources/JsonApi/` directory. Opens TQ-1…TQ-5, of which **TQ-1 (does Wayfinder tag before the first screen ships?) is the single condition that flips this decision**. |
