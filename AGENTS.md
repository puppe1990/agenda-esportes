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
| `lib/month_grid.rb` | Células do mês |
| `lib/week_strip.rb` | Faixa segunda–domingo |
| `app.rb` | Rotas Sinatra + `/interno/ge-sync` |
| `views/` | Layout + agendinha + CRUD (`_cal_event.erb` = chip do mês) |
| `public/og.html` | Card OG 1200×630 (faixa mint). Rasteriza com `bash scripts/render-og.sh` → `public/og.png` |
| `.github/workflows/ge-sync.yml` | Cron 09:00 UTC |
| `test/` | Minitest + Faker + rack-test |

Não virar Rails. Não reintroduzir corrida.

O unit do Cleat usa `ProtectHome=true`, então o Ruby do mise em `/home/ubuntu` some na hora de subir. `release_command` copia o prefixo para `/opt/agenda-esportes/ruby` e `bin/boot` chama esse Ruby.
