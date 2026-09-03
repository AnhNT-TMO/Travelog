# app/services — Agent Instructions

Rules for service objects: what earns a place in this folder, how each one is shaped, and which of them cost real money when called carelessly. The root `CLAUDE.md` governs everything else and still applies here. This file only overrides for files under `app/services/`.

## Map

| File | Role |
| --- | --- |
| `geo/radius_query.rb` | The single entry point for "which of my places are within N metres of here". Owns radius clamping, the default centre, distance ordering, the count breakdown, and the list of places that have no coordinates at all. |
| `photos/thumbnail_url.rb` | Builds CDN URLs for a photo **deterministically** from its `s3_key`. Pure string building — no I/O, no database. |
| `google/places_client.rb` | Server-side HTTP client for the Google Places API. Owns the field mask, the session-token discipline, timeouts, and response caching. |
| `google/review_link.rb` | Builds Google Maps deep links. Pure; no network. |
| `google/places_error.rb` | The one exception type `PlacesClient` raises. Carries HTTP status and Google's request id. |

Namespaces are directories: `Geo::`, `Photos::`, `Google::`. A new service goes in an existing namespace or gets a new directory — never at the top level of `app/services/`.

## Cost and Quota Surface

The domain rule that makes this folder different from the rest of the app: **two of these services spend money or quota on every call.** Nothing else in the codebase does.

- `Google::PlacesClient::DETAILS_MASK` is deliberately narrow. `rating`, `reviews`, `photos`, and opening hours sit in a much more expensive billing tier. **Widening the mask is a pricing decision, not a code change** — hand it back to a human.
- Autocomplete is only free when its session token is reused by the following Details call. Breaking that pairing turns a free lookup into a billed one, and nothing in the code will complain.
- `details` caches for 14 days. That TTL is doing two jobs at once: saving quota, and keeping third-party content from being retained longer than it should be. Do not extend it without checking both.
- The API key here is the **server-side, IP-restricted** one. The browser uses a different, referrer-restricted key. They are not interchangeable, and putting this one in a response body defeats its restriction.

When a task touches this surface, say what it will cost before writing the code.

## Working Rules

- **A service exists when logic has no single natural owner** — it spans models, or it talks to the outside world. Logic about one model belongs on that model. Logic about rendering belongs in a helper. Do not create a service to "keep the controller thin"; a five-line controller action is fine.
- `call` is the entry point for stateful services (`Geo::RadiusQuery#call`). Stateless ones expose class methods (`Photos::ThumbnailUrl.call`, `Google::ReviewLink.for`). Pick one shape per service and keep it.
- **Services do not know about the request.** No `params`, no `session`, no `cookies`, no `current_user` lookup — the caller passes `user:` in. This is what makes them testable and keeps the authorization gate in one place.
- **Fail loudly.** `PlacesClient` raises `Google::PlacesError` on any non-2xx and on timeout. Do not return `nil` to mean "something went wrong"; the caller cannot tell that apart from "no result".
- **Clamp inputs at the boundary.** `RadiusQuery` clamps the radius rather than trusting the caller, because the caller is ultimately a query string.
- **Never log a third-party response body.** It may contain content the app is not allowed to retain. Log the status and Google's request id — that is enough to debug.
- `Photos::ThumbnailUrl` raises on an unsupported size instead of silently generating a URL nothing will ever serve. Keep it that way; a wrong size is a 404 that only shows up in DevTools.

## Contracts

- **`ThumbnailUrl::SIZES` ↔ the image processor.** `SIZES` is read from `config/settings/<env>.yml` (`photo_sizes`) and must match `image_sizes` in `infra/terraform/variables.tf`. `[400, 1200]` is the agreed set: 400 maps to `{place-id}/thumb/{image-name}.webp`, 1200 to `{place-id}/preview/{image-name}.webp`. `call` therefore requires `place_id:` as well as the original `s3_key`.
- **`ThumbnailUrl` ↔ `settings.cdn_host`.** Comes from `config/settings/<env>.yml`, fed by `CDN_HOST` (the CloudFront domain, `terraform output cdn_host`). The service strips a trailing slash defensively.
- **`PlacesClient` ↔ `Place`.** Details responses map onto the `cached_*` columns. The upsert service that does this mapping is not written yet; when it is, it belongs here.
- **`RadiusQuery` ↔ `Place` scopes.** This service composes `Place.within_radius`; it does not reimplement the SQL. If distance logic needs to change, change it in the model.

## Verification

```bash
docker compose exec web bin/rails test test/services/
docker compose exec web bin/rubocop
docker compose exec web bin/rails runner 'puts Photos::ThumbnailUrl::SIZES.inspect'   # phải khớp image_sizes trong Terraform
```

Services that hit the network are **never** exercised against the real API in tests. `PlacesClient` currently has no test because nothing calls it yet — when it gains a caller, test it against a recorded fixture, not the live endpoint.

## Boundaries

Never:

- Add a field to `Google::PlacesClient::DETAILS_MASK` without a human confirming the billing tier.
- Call Google Places from a view, a model, or a Stimulus controller. Server-side, through this client, always.
- Put the server-side API key anywhere the browser can read it.
- Reach for `params`, `session`, `current_user`, or `Current` inside a service.
- Log a Google response body or a webhook payload.
- Swallow an API error and return `nil`.
- Reimplement distance SQL here instead of composing `Place`'s scopes.
- Create a service for a single call site with no cross-model or external concern — that is speculative abstraction.
- Perform I/O in `ThumbnailUrl` or `ReviewLink`. They are pure by design, which is why they are cheap to call in a loop inside a view.

## Naming Convention

Name things after what the method returns or what it means in the business — never after the caller or the UI location. Banned everywhere: `data`, `info`, `manager`, `handler`, `util`, `process`, `do_`, `temp`.

Plus, specific to services:

- A service is a **noun phrase for the job**, not an agent noun: `RadiusQuery`, `ThumbnailUrl`, `ReviewLink`. Never `RadiusQueryManager`, `PhotoUrlBuilder`, `ReviewLinkService`. The `Service` suffix is banned — the directory already says it.
- Entry point is `call` unless the domain gives a better verb that reads at the call site: `ReviewLink.for(place)`, `ThumbnailUrl.srcset(key)`.
- Constants name the constraint they encode: `MAX_RADIUS_M`, `DEFAULT_RADIUS_M`, `DETAILS_MASK`, `CACHE_TTL`, `SIZES`. Units go in the name (`_M` for metres, `_S` for seconds) — a bare `MAX_RADIUS` is ambiguous.
- Keyword arguments over positional ones for anything with more than two inputs. `RadiusQuery.new(user:, lat:, lng:, radius_m:, state:, tag_ids:)` reads at the call site; six positional arguments do not.
- Errors are named for what failed and live beside the service that raises them: `Google::PlacesError`.

## Flow Design: Isolation over Parameterization

This folder is where "one more flag" is most tempting, because a service already has a parameter list.

**✅ PREFER:** a second service, or a second method with a name that says what it returns. `RadiusQuery#call` returns the list; `#counts` returns the breakdown; `#map_points` returns the marker payload. Three names, three obvious return types.

**❌ AVOID:** `RadiusQuery#call(mode: :counts)`. `ThumbnailUrl.call(key, size, public_link: true)`. A flag that changes the return *type* is two methods sharing a name.

**The guardrail question for this folder specifically:** does the flag change what the caller gets back, or only how it is computed? Changing the return type means it is a different method. Changing an internal detail may legitimately be a parameter.
