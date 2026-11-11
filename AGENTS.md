# agenda-esportes

Sinatra + SQLite. TDD com Minitest e Faker. Um comando: `bundle exec rake test`.

## Invariantes

- Seed inicial do catálogo: `futebol`, `nfl`, `nba`, `automobilismo`. **Sem corrida** até o GE mandar o slug. `AgendaStore#find_sport!` recusa slug inédito e inclui o valor recebido + a lista atual na mensagem.
- Agenda pessoal em SQLite (`agenda_items`). Grade da TV em `tv_events` (GraphQL `geql.globo.com`, janela hoje+6 BRT, todos os esportes do GE). `TvGrid.on(day)` lê o store. Pills e radios `id="f-#{slug}"` / `data-s="#{slug}"` usam o slug inteiro (`futebol`, `basquete`). A home é o sistema: faixa da semana (`.week-strip`), pills de esporte, Lista (cards) e Grade (mês).
- Sync: `rake ge:sync` e `GET/POST /interno/ge-sync` com `Authorization: Bearer $GE_SYNC_TOKEN` (sem token → 404). GitHub Action `.github/workflows/ge-sync.yml` cron `0 9 * * *`. Lazy na `GET /` se o snapshot tem mais de 20 h; desligado em `RACK_ENV=test`.
- CRUD de `agenda_items`: `GET /agenda`, `GET /agenda/:id`, `GET /agenda/:id/edit`, `POST /agenda`, `PATCH /agenda/:id`, `DELETE /agenda/:id`. Item ausente → 404. Esporte desconhecido → 422.
- A agendinha usa `.game-card` (um form cada, com `sport` + `title` + `kicks_at` + `note` + `watch` do confronto). Cada card mostra onde assistir (`where`) e um comentário (`note`: campeonato + fase/rodada do GE). Clique grava o jogo no dia selecionado, com horário e comentário. Dia sem grade cai nos `.sport-card` dos esportes da janela. Sem `<select>` e sem botão “Colocar na agenda”. Sem título, o store usa o nome do catálogo. A lista mostra esporte, título, horário, canal e comentário, na ordem do horário.
- Faixa da semana começa na segunda (`lib/week_strip.rb`). Dia selecionado mint (`.is-on`) com “N jogos”; os outros “N jgs”. Hoje vira o rótulo `hoje`. Setas ±7 dias. Pills `Todos` + um por esporte da janela, conta do dia. Lista é o padrão (`.v-lista`); Grade mostra o mês. Calendário começa no domingo. Cada célula lista os confrontos (`.cal-event`). Clique no chip grava no dia do jogo. Chip já salvo (`.cal-event.is-saved`) abre o item. Card da lista some quando o jogo já está na agenda.
- Célula do mês tem altura fixa (`height`/`max-height` 11.2rem, 7.4rem no mobile) e `min-height:0` + `overflow-x:hidden`. `.is-on` usa o mint; não solta o teto. Título do chip com ellipsis.
- Pele dark mint: `--bg:#0b0e14`, `--accent:#6eff94`. Sem `data-theme="paper"`.
- URL do dia: `/?dia=8&mes=11&ano=2026` (helper `day_path`). ISO `?dia=YYYY-MM-DD` continua abrindo o dia. Combo inválido → 400. POST redireciona com os três params. `/agenda` filtra pelos mesmos (`dia+mes+ano` = dia, `mes+ano` = mês, `ano` = ano). Nav “Minha agenda” fica `/agenda` inteira. Hidden `day` do form continua ISO.
- Copy em português. `noindex`. Preview local fora da porta 8765 (use 8791).

## Layout

| Path | O quê |
| --- | --- |
| `lib/sports_catalog.rb` | Seed `futebol/nfl/nba/automobilismo` + `UnknownSport` |
| `lib/sport_slug.rb` | `"Vôlei"` → `volei` |
| `lib/ge_client.rb` | POST GraphQL `championshipsAgenda` + `multisportQuery` |
| `lib/ge_parser.rb` | JSON do GE → hashes de `tv_events` |
| `lib/ge_sync.rb` | Janela, upsert/prune, `stale?`, mutex |
| `lib/tv_grid.rb` | `on(day)` / `grouped` a partir do store |
| `lib/agenda_store.rb` | SQLite (`agenda_items`, `tv_events`, `sports`, `sync_state`) |
| `lib/app_helpers.rb` | Helpers Sinatra (dia, CSRF, pills, lazy sync) |
| `lib/month_grid.rb` | Células do mês |
| `lib/week_strip.rb` | Faixa segunda–domingo |
| `app.rb` | Rotas Sinatra + `/interno/ge-sync` |
| `views/` | Layout + agendinha + CRUD (`_cal_event.erb` = chip do mês) |
| `public/og.html` | Card OG 1200×630 (faixa mint). Rasteriza com `bash scripts/render-og.sh` → `public/og.png` |
| `.github/workflows/ge-sync.yml` | Cron 09:00 UTC |
| `test/` | Minitest + Faker + rack-test. HTTP em `test/app_*_test.rb`; fakes em `test/support/` |

Não virar Rails. Não reintroduzir corrida.

O unit do Cleat usa `ProtectHome=true`, então o Ruby do mise em `/home/ubuntu` some na hora de subir. `release_command` copia o prefixo para `/opt/agenda-esportes/ruby` e `bin/boot` chama esse Ruby.

## Code style

- Functions: 4-20 lines. Split if longer.
- Files: under 500 lines. Split by responsibility.
- One thing per function, one responsibility per module (SRP).
- Names: specific and unique. Avoid `data`, `handler`, `Manager`.
  Prefer names that return <5 grep hits in the codebase.
- Types: explicit on public boundaries.
- No code duplication. Extract shared logic into a function/module.
- Early returns over nested ifs. Max 2 levels of indentation for control flow.
- Exception messages must include the offending value and expected shape.

## Comments

- Keep intent/provenance comments. Don't strip them on refactor.
- Write WHY, not WHAT.
- GraphQL GE: AgendaItem is a union — query `... on SoccerEvent` / `MatchEventKind` wrapping `match { }`; contestants `... on Team` / `Athlete`. Direct `match` on AgendaItem 422s.
- Tilt ERB: `<%== %>` is a SyntaxError. `escape_html: true` encodes CSS quotes; generated `filter_css` uses unquoted `[data-s=#{slug}]`.
- Cron hits GET `/interno/ge-sync` because Rack authenticity blocks a tokenless POST.

## Tests

- Tests run with a single command: `bundle exec rake test`.
- `TZ` is set in `test/test_helper.rb` (`America/Sao_Paulo`). Local Ruby: `rvm use ext-ruby-4.0.2` then that command. CI uses 3.3.6.
- Every new function gets a test. Bug fixes get a regression test.
- Mock GE I/O with named fake classes (`EmptyGeClient`, `DownGeClient`, `RecordingClient`), not inline stubs.
- Tests must be F.I.R.S.T: fast, independent, repeatable, self-validating, timely.

## Dependencies

- Inject the GE poster via `GeClient.new(poster:)` and the client via `App.ge_client=` / `GeSync.call(client:)`.
- Wrap geql behind `GeClient`. Do not call Net::HTTP from `GeSync` or routes.
- Config: `DATABASE_PATH`, `SESSION_SECRET`, `GE_SYNC_TOKEN`, `CLEAT_DATA_DIR`, `PORT`. One source of truth in env.

## Structure

- Follow Sinatra: `app.rb` routes, `lib/` domain, `views/`, `test/` mirrors `lib/` plus `test/app_*_test.rb` for HTTP.
- Prefer small focused modules over god files.

## Formatting

- Ruby default style. Don't discuss tabs/spaces/line length in session.

## Logging

- Structured JSON for `rake ge:sync` / `/interno/ge-sync` success and 502 bodies.
- Plain `$stderr.puts "ge-sync lazy: #{error.class}: #{error.message}"` for the home fallback.

## Defensive programming

- Retries: `GeClient` retries once on timeout/socket/HTTP/JSON errors.
- Timeouts: geql open/read 8s; lazy home sync 8s.
- Graceful degradation: lazy GET `/` logs the error and still renders the last snapshot.
- No circuit breaker, rate limit, or bulkhead.

Push to `origin/main` auto-deploys via Cleat webhook. Open a PR; do not push `main` from a feature branch until merge.
