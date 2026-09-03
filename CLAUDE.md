# Travelog — Agent Instructions

This file defines repo-scope rules: what the app is, how work is routed across layers, how to run commands (everything goes through Docker), and which cross-layer contracts must move together. Detailed conventions for each layer live in nested instruction files — **a nested file is the source of truth for its own folder**, and this file keeps only what spans folders or has no folder.

## Nested instruction files

Read the one covering the folder you are editing. It overrides this file within its directory.

| File | Governs |
| --- | --- |
| `app/models/CLAUDE.md` | Data layer: shared vs owned facts, distance scopes, counters, how sharing is stored. |
| `app/services/CLAUDE.md` | Service objects: shape, the cost/quota surface, what earns a service at all. |
| `app/controllers/CLAUDE.md` | Request layer: the authorization gate, the one public route, locale resolution, Turbo Frames. |
| `app/views/CLAUDE.md` | Templates: private vs public partials, the i18n rules, Tailwind component-vs-utility. |
| `app/javascript/CLAUDE.md` | Stimulus: server-is-source-of-truth, the two Google keys, lifecycle cleanup. |

`app/helpers/` has no nested file — it is view-layer code and follows `app/views/CLAUDE.md`. Display strings belong there, never on a model.

## What this app is

A small internal web app for tracking places to eat, drink coffee, and visit — mostly in Hanoi. One person (or a few) records places they **want to go** (saved off TikTok/Facebook) and places they **have been**, grouped by multi-label tags. Every visit is its own record with the user's own photos. The app answers four questions: *what's near me right now*, *what have I not gone to yet in this area*, *what did I do in the last few months*, and *have I reviewed this place on Google yet*.

Deliberately **not** in scope: no native app, no SPA, no public discovery feed, no automated Google review posting (there is no API for it and automation violates Google's ToS — the app only deep-links and prepares content to paste).

**Stack:** Rails 8.1 MVC + Hotwire (Turbo/Stimulus), Postgres 17, Tailwind 4, Solid Queue/Cache/Cable, Devise, S3 + Lambda for images, Kamal 2 for deploy. Do not swap any of these.

**Language convention:** The UI ships in Vietnamese and English, with Vietnamese as the default and the source of truth for translations. Code, identifiers, table names, and commit messages are English. Existing business comments are written in Vietnamese — stay consistent with the file you are editing.

## Repo Map

| Module | Role |
| --- | --- |
| `app/models/` | Data layer. `Place` is objective and shared; `UserPlace` is one person's relationship to it. |
| `app/services/` | `Geo::RadiusQuery`, `Photos::ThumbnailUrl`, `Google::PlacesClient`, `Google::ReviewLink`. |
| `app/controllers/` | One controller per screen. `ApplicationController#scoped_places` is the only authorization gate. |
| `app/views/` | `shared/` renders private data; `public_collections/` has its own partials. |
| `app/helpers/` | Display strings and formatting. `status_label`, `distance_label`, `photo_image_tag`. |
| `app/javascript/controllers/` | Stimulus. No bundler — dependencies are pinned in `config/importmap.rb`. |
| `app/assets/tailwind/application.css` | The design system: `@theme` tokens + `@layer components`. The only source of colours, type scale, radii, shadows. |
| `config/locales/` | `vi.yml` (source of truth) and `en.yml`. Key trees must match exactly. |
| `lib/vietnamese.rb` | `slugify` / `strip_accents`. Rails' `parameterize` mangles Vietnamese — always use these. |
| `db/migrate/` | Migrations plus Postgres extensions (`cube`, `earthdistance`, `pg_trgm`, `unaccent`) and `immutable_unaccent`. |
| `db/structure.sql` | Primary schema, format `:sql`. **Never edit by hand** — regenerate via `db:migrate`. |
| `config/settings/{development,staging,production,test}.yml` | Per-environment configuration, one file per environment. Loaded in `config/application.rb` into `Rails.application.config.settings`. |
| `infra/lambda/` | Node 20 thumbnailer: S3 `ObjectCreated` → webp derivatives → HMAC-signed webhook back to Rails. |
| `infra/terraform/` | Two buckets, CORS, Lambda + trigger, IAM, CloudFront. **Written here, applied by a human.** |
| `test/` | Minitest + FactoryBot. Shared factories in `test/factories/places.rb`. |
| `infra/` | Lambda image processor and deploy assets. |
| `config/deploy.yml` | Kamal 2 deploy configuration. |

## Global Working Rules

- A nested `CLAUDE.md` wins over this file inside its own directory.
- **Docs are business context, not the source of truth about running code.** When a document contradicts the repo, say so and ask — do not silently pick a side.
- Stay inside the scope you were given. No opportunistic refactors into neighbouring layers, no stack changes, no new gems "while we're here".
- If a requirement is ambiguous, ask — **but first do every part that doesn't depend on the answer**, then ask.
- **Verify data shape before normalizing it.** External payloads vary in field naming. Read a real response or fixture first; never write a parser from memory.
- **No speculative abstraction.** Don't add a base class, concern, or service for a single call site. Branch business flows high up instead.
- **Never add a comment on your own initiative — ask first.** New code ships without comments; names carry the meaning. If a piece of code genuinely cannot be read without one, stop and ask the owner, and write it only after they agree. Existing comments stay as they are, in the language of the file you are editing. The one standing exception is the locals declaration at the top of a partial, which `app/views/CLAUDE.md` requires.
- Touching a model or scope means re-running **both** `bin/rails test` and `bin/rubocop`, not just the file you edited.
- **Hand these back to a human:** creating or changing AWS resources, rotating Google API keys, running migrations against production, `kamal deploy`, deleting production data, toggling sharing on a real user's tag, widening the Google Places field mask.

### Settled decisions — do not revert

- **Tailwind is the whole styling layer.** Tokens in `@theme`, component classes in `@layer components`. No SCSS, no second CSS pipeline, no inline colour values.
- **`immutable_unaccent` must stay schema-qualified and cast to `::regdictionary`.** The shorter form fails on Postgres 17 when inlined into an index expression.
- **One Postgres database for everything.** App data, Solid Cache, Solid Queue and Solid Cable share a single database (owner's decision, 02.09.2026 — the data does not justify four). The `solid_*` tables are ordinary migrations in `db/migrate` and land in `db/structure.sql`. There is no `connects_to`, no per-database `schema_format`, and no `db/*_schema.rb`. Do not re-split them.
- **Configuration is one YAML file per environment**, under `config/settings/`, read through `Rails.application.config.settings`. Secrets stay in `ENV.fetch(...)` inside those files — the files are in git. Database connection details are the one exception: they live only in `config/database.yml`, which is loaded before settings.
- **Photos go straight from the browser to S3.** Active Storage direct upload signs a PUT; the file never passes through Puma. Photo fields carry the scoped `data-direct-upload-url="/places/:place_id/direct_uploads"`, and controllers receive **signed blob ids**, not uploaded files.
- **Real S3 in every environment, including development.** There is no MinIO and no local object-storage stand-in. `terraform apply` with `environment = "development"` gives your machine its own buckets and CloudFront distribution, so CORS, IAM and cache behaviour are exercised locally instead of first failing in staging.
- **The image pipeline is one-way.** The Lambda writes derivatives and stops; it never calls back into Rails. `Photos::ThumbnailUrl` builds URLs deterministically from the route-facing place id and `s3_key`. The internal UI deliberately does not fall back to originals: a missing derivative renders an error icon so pipeline failures stay visible. Do not add a webhook, a `thumb_ready` flag, or polling.

## Command instructions

Every Rails command runs **inside the `web` container**. The host has no Ruby.

```bash
docker compose exec web <command>
```

| App / runtime | Container | Notes |
| --- | --- | --- |
| Rails (Puma) | `web` | `bin/rails`, `bin/rubocop`, `bin/rails test` |
| Tailwind watcher | `css` | `tailwindcss:watch[always]` — the `[always]` variant is required because the container has no TTY |
| Solid Queue | `worker` | Waits for `web` to be healthy, since `web` runs `db:prepare` |
| Postgres 17 | `db` | Reachable from the host at `localhost:5433` |

Paths are **relative to `/rails`** (the container WORKDIR), which mirrors the repo root — so `bin/rails test test/models/place_test.rb` works verbatim.

`db:drop` fails while `worker` holds connections to the database. Stop it first:

```bash
docker compose stop worker && docker compose exec web bin/rails db:drop db:prepare && docker compose start worker
```

Changes to initializers, `Gemfile`, or routes need `docker compose restart web` — the running process keeps the old code otherwise.

`bin/setup` is for running directly on a machine, not for the Docker flow.

### Cross-App Contracts

Three contracts must be updated as a chain; never change one end alone.

**1. Postgres schema → `structure.sql`** — `db/migrate/*.rb` → `bin/rails db:migrate` → `db/structure.sql` is regenerated → commit both. The repo uses `schema_format = :sql` because `schema.rb` cannot represent the `immutable_unaccent` function or the `gist (ll_to_earth(...))` index.

**2. Image processor → Rails** — originals and derivatives are grouped by the route-facing place id. Uploads write `{place-id}/{image-name}.{ext}`; Lambda writes `{place-id}/thumb/{image-name}.webp` for 400 and `{place-id}/preview/{image-name}.webp` for 1200. The size list must match in **three** places or the UI deliberately shows an error icon:

| Place | Value |
| --- | --- |
| `config/settings/<env>.yml` → `photo_sizes` | `[400, 1200]` |
| `Photos::ThumbnailUrl::SIZES` | reads `photo_sizes` |
| `infra/terraform/variables.tf` → `image_sizes` | `[400, 1200]` |

400 is the thumb (cards, rows, thumbstrip), 1200 the preview (hero, album). Nothing reports back to Rails, so a mismatch is invisible in Rails logs: it shows up as the intentional broken-image state. Check `Photos::ThumbnailUrl::SIZES` against `image_sizes` first whenever that icon appears.

**3. Google Places → `Place` record** — `Google::PlacesClient::DETAILS_MASK` → the upsert service → the `cached_*` columns. **Adding a field to the mask costs money.** See `app/services/CLAUDE.md`.

**Scripts that do NOT exist here** — do not call them: `npm run codegen`, `yarn build`, `bin/rails graphql:dump`, `bin/importmap update`, `rails db:schema:dump` (this repo uses `structure.sql`), `bin/dev` (inside Docker).

### Verification Commands (Quick Reference)

| Command | When to run |
| --- | --- |
| `docker compose exec web bin/rails test` | After any model / service / controller change |
| `docker compose exec web bin/rails test test/models/place_test.rb` | When touching radius scopes or geo indexes |
| `docker compose exec web bin/rails test test/integration/` | When touching authorization, the public page, or locale |
| `docker compose exec web bin/rails test test/i18n_test.rb` | After adding or changing any user-visible string |
| `docker compose exec web bundle exec i18n-tasks normalize` | After editing a locale file — the test asserts files are sorted |
| `docker compose exec web bin/rubocop` | Before finishing any task that touched a `.rb` file |
| `docker compose exec web bin/rails tailwindcss:build` | After editing `app/assets/tailwind/application.css` |
| `docker compose exec web bin/rails db:migrate` | After adding a migration — **commit `db/structure.sql` with it** |
| `docker compose exec web bin/rails db:seed` | After resetting the database; it is idempotent |
| `docker compose exec web bin/brakeman` | Before opening a PR that touches controllers or routes |
| `docker compose logs -f worker` | When debugging background jobs |

Full chain after a schema change, in order:

```bash
docker compose stop worker
docker compose exec web bin/rails db:migrate       # regenerates db/structure.sql
docker compose exec web bin/rails db:test:prepare  # loads structure.sql into the test database
docker compose exec web bin/rails test
docker compose exec web bin/rubocop
docker compose start worker
```

## Boundaries

Cross-cutting prohibitions. Layer-specific ones are in the nested files.

Never:

- Run Rails commands on the host instead of inside the `web` container.
- Hand-edit `db/structure.sql`, `db/*_schema.rb`, or `Gemfile.lock`.
- Edit a migration that has already run in production — write a new one.
- Query user data without starting from `current_user`.
- Expose a private field on the public share route (`/s/:token`). It is the only unauthenticated route in the app — see `app/controllers/CLAUDE.md` and `app/views/CLAUDE.md` before touching anything it renders.
- Use `delete_all` on `visits` / `photos` / `taggings` — skipping callbacks desynchronizes counter caches. Always `destroy`.
- Hardcode a user-visible string anywhere. Everything goes through `t(...)`.
- Add a locale scope or prefix to routes.
- Put the server-side Google API key anywhere the browser can read it.
- Run `terraform apply`, or create/modify any AWS resource. Write the code, hand the apply to a human.
- Commit `infra/terraform/terraform.tfvars` or `terraform.tfstate` — the state holds an IAM secret key and the webhook secret.
- Re-split the Solid tables onto their own databases.
- Automate posting reviews to Google.
- `rescue` and swallow an error to make tests pass. Fix the cause or report it.
- Claim work is done when tests haven't been run or are red.

## Domain-Specific Flow Design: Isolation over Parameterization

Branch at the **highest** layer that can express the difference — controller or view — instead of pushing a business flag down into shared code. A partial that takes `public: true` and hides fields internally is how data leaks: whoever edits it in six months won't know the branch exists, and one added line exposes it. Two files make that failure impossible.

**Real divergence axes in this repo:**

- **Private ↔ Public** — the most important; already isolated into its own controller, layout, and partials.
- **Wishlist ↔ Visited** — different data and different colour semantics.
- **Has coordinates ↔ Missing coordinates** — places without coordinates can never appear in distance results, so they need an explicit warning rather than silent omission.
- **Has own photos ↔ None yet** — real photos from the CDN, otherwise a deterministic gradient, never a paid third-party photo.
- **Desktop ↔ Mobile** — this axis must **NOT** be split. One partial, different breakpoints.

**✅ PREFER (Branch Early & Isolate):** branch in the controller or where the partial is chosen.
**❌ AVOID (Business Parameterization & Bloat):** `render "shared/place_card", public: true`; `scoped_places(include_other_users: false)`; `ThumbnailUrl.call(key, size, public_link: true)`. Each flag doubles the paths through code nobody tests both ways.

**🛑 The Abstraction Guardrail** — before adding a flag to a shared path, answer all three:

1. If someone edits this file in six months **without knowing the flag exists**, what is the worst outcome? "Private data leaks" or "we get billed at a higher tier" → isolate.
2. Do the branches genuinely share **≥ 80%** of their logic, or only markup that is cheap to duplicate?
3. How many call sites will this flag have in three months? One → write it inline there.

## Browser Checks

Use the **`agent-browser` skill** to drive a real Chrome whenever the task is about what a screen actually looks like — matching the design, responsive behaviour, or anything that only appears once CSS and JavaScript run (Turbo Frame updates, the map, dark mode). Reading HTML is not enough for those; `curl` shows markup, not layout.

- **Check both widths.** The shell changes at the `lg` breakpoint: sidebar and detail panel above it, bottom tab bar below. A change that looks right on desktop often breaks the phone layout, so look at both before reporting a screen as done.
- **Sign in with the dev seed account.** `db/seeds.rb` creates `anh.nguyentien@pixta.co.jp` / `travelog123` (overridable via `SEED_EMAIL` / `SEED_PASSWORD`). It exists only in local development and holds only seeded sample places — never reuse it anywhere real. Run `db:seed` first if the login fails.
- The app is at `http://localhost:3000`. Confirm `web` is `healthy` in `docker compose ps` first, and restart it if gems, initializers, or routes changed.
- **Report what you saw, not what you expected.** If the layout is wrong, say which element and at which width. Do not call a screen verified because the page returned 200.

## Git Usage Boundaries

Git is a tool for **inspection and recovery**, not for tidying the workspace or rewriting history.

### Allowed Safe Usage

- `git status`, `git diff`, `git diff --staged`, `git log`, `git log -p <path>`, `git show <sha>`
- `git blame <path>`, `git stash list`, `git branch -a`
- `git add <path>` and `git commit` — **only when the user asks for a commit**
- `git checkout -b <branch>` when on `main` and a branch is needed before committing

### Never

- `git reset --hard`, `git clean -fd`, `git checkout -- .`, `git restore .`
- `git push --force`, `git push --force-with-lease`
- `git rebase -i`, `git commit --amend`, `git filter-branch`
- `git stash` just to "clean up" before doing something else
- Commit or push unprompted
- Commit `.env`, `config/master.key`, or any file holding a real API key

### Recovery Workflow

1. `git status` — determine what is untracked / modified / staged. Don't guess.
2. `git stash list` and `git log --oneline -20` — find the nearest point that still has the right content.
3. `git diff HEAD -- <path>` — see exactly what changed before undoing anything.
4. Restore **one file at a time**: `git checkout HEAD -- <path>`. Never restore the whole tree.
5. If the content only ever existed in the working tree and is gone, say so plainly. Do not reconstruct it from guesswork.

### Deep Search (Ghost Hunting)

```bash
git log --all --oneline -S '<string>'      # which commit added or removed this string
git log --all --diff-filter=D --name-only  # which files were deleted
git log --all --full-history -- '<path>'   # full history of one path
git fsck --lost-found                      # orphaned commits after a bad reset
```
