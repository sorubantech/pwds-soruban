# Online Donation Page #10 — Footer configuration content (Aurora / STANDARD)

Ready-to-type content for **Card 9 → Landing content** on the admin screen.
Every node has four fields: **Label**, **Icon name** (@iconify Phosphor),
**Image URL**, **Link**. Rules the renderer enforces:

- **Image URL wins over Icon name.** Set one, not both.
- **Blank Link → the row renders as plain text**, not an anchor. This is what
  address / phone / registration-number rows need.
- A parent with no children is skipped; a child with a blank label is skipped.

---

## Where each of the four design columns actually comes from

Two of the design's four columns already have dedicated, purpose-built fields in
Card 9 — configuring them in the tree instead would print them twice.

| # | Design column | Configure it in |
|---|---------------|-----------------|
| 1 | Logo + description + social icons | **Brand/logo** (Card 1) + **Footer tagline** + **Footer socials** repeater |
| 2 | Get in touch | **Footer contact** (address / phone / email) |
| 3 | Useful Information | **Footer columns (parent → child)** ← the tree |
| 4 | You Can Also Help | **Footer columns (parent → child)** ← the tree |
| 5+ | anything further | **Footer columns (parent → child)** ← the tree |

If you *want* columns 1 and 2 driven by the tree instead (e.g. an address split
into several lines with its own icons), leave the dedicated fields blank and use
the tree rows given under "Optional" below.

---

## Footer socials (repeater — platform + url)

| Platform | URL |
|----------|-----|
| `facebook` | https://facebook.com/your-org |
| `instagram` | https://instagram.com/your-org |
| `twitter` | https://twitter.com/your-org |
| `youtube` | https://youtube.com/@your-org |
| `linkedin` | https://linkedin.com/company/your-org |
| `whatsapp` | https://wa.me/919876543210 |

Platform strings are matched case-insensitively; anything unrecognised falls
back to a generic link glyph.

## Footer contact

| Field | Value |
|-------|-------|
| Address | `No. 12, Anna Salai,`<br>`Guindy, Chennai – 600 032,`<br>`Tamil Nadu, India` |
| Phone | `+91 98765 43210` |
| Email | `care@your-org.org` |

## Footer tagline

> Every meal served is a life restored. We work alongside communities across
> Tamil Nadu to end hunger with dignity.

---

## Footer columns (parent → child) — the tree

### Parent 1 — Useful Information

| | Label | Icon name | Image URL | Link |
|-|-------|-----------|-----------|------|
| **Parent** | `Useful Information` | `ph:info-fill` | — | *(blank)* |
| child | `About Us` | `ph:caret-right` | — | `/about` |
| child | `Our Programs` | `ph:caret-right` | — | `/programs` |
| child | `Where We Work` | `ph:caret-right` | — | `/impact/locations` |
| child | `Annual Reports` | `ph:file-pdf` | — | `/reports` |
| child | `Financial Transparency` | `ph:chart-pie-slice` | — | `/transparency` |
| child | `Media & Press` | `ph:newspaper` | — | `/press` |
| child | `Contact Us` | `ph:caret-right` | — | `/contact` |

### Parent 2 — You Can Also Help

| | Label | Icon name | Image URL | Link |
|-|-------|-----------|-----------|------|
| **Parent** | `You Can Also Help` | `ph:hand-heart-fill` | — | *(blank)* |
| child | `Volunteer With Us` | `ph:users-three` | — | `/volunteer` |
| child | `Become a Monthly Donor` | `ph:repeat` | — | `/donate/recurring` |
| child | `Corporate Partnership (CSR)` | `ph:buildings` | — | `/csr` |
| child | `Donate In Kind` | `ph:package` | — | `/donate/in-kind` |
| child | `Fundraise for Us` | `ph:megaphone` | — | `/fundraise` |
| child | `Sponsor a Meal` | `ph:bowl-food` | — | `/sponsor` |

### Parent 3 — Legal & Compliance *(url-less plain-text rows)*

| | Label | Icon name | Image URL | Link |
|-|-------|-----------|-----------|------|
| **Parent** | `Legal & Compliance` | `ph:seal-check-fill` | — | *(blank)* |
| child | `Reg. No. TN/CHN/2011/0004521` | `ph:certificate` | — | *(blank)* |
| child | `80G: AAATU1234FF20214` | `ph:receipt` | — | *(blank)* |
| child | `FCRA: 075901234` | `ph:globe-hemisphere-east` | — | *(blank)* |
| child | `Privacy Policy` | `ph:caret-right` | — | `/privacy` |
| child | `Terms & Refund Policy` | `ph:caret-right` | — | `/terms` |

### Parent 4 — Recognised By *(image markers instead of icons)*

| | Label | Icon name | Image URL | Link |
|-|-------|-----------|-----------|------|
| **Parent** | `Recognised By` | `ph:medal-fill` | — | *(blank)* |
| child | `GuideStar India — Platinum` | — | `https://cdn.your-org.org/badges/guidestar.png` | `https://guidestarindia.org/` |
| child | `Credibility Alliance` | — | `https://cdn.your-org.org/badges/credall.png` | *(blank)* |
| child | `Give.do Verified` | — | `https://cdn.your-org.org/badges/give.png` | `https://give.do/` |

Swap the CDN paths for your own hosted badge images — they render as 16×16
thumbnails, so use square, transparent-background PNG/SVG.

---

## Optional — driving columns 1 and 2 from the tree instead

### Parent — Get in Touch (only if the dedicated contact fields are left blank)

| | Label | Icon name | Image URL | Link |
|-|-------|-----------|-----------|------|
| **Parent** | `Get in Touch` | `ph:map-pin-fill` | — | *(blank)* |
| child | `No. 12, Anna Salai, Guindy, Chennai – 600 032` | `ph:map-pin` | — | *(blank)* |
| child | `+91 98765 43210` | `ph:phone-fill` | — | `tel:+919876543210` |
| child | `care@your-org.org` | `ph:envelope-simple-fill` | — | `mailto:care@your-org.org` |
| child | `Mon–Sat, 9:00 AM – 6:00 PM IST` | `ph:clock` | — | *(blank)* |

Note the deliberate mix: address and office hours have **no link** so they print
as plain text, while phone and email carry `tel:` / `mailto:` links.

---

## Nesting (sub-headings inside a column)

A child that itself has children renders as a small sub-heading with its own
list underneath. The GraphQL selection is fixed at three levels, so **parent →
child → grandchild** is the maximum depth.

| Level | Label | Renders as |
|-------|-------|-----------|
| Parent | `Our Work` | column heading |
| child | `Hunger` | sub-heading |
| grandchild | `Community Kitchens` | link row |
| grandchild | `School Meals` | link row |
| child | `Health` | sub-heading |
| grandchild | `Mobile Clinics` | link row |
