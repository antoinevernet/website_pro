# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is Antoine Vernet's personal academic website, built with [Quarto](https://quarto.org/) and deployed on Netlify. The site covers: About, CV, Research, Teaching, Talks, and Blog sections.

## Build & Development Commands

- **Preview site locally:** `quarto preview` (runs on port 5555 with live reload)
- **Render full site:** `quarto render`
- **Render a single page:** `quarto render path/to/file.qmd`

The site uses `execute: freeze: auto` — computations are cached in `_freeze/` and only re-run when source changes. Output goes to `_site/`.

## Architecture

### Quarto Configuration

- `_quarto.yml` — Main site config: navbar, footer, metadata, format settings
- `_variables.yml` — Site-wide variables (orcid, github-url, years) referenced via `{{< var name >}}`
- The site uses `live-html` format (via the `r-wasm/live` extension) instead of plain `html`
- Custom theme: `html/custom.scss` (adapted from Andrew Heiss's theme, uses Jost + Libre Franklin fonts, primary color `#003249`)

### Content Sections

Each section uses Quarto [listings](https://quarto.org/docs/websites/website-listings.html) with custom EJS templates in `html/`:

| Section | Content location | Listing data | Template |
|---------|-----------------|--------------|----------|
| **Blog** | `blog/{year}/{month}/{slug}/index.qmd` | QMD files with frontmatter | `html/blog/listing.ejs` |
| **Research** | `research/{articles,working-papers,chapters,reviews,abandonned}/{slug}/index.qmd` | QMD files with `pub-info` frontmatter | `html/research/listing.ejs` |
| **Teaching** | `teaching/ay_{YY-YY}.yml` | YAML data files | `html/teaching/listing.ejs` |
| **Talks** | `talks/talks_{YYYY}.yml` | YAML data files | `html/talks/listing.ejs` |

Research articles also use a custom Pandoc title block template: `html/research/title-block.html`.

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
- `r-wasm/live` — WebR/live-html support for interactive R code in browser

### Key Files

- `files/references.bib` — BibTeX bibliography
- `files/amj.csl` — Citation style (AMJ format)
- `atom.qmd` — RSS/Atom feed configuration for blog posts
- `netlify.toml` — Netlify deployment config (uses `@quarto/netlify-plugin-quarto`)
- `.venv/` — Python virtual environment (for Jupyter kernel used by Quarto)
