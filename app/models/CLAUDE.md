# app/models — Agent Instructions

Rules for the data layer: which model owns which fact, how denormalized counters stay honest, and what must never appear in a model. The root `CLAUDE.md` governs everything else — commands, git, cross-layer contracts — and still applies here. This file only overrides for files under `app/models/`.

## Map

| File | Role |
| --- | --- |
| `place.rb` | Objective, **shared across all users**, deduplicated by `google_place_id`. Owns coordinates, address cache, and every distance scope. |
| `user_place.rb` | One person's **subjective** relationship to a `Place`: status, note, rating, priority, tags, cover photo, review state. The table almost every query starts from. |
| `visit.rb` | One trip to a place. Many per `user_place`. Writing one is what flips a place to `visited`. |
| `photo.rb` | A user's own photo. Belongs to a `user_place` always, to a `visit` optionally (reference photos for places not yet visited have no visit). |
| `tag.rb` | Multi-label tag owned by a user. Also owns **read-only sharing** — see "Sharing lives on Tag". |
| `tagging.rb` | Join between `tag` and `user_place`. Carries the counter cache for `tags.user_places_count`. |
| `takeout_import.rb` / `takeout_candidate.rb` | Google Takeout backfill of review history. Parser and matcher are not written yet. |
| `user.rb` | Devise. Owns `locale` and the display helpers `label` / `initials`. |
| `current.rb` | `ActiveSupport::CurrentAttributes` holding `user`. Set once in `ApplicationController`. |
| `application_record.rb` | Abstract base. Nothing app-specific lives here yet — keep it that way unless a rule genuinely applies to every table. |

## Shared Facts vs Owned Facts

The one domain rule that shapes this whole folder: **`Place` is objective and shared; `UserPlace` is subjective and owned.**

- `Place` holds what is true regardless of who is looking: name, coordinates, district, the cached Google payload. Two users pointing at the same café share one `Place` row.
- `UserPlace` holds what is true only for one person: have they been, do they want to go, what did they think, which tags, which photos.

**Never add a user-specific column to `places`.** Status, rating, note, priority, and review state all belong on `user_places`. A column on `places` is visible to every user of the app, and there is no scoping layer that will save you.

The mirror of this rule: `places` rows are never scoped by user, so **never expose a `Place` finder to request params**. Reach places through `current_user.user_places` or `current_user.places`.

`Place#cached_name`, `cached_address`, and `cached_payload` are a **cache of third-party content**, not app data — `cache_stale?` exists because that content may not be retained indefinitely. `display_name` and `UserPlace#nickname` are the user's own data and are kept forever.

## Sharing lives on Tag

Read-only sharing is stored on `tags`, not on `user_places`: `visibility` (`private_only` / `unlisted`), `public_token`, `share_notes`, `shared_at`. A whole tag is shared or it is not — there is no per-place sharing flag, and adding one would mean rethinking the public page from scratch.

`enable_sharing!` mints a token; `disable_sharing!` deletes it. Re-enabling mints a **new** token, so an old link stays dead forever. That is deliberate: revoking a share must actually revoke it. Do not "fix" this into a stable token.

`public_token` is the only column in the schema that an anonymous visitor can address a row by, so it is generated with `SecureRandom.urlsafe_base64(16)` and indexed uniquely where non-null. What the shared page may render is decided in the view and controller layers, not here.

## Working Rules

- **Distance lives here, in `Place`, and nowhere else.** `within_radius`, `with_coords`, and `select_distance_from` are the only place raw geo SQL is allowed. Callers compose them (`Geo::RadiusQuery` does) rather than writing their own.
- `select_distance_from` must run **before** any `ORDER BY distance_m`. Ordering by a column that is not in the select list fails in Postgres as soon as `DISTINCT` is involved.
- **Vietnamese text comparison must match the index expression exactly.** `Place.name_matching` uses `lower(immutable_unaccent(...))` because that is precisely what `index_places_on_display_name_trgm` indexes. Change one and you must change the other, or Postgres silently stops using the index.
- On the Ruby side the equivalent is `Vietnamese.strip_accents`. Both sides must agree; never use `parameterize` or `I18n.transliterate` for Vietnamese.
- **Denormalized counters are maintained by callbacks**, so they only stay correct if you go through them. The counters are `user_places.visits_count`, `user_places.photos_count`, `visits.photos_count`, and `tags.user_places_count`.
- `Visit` writes back to its parent via `recalc_visit_stats!` on commit. A visit is the *only* thing that should flip `status` to `visited`.
- `Photo` sets the cover on first create and recounts on create and destroy. `s3_key` is copied from the Active Storage blob key at validation time and is unique — it is the join between Rails and the image pipeline.
- Enum values are **integers in the database and symbols in code**. Never compare against the integer. Renaming an enum value is a migration, not an edit.

## Contracts

- **Model ↔ schema.** Adding a column means a migration, `bin/rails db:migrate`, and committing the regenerated `db/structure.sql`. Never assume a column exists because it is in a model — check `db/structure.sql`.
- **Model ↔ view.** `UserPlace` exposes the `wishlist` / `visited` enum; the human-readable label comes from the `status_label` helper. If you find yourself wanting a `#label`-style method that returns Vietnamese or English, it belongs in `app/helpers`, not here.
- **`Photo#s3_key` ↔ image pipeline.** `s3_key` is the Active Storage blob key `{user_place-id}/{image-name}.{ext}`. `thumb_url` and `srcset` combine its basename with `user_place_id`; Lambda writes `{user_place-id}/thumb/{image-name}.webp` (400) and `{user_place-id}/preview/{image-name}.webp` (1200). The route calls this a place id even though the table is `user_places`. Nothing reports back when a derivative lands, so a mismatch shows the intentional error icon.
- **`UserPlace#attach_photos!` ↔ direct upload.** It takes **signed blob ids**, not uploaded files: `DirectUploadsController` has already scoped the route-facing place id, created the structured Blob key, and the browser has PUT the image to S3. `find_signed!` raises on a tampered id rather than skipping it silently.

## Verification

```bash
docker compose exec web bin/rails test test/models/          # after any model change
docker compose exec web bin/rails test test/models/place_test.rb   # after touching a distance scope
docker compose exec web bin/rubocop
docker compose exec web bin/rails runner 'puts UserPlace.statuses.inspect; puts Tag.kinds.inspect'
```

A change to a scope or a callback requires running the **whole** suite, not just the model test — services and integration tests depend on both.

## Boundaries

Never:

- Put user-specific state on `places`.
- Write raw distance SQL outside `Place`.
- Use `delete_all` on `visits`, `photos`, or `taggings` — it skips the callbacks that keep counters correct. Always `destroy`.
- Update a counter column by hand instead of letting the callback recompute it.
- Return a user-visible string from a model. No Vietnamese or English display text in this folder.
- Call `I18n.t` in a model.
- Call Active Storage's `.variant()` on `Photo#file`. Resizing happens outside Rails.
- Add a `default_scope`. It is invisible at the call site and will eventually hide a row someone needed.
- Add a validation that performs a network call.

## Naming Convention

Name things after what the method returns or what it means in the business — never after the caller or the UI location. Banned everywhere: `data`, `info`, `manager`, `handler`, `util`, `process`, `do_`, `temp`.

The rules that come up most in this folder:

- Predicates end in `?`: `place.coordinates?`, `place.cache_stale?`, `tag.shared?`, `candidate.auto_matchable?`. Never `is_*` or `has_*`.
- Mutating methods that raise on failure end in `!`: `tag.enable_sharing!`, `user_place.recalc_visit_stats!`.
- Scopes are named for **the set they return**, usually with a preposition: `within_radius`, `with_coords`, `tagged_with_all`, `for_state`, `chronological`, `ordered`, `selected`, `needing_review`. Never `filter_by_*` or `get_*`.
- Enum prefixes disambiguate collisions rather than decorate: `coords_source` uses `prefix: :coords_from`, `google_review_state` uses `prefix: :review`, `Tag#visibility` uses `prefix: :share`. Add a prefix only when two enums would otherwise generate the same method.
- A scope that exists to fix N+1 says so: `with_card_data`. Not `includes_everything`.

## Flow Design: Isolation over Parameterization

Divergence in this folder is expressed with **separate scopes**, not with scopes that take a mode flag.

**✅ PREFER:** `UserPlace.wishlist` / `.visited`, composed by `for_state` at one call site. `Place.within_radius(...)` returning a relation the caller narrows further.

**❌ AVOID:** `UserPlace.by_status(status, include_all: true)`. A scope whose behavior inverts on a boolean is two scopes wearing one name, and only one of them ends up tested.

Before adding a parameter to an existing scope, check whether the caller actually wants a *different set* — if so it is a different scope.
