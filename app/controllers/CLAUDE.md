# app/controllers — Agent Instructions

Rules for the request layer: the single authorization gate every action goes through, the one action that deliberately bypasses it, and how Turbo Frame responses are shaped. The root `CLAUDE.md` governs everything else and still applies here. This file only overrides for files under `app/controllers/`.

## Map

| File | Role |
| --- | --- |
| `application_controller.rb` | The gate. Authentication, `Current.user`, sidebar tag loading, and the `scoped_places` / `scoped_tags` accessors every other controller uses. |
| `concerns/localizable.rb` | Locale resolution and persistence. Included once, in `ApplicationController`. |
| `collections_controller.rb` | Home. Tag groups plus recently saved places. Computes per-tag counts in one grouped query rather than N+1. |
| `tags_controller.rb` | Places filtered by tag, with the three-state segmented control and vibe chip intersection. Renders a partial for Turbo Frame requests. |
| `places_controller.rb` | Place CRUD, the detail screen and the full list. |
| `direct_uploads_controller.rb` | Authenticated Active Storage direct-upload handshake. Scopes the route-facing place id and creates `{place-id}/{image-name}.{ext}` keys before the browser PUT. |
| `nearby_controller.rb` | Distance filtering. Delegates entirely to `Geo::RadiusQuery`; remembers the last centre in the session. |
| `album_controller.rb` | Visit timeline grouped by month. |
| `public_collections_controller.rb` | **The one public route.** Skips authentication by design — see below. |
| `visits_controller.rb` · `photos_controller.rb` · `review_kits_controller.rb` | Check-in, photos, and the Google review kit. All nested under a place. |
| `account_controller.rb` | The mobile "Tôi" tab. Desktop shows the same things in the sidebar footer. |

One controller per screen in the mockup, one action per screen state. Controllers that do not exist yet have their routes drafted as comments in `config/routes.rb`; uncomment a route only when its controller lands.

## The Public Route

`PublicCollectionsController` is the single publicly reachable action in an otherwise internal app. It is the highest-risk file in this folder.

- It skips `authenticate_user!`, `set_current_user`, and `load_sidebar_tags`, and disables forgery protection because it is GET-only.
- It renders `layout "public"` and **its own partials** under `app/views/public_collections/`. It must never render anything from `app/views/shared/` — those partials carry private fields.
- It is rate limited, sends `X-Robots-Tag: noindex, nofollow`, and looks the tag up by `public_token` scoped to `share_unlisted`, so a disabled share 404s through the normal `RecordNotFound` path.
- Sharing is owned by `Tag`, not `UserPlace`. Disabling deletes the token; re-enabling mints a new one so old links stay dead. That is intentional.

**Before changing anything this action renders, read `test/integration/public_collection_test.rb`.** That test is the authoritative list of what may appear, and any new field needs a matching assertion in the same change.

`PublicCollectionsController` is the **only** route outside Devise. There was briefly a second one — an HMAC-signed webhook for the image processor — and it was deleted rather than maintained: an unauthenticated endpoint is a liability you carry forever, and that one bought a single boolean column.

If you add another unauthenticated route, it needs its own controller, its own layout, its own partials, and its own leak test. Do not reach for `skip_before_action` inside a controller that also serves signed-in users.

## Working Rules

- **Every query starts from `current_user`.** Use `scoped_places` and `scoped_tags`. `UserPlace.find(params[:id])` hands one user another user's data, and there is no second layer that will catch it.
- Ownership failures should surface as `RecordNotFound` → 404, not as a redirect or a 403. Not-found and not-yours look identical from outside, which is the point.
- **Filter params are whitelisted against a known set**, never passed through. `params[:state].presence_in(STATES)` with a default; the same for sort keys. A raw param reaching a scope is an injection surface.
- **Turbo Frame requests render a partial, not a full page.** The pattern is `render partial: "...", locals: {...} if turbo_frame_request?` at the end of the action, so the same action serves both the full page and the frame update. Do not create a second action for the frame.
- Filter state lives in the **URL**, not in the session, so back/forward and bookmarks work. The session holds only conveniences that should not be shareable — currently just the last map centre.
- **Instance variables are the view contract.** Assign everything the view needs in the action; do not let a view reach back through `current_user` for data the controller did not prepare.
- Preload with the `with_card_data` scope wherever a collection of places is rendered. A place card touches the place, its tags, and its cover photo's attachment.
- Direct uploads use `place_direct_uploads_url(user_place)`, never the generic Active Storage endpoint. The custom action must find the target through `scoped_places` before minting a structured S3 key.
- Controllers **compose** services and scopes; they do not contain business logic. If an action is growing conditionals about *what the data means*, that logic belongs in a model or a service.

### Locale

`Localizable` is included once, in `ApplicationController`, and wraps every action in `I18n.with_locale`. Resolution order: `?locale=` param → the signed-in user's saved `locale` → session → `Accept-Language` → `vi`. Passing `?locale=` also persists the choice to the user record and the session, so it survives the next request.

**Locale is deliberately not in the URL path.** Share links must keep a stable shape, and an internal app does not need per-language URLs — never add a locale scope to `config/routes.rb`. An unsupported locale falls back to the default rather than raising, so a stray `?locale=fr` cannot break a page.

The public route resolves locale too: it skips authentication but **not** `Localizable`, because an anonymous visitor still needs the page in a language they can read.

## Contracts

- **Controller ↔ routes.** A route may only exist if its controller action does. `config/routes.rb` keeps the unbuilt routes commented for exactly this reason.
- **Controller ↔ view.** Instance variables are the interface. Renaming one means updating every view and partial that reads it.
- **Turbo Frame ↔ partial.** The frame id in the view (`place_list`) must match the `turbo_frame_tag` inside the partial the action renders. A mismatch produces a silently empty frame.
- **`Localizable` ↔ `users.locale`.** Choosing a locale writes to the user record and the session. Locale is resolved from params, user, session, then `Accept-Language` — it is never in the URL path, and adding a locale route scope would break share links.

## Verification

```bash
docker compose exec web bin/rails test test/integration/    # authorization + public leak + locale
docker compose exec web bin/rails routes | head -40
docker compose exec web bin/rubocop
docker compose exec web bin/brakeman                        # before any PR touching this folder
```

To exercise a screen by hand, use the `agent-browser` skill — see "Browser Checks" in the root file. Note that `allow_browser versions: :modern` returns 403 to any request without a real browser User-Agent.

## Boundaries

Never:

- Call `UserPlace.find`, `Tag.find`, `Photo.find`, or any unscoped finder on user data.
- Add `skip_before_action :authenticate_user!` to a controller that also serves signed-in users.
- Render an `app/views/shared/` partial from the public namespace.
- Pass a raw filter or sort param into a scope without whitelisting it.
- Put business logic in an action that belongs on a model or in a service.
- Rescue `RecordNotFound` to render a custom page — let Rails produce the 404 consistently.
- Store filter state in the session instead of the URL.
- Add a locale scope or prefix to routes.
- Use `params.permit!`.
- Return a hardcoded user-visible string. Flash messages and page titles go through `t(...)` like everything else.

## Naming Convention

Name things after what the method returns or what it means in the business — never after the caller or the UI location. Banned everywhere: `data`, `info`, `manager`, `handler`, `util`, `process`, `do_`, `temp`.

Plus, specific to controllers:

- Controllers are named for the **resource or screen**, plural, matching the route: `CollectionsController`, `NearbyController`, `AlbumController`. Not `HomeController`, not `MainController`.
- Actions use the seven REST names wherever the action genuinely is that verb. A non-REST action is named for what the user gets: `TagsController#places`. Not `#list`, not `#filter`.
- Private methods are named for **what they return**, not when they run: `resolve_center`, `sort_clause`, `counts_by_tag`, `supported_locale`. Not `handle_params`, not `before_render_setup`.
- `before_action` callbacks are named for the effect: `set_current_user`, `load_sidebar_tags`. `set_*` for one object, `load_*` for a collection.
- Instance variables carry the domain name, never the UI slot: `@user_places`, `@counts`, `@map_points`. Not `@sidebar_data`, not `@panel_items`.
- Whitelists are frozen constants on the controller that owns them: `TagsController::STATES`.

## Flow Design: Isolation over Parameterization

This folder is where branching *should* happen. Pushing a business distinction any lower is what causes leaks.

**✅ PREFER:** a separate controller for a separate audience. The public share page has its own controller, layout, and partials — so a future edit to the signed-in card physically cannot expose a private field to an anonymous visitor. `NearbyController` delegates to `Geo::RadiusQuery` rather than teaching `TagsController` about distance.

**❌ AVOID:** `scoped_places(include_other_users: false)`. One action serving both authenticated and anonymous visitors on a flag. A `public` local passed down into a shared partial.

**The guardrail for this folder:** if the two branches differ in *who is allowed to see the result*, they get separate controllers. Audience is never a parameter.
