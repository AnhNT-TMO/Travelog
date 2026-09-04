# app/javascript — Agent Instructions

Rules for the client layer: how much behaviour a Stimulus controller is allowed to own, why the server stays the source of truth, and the two API keys that must never be confused. The root `CLAUDE.md` governs everything else and still applies here. This file only overrides for files under `app/javascript/`.

## Map

| File | Role |
| --- | --- |
| `application.js` | Entry point. Loads Turbo and the Stimulus application. |
| `controllers/application.js` | The Stimulus application instance. |
| `controllers/index.js` | Eager-loads every `*_controller.js`. **No manual registration** — dropping a file in is enough. |
| `controllers/radius_controller.js` | Radius slider. Updates the label immediately, debounces 300 ms, then submits the form into a Turbo Frame. |
| `controllers/clipboard_controller.js` | Copies review text, with a transient "copied" label and a select-the-text fallback outside a secure context. |
| `controllers/segmented_controller.js` | Flips `aria-selected` on click so the control feels responsive while the frame loads. Purely cosmetic. |
| `controllers/nearby_map_controller.js` | Google Maps JS: vector map, radius circle, draggable centre pin, one numbered marker per place with collision-managed name labels, and a working no-SDK fallback. |
| `controllers/dialog_controller.js` | Upgrades a server-rendered `<dialog open>` to a real modal (`showModal()`), and closes it on disconnect so a Turbo frame swap cannot leave the page inert. |
| `controllers/direct_upload_controller.js` | Progress bar for Active Storage direct upload; disables submit buttons while files are still going to S3. |
| `controllers/sheet_controller.js` · `autosave_controller.js` · `autosubmit_controller.js` · `geolocate_controller.js` | Check-in sheet, debounced review-draft save, submit-on-change, and the "use my location" button. |

There is no bundler. Assets are served by Propshaft and modules resolved by importmap — **`node_modules` does not exist and `npm`/`yarn` commands do not apply here.** A new library must be pinned in `config/importmap.rb`.

## The Server Is the Source of Truth

The rule that shapes this whole folder: **client code never decides what data is shown.**

Dragging the map's centre pin does not re-filter markers in JavaScript — it writes the new coordinates into the form and submits it, and both the list and the pins re-render from what Postgres returned. Moving the radius slider does the same.

This is not ceremony. The segmented control shows counts computed by the server; if JavaScript filtered the markers independently, the counts and the pins would drift apart and nothing would flag it. One filtering implementation, on the server, means they cannot disagree.

So: Stimulus controllers own **interaction** — debouncing, immediate visual feedback, wiring up a third-party SDK. They do not own **truth**. Anything that changes which records are displayed goes through a form submission or a link.

## The Two Google Keys

The single most expensive mistake available in this folder.

- `GOOGLE_MAPS_BROWSER_KEY` is what `nearby_map_controller` receives. It is restricted by **HTTP referrer** and is meant to be visible in the page — that is how browser keys work.
- `GOOGLE_MAPS_API_KEY` is the server-side Places key, restricted by **IP**. It must never reach a template or a Stimulus value. Restricted by IP, it would fail from a browser anyway; unrestricted, it would be abused.
- `AdvancedMarkerElement` requires a **vector** map with a `mapId`. Without one, markers silently render nothing and throw no error. This is the single hardest failure to diagnose in the Maps SDK — check `mapId` first, always.
- The Maps SDK is loaded **only on the page that needs it**, from inside `connect()`. Every map load bills against a monthly quota, so putting the script in the shared layout would charge every page view in the app.

## Working Rules

- **Every controller must survive its dependency being absent.** `nearby_map_controller` returns early when the key or map id is missing and catches SDK load failure, leaving the styled placeholder and the fully usable list below it. A blank screen because a third party did not load is never acceptable.
- **Clean up in `disconnect()`.** Turbo caches and restores pages, so a controller can connect twice. Detach markers, clear timers, remove overlays. `radius_controller` clears its debounce timer; `nearby_map_controller` unsets marker maps and the circle.
- **Read configuration from `static values`, never from globals.** Keys, coordinates, and payloads arrive as data attributes rendered by the server.
- **Keep the payload small.** Map points serialize only `id`, `lat`, `lng`, `name`, `status`. Never pass a whole record into a data attribute.
- **Label placement is presentation, not filtering.** `#layoutLabels` measures each label and hides the ones that would overlap a dot or an already-placed label — every pin still renders, so this is not client-side filtering. It runs on map `idle` and through a `ResizeObserver`, because a label measures 0 px until the marker is in the DOM and changes width again when the web font lands.
- **Progressive enhancement.** Filters are links and forms that work without JavaScript; controllers make them feel faster. `segmented_controller` is the clearest case — remove it and the control still works, it just updates a moment later.
- **No `fetch` to Google or any third party from the browser**, other than the Maps SDK itself. Places lookups go through the Rails proxy so the server-side key stays server-side.
- Use `element.requestSubmit()` rather than `.submit()` so Turbo intercepts the submission and the frame updates instead of the page reloading.
- **No user-visible strings in JavaScript.** Anything a person reads comes from the server as a value or as existing DOM. A label that needs translating cannot live here.

## Direct Upload

`ActiveStorage.start()` in `application.js` intercepts the **submit** event: it uploads every file input carrying `data-direct-upload-url` to S3, swaps it for a hidden field holding the blob's signed id, and only then lets the form submit for real.

Two consequences that are easy to get wrong:

- **Uploading starts on submit, not on change.** Photo inputs carry `data-direct-upload-url="/places/:place_id/direct_uploads"` instead of the generic endpoint, so the server can create the structured S3 key. A form that should upload as soon as a file is picked still needs `change->autosubmit#submit`. Waiting for a `direct-upload:*` event before submitting deadlocks.
- **Never submit the form yourself while uploads are in flight.** `direct_upload_controller` disables its `submit` targets between `direct-upload:start` and the last `direct-upload:end`; Active Storage's own re-submission is not affected by a disabled button.

`direct-upload:progress` carries `event.detail.progress` as a number 0–100. Rendering it is fine — a number is not a translatable string.

## Contracts

- **Controller ↔ markup.** `data-controller`, `data-*-target`, and `data-*-value` names are the interface. Renaming a target or value means updating every template that uses it — there is no compiler to catch a typo, only a silently inert controller.
- **`nearby_map_controller` ↔ `#radius_form`.** The controller writes into the form's `lat` and `lng` fields by id and name. Renaming the form or those fields breaks pin dragging silently.
- **`nearby_map_controller` ↔ `data-place-row-id` on `shared/_place_row`.** The marker's number is the row's number, and clicking a pin highlights that row by this attribute. Renaming it silently kills the pin↔row link; the number itself comes from `_place_row_list`'s `numbered:` local, so both sides must stay in the distance order the server returned.
- **`_place_grid` / `_place_row_list` ↔ frame id.** Forms and links target the `place_list` frame; the partial declares it. A mismatch produces an empty frame with no error.
- **New dependency ↔ `config/importmap.rb`.** A library must be pinned there before it can be imported. There is no `package.json`.

## Verification

There is no JavaScript test suite. Verify in the browser, using the `agent-browser` skill — see "Browser Checks" in the root file.

Adding or editing a `*_controller.js` needs **no restart** — importmap-rails watches `app/javascript` and re-sweeps its cache on each request in development. Editing `config/importmap.rb` **does** need `docker compose restart web`, because that file is not watched.

```bash
docker compose exec web cat config/importmap.rb   # confirm a dependency is pinned
docker compose restart web                        # only after editing config/importmap.rb
```

For map work specifically: confirm the map renders, confirm markers appear (this is where a missing `mapId` shows up), drag the centre pin and confirm the **list below** re-renders from the server, then reload with the key blanked out and confirm the page is still fully usable.

## Boundaries

Never:

- Put the server-side Google API key into a template, a data attribute, or a Stimulus value.
- Load the Maps SDK from the shared layout or from any page other than the map page.
- Filter, sort, or paginate records in JavaScript.
- Call a third-party API directly from the browser.
- Leave a timer, listener, or map overlay attached in `disconnect()`.
- Hardcode a user-visible string.
- Add `npm`, `yarn`, or a bundler step. Pin in `config/importmap.rb`.
- Manually register a controller in `index.js` — the loader picks up `*_controller.js`.
- Reach across controllers via globals. Pass state through the DOM or through a form.
- Use `.submit()` where `.requestSubmit()` is wanted; the former bypasses Turbo.

## Naming Convention

- Files are `<thing>_controller.js` and the identifier is the dasherized stem: `nearby_map_controller.js` → `data-controller="nearby-map"`.
- Controllers are named for **what they control**, never for the page: `radius`, `clipboard`, `segmented`, `nearby-map`. Not `nearby-page`, not `map-helper`.
- Actions are verbs with no `handle` or `on` prefix: `preview()`, `submit()`, `copy(event)`, `select(event)`. Not `handleInput()`, not `onCopyClick()`.
- Private methods use real JavaScript `#`, not a leading underscore: `#loadSdk()`, `#zoomForRadius()`, `#recentre()`, `#renderLabel()`.
- `static values` are named for the data they hold: `apiKeyValue`, `mapIdValue`, `centerValue`, `placesValue`. `static targets` for the DOM role: `canvasTarget`, `inputTarget`, `outputTarget`, `sourceTarget`.
- Locals are spelled out — `userPlace`, `marker`, `place` — except in one-line callbacks.
- Banned words, same as the Ruby side: `data`, `info`, `manager`, `handler`, `util`, `process`, `temp`.

## Flow Design: Isolation over Parameterization

**✅ PREFER:** one controller per behaviour, composed by putting several `data-controller` names on the same element or on nested elements. A controller that does one thing is testable by hand in ten seconds.

**❌ AVOID:** a `page_controller` with a `mode` value that branches into unrelated behaviours. A shared controller that checks `if (this.hasMapTarget)` to decide what kind of screen it is on.

**The guardrail for this folder:** if a controller's `connect()` starts with a branch on which page it is, it is two controllers. Split it.
