# PSS 2.0 — Login Page Designer (Screen #85 OrgSettings, LOGIN group)

> **Status:** NOT BUILT — ready to build
> **Type:** `/continue-screen #85` extend pass (screen #85 is COMPLETED; this is not a new screen)
> **Screen prompt:** `.claude/screen-tracker/prompts/orgsettings.md`
> **Created:** 2026-08-08
> **Model:** Sonnet for BE + FE build agents (§①–⑫ below is detailed)

---

## §① Why this exists

The `LOGIN` setting group is seeded, the 11 login templates are built, and the anonymous
SSR login page already renders them ([login/index.tsx](PSS_2.0_Frontend/src/presentation/pages/auth/login/index.tsx),
`GetTenantLoginConfigQuery`, `HostTenantResolver`). **Only the editor is missing.**

Today a tenant admin configures their login page by typing raw JSON into a single-line
`<Input type="text">`, because [setting-row.tsx](PSS_2.0_Frontend/src/presentation/components/page-components/setting/orgsettings/orgsettings/components/setting-row.tsx)
switches on 8 `paramDataType` values (`STRING · EMAIL · NUMBER · BOOLEAN · SELECT ·
MULTI_CHECK · TAGS · TIME`) and has **no `JSON` case** — `LOGIN_TEMPLATE_PAYLOAD` falls to
`default:`. There is also no colour picker and no media field.

This pass replaces that with a **Login Page Designer**: template gallery + typed payload
fields + live preview, driven by a **fixed JSON structure**.

### Hard constraints (from the user, non-negotiable)

| # | Constraint |
|---|---|
| C1 | **NO entity-level changes.** No new columns, no `Add-Migration`, no snapshot edit, no EF configuration change. New ParamCodes are *seed rows*, which is data — that is allowed. |
| C2 | **The payload JSON has a FIXED structure.** Every template slot carries the identical key set. No free-form / per-template-divergent shapes. |
| C3 | Only the `LOGIN` group stays visible. The other 12 groups are disabled (data flag, not code). |
| C4 | Uploads must be **uniform** — one shared component used by every media field. |
| C5 | Migrations and `.sql` seeds are authored/applied by the user, never run by the agent. |

---

## §② The fixed JSON structure — `LOGIN_TEMPLATE_PAYLOAD`

This is the contract. Do not deviate; key names are chosen to match the **existing** BE
reader in `GetTenantLoginConfigQuery.BuildDtoAsync` exactly, so the reader needs **zero changes**.

```jsonc
{
  "schemaVersion": 1,

  "HERO_IMAGE":                { /* slot */ },
  "HERO_IMAGE_FULL":           { /* slot */ },
  "HERO_CAROUSEL_SPLIT":       { /* slot */ },
  "HERO_CAROUSEL_OVERLAY":     { /* slot */ },
  "HERO_CAROUSEL_TESTIMONIAL": { /* slot */ },
  "HERO_VIDEO":                { /* slot */ },
  "HERO_VIDEO_SPLIT":          { /* slot */ },
  "HERO_VIDEO_OVERLAY":        { /* slot */ },
  "CARD_MINIMAL":              { /* slot */ },
  "CARD_GLASS":                { /* slot */ },
  "CARD_GRADIENT":             { /* slot */ }
}
```

**Every one of the 11 slots has this identical shape — all 7 keys always present:**

```jsonc
{
  "headline":    "",        // string,  max 60
  "subheadline": "",        // string,  max 140
  "imageUrl":    "",        // string,  absolute http(s) URL or ""
  "videoUrl":    "",        // string,  absolute http(s) URL or ""
  "posterUrl":   "",        // string,  absolute http(s) URL or ""   ← NOT videoPosterUrl
  "slides":      [],        // array of slide objects (see below), max 8
  "autoplayMs":  5000       // integer, 2000..20000
}
```

Slide object — also fixed, all 4 keys always present:

```jsonc
{
  "imageUrl": "",           // string, absolute http(s) URL or ""
  "caption":  "",           // string, max 120
  "linkUrl":  "",           // string, absolute http(s) URL or ""
  "orderBy":  1             // integer, 1-based, contiguous
}
```

### Rules

1. **Fixed means fixed.** A slot always serialises all 7 keys, even when the active template
   ignores them (`CARD_MINIMAL` still writes `imageUrl: ""` and `slides: []`). Unused keys are
   inert — the BE reader returns `null` for empty strings via existing null-coalescing, and the
   FE templates already guard on falsy media.
2. **Normalise on load.** When the FE reads a payload, run it through a
   `normalizePayload()` that fills missing slots and missing keys with the defaults above.
   This upgrades every existing `{}` and any legacy partial slot in one place, with no data migration.
3. **`schemaVersion` is a root sibling, not a slot.** `TryGetTemplateSlot` enumerates root
   properties and only matches `ValueKind == Object`, so a number is skipped safely.
   Verified against `GetTenantLoginConfigQuery.cs`.
4. **Editing one slot must not touch the other ten.** Serialise the whole normalised object;
   never hand-splice strings.
5. **Never write a `data:` URL into this payload.** See §④.

### Which fields each template actually uses (drives what the form *shows*)

All slots store all keys; this table only controls **field visibility** in the editor.

| Template code | headline | subheadline | imageUrl | videoUrl | posterUrl | slides | autoplayMs |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| `HERO_IMAGE` | ✅ | ✅ | ✅ | | | | |
| `HERO_IMAGE_FULL` | | | ✅ | | | | |
| `HERO_CAROUSEL_SPLIT` | | | | | | ✅ | ✅ |
| `HERO_CAROUSEL_OVERLAY` | | | | | | ✅ | ✅ |
| `HERO_CAROUSEL_TESTIMONIAL` | | | | | | ✅ | ✅ |
| `HERO_VIDEO` | ✅ | ✅ | | ✅ | ✅ | | |
| `HERO_VIDEO_SPLIT` | ✅ | ✅ | | ✅ | ✅ | | |
| `HERO_VIDEO_OVERLAY` | ✅ | ✅ | | ✅ | ✅ | | |
| `CARD_MINIMAL` | ✅ | ✅ | | | | | |
| `CARD_GLASS` | ✅ | ✅ | | | | | |
| `CARD_GRADIENT` | ✅ | ✅ | | | | | |

Encode this as a **single FE registry** — `template-field-schema.ts` — sitting next to
`TemplateMap`. Both maps are keyed by the same 11 codes; a code missing from either is a bug.

---

## §③ New ParamCodes (seed rows only — NOT entity changes)

The mockup's "Additional Options" toggles do not exist yet. Add them as normal
`OrganizationSettings` rows in the `LOGIN` group, so they get free validation, reset,
per-user override and audit. **They are deliberately NOT in the JSON payload** — they apply to
the shared login *form*, not to any one template.

| ParamCode | ParamName | DataType | AllValues | Default | Description |
|---|---|---|---|---|---|
| `LOGIN_SHOW_REMEMBER_ME` | Login Show Remember Me | `BOOLEAN` | null | `true` | Show the "Remember me" checkbox on the login form |
| `LOGIN_SHOW_FORGOT_PASSWORD` | Login Show Forgot Password | `BOOLEAN` | null | `true` | Show the "Forgot password?" link |
| `LOGIN_SHOW_REGISTER_LINK` | Login Show Register Link | `BOOLEAN` | null | `false` | Show the self-registration link |
| `LOGIN_FOOTER_TEXT` | Login Footer Text | `STRING` | null | null | Small print under the login form (e.g. copyright) |

All four: `CanUserOverride: false` — these are org-level presentation, and the login page is
rendered **before** any user is known, so a per-user override could never be read.

> **"Enable Social Login" from the mockup is deliberately omitted.** There is no social auth
> provider anywhere in the product. Shipping the toggle would ship a control that does nothing.
> Add it when an OAuth provider lands.

**Also change `LOGIN_TEMPLATE_PAYLOAD`'s `Description`** to point at §② of this document rather
than the free-form prose it has today.

### Counts to bump — miss this and auto-seed silently never fires

`Base.Application/.../Seeders/IOrgSettingsDefaultSeeder.cs`:

```csharp
public const int ExpectedGroupCount   = 13;    // unchanged
public const int ExpectedSettingCount = 124;   // was 120, +4 new LOGIN codes
```

`GetOrganizationSettingsView.cs:63-64` gates seeding on `settingCount < ExpectedSettingCount`,
so bumping the constant is what causes existing tenants to pick the new rows up on next load.
`OrgSettingsDefaultSeeder` is INSERT-WHERE-NOT-EXISTS, so re-running is safe.

---

## §④ Uploads — one component, URL-first, upload-slot-ready

**There is no file-storage backend in this product.**
[file-upload-card.tsx](PSS_2.0_Frontend/src/presentation/components/page-components/setting/orgsettings/companysettings/components/file-upload-card.tsx)
is explicitly labelled `SERVICE_PLACEHOLDER` and base64s the file into form state;
`presentation/lib/uploadthing.tsx` is 100% commented out and its `@/app/api/uploadthing/route`
does not exist. Grant attachments already fell back to URL-paste for the same reason.

A data-URL is **especially** wrong here: `LOGIN_TEMPLATE_PAYLOAD` is a text KV column read by an
**anonymous, SSR, 60-second-cached** query. A 400 KB base64 hero image becomes 400 KB of HTML on
every cold login render, for every visitor, forever.

**Build `media-url-field.tsx` as the single uniform media control** (`components/fields/`):

- URL text input + paste support
- Live thumbnail preview with a shaped `Skeleton` while loading, and a broken-image fallback
- Clear (✕) button
- Inline validation: must be `http://` or `https://`, must not start with `data:`
- Caption line for recommended dimensions (`caption` prop)
- An **`Upload` button rendered `disabled`** with tooltip *"File upload not yet available — paste a hosted image URL"*

`accept` / `caption` / `label` / `value` / `onChange` / `required` props mirror the existing
`file-upload-card` signature so the swap is mechanical when blob storage lands. When it does,
**only this one file changes** and every media field in the app gains upload.

Use `MediaUrlField` for: `imageUrl`, `videoUrl`, `posterUrl`, and each slide's `imageUrl`.
Do **not** rewrite `file-upload-card.tsx` in this pass (it belongs to #75) — but leave a
`// TODO(#85): supersede with MediaUrlField once storage lands` comment on it.

---

## §⑤ The #75 / #85 ownership boundary — read-only mirror

`LOGO_URL`, `PRIMARY_COLOR_HEX`, `SECONDARY_COLOR_HEX` are listed in
`SettingsOwnership.CompanySettingsOwnedParamCodes`, so `GetOrganizationSettingsView` already
**subtracts them from #85's payload entirely**. The mockup nevertheless shows logo + primary +
secondary colour inside the Login pane, and `GetTenantLoginConfigQuery` reads all three.

**Decision: mirror, do not duplicate.**

- Do **not** add these codes to #85's editable set, and do **not** amend `SettingsOwnership`.
  A second editor re-opens the last-writer-wins hazard that partition was created to close.
- The designer shows a compact **read-only "Brand identity" strip** — logo thumbnail, two colour
  swatches, hex labels — with a `Manage in Company Settings →` link to the #75 route.
- The **live preview must use the real values**, so the designer needs them. Read them from the
  existing Company Settings query (`companySettings` / `GetCompanySettings`) — verify the actual
  HotChocolate field name against the resolver before writing the query; `Get` is stripped.
- If that query is unavailable to a non-#75 route, fall back to the theme CSS variables already
  injected by the app shell, and render the strip from those.

`LOGIN_PAGE_BACKGROUND_COLOR` **is** login-owned and fully editable here.

---

## §⑥ UI blueprint

Route and shell are unchanged: `setting/orgsettings/{slug}/`, `orgsettings-page.tsx`,
`CategoryNav` left, `SettingCard` right, `ChangeBar` + sticky **Save All**.
`SettingCard` gains a dispatch: `settingGroupCode === "LOGIN"` → `<LoginDesignerPanel/>`,
everything else → the existing `SettingRow` list. Nothing else about the page changes.

### Panel layout — two columns from `lg` up, stacked below

```
┌───────────────────────────────────────────┬──────────────────────────┐
│ ① Template                                 │  LIVE PREVIEW            │
│   [Image ▾][Carousel ▾][Video ▾][Pattern ▾]│  ┌────────────────────┐  │
│   ┌────┐ ┌────┐ ┌────┐                     │  │                    │  │
│   │ ✅ │ │    │ │    │   gallery cards      │  │  real template     │  │
│   └────┘ └────┘ └────┘   + Skeleton        │  │  component, scaled │  │
│                                             │  │                    │  │
│ ② Content  (fields per §② visibility table) │  └────────────────────┘  │
│   Headline            [____________] 16/60  │   [ Desktop | Mobile ]   │
│   Subheadline         [____________] 36/140 │   [ Open full preview ↗] │
│   Hero Image          [MediaUrlField]       │                          │
│   Slides              [repeater]            │  (sticky, lg+ only)      │
│                                             │                          │
│ ③ Appearance                                │                          │
│   Background Color    [ColorField]          │                          │
│   ── Brand identity (read-only) ──          │                          │
│   [logo] ██ #43436F  ██ #7C3AED             │                          │
│   Manage in Company Settings →              │                          │
│                                             │                          │
│ ④ Login Form Options                        │                          │
│   Remember Me         [toggle]              │                          │
│   Forgot Password     [toggle]              │                          │
│   Register Link       [toggle]              │                          │
│   Footer Text         [____________]        │                          │
└───────────────────────────────────────────┴──────────────────────────┘
```

### ① Template gallery

- Cards grouped by category (Image · Carousel · Video · Pattern), category = the code prefix.
- Each card: thumbnail, template display name, one-line description, radio semantics
  (`role="radio"`, arrow-key roving tabindex, `aria-checked`).
- The **active** card gets a solid `bg-emerald-600 text-white` "Active" badge and a
  `ring-2 ring-primary` border. Per the design-system rule: solid background + white text,
  never `bg-emerald-50 / text-emerald-700`.
- **Thumbnails are static assets, not live renders.** 11 simultaneous live renders (3 with
  `<video>`) is unacceptable. Ship lightweight SVG thumbnails under
  `public/images/login-templates/{code}.svg` — flat shapes showing the layout skeleton
  (hero block / form block / dots), tinted with `currentColor` so they read in both themes.
  Show a shaped `<Skeleton className="aspect-[16/10] w-full rounded-md"/>` until loaded.
- **Switching template must not clear anything.** It writes `LOGIN_TEMPLATE_CODE` only; all 11
  payload slots stay byte-identical. Show a one-line hint: *"Each template keeps its own content."*

### ② Content fields

Rendered from `template-field-schema.ts` for the currently-selected code. Field kinds:

| Kind | Control |
|---|---|
| `text` | `Input` + live `n/max` counter, right-aligned, muted; turns `text-destructive` past max |
| `media` | `MediaUrlField` (§④) |
| `number` | `Input type=number` with the min/max from §② |
| `slides` | Repeater — see below |

**Slides repeater:** ordered list of cards, each with `MediaUrlField` + caption + link URL,
a drag handle (or ▲▼ buttons — keyboard-reachable either way), and a delete button.
`orderBy` is **derived from array position on write** (1-based, contiguous) — never an editable
field. `Add slide` disabled at 8. Empty state: a dashed placeholder with `Add your first slide`.

### ③ Appearance

`ColorField` — new shared widget: native `<input type="color">` swatch + hex text input, kept in
sync, validated `^#[0-9A-Fa-f]{6}$`, with a small palette of 8 preset swatches. Used for
`LOGIN_PAGE_BACKGROUND_COLOR` and wired into `setting-row.tsx` as a `COLOR` case for future use.

### ④ Login form options

Plain `ToggleWidget` / `Input` rows — reuse `SettingRow` directly for these four ParamCodes
rather than re-implementing. They are ordinary settings.

### Live preview — the key decision

**Render the real template components.** They already accept `TenantLoginConfigDto`
([TenantLoginConfigDto.ts](PSS_2.0_Frontend/src/domain/entities/auth-service/TenantLoginConfigDto.ts)),
so the preview is the genuine article, not a mock — WYSIWYG by construction, zero duplicated
rendering code.

```
draft store state ──► buildPreviewConfig() ──► TenantLoginConfigDto ──► TemplateMap[code]
```

- `buildPreviewConfig()` lives in `live-preview.tsx` and assembles the DTO from **unsaved**
  store values + the mirrored brand values from §⑤. It is the *only* place the two sources merge.
- Wrap in a container with `transform: scale()` + `transform-origin: top left`, sized by the
  viewport toggle: **Desktop 1280×800**, **Mobile 390×844**. Scale factor = containerWidth/1280.
- Wrap the whole preview in an **error boundary** — a malformed draft must degrade to
  *"Preview unavailable"*, never white-screen the settings page.
- Set `pointer-events: none` and `aria-hidden="true"` on the preview subtree so its login form is
  not focusable or submittable, and does not duplicate form landmarks for screen readers.
- **Autoplay off in preview** for carousel and video templates (pass `autoplayMs` through but have
  the preview wrapper set `data-preview` and freeze on slide 1 / poster frame). A looping video
  behind a settings form is hostile.
- `Open full preview ↗` opens `/login?_tenant={subdomain}&_preview=1` in a new tab. **Non-production
  only** — the `_tenant` override is already dev-gated in `GetTenantLoginConfigHandler`, so in
  production render this button `disabled` with the reason.
- Debounce preview recompute at ~250 ms; memoise on the serialised draft slot.
- Below `lg` the preview collapses into a `Preview` button that opens it in a `Sheet`.

### Loading and empty states

- Panel skeleton while the settings query is in flight: gallery = 6 shaped card skeletons,
  form = 4 row skeletons, preview = one `aspect-video` skeleton. Reuse the existing
  `CardSkeleton` idiom from `orgsettings-page.tsx`.
- Malformed stored payload → `normalizePayload()` repairs it silently and the panel shows a
  dismissible amber inline note: *"Saved layout content was incomplete and has been reset to
  defaults for the affected fields. Save to persist."*

---

## §⑦ Save semantics

Unchanged: the existing `save-all` model. The designer writes into the **same**
`orgsettings-store` as every other group.

- Editing any payload field → recompute the full normalised payload object →
  `setValue("LOGIN_TEMPLATE_PAYLOAD", JSON.stringify(payload))`.
  One store key, one dirty flag, one `BulkUpdateOrgSettings` item. **No new mutation.**
- `JSON.stringify` with no pretty-printing (this is machine-read, and the column is text).
- Reset on `LOGIN_TEMPLATE_PAYLOAD` reverts the whole payload — that is correct and matches every
  other row. The designer shows the yellow dirty treatment on the panel header, not per-field.
- `ChangeBar` count and the `beforeunload` guard work unchanged.

---

## §⑧ Backend work — no entity changes, no migration

| # | File | Change |
|---|---|---|
| B1 | `Base.Infrastructure/Seeders/OrgSettingsDefaultSeeder.cs` | Add the 4 `DefaultSetting` rows from §③ to the `LOGIN` block. Replace the `LOGIN_TEMPLATE_PAYLOAD` description. Replace the long JSON-shape comment with the §② fixed structure. |
| B2 | `Base.Application/.../Seeders/IOrgSettingsDefaultSeeder.cs` | `ExpectedSettingCount` 120 → **124**. |
| B3 | `Base.Application/.../Validators/OrgSettingsValueValidator.cs` | Add 3 rules — see below. |
| B4 | `Base.Application/.../AuthBusiness/TenantLoginConfig/Queries/GetTenantLoginConfigQuery.cs` | Add the 4 new codes to `BrandingParamCodes`; project them onto the DTO. **`BuildDtoAsync`'s slot-reading code and `TryGetTemplateSlot` are unchanged** — §②'s key names were chosen to match. |
| B5 | `Base.Application/.../AuthBusiness/TenantLoginConfig/TenantLoginConfigDto.cs` (+ FE twin) | Add `ShowRememberMe`, `ShowForgotPassword`, `ShowRegisterLink` (`bool`, defaults `true/true/false`) and `LoginFooterText` (`string?`). |
| B6 | `login-form.tsx` + the 11 templates | Honour the 4 new DTO fields. Templates already receive `config`; thread it into `LoginForm`. |

**B3 validator rules** (added to the `_rules` map, following the existing `ParamCodes` constants idiom):

```
LOGIN_TEMPLATE_PAYLOAD  → ValidateLoginPayloadJson
LOGIN_PAGE_BACKGROUND_COLOR → ValidateHexColor    (^#[0-9A-Fa-f]{6}$)
LOGIN_TEMPLATE_CODE     → ValidateTemplateCode    (member of the 11)
```

`ValidateLoginPayloadJson` must:
1. accept null/blank (existing convention: blank passes)
2. `JsonDocument.Parse` → on `JsonException` return *"Login layout content is not valid JSON."*
3. root must be an object
4. every root property other than `schemaVersion` must be one of the 11 codes → otherwise
   *"Unknown login template '{name}' in layout content."*
5. every slot must be an object; `slides` if present must be an array of ≤ 8 objects;
   `autoplayMs` if present must be a number in 2000..20000
6. **reject any string value starting with `data:`** → *"Embedded file data is not allowed. Paste a hosted URL."*
   This is the guard that keeps §④'s hazard out of the DB even if the FE is bypassed.
7. reject a serialised payload over **8 KB** → *"Login layout content is too large."*

Rule 6 and 7 are the security-relevant ones. Do not skip them; the value reaches an
anonymous SSR surface.

**Explicitly NOT in scope:** no new migration, no `Base.Domain` change, no EF configuration
change, no new GraphQL mutation, no `SettingsOwnership.cs` change.

---

## §⑨ Disabling the other 12 groups

`SettingGroup.IsVisibleInUI` already exists on the entity and is **already filtered** by
`GetOrganizationSettingsView.cs:81`. So this is a data flip, not code.

**Agent deliverable** — write `sql-scripts-dyanmic/setting-group-visibility-login-only.sql`
(one script per file, the file *is* the thing to execute, result `SELECT` at the end is fine).
It must:

- `UPDATE sett."SettingGroups" SET "IsVisibleInUI" = false WHERE "SettingGroupCode" <> 'LOGIN'`
- `UPDATE ... SET "IsVisibleInUI" = true WHERE "SettingGroupCode" = 'LOGIN'`
- touch **no rows in `OrganizationSettings`** — values stay intact, every `IOrgSettingsService`
  read still resolves, and re-enabling later is one `UPDATE`
- end with `SELECT "SettingGroupCode", "SettingGroupName", "IsVisibleInUI" FROM sett."SettingGroups" ORDER BY "OrderBy";`

**The user applies this script. The agent does not run it.**

Also mirror the flag in the seeder so a *newly provisioned* tenant is consistent: give the
`DefaultGroup` record an `IsVisibleInUI` parameter defaulting to `true`, set `false` on the 12,
`true` on `LOGIN`. **First verify `SettingGroup.Create(...)` accepts it** — if the factory does not
expose `isVisibleInUI`, set the property after construction rather than changing the domain
factory signature (C1).

Two consequences to handle:
- `CategoryNav` will render a single item. That is fine, but hide the nav column entirely when
  `groups.length === 1` and let the panel take full width.
- The page's search box filters across groups; with one group it is noise. Hide it under the
  same condition.

---

## §⑩ Files

**New (FE)** — all under
`src/presentation/components/page-components/setting/orgsettings/orgsettings/`:

```
login-designer/
  login-designer-panel.tsx      orchestrates ①②③④ + preview
  template-gallery.tsx          cards, categories, skeletons, roving focus
  template-field-schema.ts      the §② registry (11 codes → visible fields)
  payload-fields.tsx            text / media / number field rendering
  slides-repeater.tsx           the slides array editor
  live-preview.tsx              buildPreviewConfig + scaled render + error boundary
  payload-schema.ts             types, DEFAULT_SLOT, normalizePayload(), serializePayload()
fields/
  media-url-field.tsx           §④ — the uniform media control
  color-field.tsx               §③ — swatch + hex
```

**New (static):** `public/images/login-templates/{11 codes}.svg`

**Modified (FE):** `components/setting-card.tsx` (dispatch), `components/setting-row.tsx`
(add `COLOR` + `MEDIA` cases; leave `JSON` on `default:` — LOGIN is the only JSON group in scope
and it bypasses the row renderer), `orgsettings-page.tsx` (hide nav + search when one group),
`domain/entities/auth-service/TenantLoginConfigDto.ts`, `presentation/pages/auth/login/login-form.tsx`
and the 11 template files.

**Modified (BE):** the five files in §⑧.

**New (SQL, user-applied):** `sql-scripts-dyanmic/setting-group-visibility-login-only.sql`

---

## §⑪ Acceptance criteria

1. `LOGIN` is the only group visible in Organization Settings; the nav column and search box are hidden.
2. Selecting a template card updates `LOGIN_TEMPLATE_CODE`, marks the panel dirty, and updates the
   preview — **and the other 10 payload slots are byte-identical afterwards** (assert on the
   serialised string).
3. Saving from a tenant whose payload was `{}` produces a payload with `schemaVersion: 1` and all
   11 slots fully populated with the §② default keys.
4. Round-trip: save → reload → every field shows what was saved; the preview matches the real
   `/login` page for that tenant.
5. Pasting a `data:` URL into any `MediaUrlField` is rejected client-side; a direct
   `bulkUpdateOrgSettings` call carrying one is rejected server-side with the §⑧ rule-6 message.
6. A payload > 8 KB is rejected server-side.
7. Malformed stored JSON does not crash the panel — it normalises and shows the amber note.
8. The preview's login form is not focusable, not submittable, and carousel/video do not autoplay.
9. Brand identity strip is read-only and links to Company Settings; no #85 mutation ever writes
   `LOGO_URL`, `PRIMARY_COLOR_HEX`, or `SECONDARY_COLOR_HEX`.
10. The 4 new toggles change the rendered `/login` page for an anonymous visitor.
11. `npx tsc --noEmit --incremental false` exits **0**.
12. No file under `Base.Domain/`, no `Migrations/` file, and no `*ModelSnapshot.cs` is modified.

---

## §⑫ Service placeholders / known limits

| # | Limit | Reason | Unblocks when |
|---|---|---|---|
| P1 | Media fields are URL-paste; the Upload button is disabled | No blob storage provisioned anywhere in the product (§④) | Storage account + container; then only `media-url-field.tsx` changes |
| P2 | Template thumbnails are hand-authored SVGs, not renders of the real templates | 11 live renders is too heavy; screenshotting needs a pipeline that does not exist | Optional: a build-time screenshot step later |
| P3 | `Open full preview` is disabled in production | `?_tenant=` override is dev-gated in `GetTenantLoginConfigHandler` | A signed preview token, if ever needed |
| P4 | "Enable Social Login" not implemented | No OAuth provider exists (§③) | Social auth lands |
| P5 | The other 12 groups are hidden, not migrated | Deliberate — user scope decision, reversible with one `UPDATE` | User re-enables |

---

## §⑬ Build log

_(empty — not built yet)_

### Owed by the user before this behaves correctly

- Apply `sql-scripts-dyanmic/setting-group-visibility-login-only.sql` (§⑨). Until then all 13
  groups remain visible.
- Nothing else. **This pass requires no migration.**
