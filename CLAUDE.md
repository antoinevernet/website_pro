# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is Antoine Vernet's personal academic website, built with [Quarto](https://quarto.org/) and deployed on Netlify. The site covers: About, CV, Research, Teaching, Talks, and Blog sections.

## Build & Development Commands

- **Preview site locally:** `quarto preview` (runs on port 5555 with live reload)
- **Render full site:** `quarto render`
- **Render a single page:** `quarto render path/to/file.qmd`

The site uses `execute: freeze: auto` — computations are cached in `_freeze/` and only re-run when source changes. Output goes to `_site/` (gitignored).

Deployment: pushing to GitHub triggers a Netlify build, where `@quarto/netlify-plugin-quarto` runs `quarto render`. Netlify has no R, so **commit any changed `_freeze/` files** alongside source changes. Netlify's primary domain is the apex `antoinevernet.com` (www redirects to it).

## SEO & AI discoverability

- Default social card: `files/social-card.jpg` (1200×630), set in `_quarto.yml` `twitter-card`/`open-graph`. Pages with their own `image:` override it.
- Homepage (`index.qmd`) has `Person` + `WebSite` JSON-LD in `include-in-header` (affiliation, ORCID, Google Scholar, social `sameAs` links). Update it if the job title or affiliation changes.
- `llms.txt` (site root, listed under `resources`) — curated summary for AI tools. **Update it when adding papers or notable posts.**
- `robots.txt` is Quarto's default (all crawlers allowed, including AI crawlers — deliberate). The abandoned paper stays indexed on purpose.
- The CV page (`cv/index.qmd`) has an HTML "At a glance" summary above the embedded PDF, written from the CV dated July 2025 — update it when the PDF changes.

## Architecture

### Quarto Configuration

- `_quarto.yml` — Main site config: navbar, footer, metadata, format settings
- `_variables.yml` — Site-wide variables (orcid, github-url, years) referenced via `{{< var name >}}`. Update `years` each January.
- `site-url` is `https://antoinevernet.com` (no www) — keep all absolute URLs on the apex domain.
- `project.render` is `["*.qmd", "!CLAUDE.md"]` so this file is never published. Only `.qmd` files are rendered.
- Site-wide format is plain `html`. **Only `blog/2025/10/webr_test/` uses `live-html`** (r-wasm/live, ~1.5 MB of webR/OJS JS), declared in its own frontmatter with the theme options repeated (project `html` options don't carry over to `live-html`). For any new interactive post, copy that frontmatter. Do not put `format: html:` in a directory `_metadata.yml` (e.g. `blog/_metadata.yml`) — a post with its own `live-html` would then render twice and the build fails with a rename error; put directory-level format options at the top level instead.
- Page titles: Quarto appends ` – Antoine Vernet` to every `<title>` automatically — don't add the name in `pagetitle`. The homepage opts out with `title-prefix: ""` and sets its full title.
- Custom theme: `html/custom.scss` (adapted from Andrew Heiss's theme, uses Jost + Libre Franklin fonts, primary color `#003249`)

### Content Sections

Each section uses Quarto [listings](https://quarto.org/docs/websites/website-listings.html) with custom EJS templates in `html/`:

| Section | Content location | Listing data | Template |
|---------|-----------------|--------------|----------|
| **Blog** | `blog/{year}/{month}/{slug}/index.qmd` | QMD files with frontmatter | `html/blog/listing.ejs` |
| **Research** | `research/{articles,working-papers,chapters,reviews,abandonned}/{slug}/index.qmd` | QMD files with `pub-info` frontmatter | `html/research/listing.ejs` |
| **Teaching** | `teaching/ay_{YY-YY}.yml` | YAML data files | `html/teaching/listing.ejs` |
| **Talks** | `talks/talks_{YYYY}.yml` | YAML data files | `html/talks/listing.ejs` |

Research articles also use a custom Pandoc title block template: `html/research/title-block.html`, wired up in `research/_metadata.yml` (under `format: html: template-partials`), which also sets `google-scholar: true` (emits `citation_*` meta tags), `appendix-cite-as: false`, and runs the Lua filter `html/research/scholarly-jsonld.lua` (emits schema.org `ScholarlyArticle`/`Chapter` JSON-LD from the same frontmatter, only on pages with `pub-info`).

There is no site-wide `bibliography:` — with `google-scholar: true`, Quarto emits every entry of the bibliography as `citation_reference` tags, so posts that cite set their own `bibliography`/`csl` (see `blog/2018/07/writing/`).

### Blog Post Frontmatter

Blog posts live in `blog/{year}/{month}/{slug}/index.qmd`. Key frontmatter fields:
- `title`, `date`, `description`, `categories`
- `image` — thumbnail shown in listing
- `twitter-card.image`, `open-graph.image` — social sharing images
- `doi` — optional DOI displayed in listing
- `citation: true` — enables Quarto citation metadata
- `draft: true` — hides from published listings
- `resources: ["img/*"]` — include image assets

Default blog metadata (author, format, TOC settings) is inherited from `blog/_metadata.yml`.

### Research Article Frontmatter

Research articles use a `pub-info` object in frontmatter:
- `pub-info.reference` — HTML-formatted citation string
- `pub-info.links` — array of `{name, url, icon, local?}` for PDF/preprint/code links
- `description` — 1–2 sentence summary (~150–200 chars) used for meta/OG description and shown in the banner. Every research page should have one.
- `author` (with `orcid`), `date`, `doi` — feed the Google Scholar `citation_*` tags
- `citation` — publication details for Scholar tags and JSON-LD (not displayed): `type` (`article-journal`/`chapter`/`entry-encyclopedia`), `container-title`, `volume`, `issue`, `page`, `issued` (print date; `date` is the online date), `publisher`, `issn`/`isbn` (quote them), `pdf-url` (open-access/UCL Discovery PDF), and for chapters `collection-title`, `editor`. Take values from Crossref (`https://api.crossref.org/works/<doi>`). Quarto double-escapes `&` in these fields, so write "and".
- `haiku` — optional array of lines displayed as an italicized epigraph

### Teaching & Talks Data

Teaching entries (YAML) use: `title`, `description`, `university`, `number`, `logo`, `url`, `semester[{name, url}]`.

Talk entries (YAML) use: `title`, `date`, `description`, `location`, `links[{name, url, icon, local?}]`.

### Adding a New Year

When adding content for a new year:
- **Blog:** Create `blog/{year}/` directory, add a new listing block (`id: posts_{year}`) in `blog/index.qmd`
- **Teaching:** Create `teaching/ay_{YY-YY}.yml`, add listing and section in `teaching/index.qmd`
- **Talks:** Create `talks/talks_{YYYY}.yml`, add listing and section in `talks/index.qmd`

### Quarto Extensions

Installed in `_extensions/`:
- `quarto-ext/fontawesome` — Font Awesome icons (`{{< fa ... >}}`)
- `schochastics/academicons` — Academic icons (`{{< ai ... >}}`)
- `mcanouil/iconify` — Iconify icons (`{{< iconify ... >}}`)
- `r-wasm/live` — WebR/live-html support for interactive R code in browser (only used by `blog/2025/10/webr_test/`)

### Key Files

- `files/references.bib` — BibTeX bibliography
- `files/amj.csl` — Citation style (AMJ format)
- `atom.qmd` — RSS/Atom feed configuration for blog posts
- `netlify.toml` — Netlify deployment config (uses `@quarto/netlify-plugin-quarto`)
- `.venv/` — Python virtual environment (for Jupyter kernel used by Quarto)
