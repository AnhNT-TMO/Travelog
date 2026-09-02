# app/views — Agent Instructions

Rules for the template layer: which partials may be reused where, when a Tailwind component class is allowed instead of utilities, and how every user-visible string gets translated. The root `CLAUDE.md` governs everything else and still applies here. This file only overrides for files under `app/views/`.

## Map

| Directory | Role |
| --- | --- |
| `layouts/` | `application` (sidebar + tab bar shell), `public` (share page — no nav, no actions), `auth` (sign-in / password reset), `mailer`. |
| `shared/` | Partials reused across screens **and across desktop/mobile**. These render private data. |
| `public_collections/` | The share page and **its own** card partial. Deliberately duplicated rather than shared. |
| `collections/` | Home: tag groups plus recently saved. |
| `tags/` | Places filtered by tag: segmented control, vibe chips, grid. |
| `places/` | Detail and full list. Detail delegates to `shared/_place_detail`. |
| `nearby/` | Map, radius slider, result rows. |
| `album/` | Month-grouped visit timeline. |
| `devise/` | Hand-written sign-in and password screens. Not generated — do not run `rails g devise:views` over them. |
| `pwa/` | Manifest and service worker. |

### Partials in `shared/`

| Partial | Notes |
| --- | --- |
| `_place_card` · `_place_media` · `_place_row` | **Render private fields.** Never used on the public page. |
| `_place_grid` · `_place_row_list` | Turbo Frame wrappers around a collection, with the empty state built in. Both use frame id `place_list`. |
| `_place_detail` | **One partial for desktop panel and mobile page.** Do not split it. |
| `_visit_timeline` · `_review_kit` | Sections of the detail view. |
| `_segmented` · `_tag_chips` | Filter controls. Links that carry state in the query string. |
| `_sidebar` · `_sidebar_item` · `_tabbar` · `_tab_item` · `_topbar` | Navigation shell. |
| `_collection_card` · `_empty` · `_flash` · `_locale_switch` | Utility partials. |

## Private Partials vs Public Partials

The rule that shapes this folder: **`shared/` is for signed-in screens only.**

`shared/_place_card` and `shared/_place_media` render `source_url`, `priority`, review state, and rating. `public_collections/_place_card` deliberately duplicates their markup while rendering only what an anonymous visitor may see: label, photos, district or city, tags, status, visit count — plus the note **only** when `share_notes` is on.

This duplication is intentional and must stay. The alternative — one partial with a `public:` flag — means whoever edits it in six months without knowing about the flag exposes private data with one added line. Two files make that failure impossible.

**Adding a field to the public card requires adding an assertion to `test/integration/public_collection_test.rb` in the same change.**

## Working Rules

- **No user-visible string literals.** Every one goes through `t(...)`, including page titles, button labels, `aria-label`, `title`, and `placeholder`. `raise_on_missing_translations` is on outside production, so a forgotten key raises immediately.
- Prefer **lazy lookup**: `t(".title")` in `collections/index.html.erb` resolves to `collections.index.title`; inside `shared/_place_grid` it resolves to `shared.place_grid.*`. Use an absolute key only for genuinely shared strings under `common.`, `nav.`, `status.`, `review.`, or `filters.`.
- Keys ending in `_html` are marked HTML-safe with their interpolations escaped. Use them when a string needs inline markup, and **keep CSS classes out of the translation** — style the tag from markup with an arbitrary variant such as `[&_b]:font-semibold`.
- Counts use pluralized keys with `count:`, never concatenation.
- **Locals are the partial's interface.** Declare them in a comment at the top; give optional ones a default with `local_assigns.fetch(:name, default)`. A partial that reaches for an instance variable cannot be reused, which is the whole point of `shared/`.
- **Desktop and mobile are one template**, differing only by breakpoint. `hidden lg:flex` for the sidebar, `lg:hidden` for the tab bar. Never write a second partial for a screen size.
- **Media needs a fixed aspect ratio.** User photos come in every proportion; letting image height drive card height makes the grid jump. Cards are `aspect-[4/3]`, collection covers `aspect-[3/2]`, hero `aspect-[16/10]`, thumbnails `aspect-square`.
- Photos render through the `photo_image_tag` helper, which supplies `srcset`, lazy loading, and an explicit error icon when a derivative is missing. It deliberately never falls back to the original, so internal pipeline failures remain visible. Never hand-write an `<img>` for a photo.
- When there is no photo, the media block gets a deterministic gradient from `placeholder_gradient_style`, not an empty grey box and never a paid third-party photo.
- **Status pills sit on the image, top-left**, so status is readable when scanning a grid before any name is read.
- Every collection render has an **empty state**. `_place_grid` and `_place_row_list` build theirs in; a new collection view needs one too.

## Internationalization

The app is bilingual: **Vietnamese (`vi`) and English (`en`)**. `vi` is the default *and* the source of truth — fallbacks resolve to it.

- Translations live in `config/locales/vi.yml` and `config/locales/en.yml`. The two key trees must be identical.
- **Add the Vietnamese key first.** A key missing from `vi.yml` leaks in every language; one missing from `en.yml` silently shows Vietnamese to English readers. The parity test exists to catch exactly that.
- `test/i18n_test.rb` fails the build on a missing key, an unused key, or an unsorted file. After editing a locale file run `bundle exec i18n-tasks normalize`.
- Keys interpolated dynamically (`t("status.#{...}")`) are invisible to the scanner and are listed under `ignore_unused` in `config/i18n-tasks.yml`.
- Date, number, and validation strings come from the `rails-i18n` gem; Devise's come from `devise-i18n`. Only override them in `config/locales/*.yml` where the design genuinely differs.
- Locale resolution happens in the controller layer — see `app/controllers/CLAUDE.md`. Templates just call `t(...)`.

## Tailwind: component class or utilities?

The design system lives in `app/assets/tailwind/application.css` — `@theme` tokens plus `@layer components`. That file is the only source of colors, type sizes, radii, and shadows.

- **Utilities inline in the template** are the default. A partial *is* the component, so its markup carries its own classes.
- **A component class exists only for elements a partial cannot wrap**: `.btn` and variants, `.input` / `.select` / `.textarea` / `.label` / `.hint` / `.field`, `.pill`, `.chip`, `.seg-item`, `.tag-mini`, `.range`. These appear inline inside many different partials, where a partial-per-button would be worse.
- Cards, rows, shells, sidebar, album, timeline, and the review kit are **partials with utilities**, not component classes. Do not add classes for them to the CSS file.
- **Dark mode is automatic.** Tokens swap values; utilities reference the tokens. Never write a `dark:` variant for a color, and never inline a hex value.
- Use the app's 8-step type scale (`text-2xs` … `text-2xl`). Do not add a one-off `text-[0.83rem]`.
- Numeric content gets the `.num` class for tabular mono figures — distances, counts, dates.

## Contracts

- **View ↔ controller.** Instance variables are the interface; a view must not fetch data the action did not prepare.
- **View ↔ locale files.** Every `t(...)` key must exist in **both** `config/locales/vi.yml` and `en.yml`. `test/i18n_test.rb` fails the build on a missing key, an unused key, or an unsorted file.
- **Turbo Frame ↔ action.** The `turbo_frame_tag` id inside `_place_grid` / `_place_row_list` must match the frame the action renders into. A mismatch produces a silently empty frame.
- **View ↔ design system.** New visual primitives go in `application.css` first, then get used here — never as an inline style or an arbitrary hex.

## Verification

```bash
docker compose exec web bin/rails test test/i18n_test.rb          # after any string change
docker compose exec web bundle exec i18n-tasks normalize          # after editing a locale file
docker compose exec web bin/rails test test/integration/          # after touching the public page
docker compose exec web bin/rails tailwindcss:build               # after adding classes
```

Then check the screen itself using the `agent-browser` skill — see "Browser Checks" in the root file — in **both** locales, and at a narrow and a wide viewport.

## Boundaries

Never:

- Render a `shared/` partial from `public_collections/`.
- Add a `public:` or `mode:` flag to a partial to hide fields conditionally.
- Hardcode a user-visible string, including `aria-label`, `title`, and `placeholder`.
- Put a CSS class inside a translation value.
- Write a `dark:` colour variant or an inline hex value.
- Add a component class for something a partial already wraps.
- Write a separate partial for mobile.
- Let image dimensions determine container height — always a fixed aspect ratio.
- Hand-write an `<img>` for a user photo instead of using `photo_image_tag`.
- Reference an instance variable from a partial in `shared/`.
- Render a collection with no empty state.
- Regenerate the Devise views over the hand-written ones.

## Naming Convention

- Partials are named for **what they render**, not where they appear: `_place_card`, `_visit_timeline`, `_locale_switch`. Not `_sidebar_box`, not `_right_panel`.
- A partial rendering a collection ends in a plural or a container word: `_place_grid`, `_place_row_list`. A partial rendering one thing is singular: `_place_card`, `_place_row`.
- Locals carry the domain name spelled out: `user_place`, `tags`, `counts`, `visits`. Not `up`, not `item`, not `data`.
- Optional locals with defaults are read once at the top of the file, never inline at the point of use.
- i18n keys are named for **meaning**, not the widget: `shared.place_grid.empty_title`, `common.unknown_area`. Not `grey_text_under_grid`.
- The `_html` suffix is reserved for strings that genuinely contain markup — it changes escaping, so never add it decoratively.
- Helper methods called from views are named for what they return: `status_label`, `distance_label`, `month_label`, `placeholder_gradient_style`. Display strings live in `app/helpers`, never on a model.

## Flow Design: Isolation over Parameterization

**✅ PREFER:** two partials when the *audience* or the *meaning* differs — `shared/_place_card` and `public_collections/_place_card`. A separate empty-state message per collection type, passed as locals from the caller.

**❌ AVOID:** `render "shared/place_card", user_place: up, public: true`. A partial with three `if` branches for three screens. A `variant:` local that changes which fields render.

**The guardrail for this folder:** does the flag change *which fields are rendered*? If yes, split the partial — that is a data-exposure decision, not a styling one. Flags that only change spacing or a CSS class are fine as locals.

Breakpoints are the one axis that must **not** be split.
