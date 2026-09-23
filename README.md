# Horizon Mods Nautas

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
| `_topic-list.scss` | Topic-list density + AI gist styling, docs-table gist/excerpt dedupe |
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
  the only core outlet Horizon's high-context card keeps. **Prerequisite:** the
  attribute is only in the payload when discourse-ai's server-side
  `Guardian#can_see_gists?` passes — `ai_summarization_enabled` and
  `ai_summary_gists_enabled` on, `ai_summary_gists_agent` resolving to an agent whose
  `allowed_group_ids` include `everyone` or one of the viewer's groups. That last
  clause is the one that bites: backfill generates gists without consulting the
  agent's groups, so the admin UI can show healthy gists while every payload omits
  the attribute (empty `allowed_group_ids` hides them from everyone). When the
  attribute is missing the outlet renders nothing, silently — check with
  `fetch('/latest.json').then(r=>r.json()).then(d=>console.log(
  d.topic_list.topics.filter(t=>'ai_topic_gist' in t).length))`.
- **`category-back.js`** — prepends a "go back" link into `.list-controls
  .navigation-container` on category pages (parent category, or `/categories` from a
  top-level one), so it rides Horizon's sticky bar ahead of the breadcrumbs. The target
  comes from the URL path, not the route model; no outlet exists inside that bar, so the
  insert is a DOM one on page change and is skipped when the bar is absent.
- **`bot-display-name.js`** — shows the `anonist_*` bot accounts under one label
  (`anonist`). Visible link text only: hrefs, quote attributions, markdown mentions,
  search and emails keep the real username, and a post rendered after the page change
  shows the real one until the next navigation. New bots need a line in `BOT_LABELS`.
- **`translated-texts.gjs`** — appends the translated note under the leaderboard podium.
- **`category-intro.gjs`** — overwrites the category banner titles and descriptions
  rendered from `after_header.html` with the locale-appropriate strings from
  `locales/*.yml` via `i18n(themePrefix(…))`.
- **`connectors/custom-homepage`** — placeholder outlet for the custom homepage.

### Markup and assets

- `common/after_header.html` — custom category banners (ghettos, retos, karma, costumbres).
- `common/header.html` — Plausible analytics.
- `about.json` — Phosphor duotone icon allowlist, `custom_homepage` and
  `serialize_topic_is_hot` modifiers, Light/Dark colour palettes.

## Known limits

- **`blocked_sections` is navigation UX, not authorization.** It dims or hides sidebar
  links and intercepts clicks on them — all client-side. Direct URLs, links from
  anywhere else, and JSON endpoints (`/c/<id>/latest.json`) bypass it entirely, and it
  grants no access it could leak. Real access control for the configured categories has
  to come from the server: Discourse category security groups, or the
  `discourse-category-lockdown` plugin. Verify a gated category as a non-member by
  requesting `/c/<id>/latest.json` directly.
- **Lock state is read once at boot.** `block-sidebar.gjs` computes the locked tiers
  when the initializer runs, so a visitor who logs in without a page reload keeps the
  anonymous gating until they refresh.
- **Selectors that depend on core/Horizon markup.** No outlet exists for these, so a
  Discourse or Horizon upgrade can silently disable them: the sidebar-toggle chain and
  the `"closed"`/`"cerrado"` button text match (`init.gjs`), the docs topic-list
  reordering (`init.gjs`), and the user-menu karma line (`user-menu-karma.js`). Each
  degrades to a no-op, so smoke-test the four after every upgrade.

- **Docs A–Z is client-side.** Discourse cannot order a topic list by title server-side
  (`TopicQuery::SORTABLE_MAPPING` has no `title`), so `init.gjs` exhausts the paginated
  list (`loadMore()`, capped at `MAX_DOC_PAGES`) and then sorts. Two consequences: entering
  a docs category costs one request per 30 topics, and the loop reads
  the latest discovery controller (`controller:discovery/latest`; the old `controller:discovery/topics` catch-all is deprecated) — semi-private API. If it breaks or the cap is hit, it
  degrades to sorting the rows that are loaded. Delete the loop if core ever ships
  server-side title ordering.
- `compatibility.scss` and `main.scss` both set `max-width` on
  `div[class*="category-title-header"]`; `compatibility.scss` wins by `!important`.

## Development

Edits are local. Deploy via **Admin → Appearance → Themes → Install → From your device**,
or import from the git remote. See `CLAUDE.MD` for conventions.
