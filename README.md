# Custom Horizon

Theme component for **comunidad.criptonautas.co**. Child of the
[Horizon](https://meta.discourse.org/t/horizon-theme/360486) theme — everything here
overrides or extends Horizon, nothing stands alone.

## What it does

### Styling (`scss/`, loaded from `common/common.scss`)

| File | Scope |
|---|---|
| `main.scss` | Base font scale, `--d-*` overrides, grid/sidebar layout, category colour reset, topic lists, docs categories, search, leaderboard, banners, composer-redesign fixes |
| `header.scss` | Header layout with custom nav, mobile logo/avatar visibility |
| `topic.scss` | Topic max-widths and body width |
| `_topic-list.scss` | Topic-list density + AI gist styling |
| `categories-view.scss` | Category boxes and title headers |
| `mobile-stuff.scss` | Responsive font sizes, sidebar backgrounds, docs categories on mobile |
| `user.scss`, `new-user.scss` | Profile and messages pages |
| `custom-user-menu.scss`, `d-combo-button.scss`, `groups.scss` | User menu, dropdowns, group pages |
| `compatibility.scss` | Overrides that must land after everything else |

Breakpoints use core's viewport library (`@include viewport.from/until(sm|md|lg)`),
imported once in `common/common.scss`. Raw `@media` is kept only for off-grid widths
(400px, 470px, 925px, 1200px, 1400px) and `prefers-reduced-motion`.

### Behaviour (`javascripts/`)

- **`init.gjs`**
  - Loads every page of a docs category (`.topic-list.doc-simple-mode`), then sorts it
    A–Z collating with the page's `<html lang>`. Re-sorts after any later append (see
    *Known limits*).
  - Opens the docs sidebar once per category per session on mobile.
  - Replaces the discobot icon, hides "closed" group-membership buttons, disables the
    navigation dropdown on mobile, adds a `leaderboard-page` body class.
  - Optionally pauses all Discourse-only keyboard shortcuts (`disable_discourse_keyboard_shortcuts`).
- **`block-sidebar.gjs`** — gates sidebar links by group using the `blocked_sections`
  setting: dims or hides the link and explains the requirement in a modal with a CTA.
  Copy lives in `locales/*.yml`, keyed by each tier's `key`.
- **`ai-gist-horizon.gjs`** — renders `ai_topic_gist` into `topic-list-after-title`,
  the only core outlet Horizon's high-context card keeps.
- **`translated-texts.gjs`** — appends the translated note under the leaderboard podium.
- **`connectors/custom-homepage`** — placeholder outlet for the custom homepage.

### Markup and assets

- `common/after_header.html` — custom category banners (ghettos, retos, karma, costumbres).
- `common/header.html` — Plausible analytics.
- `about.json` — Phosphor duotone icon allowlist, `custom_homepage` and
  `serialize_topic_is_hot` modifiers, Light/Dark colour palettes.

## Known limits

- **Docs A–Z is client-side.** Discourse cannot order a topic list by title server-side
  (`TopicQuery::SORTABLE_MAPPING` has no `title`), so `init.gjs` exhausts the paginated
  list (`loadMore()`, capped at `MAX_DOC_PAGES`) and then sorts. Two consequences: entering
  a docs category costs one request per 30 topics, and the loop reads
  `controller:discovery/topics` — semi-private API. If it breaks or the cap is hit, it
  degrades to sorting the rows that are loaded. Delete the loop if core ever ships
  server-side title ordering.
- `compatibility.scss` and `main.scss` both set `max-width` on
  `div[class*="category-title-header"]`; `compatibility.scss` wins by `!important`.

## Development

Edits are local. Deploy via **Admin → Appearance → Themes → Install → From your device**,
or import from the git remote. See `CLAUDE.MD` for conventions.
