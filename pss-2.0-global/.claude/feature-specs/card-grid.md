---
name: CardGrid (displayMode: card-grid)
status: NOT_BUILT
owner: Frontend Developer agent
first_consumer: Screen #29 SMS Template (Wave 2.4)
related_screens: [24, 29, 31, 36]
last_updated: 2026-04-18
---

# Feature Spec — CardGrid (`displayMode: card-grid`)

> Authoritative build spec for the card-grid rendering infrastructure. Screens only **reference** this feature in their spec (`displayMode: card-grid`); the actual components are built by the first screen that consumes them, following this document.

---

## ① Purpose

Some screens (templates, contacts, media libraries, catalog lists) cannot communicate meaningful record data in dense table rows. Users need a scan-friendly card layout. Meanwhile, the filtering / pagination / CRUD / permissions logic is identical to a table listing — forking a new screen type for the rendering change would double the pipeline.

**Solution**: a `displayMode` seam on existing MASTER_GRID and FLOW screens. When `displayMode: card-grid` is set, the data-table wrapper renders records through a **variant-registry-based** card renderer instead of table rows. Everything around it — filters, search, sort, pagination, toolbar — stays identical.

The variant registry mirrors the existing `elementMapping` convention (grid cell renderers) — same pattern, same extension model, same mental load for developers.

---

## ② Scope

### In scope (build this)

- Responsive grid shell `<CardGrid>`
- Variant registry (`card-variant-registry.ts`)
- Three initial card variants + their skeletons: `details`, `profile`, `iframe`
- Wiring into the existing `AdvancedDataTable` / `DataTableContainer`
- `PageConfig` type additions: `displayMode`, `cardVariant`, `cardConfig`

### Out of scope (do NOT build)

- User-facing table↔card toggle (future enhancement — design this to be easy to add, but don't ship it now)
- Carousel / slider / masonry layouts (rejected — see frontend-developer.md anti-patterns)
- Card-level animations / transitions beyond simple hover state
- Server-side card rendering / virtualization (not needed until we see 500+ card lists)
- Column resizing, column reorder, sort headers when in card mode (not applicable)

---

## ③ Architecture

### Folder layout (create these paths)

```
PSS_2.0_Frontend/src/presentation/components/page-components/card-grid/
  card-grid.tsx                    ← responsive shell, never changes per screen
  card-variant-registry.ts         ← maps cardVariant → { Card, Skeleton }
  types.ts                         ← CardVariant, CardConfig (discriminated union)
  index.ts                         ← barrel exports
  variants/
    details-card.tsx               ← name + meta chips + plain snippet + footer
    profile-card.tsx               ← avatar + name + role + contact actions
    iframe-card.tsx                ← sandboxed HTML preview + metadata overlay
  skeletons/
    details-card-skeleton.tsx
    profile-card-skeleton.tsx
    iframe-card-skeleton.tsx
  helpers/
    strip-html.ts                  ← safe plain-text extraction for details snippet
    format-modified-ago.ts         ← uses existing date formatter if present
```

### Why this shape

- `card-grid/` is colocated with `page-components/` (not `custom-components/`) because it's a **listing surface composition**, not a primitive. Matches where `AdvancedDataTable` is wired up.
- Variants live in their own folder so adding one = adding one file. Shell stays untouched.
- Skeletons live in their own folder with 1:1 naming (`details-card.tsx` ↔ `details-card-skeleton.tsx`). No clever reuse — skeletons are shape-specific.
- `helpers/` for anything a variant needs but isn't a card itself.

---

## ④ Types (build this first)

Place in `card-grid/types.ts`:

```ts
export type CardVariant = "details" | "profile" | "iframe";

// ───────────────────────────────────────────────────────────────
// Per-variant config shapes (discriminated union by `variant`)
// ───────────────────────────────────────────────────────────────

export interface DetailsCardConfig {
  variant: "details";
  headerField: string;            // primary title field — required
  metaFields: string[];           // 1-3 fields rendered as chips
  snippetField: string;           // plain-text body; HTML stripped
  footerField: string;            // e.g., modifiedAt (formatted as "2d ago")
  snippetMaxChars?: number;       // default 100
}

export interface ProfileCardConfig {
  variant: "profile";
  avatarField: string | null;     // null → render initials from nameField
  nameField: string;              // required
  subtitleField: string;          // role / title / category
  metaFields: string[];           // 1-2 rows (e.g., email, phone)
  contactActions?: ContactAction[]; // optional inline icons
}

export type ContactAction = "email" | "phone" | "whatsapp" | "sms";

export interface IframeCardConfig {
  variant: "iframe";
  htmlField: string;              // rich HTML to render in sandboxed iframe
  headerField: string;            // overlay title
  metaFields: string[];           // overlay chips
  fallbackSnippetField: string;   // plain-text used if html empty/oversized
  maxHtmlBytes?: number;          // default 100_000
}

export type CardConfig =
  | DetailsCardConfig
  | ProfileCardConfig
  | IframeCardConfig;

// ───────────────────────────────────────────────────────────────
// Grid + card renderer props (what every variant receives)
// ───────────────────────────────────────────────────────────────

export interface CardProps<TRow = Record<string, unknown>> {
  row: TRow;
  config: CardConfig;
  onCardClick?: (row: TRow) => void;
  rowActions: RowAction<TRow>[];  // reuses existing RowAction type from data-tables
}

export interface CardGridProps<TRow = Record<string, unknown>> {
  rows: TRow[];
  variant: CardVariant;
  config: CardConfig;
  loading: boolean;
  loadingCount?: number;          // default 8
  empty: boolean;
  emptyLabel?: string;
  onCardClick?: (row: TRow) => void;
  rowActions: RowAction<TRow>[];
}
```

Note: `RowAction<TRow>` should reuse whatever shape the existing `AdvancedDataTable` uses for row actions — do NOT invent a new one. Find it in `src/presentation/components/custom-components/data-tables/advanced/data-table-crud-options/`.

---

## ⑤ Component implementations

### ⑤.1 `<CardGrid>` shell (`card-grid.tsx`)

Single responsibility: responsive grid, loading state, empty state, variant dispatch.

```tsx
"use client";

import { cardVariantRegistry } from "./card-variant-registry";
import type { CardGridProps } from "./types";

export function CardGrid<TRow>({
  rows,
  variant,
  config,
  loading,
  loadingCount = 8,
  empty,
  emptyLabel = "No records yet",
  onCardClick,
  rowActions,
}: CardGridProps<TRow>) {
  const entry = cardVariantRegistry[variant];
  if (!entry) {
    // Dev-time error — variant missing from registry
    return (
      <div className="rounded-lg border border-destructive/40 bg-destructive/5 p-4 text-sm text-destructive">
        Unknown cardVariant: {variant}
      </div>
    );
  }

  const { Card, Skeleton } = entry;

  if (loading) {
    return (
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
        {Array.from({ length: loadingCount }).map((_, i) => (
          <Skeleton key={i} />
        ))}
      </div>
    );
  }

  if (empty) {
    return (
      <div className="flex min-h-[240px] flex-col items-center justify-center rounded-lg border border-border bg-card text-center">
        <Icon icon="ph:folder-open" className="mb-2 h-8 w-8 text-muted-foreground" />
        <p className="text-sm text-muted-foreground">{emptyLabel}</p>
      </div>
    );
  }

  return (
    <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
      {rows.map((row, idx) => (
        <Card
          key={(row as { id?: string | number }).id ?? idx}
          row={row}
          config={config}
          onCardClick={onCardClick}
          rowActions={rowActions}
        />
      ))}
    </div>
  );
}
```

**Rules:**
- No hardcoded widths. Grid auto-sizes columns.
- `gap-3` fixed. Do not vary.
- Empty state uses the same `rounded-lg border border-border bg-card` framing as a real card (consistent with UI Uniformity Rule 6).
- Unknown variant renders a loud dev error — fail fast, don't silently fall back.

### ⑤.2 Variant registry (`card-variant-registry.ts`)

```ts
import { DetailsCard } from "./variants/details-card";
import { ProfileCard } from "./variants/profile-card";
import { IframeCard } from "./variants/iframe-card";
import { DetailsCardSkeleton } from "./skeletons/details-card-skeleton";
import { ProfileCardSkeleton } from "./skeletons/profile-card-skeleton";
import { IframeCardSkeleton } from "./skeletons/iframe-card-skeleton";
import type { CardVariant, CardProps } from "./types";
import type { ComponentType } from "react";

interface RegistryEntry {
  Card: ComponentType<CardProps>;
  Skeleton: ComponentType;
}

export const cardVariantRegistry: Record<CardVariant, RegistryEntry> = {
  details: { Card: DetailsCard, Skeleton: DetailsCardSkeleton },
  profile: { Card: ProfileCard, Skeleton: ProfileCardSkeleton },
  iframe: { Card: IframeCard, Skeleton: IframeCardSkeleton },
};
```

**Rule:** adding a variant later = one import + one entry. Do not touch `<CardGrid>`.

### ⑤.3 `DetailsCard` variant (`variants/details-card.tsx`)

```tsx
"use client";

import { Icon } from "@iconify/react";
import { stripHtml } from "../helpers/strip-html";
import { formatModifiedAgo } from "../helpers/format-modified-ago";
import { RowActionMenu } from "../../../custom-components/data-tables/advanced/data-table-crud-options/row-action-menu"; // verify actual path during build
import type { CardProps, DetailsCardConfig } from "../types";

export function DetailsCard({ row, config, onCardClick, rowActions }: CardProps) {
  const c = config as DetailsCardConfig; // safe because registry dispatches on variant
  const header = (row as any)[c.headerField] ?? "—";
  const metaValues = c.metaFields.map((f) => (row as any)[f]).filter(Boolean);
  const rawSnippet = (row as any)[c.snippetField] ?? "";
  const snippet = stripHtml(rawSnippet).slice(0, c.snippetMaxChars ?? 100);
  const modified = formatModifiedAgo((row as any)[c.footerField]);

  return (
    <div
      role="button"
      tabIndex={0}
      onClick={() => onCardClick?.(row)}
      onKeyDown={(e) => e.key === "Enter" && onCardClick?.(row)}
      className="cursor-pointer rounded-lg border border-border bg-card p-4 transition hover:border-primary/40 hover:shadow-sm focus:outline-none focus:ring-2 focus:ring-primary/40"
    >
      <div className="flex items-start justify-between gap-2">
        <h3 className="truncate text-sm font-semibold text-foreground">{header}</h3>
        <RowActionMenu row={row} actions={rowActions} />
      </div>
      <div className="mt-2 flex flex-wrap items-center gap-2">
        {metaValues.map((v, i) => (
          <span
            key={i}
            className="rounded-md bg-muted px-2 py-0.5 text-xs text-muted-foreground"
          >
            {String(v)}
          </span>
        ))}
      </div>
      <p className="mt-3 line-clamp-2 min-h-[2.5rem] text-xs text-muted-foreground">
        {snippet || <span className="italic">No preview</span>}
      </p>
      <div className="mt-3 flex items-center justify-between text-xs text-muted-foreground">
        <span className="flex items-center gap-1">
          <Icon icon="ph:clock" className="h-3.5 w-3.5" />
          {modified}
        </span>
      </div>
    </div>
  );
}
```

**Rules:**
- Click anywhere on the card body → `onCardClick(row)`. `RowActionMenu` must `stopPropagation` on its own clicks.
- `stripHtml()` is REQUIRED for the snippet — never render raw field.
- `min-h-[2.5rem]` on snippet prevents layout shift when some rows have snippets and others don't.
- Uses existing `RowActionMenu` — do NOT invent a new action menu component. If the existing one's path differs, use that path; register a Build Log note if you had to create one.

### ⑤.4 `ProfileCard` variant (`variants/profile-card.tsx`)

```tsx
"use client";

import { Icon } from "@iconify/react";
import type { CardProps, ProfileCardConfig, ContactAction } from "../types";

const CONTACT_ICON: Record<ContactAction, string> = {
  email: "ph:envelope-simple",
  phone: "ph:phone",
  whatsapp: "ph:whatsapp-logo",
  sms: "ph:chat-text",
};

export function ProfileCard({ row, config, onCardClick, rowActions }: CardProps) {
  const c = config as ProfileCardConfig;
  const avatar = c.avatarField ? (row as any)[c.avatarField] : null;
  const name = (row as any)[c.nameField] ?? "—";
  const subtitle = (row as any)[c.subtitleField] ?? "";
  const initials = getInitials(name);

  return (
    <div
      role="button"
      tabIndex={0}
      onClick={() => onCardClick?.(row)}
      onKeyDown={(e) => e.key === "Enter" && onCardClick?.(row)}
      className="cursor-pointer rounded-lg border border-border bg-card p-4 transition hover:border-primary/40 hover:shadow-sm"
    >
      <div className="flex items-start gap-3">
        {avatar ? (
          <img src={avatar} alt={name} className="h-12 w-12 rounded-full object-cover" />
        ) : (
          <div className="flex h-12 w-12 items-center justify-center rounded-full bg-primary/10 text-sm font-semibold text-primary">
            {initials}
          </div>
        )}
        <div className="min-w-0 flex-1">
          <h3 className="truncate text-sm font-semibold text-foreground">{name}</h3>
          {subtitle && (
            <p className="truncate text-xs text-muted-foreground">{subtitle}</p>
          )}
        </div>
        <RowActionMenu row={row} actions={rowActions} />
      </div>
      <div className="mt-3 space-y-1">
        {c.metaFields.map((f) => {
          const val = (row as any)[f];
          if (!val) return null;
          return (
            <div key={f} className="truncate text-xs text-muted-foreground">
              {String(val)}
            </div>
          );
        })}
      </div>
      {c.contactActions && c.contactActions.length > 0 && (
        <div className="mt-3 flex items-center gap-2 border-t border-border pt-3">
          {c.contactActions.map((action) => (
            <button
              key={action}
              type="button"
              onClick={(e) => { e.stopPropagation(); /* wire action handler */ }}
              className="rounded-md p-1.5 text-muted-foreground hover:bg-muted hover:text-primary"
              aria-label={action}
            >
              <Icon icon={CONTACT_ICON[action]} className="h-4 w-4" />
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

function getInitials(name: string): string {
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase() ?? "")
    .join("") || "?";
}
```

### ⑤.5 `IframeCard` variant (`variants/iframe-card.tsx`)

**Critical constraints:**
- Lazy-load via `IntersectionObserver` — render iframe only when card enters viewport.
- `sandbox="allow-same-origin"` — NEVER include `allow-scripts`.
- Size-cap the HTML (default 100 KB). If oversized or empty → fall back to `fallbackSnippetField`.
- Use `srcDoc` prop, never `dangerouslySetInnerHTML`.
- Fixed aspect ratio `aspect-[4/3]` on the iframe wrapper for uniform grid.

```tsx
"use client";

import { useEffect, useRef, useState } from "react";
import type { CardProps, IframeCardConfig } from "../types";

export function IframeCard({ row, config, onCardClick, rowActions }: CardProps) {
  const c = config as IframeCardConfig;
  const html = String((row as any)[c.htmlField] ?? "");
  const maxBytes = c.maxHtmlBytes ?? 100_000;
  const header = (row as any)[c.headerField] ?? "—";
  const fallback = String((row as any)[c.fallbackSnippetField] ?? "");

  const tooLargeOrEmpty = !html || new Blob([html]).size > maxBytes;
  const [visible, setVisible] = useState(false);
  const ref = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    if (!ref.current || tooLargeOrEmpty) return;
    const io = new IntersectionObserver(
      (entries) => entries.forEach((e) => e.isIntersecting && setVisible(true)),
      { rootMargin: "200px" }
    );
    io.observe(ref.current);
    return () => io.disconnect();
  }, [tooLargeOrEmpty]);

  return (
    <div
      ref={ref}
      role="button"
      tabIndex={0}
      onClick={() => onCardClick?.(row)}
      onKeyDown={(e) => e.key === "Enter" && onCardClick?.(row)}
      className="group relative cursor-pointer overflow-hidden rounded-lg border border-border bg-card transition hover:border-primary/40 hover:shadow-sm"
    >
      <div className="aspect-[4/3] w-full overflow-hidden bg-muted/40">
        {tooLargeOrEmpty ? (
          <div className="flex h-full items-center justify-center p-4">
            <p className="line-clamp-4 text-xs text-muted-foreground">{fallback || "No preview"}</p>
          </div>
        ) : visible ? (
          <iframe
            title={header}
            srcDoc={html}
            sandbox="allow-same-origin"
            loading="lazy"
            className="pointer-events-none h-full w-full origin-top-left scale-[0.5] transform"
            style={{ width: "200%", height: "200%" }} // 2x size at 0.5 scale = normal view at thumbnail size
          />
        ) : (
          <div className="h-full w-full animate-pulse bg-muted" />
        )}
      </div>
      <div className="flex items-start justify-between gap-2 p-3">
        <div className="min-w-0 flex-1">
          <h3 className="truncate text-sm font-semibold text-foreground">{header}</h3>
          <div className="mt-1 flex flex-wrap items-center gap-1.5">
            {c.metaFields.map((f) => {
              const v = (row as any)[f];
              if (!v) return null;
              return (
                <span key={f} className="rounded-md bg-muted px-1.5 py-0.5 text-[10px] text-muted-foreground">
                  {String(v)}
                </span>
              );
            })}
          </div>
        </div>
        <RowActionMenu row={row} actions={rowActions} />
      </div>
    </div>
  );
}
```

**Rule:** iframe `pointer-events-none` — clicks pass through to the card `onClick`. Otherwise clicking the preview doesn't navigate.

### ⑤.6 Skeletons

Each skeleton matches its variant's shape. Use `<Skeleton>` from `common-components`.

`details-card-skeleton.tsx`:
```tsx
import { Skeleton } from "@/presentation/components/common-components";

export function DetailsCardSkeleton() {
  return (
    <div className="rounded-lg border border-border bg-card p-4">
      <div className="flex items-start justify-between gap-2">
        <Skeleton className="h-4 w-3/5" />
        <Skeleton className="h-6 w-6 rounded-md" />
      </div>
      <div className="mt-2 flex items-center gap-2">
        <Skeleton className="h-5 w-16 rounded-md" />
        <Skeleton className="h-5 w-20 rounded-md" />
      </div>
      <div className="mt-3 space-y-1.5">
        <Skeleton className="h-3 w-full" />
        <Skeleton className="h-3 w-4/5" />
      </div>
      <div className="mt-3 flex items-center justify-between">
        <Skeleton className="h-3 w-16" />
      </div>
    </div>
  );
}
```

`profile-card-skeleton.tsx`: matches avatar + name + meta + action-row shape.

`iframe-card-skeleton.tsx`: `aspect-[4/3]` shimmer for preview area + lower strip for title/meta.

---

## ⑥ Helpers

### `helpers/strip-html.ts`

```ts
export function stripHtml(input: unknown): string {
  if (typeof input !== "string") return "";
  return input
    .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, " ")
    .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}
```

Good-enough for listing snippets. Not a security boundary — it's paired with `iframe` variant having sandbox for actual HTML rendering.

### `helpers/format-modified-ago.ts`

If the codebase already has a date-formatting util, use it. If not, implement a minimal relative-time formatter (e.g., `"2d ago"`, `"5h ago"`, `"just now"`). Grep first: `Grep "modifiedAgo|formatAgo|fromNow|timeAgo"`.

---

## ⑦ Wiring into `DataTableContainer`

File: `src/presentation/components/custom-components/data-tables/advanced/data-table-container.tsx`

**This file is 637 lines today.** The edit is surgical:

1. Read `displayMode`, `cardVariant`, `cardConfig` from the store's `tableConfig` (or wherever page config flows through to the container).
2. At the point where table rows are rendered, add a branch:
   ```tsx
   if (tableConfig?.displayMode === "card-grid" && tableConfig.cardVariant) {
     return (
       <CardGrid
         rows={data}
         variant={tableConfig.cardVariant}
         config={tableConfig.cardConfig}
         loading={isLoading}
         empty={!isLoading && data.length === 0}
         onCardClick={(row) => handleRowClick(row)}
         rowActions={rowActions}
       />
     );
   }
   // else → existing table render
   ```
3. Everything above this branch (filter chip bar, search, toolbar) stays above. Everything below (pagination footer) stays below.

**Do NOT replicate the filter/pagination logic** — reuse the exact same state + handlers the table branch uses.

### `PageConfig` type additions

Find the existing `PageConfig` type (grep `interface PageConfig` or `type PageConfig`). Add:

```ts
interface PageConfig {
  // ...existing fields...
  displayMode?: "table" | "card-grid"; // default "table" if undefined
  cardVariant?: CardVariant;
  cardConfig?: CardConfig;
}
```

Runtime validation: if `displayMode === "card-grid"`, both `cardVariant` and `cardConfig` must be set. Otherwise log a dev-time warning and fall back to `table`.

---

## ⑧ Build order (for the first consumer screen — SMS Template #29)

When `/build-screen #29` runs with this spec in context:

1. **Read this file first** (`.claude/feature-specs/card-grid.md`).
2. Create the `card-grid/` folder + `types.ts` + registry + shell.
3. Create ONLY the variant SMS Template needs: `details-card.tsx` + `details-card-skeleton.tsx`.
   - Do NOT speculatively build `profile-card.tsx` or `iframe-card.tsx` — no screen needs them yet. Leave the registry entries commented out or wired to a placeholder that throws.
   - **Correction:** actually DO wire all three registry entries. The registry is fail-fast if a variant is missing — so either all three are implemented or the registry must gracefully handle absence. Cleanest: implement `details` now, AND stub out `profile` + `iframe` as components that render `<div className="p-4 text-sm text-destructive">Variant not yet implemented — see .claude/feature-specs/card-grid.md</div>`. The stubs are one-liners.
4. Wire into `DataTableContainer` as described in Section ⑦.
5. Build the SMS Template screen (page, config, query, mutation, columns) following the standard `/build-screen` flow, with `displayMode: card-grid` + `cardVariant: details` + `cardConfig` populated from the screen spec.
6. Verify on screen: filter chip bar works, search works, pagination works, cards render, loading shows skeletons, empty state renders, row click navigates to `?mode=read&id={id}`, action menu works per card.
7. Log the new files in Section ⑬ Build Log of the SMS Template prompt file.
8. Flip this spec's frontmatter to `status: BUILT` (or `status: BUILT — details variant only`) and add a "First built by: Session #29 BUILD on {date}" line below.

Screens #31 (WhatsApp Template) and #36 (Notification Templates): set `displayMode`, `cardVariant: details`, and `cardConfig` in their page configs. Verify the existing components work. No new files.

Screen #24 (Email Template, later in Wave 5): replace the stub `iframe-card.tsx` with the real implementation from Section ⑤.5. One new file + one real implementation — shell untouched.

---

## ⑨ Responsive rules (applies to all variants)

| Breakpoint | Columns |
|-----------|---------|
| `xs` (< 640px) | 1 |
| `sm` (≥ 640px) | 2 |
| `lg` (≥ 1024px) | 3 |
| `xl` (≥ 1280px) | 4 |

- Card inner padding `p-4` (details/profile) or `p-3` (iframe footer strip).
- Gap between cards `gap-3`.
- All cards within one grid have uniform shape (enforced by single variant per screen).
- Toolbar and filter chips above the grid collapse independently — their responsive behavior is NOT affected by `card-grid`.

**Manual test gates** (must pass before marking COMPLETED):
- 375px (phone) — 1 column, no horizontal overflow, action menus usable.
- 768px (tablet) — 2 columns, card content legible.
- 1280px (desktop) — 4 columns with reasonable density.

---

## ⑩ Accessibility

- Each card has `role="button"` + `tabIndex={0}` + Enter/Space key handler → same action as click.
- `aria-label` on contact-action icons (profile variant).
- Avatar `<img>` has `alt={name}`.
- Skeletons are visually informative; no aria-live chatter needed during loading (progressive rendering).
- Focus ring: `focus:ring-2 focus:ring-primary/40` — consistent with existing buttons.

---

## ⑪ Performance guardrails

- `<CardGrid>` does not virtualize. That's intentional — `pageSize` caps rendering at ~25–50 cards per page. If a screen needs 500+ per page, escalate and discuss virtualization as a separate feature.
- `IframeCard` MUST lazy-load (IntersectionObserver) — eager rendering of 20 iframes will freeze mobile browsers.
- Snippet `stripHtml` is synchronous but runs on ~100-char strings — fine. Do NOT pre-compute at data-fetch time; let React handle it per-render.

---

## ⑫ Anti-patterns (reject at review)

- Invented card component inside a page file instead of the registry → reject, move to `card-grid/variants/`.
- Inline `<div className="grid grid-cols-*">` replicating `<CardGrid>` logic → reject, use the shell.
- `dangerouslySetInnerHTML` anywhere except inside the sandboxed `<iframe srcDoc>` → reject.
- Iframe without `sandbox` attribute, with `allow-scripts`, or without lazy-load → reject.
- Fixed pixel widths on cards → reject, let the grid auto-size.
- Different card shapes on two sibling screens using the same variant → reject, config-driven only.
- Spinner replacing the variant-specific skeleton → reject, skeletons must match card shape.
- Carousel / slider swap → reject, this is a management surface.
- User-facing table↔card toggle implemented without explicit approval → out of scope, do not ship.

---

## ⑬ Acceptance criteria (DoD for the first build)

### Infrastructure
- [ ] `card-grid/` folder and all files from Section ③ exist.
- [ ] `types.ts` compiles with strict mode.
- [ ] `card-variant-registry.ts` lists all three variants (real `details`, stubs for `profile` + `iframe`).
- [ ] `<CardGrid>` renders: loading skeletons, empty state, real cards.
- [ ] Unknown variant → shows the dev-time error box (verify manually by temporarily setting `cardVariant: "foo"`).

### Wiring
- [ ] `DataTableContainer` reads `displayMode` / `cardVariant` / `cardConfig` and branches correctly.
- [ ] `PageConfig` type updated.
- [ ] Filter chip bar, search, pagination, toolbar all work in card-grid mode (no regression vs table mode).
- [ ] Row click navigates to `?mode=read&id={id}` (FLOW) or opens RJSF modal (MASTER_GRID).

### DetailsCard
- [ ] Renders at 1/2/3/4 column breakpoints without clipping.
- [ ] Snippet HTML is stripped (test with a row whose `body` contains `<b>bold</b>`).
- [ ] Empty snippet shows italic "No preview" — no layout shift.
- [ ] Action menu opens on click without triggering card click (stopPropagation works).

### Skeletons
- [ ] `DetailsCardSkeleton` visual shape matches `DetailsCard` shape.
- [ ] 8 skeletons render during loading by default.

### Build Log
- [ ] SMS Template (#29) Build Log Section ⑬ records all card-grid files in `Files touched`.
- [ ] This feature spec's frontmatter `status` is flipped to `BUILT — details variant` after SMS ships.

---

## ⑭ Future extensions (tracked, not built)

| Extension | When | Notes |
|-----------|------|-------|
| `profile` variant real impl | First contact/staff screen (likely #18 Contact or #42 Staff) | Replace stub with Section ⑤.4 code |
| `iframe` variant real impl | Email Template #24 (Wave 5) | Replace stub with Section ⑤.5 code |
| User-facing table↔card toggle | After 2+ screens ship card-grid in prod | Adds a segmented control in the toolbar, persists per-user pref |
| `media` variant | First media-library / gallery screen | Large image + small metadata |
| `kanban` variant | First board-style screen | Drag-drop columns — separate feature, share only card renderer |
| Virtualization | If a screen needs 500+ cards/page | Wrap `<CardGrid>` body in `react-virtuoso` or similar |

These are parking-lot entries — do NOT build them as part of the SMS Template session.
