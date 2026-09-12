# Laravel packages & DX tooling — what to adopt, what to defer, what to decline

*Architecture chapter 02. Companion to [Stack decision](01-stack.md), which remains authoritative for the language, runtime and engine rulings this chapter must obey.*

| | |
|---|---|
| **Doc version** | 1.0.0 |
| **Date** | 2026-08-21 |
| **Status** | **Decided, unimplemented.** No package in tier 1 is installed yet |
| **Owner** | Vincent Khoo (sole operator) |
| **Headline** | **The two highest-value changes in this chapter are not packages** — five lines of `config/database.php` that finally satisfy SQ-7, and moving cache and sessions off the `database` driver that silently put three extra writers in the domain file. **Only one package install earns tier 1** — `spatie/laravel-data` plus the two typescript-transformer packages, as one unit, to close SQ-5's data-shape half. The other three tier-1 rulings install nothing: a CI drift check, Pest plugins that are already dependencies, and `composer audit`. **SD-4's local SQLite file disqualifies Pulse outright and neuters Scout, Horizon and Octane**; and Laravel 13 core plus the installed toolchain has quietly absorbed four more candidates |

---

## 1. Scope & method {#scope}

**Covers** the Laravel-ecosystem PHP packages and the developer-experience toolchain for `apps/web`. It classifies each candidate into one of three tiers — critically recommended, optional with a named trigger, or declined — against the actual workload: one scrape run per day, roughly 105 writes and a few hundred reads, a single human operator, an Inertia SPA, and a local SQLite file.

**Non-goals.** The schema (`DATABASE_SCHEMA.md` and its chapters), the language and engine rulings (`01-stack.md` SD-1 through SD-9), the frontend component library, and hosting. Where a package would require changing one of those, this chapter flags the conflict rather than proposing the change.

**Provenance markers** follow the convention of the database chapters and `01-stack.md`: `[MEASURED]` for something observed directly, `[E]` for evidenced in the repository, `[D]` for design intent, `[ASSUMED]` for a working assumption not yet tested, and `[UNVERIFIED]` for a claim this chapter could not confirm against a primary source.

**Evidence standard.** Every version number, release date, licence and Laravel 13 support claim in §3 comes from the Packagist metadata API (`repo.packagist.org/p2/<vendor>/<package>.json`), read on **2026-08-21**. Every capability claim — what a package requires, what it can and cannot do — comes from the vendor's own documentation, the package's declared Composer constraints, or direct observation of the installed code. No blog post, article or listicle is cited as evidence for a capability. Where community opinion is worth recording at all, it is marked as such and carries no decision weight.

**A note on the observation date.** Packagist is a moving target. A version number in §3 is a snapshot, not a guarantee. The facts that matter for the decisions — a package's Laravel 13 constraint, its licence, whether it is maintained at all — are stable over months; the patch numbers are not. Re-read §3 before acting on it if more than a quarter has passed.

---

## 2. The decision {#decision}

| ID | Subject | Ruling | Tier |
|---|---|---|---|
| **PD-1** | `spatie/laravel-data` + `spatie/laravel-typescript-transformer` | **Adopt as one unit.** This is SQ-5's data-shape half, and it is the only candidate that closes a gap `01-stack.md` explicitly left open | 1 — §4.1 |
| **PD-2** | CI drift check on the generated TypeScript | **Adopt with PD-1, not after.** SQ-5's own wording: the generated file needs the drift check Wayfinder gives routes for free | 1 — §4.2 |
| **PD-3** | Pest arch tests + mutation testing | **Already installed.** Both plugins are hard requires of `pestphp/pest` ^5. Write the tests; install nothing | 1 — §4.3 |
| **PD-4** | `composer audit` in CI | **Adopt.** Composer 2.10 ships it; `roave/security-advisories` is the heavier alternative and is not needed to start | 1 — §4.4 |
| **PD-22** | SQLite pragmas in `config/database.php` | **Adopt — highest value per line in this document.** Laravel ships `busy_timeout`, `journal_mode` and `synchronous` as `null`, so **no pragma is issued at all**. Setting them is what SQ-7 actually asks for | 1 — §9.2 |
| **PD-23** | Move cache and sessions off the `database` driver | **Adopt before M3.** The starter kit defaults put sessions, cache *and* queue in the domain SQLite file — three writers nobody chose | 1 — §9.4 |
| **PD-5** | `driftingly/rector-laravel` | Optional — trigger in §5.1 | 2 |
| **PD-6** | `laravel/telescope` | Optional — trigger in §5.2 | 2 |
| **PD-7** | `laravel/sanctum` | Optional — trigger in §5.3, and it is the scraper's ingest endpoint | 2 |
| **PD-8** | `spatie/laravel-backup` | Optional — trigger in §5.4 | 2 |
| **PD-9** | `spatie/laravel-medialibrary` | Optional — trigger in §5.5 | 2 |
| **PD-10** | `laravel/scout` | Optional and **capped by SD-4** — trigger in §5.6 | 2 |
| **PD-11** | `ergebnis/composer-normalize` | Optional, cosmetic — §5.7 | 2 |
| **PD-12** | `laravel/dusk` vs Playwright | **Playwright if anything.** Dusk is the wrong browser driver for a Svelte SPA — §5.8 | 2 |
| **PD-13** | `laravel/pulse` | **Declined — incompatible with SD-4.** Requires MySQL, MariaDB or PostgreSQL | 3 — §6.1 |
| **PD-14** | `laravel/horizon` | **Declined — incompatible with SD-4's spirit.** Requires Redis, and `01-stack.md` §8 already says the scheduler alone suffices | 3 — §6.2 |
| **PD-15** | `laravel/octane` | **Declined — actively dangerous here.** It multiplies concurrent writers against a single-writer SQLite file | 3 — §6.3 |
| **PD-16** | `soloterm/solo` | **Declined — cannot install, and superseded.** No Laravel 13 constraint, 17 months stale, and `php artisan dev` does the same job in core | 3 — §6.4 |
| **PD-17** | `barryvdh/laravel-ide-helper` | **Declined.** Larastan already infers model properties from migrations. Boost and Pao do *not* supersede it — Larastan does | 3 — §6.5 |
| **PD-18** | `laravel/reverb`, `laravel/cashier`, `laravel/folio`, `livewire/volt`, `laravel/pennant`, `laravel/nightwatch`, `laravel/envoy` | **Declined.** Each solves a problem this project does not have — §6.6 | 3 |
| **PD-19** | `spatie/laravel-permission`, `-activitylog`, `-settings`, `-sluggable`, `-tags`, `-query-builder` | **Declined.** §6.7 gives the per-package reason; several are already answered by the schema | 3 |
| **PD-20** | `nunomaduro/phpinsights`, `spatie/laravel-ray`, `infection/infection`, `tomasvotruba/type-coverage` | **Declined.** Each duplicates a gate already in place — §6.8 | 3 |

---

## 3. Registry facts {#registry}

`[MEASURED: repo.packagist.org/p2/<package>.json @ 2026-08-21]` for every row. "L13" is the package's own declared constraint on `illuminate/contracts`, `illuminate/support` or `laravel/framework`, whichever it uses. Every package listed is MIT-licensed unless stated otherwise.

### 3.1 The baseline

| Package | Version | Released | Licence |
|---|---|---|---|
| `laravel/framework` | **v13.26.1** | 2026-08-18 | MIT |
| `pestphp/pest` | v5.1.1 | 2026-08-12 | MIT |
| `larastan/larastan` | v3.10.0 | 2026-05-28 | MIT |
| `laravel/pint` | v1.30.5 | 2026-08-10 | MIT |
| `rector/rector` | 2.6.3 | 2026-08-18 | MIT |
| `peckphp/peck` | v0.3.0 | 2026-04-07 | MIT |
| `inertiajs/inertia-laravel` | v3.3.1 | 2026-08-04 | MIT |
| `laravel/wayfinder` | v0.1.21 | 2026-08-04 | MIT |
| `laravel/fortify` | (installed ^1.37.2) `[E]` | — | MIT |
| `barryvdh/laravel-debugbar` | v4.4.2 | 2026-08-20 | MIT |
| `laravel/boost` | v2.5.5 | 2026-08-19 | MIT |
| `laravel/pao` | v1.1.4 | 2026-08-10 | MIT |
| `laravel/pail` | v1.2.7 | 2026-05-20 | MIT |

Laravel 13.x requires PHP 8.3 as a minimum, was released **17 March 2026**, receives bug fixes until Q3 2027 and security fixes until **17 March 2028** `[MEASURED: laravel.com/docs/13.x/releases @ 2026-08-21]`. The repository requires PHP `^8.4` `[E: apps/web/composer.json]`, comfortably inside that window.

### 3.2 Spatie candidates

Maintainer for all rows: **Spatie** (spatie.be, Antwerp), a company rather than an individual — a materially different maintenance risk from the `turso/libsql` situation §6.2 of `01-stack.md` rejected.

| Package | Version | Released | L13 constraint | PHP | Licence |
|---|---|---|---|---|---|
| `spatie/laravel-data` | **4.23.0** | 2026-05-08 | `^10.0\|^11.0\|^12.0\|^13.0` | ^8.1 | MIT |
| `spatie/typescript-transformer` | **3.3.0** | 2026-06-19 | framework-agnostic | ^8.2 | MIT |
| `spatie/laravel-typescript-transformer` | **3.3.0** | 2026-06-19 | `^11.0\|^12.0\|^13.0` | ^8.2 | MIT |
| `spatie/laravel-query-builder` | 7.3.3 | 2026-08-07 | `^12.0\|^13.0` | ^8.3 | MIT |
| `spatie/laravel-permission` | 8.3.0 | 2026-07-03 | `^12.0\|^13.0` | ^8.3 | MIT |
| `spatie/laravel-activitylog` | 5.1.0 | 2026-08-12 | `^13.0` | ^8.4 | MIT |
| `spatie/laravel-backup` | 10.3.2 | 2026-08-20 | `^12.40\|^13.0` | ^8.3 | MIT |
| `spatie/laravel-settings` | 3.9.0 | 2026-05-26 | `^11.0\|^12.0\|^13.0` | ^8.2 | MIT |
| `spatie/laravel-medialibrary` | 11.23.5 | 2026-08-10 | `^10.2\|^11.0\|^12.0\|^13.0` | ^8.2 | MIT |
| `spatie/laravel-sluggable` | 4.0.3 | 2026-07-28 | `^12.0\|^13.0` | ^8.3 | MIT |
| `spatie/laravel-tags` | 4.12.0 | 2026-06-20 | `^10.0\|^11.0\|^12.0\|^13.0` | ^8.1 | MIT |
| `spatie/laravel-ray` | 1.43.9 | 2026-04-28 | `^7.20`…`^13.0` | ^7.4\|^8.0 | MIT |

**Every one of these declares Laravel 13 support and every one has shipped a release in 2026.** There is no maintenance question to answer about any of them; the questions in §6.7 are about fit, not about health.

`spatie/laravel-data` release cadence, most recent twelve stable tags `[MEASURED @ 2026-08-21]`: 4.23.0 (2026-05-08), 4.22.1 (04-27), 4.22.0 (04-16), 4.21.0 (04-02), 4.20.1 (03-18), 4.20.0 (02-25), 4.19.1 (01-28), 4.19.0 (01-19), 4.18.0 (2025-10-16), 4.17.1 (09-04), 4.17.0 (06-25), 4.16.1 (06-24). That is roughly monthly through 2026 — healthy, and the three-month gap since May is unremarkable for a mature package on a stable major.

### 3.3 First-party Laravel candidates

Maintainer for all rows: **Laravel LLC** (Taylor Otwell). All MIT.

| Package | Version | Released | L13 constraint | Verdict driver |
|---|---|---|---|---|
| `laravel/horizon` | v5.48.3 | 2026-08-10 | `^9.21`…`^13.0` | **Requires Redis** — §6.2 |
| `laravel/pulse` | v1.8.0 | 2026-07-29 | `^10.48.4`…`^13.0` | **Requires MySQL/MariaDB/PostgreSQL** — §6.1 |
| `laravel/nightwatch` | v1.28.7 | 2026-08-13 | `^10.0`…`^13.0` | Client for a paid hosted SaaS — §6.6 |
| `laravel/telescope` | v5.22.1 | 2026-08-05 | `^8.37`…`^13.0` | Works on SQLite — §5.2 |
| `laravel/octane` | v2.19.1 | 2026-08-13 | `^10.10.1`…`^13.0` | **Unsafe under SD-4** — §6.3 |
| `laravel/scout` | v11.5.0 | 2026-08-04 | `^9.0`…`^13.0` | Capped by SQLite — §5.6 |
| `laravel/reverb` | v1.11.1 | 2026-08-06 | `^10.47`…`^13.0` | No realtime requirement — §6.6 |
| `laravel/sanctum` | v4.3.3 | 2026-06-23 | `^11.0\|^12.0\|^13.0` | Complementary to Fortify — §5.3 |
| `laravel/cashier` | v16.7.0 | 2026-08-05 | `^10.0`…`^13.0` | Requires `stripe/stripe-php` — §6.6 |
| `laravel/folio` | v1.2.0 | 2026-08-13 | `^10.19`…`^13.0` | Blade page routing — §6.6 |
| `livewire/volt` | v1.11.2 | 2026-07-31 | `^10.38.2`…`^13.0` | **Requires `livewire/livewire`** — §6.6 |
| `laravel/pennant` | v1.26.0 | 2026-08-13 | `^10.0`…`^13.0` | No flag requirement — §6.6 |
| `laravel/prompts` | v0.3.23 | 2026-08-11 | — | **Already installed transitively** — §7.2 |
| `laravel/envoy` | v2.12.2 | 2026-04-01 | `^6.0`…`^13.0` | No remote servers yet — §6.6 |
| `laravel/dusk` | v8.6.0 | 2026-04-15 | `^10.0`…`^13.0` | Wrong tool for a Svelte SPA — §5.8 |

### 3.4 DX and quality-gate candidates

| Package | Version | Released | Maintainer | Licence | Note |
|---|---|---|---|---|---|
| `pestphp/pest-plugin-arch` | v5.0.0 | 2026-07-21 | Pest / Nuno Maduro | MIT | **Already a hard require of `pestphp/pest` ^5** |
| `pestphp/pest-plugin-mutate` | v5.0.2 | 2026-08-10 | Pest / Nuno Maduro | MIT | **Already a hard require of `pestphp/pest` ^5** |
| `pestphp/pest-plugin-stressless` | v5.0.2 | 2026-08-04 | Pest / Nuno Maduro | MIT | Not bundled; separate install |
| `infection/infection` | 0.35.2 | 2026-08-19 | Maks Rafalko et al. | **BSD-3-Clause** | Duplicates the bundled mutate plugin |
| `roave/security-advisories` | **dev-latest** | 2026-08-20 | Roave | MIT | Rolling branch only — **no stable tag exists by design** |
| `ergebnis/composer-normalize` | 2.52.0 | 2026-05-15 | Andreas Möller | MIT | Composer plugin |
| `driftingly/rector-laravel` | 2.5.0 | 2026-06-02 | Drift Solutions | MIT | Rector rule set, not a Laravel package |
| `tomasvotruba/type-coverage` | 2.3.4 | 2026-08-18 | Tomáš Votruba | MIT | PHPStan extension; overlaps the Pest plugin |
| `nunomaduro/phpinsights` | v2.14.2 | 2026-04-12 | Nuno Maduro | MIT | Overlaps Pint + Larastan |
| `barryvdh/laravel-ide-helper` | v3.7.0 | 2026-03-17 | Barry vd. Heuvel | MIT | Declares L13 support — §6.5 |
| `soloterm/solo` | **v0.5.0** | **2025-03-21** | Aaron Francis | MIT | **`illuminate/* ^10\|^11\|^12` — no Laravel 13** |
| `nunomaduro/essentials` | v1.2.0 | 2026-02-23 | Nuno Maduro | MIT | `^11.44.2\|^12.52.0\|^13.0` — §5.9 |
| `dedoc/scramble` | v0.13.41 | 2026-08-14 | Roman Lytvynenko | MIT | OpenAPI generation — the SQ-5 alternative |
| `phpstan/phpstan` | 2.2.8 | 2026-08-04 | Ondřej Mirtes | MIT | Already installed via Larastan |

**`soloterm/solo` is the only candidate in this whole chapter that is stale.** Its most recent stable tag is v0.5.0 of **21 March 2025** — seventeen months before the observation date — and its Composer constraints top out at `illuminate/support ^12`. It is not installable on Laravel 13 without a version override. See §6.4, which also records that core has since absorbed its function.

**`roave/security-advisories` has no stable tag and never will.** It publishes only `dev-latest` (and historically `dev-master`), because the package *is* a rolling list of `conflict` entries. Installing it means `composer require --dev roave/security-advisories:dev-latest`, which is the documented usage, not a mistake. `[MEASURED: repo.packagist.org/p2/roave/security-advisories~dev.json @ 2026-08-21 — dev-latest, 2026-08-20, MIT]`

---

## 4. Tier 1 — critically recommended {#tier-1}

**Six rulings, of which exactly one is a package install.** Four are documented here; **PD-22** (SQLite pragmas) and **PD-23** (cache and session drivers) are tier 1 too, but their reasoning belongs with the boundary discussion and lives in §9.2 and §9.4. Only PD-1 costs anything in the currency that matters here, which is the operator's attention.

### 4.1 PD-1 — `spatie/laravel-data` and the typescript-transformer pair {#pd-1}

**This is the only tier-1 package install, and it is a three-package unit, not one package.**

`01-stack.md` §3.5 item 1 records "no shared types between backend and frontend" as an *accepted cost*, and SQ-5 sharpens it: Wayfinder closes the **route** half of the type gap at build time, and nothing closes the **data-shape** half. SQ-5 names the specific values that will drift first — "the six `CHECK` enumerations and the `acquisition` discriminator" — and names the specific failure mode: "a stale enum in a Svelte component produces a wrong dropdown rather than an error."

That is a gap the architecture doc opened deliberately and left for this chapter. It is the single highest-value package decision available, and it is the reason this tier is not empty.

**What the three packages do, and why all three.**

`spatie/typescript-transformer` (3.3.0) is the framework-agnostic engine: it reads PHP classes and emits TypeScript type declarations. `spatie/laravel-typescript-transformer` (3.3.0) is the Laravel binding that adds the `typescript:transform` Artisan command and a config file. `spatie/laravel-data` (4.23.0) is the data-object layer that gives you classes worth transforming in the first place.

The generation path is `[MEASURED: spatie.be/docs/laravel-data/v4/advanced-usage/typescript, via Context7 @ 2026-08-21]`: annotate a data object with the `#[TypeScript]` attribute or a `/** @typescript */` docblock, then run `php artisan typescript:transform`. For whole-application coverage, register `DataTypeScriptCollector` in `typescript-transformer.php` **before** `DefaultCollector` — the ordering is load-bearing and is the kind of detail that costs an hour if you meet it by accident.

The transformer also understands `laravel-data`'s optionality semantics, which is what makes the pairing more than a coincidence. `Spatie\TypeScriptTransformer\Attributes\Optional` marks a property optional in the emitted TypeScript without making it optional in PHP, and `Lazy` and `Optional` properties emit as `lazy?: string` rather than as required fields. A hand-rolled generator would get this wrong, and getting it wrong is worse than not generating at all, because a wrong type is trusted.

**Could you use `laravel-data` without the transformer, or the transformer without `laravel-data`?** Both, technically. Neither is the recommendation. The transformer alone can emit types from plain PHP classes and enums, which would cover the six `CHECK` enumerations — genuinely the highest-risk half of SQ-5 — at a fraction of the adoption cost. If the appetite for `laravel-data` is low, **transform the enums first and add `laravel-data` later**; that path is strictly incremental and closes the drift that SQ-5 says will bite first. But `laravel-data` without the transformer buys the least of the three combinations, because the DTO ergonomics are the smaller half of the value here.

**Assessed against Laravel 13 core.** Laravel 13 ships no data-object or DTO primitive. Its release notes list first-party AI primitives, JSON:API resources, `PreventRequestForgery`, `Queue::route()`, expanded PHP attributes, `Cache::touch()` and vector search — and nothing in the DTO space `[MEASURED: laravel.com/docs/13.x/releases @ 2026-08-21]`. The core alternatives are the same ones that have existed for years: **Form Requests** for inbound validation, **Eloquent API Resources** for outbound shaping, and **casts plus native enums** for attribute typing. Between them they cover most of what `laravel-data` does — but in *two different classes per shape*, with no single artefact a TypeScript generator can point at. `laravel-data`'s actual argument here is not "better DTOs"; it is **one class per shape, which is a thing that can be transformed**. That is the argument that survives contact with a project of this size.

Laravel 13's new **JSON:API resources** are worth naming explicitly so they are not mistaken for an answer. They are an *outbound serialisation* feature, and Inertia does not consume JSON:API — Inertia props are plain arrays. They solve a problem this project does not have, which is a public API surface conforming to a spec.

**Cost, honestly.** `laravel-data` is a real abstraction with a real learning curve, and adopting it on `app/` code that does not exist yet means adopting it as a convention rather than as a refactor. That is the cheapest moment, exactly as `01-stack.md` §2 argues about the language choice — and unlike the language choice, this one is reversible. It also pulls four transitive dependencies (`phpdocumentor/type-resolver`, `phpdocumentor/reflection-common`, `phpdocumentor/reflection-docblock`, `spatie/php-structure-discoverer`) plus `spatie/laravel-package-tools`, which is a larger dependency footprint than anything else in tier 1.

**Interaction with Wayfinder.** They are complementary and do not overlap. Wayfinder generates typed *route* functions into `resources/js/actions/` and `resources/js/routes/` `[E: apps/web/AGENTS.md, wayfinder/core rules]`; the transformer generates typed *data shapes*. Together they cover both halves of SQ-5. Neither generates the other's output, and neither will warn you about the other's drift — which is why PD-2 exists.

### 4.2 PD-2 — the drift check, adopted at the same time {#pd-2}

SQ-5 does not merely suggest this, it specifies it: *"Whatever tool is chosen for model/DTO types … the generated file needs the same CI drift check Wayfinder gives routes for free."* And `01-stack.md` §3.5 item 1 gives the reason in one sentence: *"A generation step that can be skipped will eventually be skipped."*

The mechanism is the standard generated-artifact gate: run `php artisan typescript:transform` in CI, then fail if the working tree is dirty. The existing `.github/workflows/tests.yml` `web` job is the right home — it already runs `composer setup` followed by `composer ci:check` `[E]`, so the generation step has a booted application available to it.

**Adopt this in the same commit as PD-1, not in a follow-up.** A drift check added later has to be added against an already-drifted file, and the first thing it does is fail for reasons nobody remembers. Added at the same time, it never has a backlog — the same reasoning `apps/scraper/pyproject.toml` records for turning on `ty` while `src/pw` was still empty `[E]`.

### 4.3 PD-3 — Pest arch tests and mutation testing are already installed {#pd-3}

**`pestphp/pest-plugin-arch` and `pestphp/pest-plugin-mutate` are hard `require` entries of `pestphp/pest` v5.1.1.** `[MEASURED: repo.packagist.org/p2/pestphp/pest.json @ 2026-08-21 — v5.1.1 requires `pestphp/pest-plugin-arch: ^5.0.0` and `pestphp/pest-plugin-mutate: ^5.0.2`, alongside `pest-plugin-profanity`]`. The repository already requires `pestphp/pest: ^5.1` `[E: apps/web/composer.json]`.

So the correct action for both is **write the tests, install nothing**. Adding either to `composer.json` would be a no-op that implies a dependency the project does not separately own.

Arch tests are worth writing here for a specific, non-generic reason: the house conventions in `pint.json` are enforced only where Pint has a rule. `final_class`, `declare_strict_types` and `date_time_immutable` are Pint's `[E]`. But "no `App\Models\*` referenced from `App\Actions\*`", "every Job is final and implements `ShouldQueue`", "nothing in `app/` calls `env()`" and "the ingest path is the only writer" are architectural invariants that no formatter can express — and this project has an unusually high-stakes one of those, in `01-stack.md` §3.5 item 2 and SQ-7: **all writes go through one path**. An arch test is the only cheap, automatic guard on that invariant, and a solo operator with no reviewer is exactly the person who benefits from a machine holding it.

Mutation testing is a lower priority — the 90% coverage gate is not yet enforced (see §7.4), and mutation testing on top of unenforced coverage measures nothing. Revisit once §7.4 is resolved and there is real domain code.

### 4.4 PD-4 — `composer audit` in CI {#pd-4}

**Composer ships vulnerability auditing in core.** `[MEASURED: `composer audit --help` against Composer 2.10.1 (2026-06-04) on the local machine @ 2026-08-21 — "Checks for security vulnerability advisories for installed packages", with `--locked`, `--format`, `--abandoned` and `--ignore-severity` options]`.

The CI workflow already installs `composer:v2` `[E: .github/workflows/tests.yml]`, so this is one line in the `web` job — `composer audit --locked` — and no new dependency at all. `--abandoned=fail` is worth considering as well, since an abandoned package is the failure mode that actually threatens a solo project: not a CVE, but a dependency that quietly stops being maintained. That is precisely the risk `01-stack.md` §6.2 caught in `turso/libsql`, and it caught it by reading the registry by hand.

**`roave/security-advisories` is the heavier alternative and is not tier 1.** It works by adding thousands of `conflict` constraints to the dependency graph, which makes `composer update` *refuse* to install a vulnerable version rather than reporting one after the fact. That is genuinely stronger — prevention rather than detection — but it also means a security advisory can block an unrelated update at an inconvenient moment, and it slows resolution measurably on a large graph. For a solo operator on a private, non-public-facing workspace with a nightly batch as its only external input, `composer audit --locked` in CI is the right point on that curve. Promote to `roave/security-advisories` if and when the public feed of SD-6 ships and the application becomes internet-facing.

---

## 5. Tier 2 — optional, with a named trigger {#tier-2}

Nothing in this tier should be installed today. Each row names the concrete event that flips it.

### 5.1 PD-5 — `driftingly/rector-laravel` {#pd-5}

2.5.0, 2026-06-02, MIT, maintained by Drift Solutions. It is a rule set for Rector, not a Laravel package — its only Composer requirement is `php ^7.4 || ^8.0` `[MEASURED @ 2026-08-21]`, so "Laravel 13 support" is a question about its *rules*, not its installability.

`rector.php` currently runs `deadCode`, `codeQuality` and `withPhpSets()` `[E]`. Those are language-level. `rector-laravel` adds framework-level upgrade rules — the ones that rewrite deprecated facade calls, migrate container bindings, and modernise Laravel idioms across major versions.

**Trigger: the Laravel 14 upgrade, or the first time an upgrade guide asks for a mechanical change across more than a handful of files.** Today `app/` holds sixteen files, all of them starter-kit scaffolding `[MEASURED: `find apps/web/app -type f` @ 2026-08-21 → 16 files, of which one model (`User.php`), two Fortify actions, three controllers, four form requests, two middleware, two concerns, two providers]`. There is nothing for an automated upgrade rule to upgrade. Adding it now buys a slower Rector run and a longer `composer.json`.

**A caution when it is adopted.** `rector.php` already carries a deliberate `withSkip([ClosureToArrowFunctionRector::class])` with a comment explaining that Rector's output fights Pint's `laravel` preset on `fn ()` spacing `[E]`. Framework rule sets are more opinionated than language rule sets, so expect that skip list to grow. Add the set behind a `--dry-run` review pass, not straight into `composer test:rector`.

### 5.2 PD-6 — `laravel/telescope` {#pd-6}

v5.22.1, 2026-08-05, MIT, Laravel LLC. Installs as `composer require laravel/telescope --dev`, then `telescope:install` and `migrate` `[MEASURED: laravel.com/docs/13.x/telescope via Context7 @ 2026-08-21]`. It stores entries through ordinary Laravel migrations, so **unlike Pulse it works on SQLite** — this is the important distinction between the two first-party observability tools and the reason one is tier 2 and the other is declined.

**It overlaps Debugbar, which is already installed `[E: barryvdh/laravel-debugbar ^4.4]`, but not completely.** Debugbar is a per-request overlay: it shows queries, timings and dumps for the page currently in front of you. Telescope is a recorder: it keeps a searchable history across requests, and — the part that matters here — across **queued jobs, scheduled commands and console runs**, which have no browser to attach an overlay to.

**Trigger: the first time the nightly ingest batch fails in a way that is not reproducible from the logs.** That is the exact shape of problem Debugbar cannot see, because the batch runs from the scheduler with no HTTP request. `laravel/pail` is already installed and tails logs `[E]`, which covers the easy half; Telescope covers the half where you need to know what queries the failing run actually issued.

**One caveat specific to SD-4.** Telescope writes an entry per recorded event into the same database. Under a local SQLite file with a single-writer discipline (`01-stack.md` §3.5 item 2, SQ-7), a chatty recorder running *during* the nightly batch adds write traffic to the connection you least want contended. If Telescope is adopted, restrict it to local development — the `--dev` install and `TELESCOPE_ENABLED` already point that way — or point it at a second SQLite file via a dedicated connection. Do not run it in production against the domain database.

### 5.3 PD-7 — `laravel/sanctum` {#pd-7}

v4.3.3, 2026-06-23, MIT, Laravel LLC.

**First, dispose of the "Sanctum vs Fortify" framing: there is no overlap to resolve.** Laravel's own documentation is explicit `[MEASURED: laravel.com/docs/13.x/fortify via Context7 @ 2026-08-21]`: *"Laravel Fortify and Laravel Sanctum are complementary packages, not competing ones. Fortify handles backend authentication features like user registration and password reset, while Sanctum focuses on managing API tokens and authenticating existing users via session cookies or tokens."* Fortify is the *how do you log in*; Sanctum is the *how does a request prove it is you*.

For the workspace screens themselves, Sanctum is **not needed**: Inertia is not a decoupled SPA. It runs on the same origin, served by the same Laravel application, authenticated by the ordinary session cookie and the `web` guard. `01-stack.md` §7 makes this the point of choosing Inertia — *"no REST API is hand-built for the workspace's own screens."* Adding Sanctum for the screens would be answering a question Inertia already removed.

**Trigger: the scraper's ingest endpoint — which SQ-1 says is coming, and soon.** `01-stack.md` §6.4 puts order B in force: *"Keep n8n, but point it at a Laravel HTTP endpoint instead of the database."* §7 carries the same caveat — *"A scraper posting listings (§5.2) still needs a conventional JSON endpoint. Inertia removes the API for screens, not for machines."* That endpoint has a non-browser client with no session, and it needs machine authentication.

Sanctum's personal access tokens are the least-effort correct answer: one `tokens` table, a `auth:sanctum` middleware, one token issued to the scraper. **But it is not the only answer, and at one client it may not be the best one.** A single shared secret compared with `hash_equals()` in a middleware is perhaps twenty lines, has no migration, and no token-abilities model to reason about. Sanctum earns its place at the *second* machine client, or the first time a token needs to be revoked without a deploy. Record which you chose, because a shared secret that grows a second client silently becomes the wrong answer.

### 5.4 PD-8 — `spatie/laravel-backup` {#pd-8}

10.3.2, 2026-08-20, MIT, Spatie. **SQLite is supported** — the package's own installation documentation states *"MySQL, PostgreSQL, SQLite and Mongo databases are supported"* `[MEASURED: spatie.be/docs/laravel-backup/v10/installation-and-setup @ 2026-08-21]`.

**But weigh it against what SD-4 actually gives you.** The entire database is *one file*, projected at 6 MB at twelve months (`01-stack.md` §3.3, citing §15 of the database chapters). Backing up a 6 MB local file is `cp`, or better `sqlite3 db.sqlite ".backup out.sqlite"`, which is safe under a concurrent reader in a way a plain `cp` of a WAL-mode database is not. `laravel-backup`'s value is in the parts this project does not need yet: scheduled uploads to S3 or another remote filesystem, retention policies with monthly and yearly tiers, notification on failure, and multi-database orchestration.

**Trigger: the first remote deployment.** While the database is a file on a machine the operator can see, a cron entry and a `.backup` call is a smaller, more auditable thing than a package. The moment the file lives on a host the operator does not routinely log into, "did last night's backup actually run and land somewhere off-box" becomes a question worth a package that answers it with a notification. Adopt then, and adopt the notification channel at the same time — an unmonitored backup is a belief, not a backup.

### 5.5 PD-9 — `spatie/laravel-medialibrary` {#pd-9}

11.23.5, 2026-08-10, MIT, Spatie.

**The schema question is now answered, and the answer is "not yet, but a specific trigger is already written down."** No V1 table stores photos, images or files of any kind `[MEASURED: grep across `docs/DATABASE_SCHEMA.md` and `docs/database/*.md` for photo/image/media/attachment/upload/S3 @ 2026-08-21 — the only hits are portal URL slugs and the proposed `documents` table]`. A `documents` table is staged in `08-review-v1.1.md` §23.4 as part of the Tier-1 workspace roadmap, and it carries its own open question, **OQ-13**: *"Where do `documents` files actually live, and who deletes them? In force: nothing — the table does not exist and the files are presumed to be in Google Drive."*

The general shape of the judgement does not depend on that answer. Media Library is a heavyweight: it adds a `media` table, a polymorphic association, conversion pipelines that want a queue, and image manipulation that wants `ext-imagick` or `ext-gd`. If listings carry **remote URLs scraped from a portal** — which is the likely shape for a market feed — then nothing is being *stored* and the package solves nothing; a `TEXT` column holding a URL is the whole feature.

**Trigger: `documents` is implemented — i.e. OQ-13 is answered.** At that point compare against Laravel's core `Storage` facade plus the `documents` table the roadmap already specifies, because Media Library's conversion pipeline — its main differentiator — wants a queue worker, and `01-stack.md` §8 says the scheduler alone is currently sufficient.

**And read OQ-13's constraint before choosing, because it disqualifies the naive integration.** OQ-13's blast radius is *"PDPA. Deleting a `documents` row orphans the underlying file, so erasure has to delete the object first and the row second. **That ordering must be written down before the first upload, not after.**"* Media Library couples row and file lifecycle through model events, which is convenient until you need to *guarantee* object-before-row ordering under a regulatory erasure request. Whichever approach is taken, the erasure ordering is the acceptance criterion — not the upload ergonomics.

**A caution specific to SD-4.** Conversions are queued jobs. Queued jobs on the `database` driver mean *more writers* against the single SQLite file, which is the risk SQ-7 exists to watch. If Media Library is adopted, either run conversions synchronously or accept that SQ-7 has been re-opened deliberately.

### 5.6 PD-10 — `laravel/scout`, and the SQLite search ceiling {#pd-10}

v11.5.0, 2026-08-04, MIT, Laravel LLC. **This is the most important tier-2 entry, because the honest answer is worse than most people expect.**

Scout supports several engines. Two of them need no external service, and the documentation is unambiguous about what each requires `[MEASURED: laravel.com/docs/13.x/scout and /13.x/search via Context7 @ 2026-08-21]`:

| Engine | Requirement | Usable under SD-4? |
|---|---|---|
| `database` | *"enable MySQL or PostgreSQL full-text indexing and LIKE clause searching"* | **No** |
| `collection` | *"the most portable option across all relational databases supported by Laravel, including SQLite and SQL Server"* | Yes — with a hard ceiling |
| Algolia / Meilisearch / Typesense | An external search service | Yes, at the cost of a service |

The `collection` engine's own documentation places its ceiling explicitly: it is *"intended for prototypes, testing, or extremely small datasets of a few hundred records,"* it *"retrieves all possible records from the database and filters them in PHP,"* and it is *"significantly less efficient than the database engine and should not be used for large datasets."*

**Laravel's native full-text support is equally closed to SQLite.** `$table->fullText([...])` in migrations and `whereFullText()` in the query builder are *"supported by MariaDB, MySQL, and PostgreSQL"* `[MEASURED: laravel.com/docs/13.x/search and /13.x/queries via Context7 @ 2026-08-21]`. There is no SQLite branch. Laravel 13's new `whereVectorSimilarTo()` semantic search is narrower still — the release notes tie it to *"PostgreSQL + `pgvector`"* `[MEASURED: laravel.com/docs/13.x/releases @ 2026-08-21]`.

**So what is the SQLite/FTS5 story? There is no packaged one.** SQLite's own FTS5 extension is excellent and is compiled into essentially every modern SQLite build, but no credible Laravel package wraps it. A Packagist search for SQLite FTS5 returns three candidates with **30, 468 and 1,238 total downloads and 5, 0 and 2 GitHub stars respectively** `[MEASURED: packagist.org search API for "sqlite fts5" @ 2026-08-21]`. Those are not adoption numbers; they are hobby-project numbers. Judged by the same standard `01-stack.md` §6.2 applied to `turso/libsql` — read the registry, not the marketing page — none of them is a production bet, and §6.2's standard is the house standard.

**The practical answer, and it is a good one:** if full-text search is needed, create the FTS5 virtual table and its synchronising triggers in a **raw Laravel migration** via `DB::statement()`, and query it with `DB::select()` or a query-builder `whereRaw()`. This is perhaps forty lines of DDL, owned in the repository, with no dependency and no service. It also sits naturally beside a schema that already needs raw DDL for `STRICT` tables — `01-stack.md` §6.3 says *"`STRICT` tables remain the single biggest win and should be declared in the Laravel migrations"*, and Laravel's schema builder does not emit `STRICT` either. The migration layer for this project was always going to contain hand-written SQL. FTS5 is one more statement in a file that will already have some.

**And this is not a suggestion of this chapter — the database chapters reached it first, independently.** `04-integrity.md` §9 rules on `properties.title` and `summary` directly: *"Substring search is not an access pattern. When it is, it needs **FTS5** (profile §3), not a B-tree — `LIKE '%x%'` cannot use an ordered index."* The same objection is recorded against the one search access pattern that does exist. **AP-15** — *"Find a contact by name (partial match)"*, `name LIKE ?`, ~15 queries a day — is served by `idx_contacts_name`, and `03-entities.md` §6.1 marks the index *"prefix matches only … Serves `LIKE 'Ahmad%'`. Will **not** serve `LIKE '%Ahmad%'`, **which is what a search box actually sends**."* `06-operations.md` §18 carries the query-plan assertion for both cases.

**So the search gap is real, it is documented, and it has a named answer that is not a package.** What this chapter adds is only the negative half: Scout cannot supply that answer under SD-4, and no package wraps FTS5 credibly. At ~15 searches a day over a few thousand contacts, a full scan with `LIKE '%…%'` is also entirely acceptable — `01-stack.md` §3.3 forecloses the argument that it is not.

**Trigger for Scout proper: an external search service becomes acceptable.** That is a hosting decision, and hosting is explicitly out of scope in `01-stack.md` §1. Until then, Scout's only SQLite-compatible engine is a prototype tool, and the honest recommendation is FTS5 by hand or `LIKE` — at a few hundred rows, `LIKE '%term%'` is genuinely fine, and pretending otherwise is the performance argument `01-stack.md` §3.3 already rejected.

### 5.7 PD-11 — `ergebnis/composer-normalize` {#pd-11}

2.52.0, 2026-05-15, MIT, Andreas Möller. A Composer plugin that sorts and formats `composer.json` to a canonical shape.

Purely cosmetic, and the file is already tidy `[E: `"sort-packages": true` is set in the `config` block of apps/web/composer.json]`, which handles the part that actually causes diff noise. **Trigger: a second contributor**, at which point `composer.json` diff churn becomes a review cost rather than a private one. For a solo operator it is a gate that will only ever fail on the operator's own formatting.

### 5.8 PD-12 — `laravel/dusk` versus Playwright {#pd-12}

`laravel/dusk` v8.6.0, 2026-04-15, MIT, Laravel LLC. Fully Laravel 13 compatible; that is not the objection.

Dusk drives ChromeDriver through the WebDriver protocol and is designed around Blade-rendered pages and Laravel-side assertions. For a **Svelte 5 SPA over Inertia 3**, the interesting failures live on the client: hydration, reactive state, `$state`/`$derived` behaviour, deferred and merged Inertia props, optimistic updates with rollback (an Inertia 3 feature `[E: apps/web/AGENTS.md, inertia-laravel/core rules]`). Dusk's waiting model and assertion vocabulary are a poor match for that, and its selector story pushes toward Blade-era markup.

**Playwright is the better fit if browser testing is adopted at all**, and the frontend toolchain is already Node-based `[E: apps/web/package.json — Vite 8, TypeScript, eslint, prettier, svelte-check]`, so it adds no new *runtime*, only a dev dependency and browser binaries.

**But the honest recommendation is neither, yet.** Browser tests are the most expensive tests to write and maintain, and they pay off in proportion to how much can break invisibly. With sixteen scaffolding files in `app/` and no domain screens `[MEASURED @ 2026-08-21]`, there is nothing to regress. **Trigger: the third screen ships, or the first bug that Pest feature tests structurally cannot catch** — meaning it lives entirely in client state and never reaches the server.

**A note on the existing gates.** `svelte-check` already runs in `ci:check` via `pnpm run types:check` `[E]`, which catches a large class of Svelte and TypeScript errors statically and for free. That is a meaningful part of what browser tests would otherwise be asked to find, and it is already paid for.

### 5.9 PD-21 — `nunomaduro/essentials` {#pd-21}

v1.2.0, 2026-02-23, MIT, Nuno Maduro, `^11.44.2|^12.52.0|^13.0`. Not on the original candidate list; surfaced while verifying the Pest ecosystem and worth a line because it is adjacent to conventions this repository has already adopted by hand.

It applies a set of opinionated framework defaults — strict Eloquent models (`preventLazyLoading`, `preventSilentlyDiscardingAttributes`), immutable dates, automatic eager-loading prevention, and similar. The repository already reaches for the same philosophy through Pint (`declare_strict_types`, `final_class`, `date_time_immutable`, `strict_comparison`) `[E: apps/web/pint.json]`.

**Trigger: after the first domain models exist and `AppServiceProvider` has accumulated three or more `Model::` hardening calls.** At that point the package replaces boilerplate the operator has already written by hand and agrees with. Before that, it is inherited opinions in place of chosen ones — and `[UNVERIFIED]`: this chapter did not audit the full list of defaults it applies, so read them before adopting rather than trusting the summary above.

---

## 6. Tier 3 — arguably not needed {#tier-3}

### 6.1 PD-13 — `laravel/pulse` conflicts with SD-4 {#pd-13}

**This is a hard incompatibility, not a preference.** Laravel's own documentation: *"Pulse's first-party storage implementation requires a MySQL, MariaDB, or PostgreSQL database. If the primary application uses a different database engine, a separate supported database must be configured specifically for Pulse data."* `[MEASURED: laravel.com/docs/13.x/pulse via Context7 @ 2026-08-21]`

**SD-4 rules that the engine is PDO SQLite against a local file, and that Turso Cloud exits.** Adopting Pulse therefore requires standing up a MySQL, MariaDB or PostgreSQL instance purely to hold telemetry — which is exactly the cost §19 item 1 of the database chapters and rejected-alternative 8 of `01-stack.md` refused to pay for the *domain* data: *"it buys nothing this workload can use and costs a server, a backup story and a pooler."* Paying that price for a dashboard, on a system doing ~105 writes a day, inverts the reasoning.

**Recommending Pulse would conflict with SD-4.** It is recorded here as a conflict rather than proposed, per the standing instruction that a decided SD-\* is not silently overridden.

Pulse also offers a Redis ingest driver (`PULSE_INGEST_DRIVER=redis`, requiring Redis 6.2+ and `phpredis` or `predis`, with a `pulse:work` process to drain the stream) `[MEASURED: laravel.com/docs/13.x/pulse via Context7 @ 2026-08-21]`. That changes the *ingest* path only; the storage requirement is unchanged. It adds a dependency without removing the blocking one.

### 6.2 PD-14 — `laravel/horizon` requires Redis, and the scheduler already suffices {#pd-14}

**Confirmed verbatim from the official documentation:** *"Laravel Horizon requires that you use [Redis](https://redis.io) to power your queue. Therefore, you should ensure that your queue connection is set to `redis` in your application's `config/queue.php` configuration file. Horizon is not compatible with Redis Cluster at this time."* `[MEASURED: laravel.com/docs/13.x/horizon @ 2026-08-21]`

So the answer to the brief's "confirm Horizon requires Redis" is **yes, unconditionally**, and Horizon has no database-queue mode to fall back to.

**The more interesting point is that `01-stack.md` already decided this**, and the registry fact merely confirms it. §3.2 lists "Scheduler, queues, Horizon" among Laravel's batteries — but §8 then rules on the actual need: *"It lives in Laravel — scheduler for the daily run, queues plus Horizon if retries and backoff are wanted. **At one scrape run per day, the scheduler alone is sufficient.**"*

This is a case worth naming explicitly under the brief's request to flag packages the repo's own docs already decided against: **Horizon is popular, first-party, excellent, and answers a question this project does not ask.** One job per day does not need throughput dashboards, auto-balancing supervisors, or wait-time notifications. It needs `Schedule::command(...)->daily()`.

There is a second reason, which outranks the first and belongs to §8 of the stack doc: *"The detail that outranks the job runner … the daily batch of ~105 upserts must be wrapped in one transaction … No scheduler compensates for getting this wrong, and none is needed to get it right."* Horizon is a job runner. The risk in this system is not job orchestration.

**Also note what adopting Horizon would drag in.** A Redis server is a second stateful service, with its own memory profile, persistence configuration and failure modes, added to a project whose entire database is a 6 MB file. And Horizon's own deployment section recommends Supervisor to keep `php artisan horizon` alive `[MEASURED: laravel.com/docs/13.x/horizon @ 2026-08-21]` — a third moving part.

**Trigger, recorded for completeness:** if queued work ever becomes genuinely concurrent and failure-prone — many retryable per-listing jobs rather than one nightly batch — revisit. Note that under SD-4 the `database` queue driver is itself a second writer against the SQLite file, so the trigger for *queues* is entangled with SQ-7 and should be evaluated together, not separately.

### 6.3 PD-15 — `laravel/octane` is actively unsafe here {#pd-15}

v2.19.1, 2026-08-13, MIT. Octane *"enhances application performance by utilizing high-powered servers such as FrankenPHP, Open Swoole, Swoole, and RoadRunner. By booting the application once and keeping it in memory, Octane significantly increases the speed at which requests are processed."* `[MEASURED: laravel.com/docs/13.x/octane via Context7 @ 2026-08-21]`

**Three independent reasons this is the wrong package for this project, in increasing order of seriousness.**

*It answers a question already ruled out of order.* `01-stack.md` §3.3: *"AP-01 through AP-16 total roughly 105 writes and a few hundred reads per day … Every language considered is idle at this volume. Any argument reaching for throughput benchmarks is answering a question this project does not ask."* Octane is a throughput package. The section that pre-emptively rejects throughput arguments applies to it directly.

*It changes SD-2.* SD-2 rules the runtime is **PHP-FPM**. Octane replaces PHP-FPM with a persistent application server. That is a change to a decided SD-\*, and is flagged as such rather than proposed.

*It makes the one open risk in the architecture materially worse.* SQ-7 asks whether PHP-FPM's worker model ever collides with the single-writer rule, and answers *"no, at ~105 writes/day in one nightly batch"* — while warning that the failure mode is *"a `SQLITE_BUSY` under concurrent write attempts … an intermittent, hard-to-reproduce error rather than a clean failure."* Octane keeps N long-lived workers resident with warm database connections, which is strictly more concurrent write pressure on a single file than FPM's request-scoped connections. It moves SQ-7 in the wrong direction while buying performance the system does not need.

Octane also introduces a class of state-leak bug — singletons and static properties surviving between requests — that a solo operator would be debugging alone. Larastan can help (`checkOctaneCompatibility` is one of its parameters `[MEASURED: larastan/larastan 3.x configuration docs via Context7 @ 2026-08-21]`), but needing a static-analysis rule to make a performance package safe is itself an argument against adopting the package at this size.

### 6.4 PD-16 — `soloterm/solo` cannot be installed, and core replaced it {#pd-16}

**Two independent disqualifications, either of which would be sufficient.**

*It does not support Laravel 13.* Latest stable is **v0.5.0, released 21 March 2025** — seventeen months before the observation date — and it declares `illuminate/support: ^10|^11|^12`, `illuminate/console: ^10|^11|^12`, `illuminate/process: ^10|^11|^12` `[MEASURED: repo.packagist.org/p2/soloterm/solo.json @ 2026-08-21]`. On `laravel/framework ^13.17` `[E]` Composer will refuse to resolve it. It also requires `ext-pcntl` and `ext-posix`, which excludes Windows.

*Laravel 13 ships the same capability in core.* **`php artisan dev` is a multiplexed TUI process runner.** `[MEASURED: `php artisan dev --help` in apps/web @ 2026-08-21 — "Run the dev processes", with `--stream`, `--tabs`, `--inline`, `--timestamps`, `--no-restart`, `--json`, `--buffer-size` and `--stream-buffer-size` options; implemented in `Illuminate\Foundation\DevCommand`, `DevCommands`, `DevCommandMode` and `DevCommandColor`]`. That is tabbed output, per-process buffers, auto-restart on crash and a JSON event stream — the feature set Solo existed to provide.

The repository is already wired to it: `composer dev` runs `@php artisan dev` `[E: apps/web/composer.json]`, `just dev` calls `composer dev` `[E: justfile]`, and `@laravel/multiplex` sits in `optionalDependencies` `[E: apps/web/package.json]`.

**This is the cleanest example in the chapter of a package made redundant by Laravel 13 core** — and the redundancy is already installed and already the documented workflow.

### 6.5 PD-17 — `barryvdh/laravel-ide-helper`, and what actually supersedes it {#pd-17}

v3.7.0, 2026-03-17, MIT, Barry vd. Heuvel, `^11.15 || ^12 || ^13.0`. It is maintained and it does support Laravel 13; the objection is redundancy.

**The brief asks whether Boost or Pao supersede it. They do not, and it is worth being precise about why, because the two packages are frequently mistaken for something they are not.** `[MEASURED: composer.json `description` fields in apps/web/vendor @ 2026-08-21]`:

- `laravel/pao` — *"Agent-optimized output for PHP testing tools."* It reformats test output for AI agents. It has nothing to do with type hints.
- `laravel/boost` — *"Laravel Boost accelerates AI-assisted development by providing the essential context and structure that AI needs to generate high-quality, Laravel-specific code."* It is an MCP server exposing `search-docs`, `database-schema`, `database-query` and similar tools `[E: apps/web/AGENTS.md, boost rules]`. It gives an *agent* schema knowledge at conversation time. It does not emit docblocks, and it does nothing for PHPStan or for IDE autocomplete when no agent is involved.

**What actually supersedes IDE Helper here is Larastan, which the project already runs at level 7 `[E: apps/web/phpstan.neon]`.** Larastan derives Eloquent model property types by reading your migrations directly. Its source tree contains `Properties/ModelPropertyExtension.php`, `Properties/ModelPropertyHelper.php`, `Properties/ModelRelationsExtension.php`, `Properties/ModelAccessorExtension.php`, `Properties/MigrationHelper.php`, `Properties/SchemaAggregator.php`, `Properties/SchemaColumn.php` and `Properties/SquashedMigrationHelper.php` `[MEASURED: `ls apps/web/vendor/larastan/larastan/src/Properties/` @ 2026-08-21]`, and its own documentation describes `ModelPropertyHelper` as *"the core mechanism for inferring Eloquent model properties within Larastan … by analyzing database migrations, model casts, and computed property definitions"* `[MEASURED: larastan/larastan 3.x autodocs via Context7 @ 2026-08-21]`.

That is the same information `_ide_helper_models.php` exists to write down, obtained without a generated file to keep in sync — and a generated file that can drift is precisely the failure mode PD-2 exists to guard against elsewhere. Adding IDE Helper would introduce a second such artefact to solve a problem the static analyser has already solved.

**A concrete recommendation instead of the package.** Turn on Larastan's model-property checking once real models exist:

```neon
parameters:
    checkModelProperties: true
    databaseMigrationsPath:
        - database/migrations
```

`[MEASURED: larastan/larastan 3.x autodocs via Context7 @ 2026-08-21]`. It currently defaults to `false` `[MEASURED: `apps/web/vendor/larastan/larastan/extension.neon` @ 2026-08-21]`. This upgrades level 7 from "understands your models" to "fails when you reference a column that no migration creates" — a genuine gate, and one that fits the drift-check philosophy the rest of this chapter argues for.

**The residual gap, stated honestly.** IDE Helper's `_ide_helper.php` also documents facade methods for editors that do not run PHPStan. If the operator's editor autocomplete for facades is poor, that is a real inconvenience the above does not fix. It is an editor-configuration problem, not an architecture problem, and it should not put a generated file into the repository.

### 6.6 PD-18 — first-party packages that solve absent problems {#pd-18}

Each of these is well-made, first-party and Laravel 13 compatible. Each is declined because the problem is absent, not because the package is deficient.

| Package | Version / date | Why not here |
|---|---|---|
| `laravel/reverb` | v1.11.1, 2026-08-06 | A WebSocket server for realtime broadcasting. It runs as a **persistent process** and pulls `react/socket`, `ratchet/rfc6455`, `pusher/pusher-php-server` and `clue/redis-react` `[MEASURED @ 2026-08-21]`. There is no realtime requirement: one scrape run per day, one human, no collaborative editing, no live feed. Inertia's polling and `router.reload()` cover "the data changed" at this cadence. **Trigger:** a second concurrent user who must see another's changes without a refresh — i.e. OQ-6 answered *yes*, plus a collaboration requirement on top |
| `laravel/cashier` | v16.7.0, 2026-08-05 | Stripe billing; requires `stripe/stripe-php` and `moneyphp/money` `[MEASURED @ 2026-08-21]`. Nothing in the schema chapters or `01-stack.md` describes charging anyone for anything. **Trigger:** the product is sold to a second agent |
| `laravel/folio` | v1.2.0, 2026-08-13 | Filesystem-based **page routing for Blade**; requires `illuminate/view` `[MEASURED @ 2026-08-21]`. SD-5 puts pages in `resources/js/pages` as Svelte components rendered through `Inertia::render()` `[E: apps/web/AGENTS.md]`. Folio routes to Blade views this application does not have |
| `livewire/volt` | v1.11.2, 2026-07-31 | **Requires `livewire/livewire ^3.6.1\|^4.0`** `[MEASURED @ 2026-08-21]`. Livewire is the server-rendered-component alternative *to* Inertia. Adopting it means running two competing frontend paradigms. Directly contrary to SD-5 |
| `laravel/pennant` | v1.26.0, 2026-08-13 | Feature flags. Their value is decoupling deploy from release across an audience — a team shipping to many users. One operator who deploys and uses the application can achieve the same with a branch, or by not merging. **Trigger:** the public feed of SD-6 ships, where "on for me, off for the public" becomes a real distinction |
| `laravel/nightwatch` | v1.28.7, 2026-08-13 | The client agent for **Laravel's hosted monitoring SaaS** — the site offers "Start for free" and "Contact sales" `[MEASURED: nightwatch.laravel.com @ 2026-08-21]`. Application performance monitoring is for systems whose failures you learn about from users. This one has one user, who is the operator. `laravel/pail` `[E]` plus the logs cover it. **Trigger:** the SD-6 public feed, plus a real uptime obligation. `[UNVERIFIED: pricing — the pricing page was not read, so no cost claim is made here]` |
| `laravel/envoy` | v2.12.2, 2026-04-01 | Task runner for **remote servers over SSH**. There are no remote servers: `01-stack.md` §1 puts hosting explicitly out of scope, and the local task runner slot is filled by `justfile` `[E]`. **Trigger:** a deployment target exists and its steps outgrow a shell script |
| Forge / Vapor / Cloud | — | Hosting products, not packages. Out of scope per `01-stack.md` §1, which states hosting and deployment topology are undecided. Worth noting only that **Vapor is serverless and structurally incompatible with SD-4** — a local SQLite file has no meaning on ephemeral Lambda storage. Forge (a VPS) and Cloud both can host a persistent file, so neither conflicts with SD-4 in principle. `[UNVERIFIED: Cloud's persistent-volume and SQLite story was not verified against primary sources]` |

### 6.7 PD-19 — Spatie packages the schema or the shape already answers {#pd-19}

All are healthy, Laravel 13 compatible and MIT (§3.2). The objections are about fit.

| Package | Why not here |
|---|---|
| `spatie/laravel-permission` | Roles and permissions for **many users with differing access**. `01-stack.md` describes a *sole operator* and calls the workspace "single-tenant-ish"; OQ-6 — *"Will a second agent ever use this database?"* — is open and is described in `07-decisions.md` as **the most expensive item on that list**. Adding a roles-and-permissions model before OQ-6 is answered builds an authorisation structure for a population that does not exist. It also adds four tables and two pivots to a seven-table schema. **Trigger: OQ-6 answered *yes*** — and note that `07-decisions.md` records OQ-6 gaining *"a second deadline"* in its v1.1.2 changelog: because the Svelte starter kit can be generated with team support and *"that choice is made at `laravel new` time and is disruptive to add later,"* the question *"now wants an answer before the first scaffold, not merely before the tables fill."* **That deadline has arguably already passed** — `apps/web` exists `[E]` — which makes this a question to close deliberately rather than a package to install. Laravel's core Gates and Policies cover the single-operator case completely |
| `spatie/laravel-activitylog` | **`06-operations.md` §14.1 already decided this, explicitly and by name:** *"there is no `created_by` / `updated_by` because there is exactly one actor, and **there is no `audit_log` table** because the generic after-trigger that would populate it needs triggers, which this engine gates as experimental."* It goes further and names the replacement — *"`interactions` is the de-facto business audit log … it should be append-only"* — and sets the depth deliberately: *"Layer 1 of doctrine §8's five — row provenance only, and that is the right depth for a single-operator tool."* **One half of that reasoning has expired and one has not.** SD-4 moves the engine to stock SQLite, where triggers are no longer experimental, so the *mechanism* objection is gone. The *"exactly one actor"* objection is untouched and is the load-bearing one. Two further objections of this chapter's own. First, it writes an `activity_log` row **per tracked change**, which against a nightly batch of ~105 upserts roughly doubles the write volume into a single-writer SQLite file — the exact pressure SQ-7 watches. Second, provenance for scraped data is a *schema* concern that the database chapters own, and duplicating it in a generic log means two answers to "where did this value come from". **Trigger:** a compliance or dispute requirement that needs "who changed this and when" for operator-entered data specifically — and even then, scope it to the contact/property book, never to the ingest path |
| `spatie/laravel-settings` | Typed, persisted application settings backed by a table. For a single operator, `config/` files plus `.env` cover every setting that is not *user*-editable, and Laravel already treats those as first-class. This package earns its place when non-technical users must change behaviour without a deploy. **Trigger:** a settings screen appears in the UI |
| `spatie/laravel-sluggable` | Auto-generated URL slugs. Slugs matter for **public, shareable, SEO-relevant URLs**. The workspace is a private tool behind Fortify auth, where `/properties/{id}` is entirely adequate. **Trigger: SD-6 fires** — the public feed is exactly when a human-readable URL starts earning its keep. Until then this is a uniqueness constraint and a collision-suffix strategy added for nobody |
| `spatie/laravel-tags` | Polymorphic tagging with a `tags` and `taggables` table. **The schema chapters have already ruled on this exact shape and ruled against it.** The nearest thing to a tag in the schema is `properties.facilities`, and `03-entities.md` §6 stores it as a JSON array guarded by `CHECK (facilities IS NULL OR json_valid(facilities))`, rejecting the alternative in terms that apply verbatim to this package: *"a `facilities` lookup table plus a `property_facilities` join table buys referential integrity over a vocabulary **we do not control and cannot validate**, and costs a join on every listing read plus a normalisation step that will silently drop any facility the portal invents next month."* Separately, `02-access-patterns.md` §4 rules on the closed sets: enumerations are `TEXT CHECK (c IN (...))` and *"all six V1 enums already do this. **Do not promote to lookup tables until a value needs attributes.**"* So both halves of the tagging space — open vocabulary and closed vocabulary — already have a decided, different answer. **Trigger:** a tag value needs *attributes* of its own (a colour, a description, an ordering), which is the condition §4 itself names |
| `spatie/laravel-query-builder` | Turns query-string parameters into filters, sorts and includes — `?filter[state]=sold&sort=-price&include=agent`. Its value is a **public or client-consumed REST API** where an unknown client composes queries. Under SD-5 the workspace has no such API: Inertia controllers receive typed request objects and build queries in PHP, and `01-stack.md` §7 says *"no REST API is hand-built for the workspace's own screens."* The package would add a parameter-parsing layer between a controller and a query that the same controller already fully controls — and every filterable field must be allow-listed by hand anyway, so it does not even save the enumeration. **Trigger:** the SD-6 public feed grows a JSON API with third-party clients |

### 6.8 PD-20 — DX tooling that duplicates a gate already in place {#pd-20}

| Package | Duplicates | Verdict |
|---|---|---|
| `nunomaduro/phpinsights` | Pint (style) + Larastan (analysis) | Declined. It bundles style, complexity and architecture scoring into a single percentage. The project already has **stricter, more specific** gates: Pint with 30+ explicit rules `[E: apps/web/pint.json]` and Larastan at level 7 `[E]`. A composite score that can be gamed by a threshold is a weaker signal than a gate that either passes or fails, and running both means two tools disagreeing about the same file |
| `infection/infection` | `pestphp/pest-plugin-mutate`, already bundled | Declined. Infection is the older, more configurable engine and is **BSD-3-Clause**, the only non-MIT candidate in this chapter `[MEASURED @ 2026-08-21]`. Since Pest 5 already ships a mutation plugin as a hard require (§4.3), adding Infection means a second mutation engine and a second configuration file for one capability |
| `tomasvotruba/type-coverage` | `pestphp/pest-plugin-type-coverage`, installed | Declined. The repository already enforces **100% type coverage** through Pest `[E: `composer test:type-coverage` → `pest --type-coverage --min=100`]`. `tomasvotruba/type-coverage` is the PHPStan-extension route to the same metric. Two tools measuring one number, with the possibility of disagreeing about it, is worse than one |
| `spatie/laravel-ray` | Debugbar + Pail, both installed | Declined, with a caveat. Ray is an excellent debugging tool, but **the desktop application it sends to is commercial** — the free package is only the client half. `01-stack.md` weighs cost nowhere because nothing in the stack has any. The already-installed pair covers the ground: Debugbar for in-request inspection, `laravel/pail` for tailing logs including from the scheduler `[E]`. `[UNVERIFIED: current Ray desktop pricing was not checked against a primary source]` **Community signal, marked as opinion and carrying no decision weight:** Ray is widely liked among Laravel developers. That is not evidence of need |
| `pestphp/pest-plugin-stressless` | — (nothing; it is genuinely additive) | Declined on relevance, not duplication. It is a load-testing plugin wrapping k6. `01-stack.md` §3.3 rules performance arguments out of order at ~105 writes/day, and load-testing a single-user tool measures a number nobody will act on. **Trigger: SD-6 fires** and AP-05 becomes, in its own provenance note, *"the hottest path in the system"* at 5k/day. That is the first moment a load test would tell anyone anything |
| `dedoc/scramble` | The PD-1 unit | Declined **as the SQ-5 answer**, though it is healthy (v0.13.41, 2026-08-14, MIT). SQ-5 names it as an alternative — *"Spatie's typescript-transformer, or Scramble for an OpenAPI surface."* Scramble generates OpenAPI from controllers, which then needs a second step to reach TypeScript. Under SD-5 there is no REST API for the workspace's screens, so Scramble would be documenting an API that mostly does not exist, and the OpenAPI document would be an intermediate artefact whose only consumer is a type generator. The transformer route is one step where Scramble is two. **Trigger:** the SD-6 public feed ships a real JSON API that third parties consume — at that point OpenAPI is worth having *for its own sake*, and the calculus changes |
| `phpstan/*` extensions | Larastan | Declined by default. Larastan already bundles the Laravel extension, and `phpstan.neon` also includes `nesbot/carbon/extension.neon` `[E]`. Generic strict-rules packages (`phpstan/phpstan-strict-rules`, `phpstan/phpstan-deprecation-rules`) are the only ones worth considering, and the cheaper first move is **raising Larastan from level 7 to 8 or `max`**, which costs one line and no dependency. Do that before adding extensions |

---

## 7. What Laravel 13 core already covers {#core}

The brief asks specifically what Laravel 13 made redundant. Verified against the official release notes `[MEASURED: laravel.com/docs/13.x/releases @ 2026-08-21]`.

### 7.1 What is actually new in Laravel 13

Laravel 13 was released **17 March 2026**, requires **PHP 8.3** minimum, and is described in its own release notes as *"a relatively minor upgrade in terms of effort, while still delivering substantial new capabilities"* — the cycle explicitly prioritised minimising breaking changes.

| Feature | What it is | Bearing on this project |
|---|---|---|
| **Laravel AI SDK** | First-party unified API for text generation, tool-calling agents, embeddings, audio, images and vector stores | **Potentially significant, and not on the brief's list.** SD-8 puts AI/ML in Python as a separate service, and SQ-3 rules it holds no database credentials. The AI SDK does not overturn that — but if the AI work turns out to be "call a model and store the answer" rather than local Ollama inference, this is a first-party path that avoids a second service entirely. Worth a look when the AI/ML scope firms up; **it does not currently conflict with SD-8 because SD-8 has not been implemented** |
| **JSON:API resources** | Spec-compliant serialisation, sparse fieldsets, relationship inclusion | Not applicable. Inertia props are plain arrays; there is no JSON:API client |
| **`PreventRequestForgery`** | Origin-aware CSRF middleware, formalised | Free improvement, already active via the framework |
| **Queue routing** | `Queue::route(Job::class, connection:, queue:)` for central routing rules | Marginal at one job per day, but it is the kind of thing that keeps a growing job set tidy without a package |
| **Expanded PHP attributes** | `#[Middleware]`, `#[Authorize]`, `#[Tries]`, `#[Backoff]`, `#[Timeout]`, `#[FailOnTimeout]`, plus more across Eloquent, events, notifications, validation and testing | **Genuinely reduces package pull.** `#[Tries]`/`#[Backoff]`/`#[Timeout]` on a job class cover the retry-and-backoff need that §8 of `01-stack.md` floats Horizon for — declaratively, in core, with no Redis |
| **`Cache::touch()`** | Extend a cache item's TTL without read-and-rewrite | Minor convenience |
| **Semantic / vector search** | `whereVectorSimilarTo()` on the query builder, plus embedding workflows | **Not available under SD-4.** The release notes tie it to *"PostgreSQL + `pgvector`"*. Recorded because it is a real reason someone might argue for Postgres later; it would be a §16.2-trigger conversation, not a package decision |

### 7.2 Packages made redundant, or already present

| Candidate | Status |
|---|---|
| `soloterm/solo` | **Redundant** — `php artisan dev` in core, and Solo cannot install on L13 (§6.4) |
| `pestphp/pest-plugin-arch` | **Already installed** — hard require of `pestphp/pest` ^5 (§4.3) |
| `pestphp/pest-plugin-mutate` | **Already installed** — hard require of `pestphp/pest` ^5 (§4.3) |
| `laravel/prompts` | **Already installed transitively** — `laravel/framework` requires `laravel/prompts: ^0.1.18\|^0.2.0\|^0.3.0` `[MEASURED @ 2026-08-21]`. Adding it to `composer.json` declares a dependency the framework already owns. Use it; do not require it |
| `roave/security-advisories` | **Largely covered** — `composer audit` ships in Composer 2.10.1 (§4.4) |
| `barryvdh/laravel-ide-helper` | **Redundant** — Larastan infers model properties from migrations (§6.5) |

### 7.3 Query and ORM ergonomics: does core cover it?

The brief asks whether Laravel 13 core covers what people used to reach for packages for. For this project's workload, **yes, comfortably** — and the reason is that the workload is small and the schema is fully specified.

Laravel's core query builder and Eloquent already provide: upserts (`upsert()`), which is precisely the nightly-batch operation; chunked and lazy iteration; explicit transactions (`DB::transaction()`), which §8's one-transaction rule requires; native enum casts, which pair directly with the `TEXT CHECK` enumerations; `whereRaw()` and `DB::statement()`, which are the escape hatch that makes `STRICT` tables and FTS5 possible in migrations; and eager-loading controls.

The historically package-shaped gaps — query-string filtering (`spatie/laravel-query-builder`, §6.7), model property type hints (§6.5), and DTOs (§4.1) — are, respectively, not needed, covered by Larastan, and the one genuine gap. That is the complete answer.

**The one core capability worth turning on that costs nothing:** Larastan's `checkModelProperties: true` (§6.5). It converts a whole class of would-be runtime errors — referencing a column that no migration creates — into CI failures, which is disproportionately valuable when there is no second developer to catch them in review.

### 7.4 An observation about the existing gates {#gates-observation}

Not a package recommendation, but it surfaced while auditing the toolchain and materially affects §4.3's advice about mutation testing.

**The 90% code-coverage gate is defined but not wired into any command that runs.** `composer test:coverage` exists and runs `pest --coverage --min=90` `[E: apps/web/composer.json]`. But the aggregate `composer test` script chains `test:lint`, `test:rector`, `test:spelling`, `test:types`, `test:type-coverage` and `test:unit` — and **not** `test:coverage` `[E]`. CI runs `composer ci:check`, which chains the three `pnpm` checks and `@test` `[E]`, and the workflow sets `coverage: none` on `shivammathur/setup-php` `[E: .github/workflows/tests.yml]`, so no coverage driver is even available to the runner.

The 100% *type*-coverage gate, by contrast, is fully wired and does run.

This may well be deliberate — coverage drivers are slow, and there is no domain code to cover yet. It is recorded here because the situation summary this chapter was commissioned against describes "90% code coverage gate" as an existing gate, and on the evidence it is currently a defined script rather than an enforced gate. **It should be resolved before mutation testing is considered** (§4.3), since mutation scores computed against uncollected coverage are meaningless.

---

## 8. The SQLite ceiling, in one place {#sqlite-ceiling}

Consolidated because it is the single most decision-relevant constraint in this chapter, and because it is easy to hit by accident.

| Capability | SQLite under SD-4 | Source |
|---|---|---|
| Foreign keys | **Yes, on by default.** *"Foreign key constraints are enabled by default for SQLite connections but can be disabled via environment settings"* (`DB_FOREIGN_KEYS`) | laravel.com/docs/13.x/database `[MEASURED @ 2026-08-21]` |
| `fullText()` index in migrations | **No.** MariaDB, MySQL, PostgreSQL only | laravel.com/docs/13.x/search `[MEASURED @ 2026-08-21]` |
| `whereFullText()` | **No.** MariaDB, MySQL, PostgreSQL only | laravel.com/docs/13.x/queries `[MEASURED @ 2026-08-21]` |
| `whereVectorSimilarTo()` (new in 13) | **No.** PostgreSQL + `pgvector` | laravel.com/docs/13.x/releases `[MEASURED @ 2026-08-21]` |
| Scout `database` engine | **No.** MySQL or PostgreSQL | laravel.com/docs/13.x/scout `[MEASURED @ 2026-08-21]` |
| Scout `collection` engine | **Yes**, explicitly including SQLite — but "a few hundred records" and filters in PHP | laravel.com/docs/13.x/scout `[MEASURED @ 2026-08-21]` |
| Pulse storage | **No.** MySQL, MariaDB or PostgreSQL required | laravel.com/docs/13.x/pulse `[MEASURED @ 2026-08-21]` |
| Horizon | **No** — requires Redis, independent of the database engine | laravel.com/docs/13.x/horizon `[MEASURED @ 2026-08-21]` |
| Telescope storage | **Yes** — ordinary migrations | laravel.com/docs/13.x/telescope `[MEASURED @ 2026-08-21]` |
| `spatie/laravel-backup` | **Yes** — *"MySQL, PostgreSQL, SQLite and Mongo databases are supported"* | spatie.be/docs/laravel-backup/v10 `[MEASURED @ 2026-08-21]` |
| SQLite FTS5 | **Yes, via raw SQL.** No credible package wrapper exists (§5.6) | packagist.org search `[MEASURED @ 2026-08-21]` |

**The pattern is worth stating plainly, because it will recur every time a new package is considered.** SD-4 costs this project nothing on the *data* — the schema is seven tables and 6 MB at twelve months, and SQLite is more than equal to it. What SD-4 costs is access to the **ecosystem's search and observability tier**, because those components were built against MySQL and PostgreSQL and, in Pulse's case, say so in the first line of their installation instructions.

That is a fair trade at this size and it does not reopen SD-4. It does mean that the answer to "should we add \<popular Laravel package\>" should start by checking its database requirements, not its stars.

---

## 9. The Python ↔ Laravel boundary {#boundary}

### 9.1 Who writes to the database today — and why the brief's premise is already obsolete

`[MEASURED: docs/database/01-current-state.md §2, DATABASE_SCHEMA.md, 06-operations.md §17 @ 2026-08-21]`

The live file `listings.db` sits at the repository root and carries a **V0** shape: one table, `listings`, 39 columns, **0 rows**. The V1 schema — `contacts`, `properties`, `property_sources`, `contact_properties`, `interactions`, `price_history`, `scrape_runs`, plus the `follow_up_inbox` view — is declared in `apps/scraper/src/pw/db/schema.sql` and is deployed **nowhere**. `DATABASE_SCHEMA.md` states the position bluntly: *"the live database and the repo schema have no table in common … **Zero overlap**."*

The only current write path is **n8n**, over Turso Cloud's HTTP `/v2/pipeline` API. `01-current-state.md` describes the deployment shape as inherently multi-process: *"the n8n container, a future `pw-api` (FastAPI/uvicorn), an APScheduler process, and the test suite."*

**So the premise that "the scraper writes to the same SQLite file" is neither the current state nor the intended one, and this matters for every package judgement below.** Three decided rulings converge on the opposite shape:

- **SQ-6** puts the scraper on Python **posting to the Laravel API**, not touching the file.
- **SQ-3** rules the Python side *"holds no database credentials and owns no domain logic."*
- **M6** — *"Retarget n8n writes at a single writer — either `pw-api` or the V1 tables directly"* — and `06-operations.md` marks it **"this is the last abort-safe moment."**

Under SD-4 plus `01-stack.md` §6.4's order B, the intended end state is therefore: **Python fetches and parses; Laravel is the only process that opens the file.** Every recommendation in this chapter is priced on that shape, and §9.4's rule exists to keep it true.

### 9.2 The four pragmas — and the three-line change that satisfies SQ-7 {#pragmas}

`06-operations.md` §16.1 rules that connection pooling is *"not applicable"* to an embedded engine and names what replaces it: *"`PRAGMA journal_mode=WAL` (already set on the live file `[MEASURED: PRAGMA journal_mode → wal @ 2026-08-06]`), `PRAGMA synchronous=NORMAL`, `PRAGMA busy_timeout=5000`, and **`PRAGMA foreign_keys=ON` on every connection** (IG-7)."* **M3** turns the same four into a migration step. **IG-7** is called *"the highest-severity item in this table,"* with the failure mode spelled out: *"Every `ON DELETE CASCADE` and `SET NULL` in §7.1 silently does nothing … the schema's referential guarantees are fiction."*

**Laravel 13 has a first-class configuration key for every one of the four, and ships three of them switched off.** `[MEASURED: `apps/web/config/database.php` and `vendor/laravel/framework/src/Illuminate/Database/Connectors/SQLiteConnector.php` @ 2026-08-21]`

| Key in `config/database.php` | Shipped default `[E]` | Connector behaviour | What the database chapters require |
|---|---|---|---|
| `foreign_key_constraints` | `env('DB_FOREIGN_KEYS', true)` | Always issues `pragma foreign_keys = …` | `ON` — **already satisfied** |
| `busy_timeout` | `null` | `if (! isset(...)) return;` — **no pragma issued** | `5000` |
| `journal_mode` | `null` | `if (! isset(...)) return;` — **no pragma issued** | `WAL` |
| `synchronous` | `null` | `if (! isset(...)) return;` — **no pragma issued** | `NORMAL` |
| `transaction_mode` | `'DEFERRED'` | `BEGIN {$mode} TRANSACTION` on PHP 8.4+ | see below |

This is the single most actionable finding in the chapter, and it costs three lines.

`01-stack.md` SQ-7 instructs: *"Set `busy_timeout` and WAL explicitly on every connection rather than relying on defaults."* Laravel's connector applies these pragmas on **every** connection it opens, which is exactly the per-connection guarantee IG-7 demands and which `schema.sql` — setting `foreign_keys` *"at the top of the script,"* covering *"the connection that applies the schema and no other"* — conspicuously fails to give. So SQ-7's instruction is not a discipline to be remembered; it is a config block:

```php
'sqlite' => [
    // …
    'foreign_key_constraints' => env('DB_FOREIGN_KEYS', true),  // already correct
    'busy_timeout' => 5000,        // was null — no pragma was issued at all
    'journal_mode' => 'WAL',       // was null — do not assume the file is in WAL
    'synchronous' => 'NORMAL',     // was null
    'transaction_mode' => 'IMMEDIATE',
],
```

**On `transaction_mode`, which is the one judgement call in that block.** Laravel emits `BEGIN {$mode} TRANSACTION` using this value on PHP 8.4 and above `[MEASURED: `Illuminate\Database\SQLiteConnection::executeBeginTransactionStatement` @ 2026-08-21]`, and the repository requires PHP `^8.4` `[E]`, so the path is live. `DEFERRED` — the shipped default — takes no write lock at `BEGIN` and instead upgrades on the first write. If any other connection holds the write lock at that moment, the upgrade cannot wait politely and surfaces as `SQLITE_BUSY`, which is precisely the *"intermittent, hard-to-reproduce error rather than a clean failure"* SQ-7 warns about. `IMMEDIATE` acquires the write lock at `BEGIN`, where `busy_timeout` **can** apply. For the ~105-upsert nightly batch that `02-access-patterns.md` §3 requires be wrapped in one transaction, `IMMEDIATE` is the mode that makes `busy_timeout` mean something. `[ASSUMED: that the daily batch is the only long transaction. If interactive request-scoped transactions become common, `IMMEDIATE` on all of them would serialise more than intended and the setting should be applied per-transaction instead.]`

**One caution about WAL that no package will warn about.** WAL mode is a property of the *database file*, persisted in its header, not a per-connection setting — so setting it here is idempotent rather than harmful. But it does mean the database is three files (`-wal` and `-shm` alongside it), which is a fact any backup approach must respect: copying only the main file mid-transaction yields a torn backup. This is a further argument for §5.4's `sqlite3 .backup` over `cp`, and a thing to verify if `spatie/laravel-backup` is ever adopted.

### 9.3 Migrations ownership {#migrations-ownership}

**Unambiguous, and already on record.** SD-3 makes Eloquent plus Laravel migrations the ruling for database access. SQ-4's blocking note states the current obstacle: *"`src/pw/db/schema.sql` is the only V1 DDL that exists anywhere,"* and the Python deletion is *"Unblocked by M1 … which ports the schema to Laravel migrations."*

**Laravel therefore owns the schema exclusively, and the Python side must neither create nor alter tables.** Two consequences worth stating:

1. **Laravel migrations already answer a Tier-0 roadmap table.** `DATABASE_SCHEMA.md` lists `schema_migrations` first in its suggested order, with the note *"nothing else is safe to ship without it."* Laravel's `migrations` table is that, shipped, tested and wired to `artisan migrate`. This is the clearest instance in the whole project of the batteries argument in `01-stack.md` §3.2 paying off, and it means the roadmap item is closed by SD-3 rather than by a `CREATE TABLE`.

2. **Every package that ships migrations adds tables to a file whose schema Laravel is meant to own end-to-end.** Telescope, Media Library, Permission, Activitylog, Settings and Tags all do. That is not an objection in itself — they are Laravel migrations too — but it is a reason to prefer fewer of them while M1 is outstanding and the Python side still carries the only V1 DDL.

**A related trap, flagged because it is a Laravel developer's reflex rather than a package.** `07-decisions.md` rejected alternative 7 is **soft delete on `properties`**, and `03-entities.md` §7.3 argues it at length: *"`status` is a **lifecycle** fact … A soft-delete marker is a **visibility** fact … Adding `deleted_at` to a table that already has `status` produces states with no defined meaning."* §14.3 adds the regulatory half — soft delete does not satisfy PDPA erasure, which must be a hard delete cascading from `contacts`. **Laravel's `SoftDeletes` trait must not be used on the domain models.** No package recommends it; the framework simply makes it one `use` statement away, and it would silently contradict a decided rejection. This belongs in an arch test (§4.3).

### 9.4 The rule this chapter adds {#second-writer-rule}

**Any package that writes to the database from a process other than the one handling the nightly batch is a second writer, and must be evaluated against SQ-7 and M6 before it is evaluated on its merits.**

`02-access-patterns.md` §3 states the current position — *"Single writer, no contention — the SQLite concurrency ceiling is not remotely in play"* — and that is a property of the design, not of SQLite. It holds only while nothing else writes.

| Package / feature | Write pressure it adds | Ruling |
|---|---|---|
| `laravel/octane` | N resident workers with warm connections, permanently | **Declined** (§6.3) — strictly worse than PHP-FPM on the one dimension SQ-7 watches |
| `laravel/telescope` | One row per recorded event, including during the batch | **Local only, or a separate SQLite file** (§5.2) |
| `spatie/laravel-activitylog` | One row per tracked model change — roughly doubles nightly write volume | **Declined** (§6.7); if ever adopted, exclude the ingest path |
| `spatie/laravel-medialibrary` | Queued conversion jobs, i.e. worker processes writing | **Deferred** (§5.5); run conversions synchronously if adopted |
| `database` queue driver (core) | Job reserve/release/delete cycles from every worker | Fine for one nightly job; **re-evaluate before any second queued workload**. This is the entanglement noted in §6.2 |
| `database` cache / session drivers (core) | Session, cache **and** queue writes into the same file | **Already true, and it was not a decision anyone took** — see the finding immediately below |

**The starter kit has already installed three extra writers into the domain database, by default.** `[MEASURED: `apps/web/.env.example`, `config/session.php`, `config/cache.php`, `config/queue.php` @ 2026-08-21]`

```
DB_CONNECTION=sqlite
SESSION_DRIVER=database      # config/session.php: env('SESSION_DRIVER', 'database')
CACHE_STORE=database         # config/cache.php:   env('CACHE_STORE', 'database')
QUEUE_CONNECTION=database    # config/queue.php:   env('QUEUE_CONNECTION', 'database')
```

All three resolve to the **same connection as the domain tables**, which under SD-4 is the same local SQLite file. So the framework writes a `sessions` row on essentially every authenticated request, a `cache` row whenever anything is cached, and `jobs` rows for every dispatch — **into the file that `02-access-patterns.md` §3 describes as having a "single writer, no contention."**

**This does not invalidate that description, but it does sharpen what SQ-7 is really about.** The claim that survives is *no concurrent writers to the **domain** tables*. The literal claim — one process ever writing the file — is already false, and would have been discovered the hard way as an occasional `SQLITE_BUSY` during a nightly batch that overlaps a page load. It is also the strongest practical argument for PD-22: with `busy_timeout` unset, those housekeeping writes have **no wait at all** and fail immediately on contention.

**Two mitigations, in ascending order of effort, neither of which is a package.**

1. **`CACHE_STORE=file` and `SESSION_DRIVER=file`.** At one user this loses nothing — file sessions and file cache are entirely adequate — and it removes two of the three write streams from the domain file outright. This is the recommended default here.
2. **A second SQLite file for framework housekeeping**, via a separate connection in `config/database.php` with `'connection' => …` set on the cache, session and queue configs. More faithful to Laravel's model, and the right answer if the queue is ever genuinely used, since `jobs` and `failed_jobs` genuinely want a database.

Either way, **do it before M3 creates the fresh database file**, not after — M3 is the moment the file is made, and deciding what lives in it is cheapest then. `[ASSUMED: that no domain code will want transactional consistency between a cache entry and a domain row. If it does, mitigation 2 is required rather than optional, since cross-database transactions are not available.]`

**Nothing in tier 1 touches the database at all.** `spatie/laravel-data` and the two transformer packages ship no migrations, add no tables, open no connections and run no background processes. PD-4 and PD-2 are CI-only. That is not a coincidence — it is most of why they are the three that made tier 1, and it is the reason tier 1 can be adopted before M1 lands without prejudicing anything.

## 10. Adoption order and effort {#adoption}

| Order | Item | Effort | Why here |
|---|---|---|---|
| **1** | SQLite pragmas in `config/database.php` (PD-22) | **~5 min** | **Do this first.** Three lines. It is what SQ-7 instructs, it closes the gap `06-operations.md` §16.1 and M3 both specify, and it is currently unset — `busy_timeout`, `journal_mode` and `synchronous` all ship as `null`, so no pragma is issued. Costs nothing and prevents the one failure mode SQ-7 calls hard to reproduce |
| **2** | `CACHE_STORE=file`, `SESSION_DRIVER=file` (PD-23) | **~5 min** | Removes two of the three unchosen writers from the domain file. **Must land before M3 creates the fresh database**, which is the cheapest moment to decide what lives in it |
| **3** | `composer audit --locked` in CI (PD-4) | **~15 min** | One line, no dependency. Next because it is the only remaining item with no design decision attached |
| **4** | Larastan `checkModelProperties: true` (§6.5) | **~15 min**, once the first migration exists | One config block. Must come *after* M1 lands a migration, or there is nothing to infer from |
| **5** | Resolve the coverage-gate question (§7.4) | **~30 min** | Either wire `test:coverage` into `test` and give CI a coverage driver, or delete the script. A gate that exists but does not run is worse than no gate, because it is believed |
| **6** | PD-1 + PD-2 together — `laravel-data` + transformer + drift check | **~half a day** for the install, config, first data object and CI step; then ongoing convention | The tier-1 item. Do it **before the first domain screen ships**, which is also what SQ-5 says. Adopting it after there are Svelte components with hand-written types means a migration instead of a convention |
| **7** | Pest arch tests (PD-3) | **~1–2 hours**, once `app/` has real structure | Nothing to install. Write the single-writer invariant test first — it is the one guarding SQ-7 |
| **8** | Machine auth for the ingest endpoint (PD-7) | **~1 hour** shared secret, **~half a day** Sanctum | Driven by SQ-1's order-B sequencing, not by this chapter. Whichever is chosen, record it |

Everything below order 8 is tier 2 and waits for its trigger.

**A deliberate omission: nothing here is urgent.** The largest risk this chapter identified is not a missing package — it is SQ-5's data-shape drift, and item 6 addresses it at the cheapest possible moment, which is now, before the first screen. The items that are *urgent in proportion to their cost* are 1, 2 and 5: ten minutes of configuration that satisfies a standing instruction from SQ-7 and removes two unchosen writers from the domain file, and half an hour that turns a believed gate into a real one. Nothing here becomes cheaper by waiting.

---

## 11. Install this today {#install}

Tier 1 only. Run from `apps/web`.

```shell
# PD-1 — the data-shape half of SQ-5. Three packages, one unit.
composer require spatie/laravel-data spatie/laravel-typescript-transformer

# spatie/typescript-transformer arrives as a dependency of the Laravel binding;
# it does not need to be required separately.

php artisan vendor:publish --provider="Spatie\LaravelData\LaravelDataServiceProvider" --tag=data-config
php artisan vendor:publish --provider="Spatie\LaravelTypeScriptTransformer\TypeScriptTransformerServiceProvider" --tag=typescript-transformer-config

# Then, in config/typescript-transformer.php, register DataTypeScriptCollector
# BEFORE DefaultCollector — the order is load-bearing.

# Generate:
php artisan typescript:transform
```

```shell
# PD-3 — nothing to install. Both plugins are already hard requires of
# pestphp/pest ^5. Verify, then write the tests:
composer show pestphp/pest | grep -A2 requires
php artisan make:test --pest ArchitectureTest
```

```shell
# PD-4 — no dependency. Add to .github/workflows/tests.yml, web job:
composer audit --locked
```

**PD-22 has no install command either** — it is an edit to the `sqlite` block of `config/database.php`, replacing three `null`s. See §9.2 for the reasoning on each value, and in particular for why `transaction_mode` is the one line in the block that is a judgement rather than a transcription:

```php
'sqlite' => [
    // …
    'busy_timeout' => 5000,
    'journal_mode' => 'WAL',
    'synchronous' => 'NORMAL',
    'transaction_mode' => 'IMMEDIATE',
],
```

**PD-2 (the drift check) has no install command** — it is a CI step. Add to the `web` job of `.github/workflows/tests.yml`, after `composer setup`:

```yaml
      - name: Check generated TypeScript is current
        run: |
          php artisan typescript:transform
          git diff --exit-code -- resources/js/types/
```

Adjust the path to match whatever `config/typescript-transformer.php` is configured to write. **Commit this in the same change as PD-1**, per §4.2.

---

## 12. Conflicts with `01-stack.md` {#conflicts}

Recorded explicitly rather than buried, per the standing rule that a decided SD-\* is never silently overridden.

| Item | Conflicts with | Nature |
|---|---|---|
| `laravel/pulse` | **SD-4** (PDO SQLite, local file) | **Hard.** Pulse's storage requires MySQL, MariaDB or PostgreSQL. Adopting it means either a second database engine purely for telemetry, or overturning SD-4. Declined — §6.1 |
| `laravel/octane` | **SD-2** (PHP-FPM) and **SQ-7** | **Hard on SD-2, aggravating on SQ-7.** Octane replaces the FPM runtime and increases concurrent write pressure on a single-writer SQLite file. Declined — §6.3 |
| `laravel/horizon` | No SD-\* directly, but contradicts **§8**'s ruling | **Soft.** §8 states the scheduler alone is sufficient at one run per day. Horizon additionally requires Redis, a service the stack does not have. Declined — §6.2 |
| `livewire/volt` | **SD-5** (Inertia 3 + Svelte 5) | **Hard.** Volt requires Livewire, which is the competing paradigm to Inertia. Declined — §6.6 |
| `laravel/folio` | **SD-5** | **Hard.** Folio routes to Blade views; SD-5 puts pages in Svelte. Declined — §6.6 |
| Laravel Vapor | **SD-4** | **Hard.** Serverless has no persistent local file. Noted, not proposed — §6.6 |
| Scout `database` engine, `fullText()`, `whereVectorSimilarTo()` | **SD-4** | **Hard, and they are core features rather than packages.** Recorded in §8 so that a future "just use `whereFullText`" is caught at design time rather than at runtime |
| `spatie/laravel-permission` | **OQ-6** (open) | **Not a conflict — a sequencing dependency.** It cannot be sensibly evaluated until OQ-6 is answered, and `01-stack.md` §7 records that starter-kit teams is the cheaper first move if the answer is yes |

**No tier-1 recommendation conflicts with any SD-\*, and two of them implement standing instructions rather than adding anything.** PD-1 implements the mitigation §3.5 item 1 itself proposes (*"generate TypeScript types from PHP (Spatie's typescript-transformer …)"*), PD-2 implements what SQ-5 explicitly asks for, PD-3 installs nothing, PD-4 adds no dependency, and **PD-22 is simply SQ-7's own instruction — *"set `busy_timeout` and WAL explicitly on every connection rather than relying on defaults"* — carried out.** It also completes the application half of **M3** and of **IG-7**.

---

## 13. Rejected alternatives {#rejected}

Following the convention of `01-stack.md` §4 and §19 of the database chapters: approaches considered for the *tier-1 problem* — closing SQ-5's data-shape gap — and why each lost.

| # | Considered | Why it lost |
|---|---|---|
| 1 | **Do nothing; accept the cost as written** | `01-stack.md` §3.5 item 1 does list this as an *accepted* cost. But SQ-5 re-opened it with a named failure mode — a stale enum producing a wrong dropdown rather than an error — and named the moment to act: *"before the first screen ships."* That moment is now, and it does not recur cheaply |
| 2 | **`dedoc/scramble` for an OpenAPI surface** | Named as the alternative in SQ-5 itself, and healthy (v0.13.41, 2026-08-14). Lost because under SD-5 there is no REST API for the screens, so it would document an API that mostly does not exist, and OpenAPI would be an intermediate artefact whose sole consumer is a type generator. Two steps where the transformer is one. **Becomes the right answer if SD-6's public feed ships a real JSON API** |
| 3 | **Hand-written TypeScript types, maintained by discipline** | Rejected by `01-stack.md` §3.5 item 1's own logic in its stronger form: if *"a generation step that can be skipped will eventually be skipped"*, then a manual step with no generation at all is worse. Also the status quo, which is what SQ-5 objects to |
| 4 | **`spatie/typescript-transformer` alone, no `laravel-data`** | Did not lose outright — it is explicitly endorsed in §4.1 as the incremental path if appetite for `laravel-data` is low, because it covers the six `CHECK` enumerations, which SQ-5 says drift first. It is second choice only because per-shape DTOs give the generator a single artefact per shape rather than a scattering of Form Requests and API Resources |
| 5 | **`laravel-data` alone, no transformer** | The weakest combination. It buys DTO ergonomics — the smaller half of the value — while leaving the actual gap SQ-5 identifies wide open |
| 6 | **Generate TypeScript from the database schema directly** | Superficially attractive because the schema is the real source of truth and is fully specified. Lost because the `CHECK` constraint text would have to be parsed to recover the enumerations, and because it would bypass the application layer entirely — meaning any shape that is not one-table-one-type (which is most screens) is unrepresentable. Filed as `[UNVERIFIED]` in the sense that no tool for this was evaluated; it is rejected on design grounds, not on tooling |

---

## 14. Open questions {#open-questions}

1. **PQ-1 — Does `laravel-data` become the convention for *all* boundary shapes, or only for those crossing to TypeScript?** *In force:* undecided. Using it only where a Svelte component consumes the shape keeps the abstraction small but creates two conventions in one codebase; using it everywhere is consistent but heavier. *Blast radius:* moderate, and it grows with every controller written before the question is answered. *Who answers:* Vincent, at PD-1 adoption.

2. **PQ-2 — Is the 90% coverage gate intended to be enforced?** *In force:* it is defined but not run (§7.4). *Blast radius:* low today, since there is no domain code — but it is currently described as an existing gate in project summaries, which makes it a false belief rather than a missing feature. *Who answers:* Vincent, cheaply, before the first domain code lands.

3. **PQ-3 — Shared secret or Sanctum for the ingest endpoint?** *In force:* undecided; §5.3 leans shared secret at one client. *Blast radius:* low if recorded, moderate if not — a shared secret that silently acquires a second client is the wrong answer by then. *Who answers:* Vincent, when SQ-1's order-B endpoint is built.

4. **PQ-4 — Does the Laravel 13 AI SDK change SD-8?** *In force:* no; SD-8 stands and Python owns AI/ML. But SD-8 is unimplemented, and a first-party SDK that removes a service from the deployment is worth weighing before the Python AI layer is written rather than after. *Blast radius:* low now, moderate once Python AI code exists. *Who answers:* Vincent, when the AI/ML scope firms up.

5. **PQ-6 — Is `transaction_mode => 'IMMEDIATE'` right for every transaction, or only for the batch?** *In force:* `IMMEDIATE` is recommended in §9.2 because it is the mode under which `busy_timeout` can actually apply to the nightly batch. *Blast radius:* low, but it is a global setting applied to every transaction Laravel opens, and on a busy interactive path it would serialise more than intended. `[ASSUMED: the daily batch is the only long transaction.]` If that stops being true, move the mode to a per-transaction concern. *Who answers:* Vincent, if a second long-running write path appears.

6. **PQ-5 — If full-text search is needed, is hand-written FTS5 acceptable?** *In force:* it is the only credible option under SD-4 (§5.6). The question is whether the operator wants to own DDL and synchronising triggers, or would rather treat search as a trigger for revisiting §16.2. *Blast radius:* contained — FTS5 is additive and can be dropped without touching base tables. *Who answers:* Vincent, when a search requirement is actually specified.

---

## 15. Changelog {#changelog}

| Version | Date | Author | Change |
|---|---|---|---|
| **1.0.0** | 2026-08-21 | Vincent + Claude | Initial document. **The highest-value finding is PD-22 and it is not a package at all:** Laravel 13's `config/database.php` ships `busy_timeout`, `journal_mode` and `synchronous` as `null`, and `SQLiteConnector` issues no pragma when they are unset `[MEASURED @ 2026-08-21]` — so SQ-7's standing instruction to set WAL and `busy_timeout` on every connection, and M3's equivalent, are currently unmet and are three lines from being met. `foreign_key_constraints` already defaults to `true`, which closes IG-7 on the application path. **PD-23 records a second unchosen default:** `.env.example` ships `SESSION_DRIVER=database`, `CACHE_STORE=database` and `QUEUE_CONNECTION=database` `[E]`, all resolving to the domain SQLite file — so the *"single writer, no contention"* description in `02-access-patterns.md` §3 is true of the domain tables but not of the file, and was already not true before any package was considered. Classifies 40+ Laravel-ecosystem packages into three tiers against the workload defined by `01-stack.md` and the database chapters. **Tier 1 is `spatie/laravel-data` plus the two typescript-transformer packages as one unit (PD-1), its CI drift check (PD-2), Pest arch and mutation testing which are already installed (PD-3), and `composer audit` in CI (PD-4).** Records two hard incompatibilities with **SD-4**: `laravel/pulse` requires MySQL/MariaDB/PostgreSQL, and `laravel/octane` additionally conflicts with **SD-2** while aggravating **SQ-7**. Confirms `laravel/horizon` requires Redis unconditionally, which `01-stack.md` §8 had already made moot. Documents the SQLite ceiling in one table (§8): `fullText()`, `whereFullText()`, `whereVectorSimilarTo()` and Scout's `database` engine are all closed to SQLite, and no credible SQLite FTS5 package exists — hand-written FTS5 in a raw migration is the only production-grade route. Finds four candidates already absorbed by core or by installed dependencies: `pest-plugin-arch` and `pest-plugin-mutate` are hard requires of `pestphp/pest ^5`, `laravel/prompts` is a transitive dependency of the framework, and `soloterm/solo` is both un-installable on Laravel 13 (last release 2025-03-21, constraints top out at `^12`) and superseded by `php artisan dev`. Establishes that **Larastan, not Boost or Pao, is what supersedes `barryvdh/laravel-ide-helper`**, and recommends `checkModelProperties: true` in its place. Adds §9's rule that any package introducing a second writer must be evaluated against SQ-7 and M6 before it is evaluated on merit, and records that the brief's premise — the Python scraper writing the same SQLite file — is contradicted by SQ-3, SQ-6 and M6, which together put Laravel in sole possession of the file. Confirms from the database chapters that three Spatie candidates are answered by decisions already taken: **`laravel-activitylog`** by §14.1 (*"there is no `audit_log` table … exactly one actor"*, with `interactions` as the de-facto append-only log), **`laravel-tags`** by §6's ruling that `facilities` is a JSON array rather than a lookup-plus-join table and by §4's *"do not promote to lookup tables until a value needs attributes"*, and **`laravel-medialibrary`** by the absence of any media table plus OQ-13's PDPA object-before-row erasure ordering. Flags that Laravel's `SoftDeletes` trait must not be used, since `07-decisions.md` rejected alternative 7 and §7.3 argue soft delete out explicitly. Notes that Laravel's own `migrations` table closes the `schema_migrations` Tier-0 roadmap item that `DATABASE_SCHEMA.md` calls the one *"nothing else is safe to ship without"*. Corroborates §5.6 against `04-integrity.md` §9, which already names **FTS5** as the answer for substring search and records that `idx_contacts_name` cannot serve the infix `LIKE` an AP-15 search box sends. Notes in §7.4 that the 90% coverage gate is defined but not wired into any command CI runs. Opens PQ-1…PQ-5. |
