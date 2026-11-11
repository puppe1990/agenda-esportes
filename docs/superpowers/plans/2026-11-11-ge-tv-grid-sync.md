# GE TV Grid Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A home grade filled from `geql.globo.com` for today+6 days (Brasília), every GE sport, via SQLite + daily POST.

**Architecture:** `GeClient` POSTs GraphQL; `GeParser` turns JSON into event hashes; `GeSync` upserts `tv_events` and prunes the window; `TvGrid.on` reads the store; pills/CSS radios are generated from sports in that window. GitHub Action curls `POST /interno/ge-sync`.

**Tech Stack:** Sinatra, SQLite3, Minitest, Faker, Net::HTTP, GitHub Actions cron.

**Spec:** `docs/superpowers/specs/2026-11-11-ge-tv-grid-sync-design.md`

---

## Files

| File | Responsibility |
| --- | --- |
| `lib/sport_slug.rb` | `"Vôlei"` → `volei` |
| `lib/ge_parser.rb` | GraphQL JSON → event hashes |
| `lib/ge_client.rb` | Two GraphQL POSTs per date |
| `lib/ge_sync.rb` | Window, upsert, prune, stale?, mutex |
| `lib/agenda_store.rb` | `sports`, `tv_events`, `sync_state` |
| `lib/sports_catalog.rb` | `UnknownSport` + `Item`; lookup via store |
| `lib/tv_grid.rb` | `Event#clock` + `on(day)` from store |
| `app.rb` | Sync route, pills, lazy GET /, drop FILTER_SLUG |
| `views/layout.erb` | Dynamic radios + generated CSS |
| `views/index.erb` | `data-s="#{slug}"`, pills from window |
| `public/app.css` | Drop hardcoded `#f-fut` / `#f-auto` hide rules |
| `Rakefile` | `ge:sync` |
| `.github/workflows/ge-sync.yml` | Daily curl |
| `test/*` | TDD as below |

`TvGrid::ALL` is deleted. Tests seed the store.

---

### Task 1: SportSlug

- Create: `lib/sport_slug.rb`, `test/sport_slug_test.rb`

- [x] Failing tests: `Basquete`→`basquete`, `Vôlei`→`volei`, `Futebol americano`→`futebol-americano`, Faker name round-trips to `[a-z0-9-]+`
- [ ] Implement `SportSlug.call(name)` with Unicode downcase + hyphen
- [ ] Commit

### Task 2: GeParser

- Create: `lib/ge_parser.rb`, `test/ge_parser_test.rb`

- [ ] Fixture hashes (Faker names) for futebol `championshipsAgenda` and multisport `multisportTabAgenda` (NBA + NBB + vôlei)
- [ ] Assert NBB and NBA share `sport=basquete`; `where` joins source names; skip items without two `popularName`s; `ge_id` from `match.id`
- [ ] Commit

### Task 3: Store tables

- Modify: `lib/agenda_store.rb`
- Test: `test/agenda_store_test.rb`

- [ ] `sports(slug PK, name)`, seed futebol/nfl/nba/automobilismo so existing `add(sport: "nba")` still works
- [ ] `tv_events` + `replace_tv_window` / `tv_events_on` / `sports_in_tv_window`
- [ ] `sync_state` read/write
- [ ] `find_sport!` raises `UnknownSport` with received value + current slugs; still refuses `corrida` until GE inserts it
- [ ] Commit

### Task 4: TvGrid from store

- Rewrite: `lib/tv_grid.rb`, `test/tv_grid_test.rb`

- [ ] `TvGrid.store =`; `on(day)` maps rows to `Event`, sorted by `starts_at`
- [ ] Clock still `17h` / `17h30` / `d mon` when `timed=false`
- [ ] Empty day is empty
- [ ] Commit

### Task 5: GeSync

- Create: `lib/ge_client.rb`, `lib/ge_sync.rb`, tests

- [ ] Client sends `championshipsAgenda` + `multisportQuery` (inject HTTP)
- [ ] `GeSync.call(store:, client:, now:)` hits 7 dates × 2, upserts, deletes ids not in batch / outside window
- [ ] Total failure leaves table, sets error
- [ ] `stale?` after 20h; mutex 8s
- [ ] Commit

### Task 6: App + UI

- Modify: `app.rb`, views, `app.css`, `test/app_test.rb`

- [ ] `POST/GET /interno/ge-sync` bearer; 404 without `GE_SYNC_TOKEN`
- [ ] Home seeds from store; pills = window sports; `data-s` = full slug
- [ ] Generated CSS `:has(#f-#{slug}:checked)`
- [ ] Lazy sync off in test
- [ ] Rewrite app tests that assumed Vasco/Bills hardcoded grid to seed Faker events
- [ ] Meta copy “Jogos da TV nos próximos 7 dias.”
- [ ] Commit

### Task 7: Rake, Action, docs

- [ ] `rake ge:sync`
- [ ] `.github/workflows/ge-sync.yml` cron `0 9 * * *`
- [ ] AGENTS.md + README
- [ ] `bundle exec rake test` green
- [ ] Commit
