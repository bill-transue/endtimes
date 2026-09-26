# End Times

A public Rails 8 reader that **links out** to news stories and adds original Biblical analysis. We do not reprint full article bodies. End-times prophecy is a theme, not the only frame: sin, justice, hope, and mercy count.

## Local run

You need Ruby 3.2+, PostgreSQL, and Bundler.

```bash
cp .env.example .env          # optional; the app runs with no API keys
bundle install
bin/rails db:prepare
bin/rails db:seed
bin/dev                       # or: bin/rails server -b 0.0.0.0 -p 4317
```

Then open [http://127.0.0.1:4317](http://127.0.0.1:4317).

- Public feed: `/`
- Story: `/stories/:id`
- About: `/about`
- Admin (HTTP basic): `/admin/stories` — default local user `admin` / `endtimes`

Without `NEWS_API_KEY`, ingest is RSS-only. Without `GEMINI_API_KEY` or `OPENAI_API_KEY`, analyses use a mock client so the UI still works. `db:seed` loads a representative World English Bible index and demo published stories if the feed is empty.

Background jobs use **Solid Queue** on Postgres (no Redis). Recurring work lives in `config/recurring.yml` (ingest ~every 20 minutes, select ~hourly). Start the worker with:

```bash
bin/jobs
```

In development, Active Job also runs inline via the async adapter, so `bin/rails runner IngestNewsJob.perform_now` is enough for a manual crawl.

## Environment variables

| Variable | Required | Purpose |
| --- | --- | --- |
| `NEWS_API_KEY` | No | GNews API key. Blank → RSS-only ingest |
| `GEMINI_API_KEY` | No | Default LLM (Gemini Flash-Lite). Blank with no OpenAI key → mock analyses |
| `OPENAI_API_KEY` | No | Optional OpenAI mini path when Gemini is unset |
| `LLM_PROVIDER` | No | `gemini`, `openai`, or `mock` |
| `LLM_MODEL` | No | Override model id |
| `ADMIN_USERNAME` / `ADMIN_PASSWORD` | Production yes | HTTP basic for `/admin/stories` |
| `DAILY_PUBLISH_CAP` | No | Max auto-publishes per day (default 10) |
| `DATABASE_URL` | Production | Postgres connection string |
| `RAILS_MASTER_KEY` | Production | Decrypts `config/credentials.yml.enc` |
| `SECRET_KEY_BASE` | Production | Set automatically on Render via `generateValue` |
| `PORT` | No | Defaults to 3000; this repo’s Procfile uses **4317** locally |

## Deploy on Render

This repo is a Render Blueprint.

1. New → Blueprint → this repository.
2. Fill the **sync: false** secrets in the dashboard:
   - `RAILS_MASTER_KEY` — contents of local `config/master.key`
   - `ADMIN_USERNAME` / `ADMIN_PASSWORD`
   - optional `NEWS_API_KEY`, `GEMINI_API_KEY`, `OPENAI_API_KEY`
3. The blueprint starts:
   - **web**: `bin/rails server` (`./bin/render-build.sh` builds, migrates, and seeds)
   - **worker**: `bin/jobs` (Solid Queue + `config/recurring.yml`)
   - **Postgres**: one database used for the app, cache, queue, and cable

Copy `config/master.key` from the machine that generated `config/credentials.yml.enc`. Do not commit the key.

If GNews and LLM keys are missing in production, RSS ingest and mock analyses still run; the seed demo stories appear only when there is not yet a published feed.

## Tests

```bash
bin/rails test
```

HTTP and LLM calls are stubbed (WebMock + mock client). CI must not hit live APIs.

## License notes

World English Bible quotations are public domain. News titles and excerpts remain the publishers’; this app stores only enough to analyze and to link out.
