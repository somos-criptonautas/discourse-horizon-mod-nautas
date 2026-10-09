# Horizon Mods Nautas — agent guide

Rules for anyone changing this repo, people and AI agents alike. Org-wide
conventions (README, licenses, commits) are in the
[contributing guide](https://github.com/somos-criptonautas/.github/blob/main/CONTRIBUTING.md).

## Scope

This is a **Discourse theme** (not a plugin, not core). All work stays within:

```
scss/           ← all SCSS (one file per area, see README)
javascripts/    ← api-initializers, components, connectors, services (.gjs / .js)
common/         ← theme fields: header, after_header, head_tag, common.scss
locales/        ← translation strings (.yml)
settings.yml    ← user-configurable theme settings
about.json      ← theme manifest (modifiers, svg_icons, palettes)
```

This is a **component**, child of Horizon (`parent_themes` in `about.json`).

**Never touch** core Discourse files, `node_modules`, `.git`, or any file
outside the theme directory unless explicitly instructed.

---

## CSS / SCSS

- Use **BEM** methodology for all class names.
  Reference: [CSS guidelines (BEM)](https://github.com/discourse/discourse/blob/main/docs/developer-guides/docs/03-code-internals/26-css-guidelines-bem.md)
- No inline styles. No `!important` unless overriding a Discourse core rule
  that cannot be scoped otherwise — comment why when used.
- Use Discourse CSS variables (`--d-*`) over hardcoded colors or sizes.
- Responsive work uses the `viewport.until/from/between(sm|md|lg|xl|2xl)` mixins,
  not raw media queries. Mobile-only rules live in `scss/mobile-stuff.scss`.

---

### Embedded topics (Ghost)

Content scraped by the Embedding feature keeps only the classes listed in the
`allowed embed classnames` site setting (default: `emoji`). Stripping happens at import
time, so changing that setting only affects newly imported topics — existing ones need a
rails-console `TopicEmbed.import` reimport. `scss/ghost-cards.scss` styles Ghost's bookmark
cards and depends on that list; Ghost's callout cards are instead rewritten into
`[!type]` blockquotes by `api-initializers/ghost-callouts.js` so the Quote Callouts
component renders them — that rewrite happens in the `cooked` getter (not a cooked
decorator) so it cannot lose a race with another component's decorator.

---

### Form templates

`scss/form-templates.scss` adds checklist headings and a checklist that swaps with a
dropdown. Form templates have no heading type, no conditional logic and no JS hook —
core validates the YAML against a closed type list, sanitizes `attributes.description`
to `<a href target>` only, and the field components expose no plugin outlet or value
transformer. What makes CSS enough: every field is a sibling inside
`.form-template-form__wrapper`, dropdown/multi-select are still native `<select>` (so
`:has()` + `option:checked` reads the selection live), and a field's YAML `id` arrives
as the input's `name` — there is **no** `data-field-id` attribute, `name` is the only
hook. Two rules: never `required: true` on a field CSS can hide (a hidden invalid field
makes `form.checkValidity()` refuse the post with nothing focusable), and the post body
comes from `FormData`, which ignores this CSS — a box checked and then hidden still
appears in the post.

---

## Templates (`.gjs` — there are no `.hbs` files here)

- Use `{{}}` (HTML-escaped) — **never** `{{{}}}` (unescaped / triple-braces).
  Unescaped output is an XSS vector. No exceptions.
- Do not use `innerHTML` or `@html` helpers without explicit sanitization.
- All user-facing strings must be translatable.
  Use `{{i18n "theme_key"}}` — never split strings across tags.
- Use **Sentence case** for all UI strings. Not "Proper Case", not "lower case".

---

## JavaScript

- Use `pnpm` for any package operations.
- No empty backing classes for template-only components unless requested.
- Do **not** add JSDoc to new code. If existing JSDoc is present, keep it accurate.
- Use `@service siteSettings` to access site settings in JS:
  `this.siteSettings.setting_name`

---

## Theme Settings (`settings.yml`)

- Every user-facing option belongs in `settings.yml`, not hardcoded in SCSS/JS.
- Use typed settings: `type: color`, `type: bool`, `type: list`, etc.
- Keep defaults sensible for a stock Discourse install.

---

## Checks

`pnpm install && pnpm lint` runs Discourse's eslint, prettier, stylelint and type
checks; `pnpm lint:fix` fixes most findings. CI (`.github/workflows/discourse-theme.yml`)
runs the same lint; there is no system spec, since core's "core features" spec runs
the component without Horizon. Also worth checking:

```bash
# every SCSS file must have balanced braces (Discourse rejects the theme otherwise)
for f in scss/*.scss common/*.scss; do \
  [ "$(grep -o '{' "$f" | wc -l)" = "$(grep -o '}' "$f" | wc -l)" ] || echo "UNBALANCED $f"; done
ruby -ryaml -e 'ARGV.each { |f| YAML.load_file(f) }' locales/*.yml settings.yml
python3 -c 'import json; json.load(open("about.json"))'
```

Everything else is verified by installing the component in Discourse
(**Admin → Appearance → Themes**) and looking at the page.

---

## Deploying the theme

Edits are made locally. To deploy, manually upload the theme:
**Discourse admin → Appearance → Themes → Install → From your device**
(or commit and import via the theme's Git repository URL).

---

## Conventions

- Architect mode on by default: analyse patterns and trade-offs before editing.
- If context is unclear (which Discourse version, what the setting does, how a
  component is structured), ask before writing code.
- Add conventions and gotchas you discover to this file, in the same PR.
