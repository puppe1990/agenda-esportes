# agenda-esportes

Sinatra + SQLite. TDD com Minitest e Faker. Um comando: `bundle exec rake test`.

## Invariantes

- Catálogo: `futebol`, `nfl`, `nba`, `automobilismo`. **Sem corrida.**
- `SportsCatalog.find!` recusa slug fora da lista e inclui o valor recebido na mensagem.
- Agenda pessoal em SQLite (`agenda_items`). Confrontos da TV em `lib/tv_grid.rb`. A home é o sistema: faixa da semana (`.week-strip`), pills de esporte, Lista (cards) e Grade (mês).
- CRUD de `agenda_items`: `GET /agenda`, `GET /agenda/:id`, `GET /agenda/:id/edit`, `POST /agenda`, `PATCH /agenda/:id`, `DELETE /agenda/:id`. Item ausente → 404. Esporte desconhecido → 422.
- A agendinha usa `.game-card` (um form cada, com `sport` + `title` + `kicks_at` + `note` + `watch` do confronto). Cada card mostra onde assistir (`where`) e um comentário (`note`: posição ou se é decisivo). Clique grava o jogo no dia selecionado, com horário e comentário. Dia sem grade cai nos quatro `.sport-card`. Sem `<select>` e sem botão “Colocar na agenda”. Sem título, o store usa o nome do catálogo. A lista mostra esporte, título, horário, canal e comentário, na ordem do horário.
- Faixa da semana começa na segunda (`lib/week_strip.rb`). Dia selecionado mint (`.is-on`) com “N jogos”; os outros “N jgs”. Hoje vira o rótulo `hoje`. Setas ±7 dias. Pills `Todos` / Futebol / NFL / NBA / Automobilismo com a conta do dia. Lista é o padrão (`.v-lista`); Grade mostra o mês. Calendário começa no domingo. Cada célula lista os confrontos (`.cal-event`). Clique no chip grava no dia do jogo. Chip já salvo (`.cal-event.is-saved`) abre o item. Card da lista some quando o jogo já está na agenda.
- Célula do mês tem altura fixa (`height`/`max-height` 11.2rem, 7.4rem no mobile) e `min-height:0` + `overflow-x:hidden`. `.is-on` usa o mint; não solta o teto. Título do chip com ellipsis.
- Pele dark mint: `--bg:#0b0e14`, `--accent:#6eff94`. Sem `data-theme="paper"`.
- URL do dia: `/?dia=8&mes=11&ano=2026` (helper `day_path`). ISO `?dia=YYYY-MM-DD` continua abrindo o dia. Combo inválido → 400. POST redireciona com os três params. `/agenda` filtra pelos mesmos (`dia+mes+ano` = dia, `mes+ano` = mês, `ano` = ano). Nav “Minha agenda” fica `/agenda` inteira. Hidden `day` do form continua ISO.
- Copy em português. `noindex`. Preview local fora da porta 8765 (use 8791).

## Layout

| Path | O quê |
| --- | --- |
| `lib/sports_catalog.rb` | Catálogo congelado |
| `lib/tv_grid.rb` | Confrontos da TV por dia |
| `lib/agenda_store.rb` | SQLite |
| `lib/month_grid.rb` | Células do mês |
| `lib/week_strip.rb` | Faixa segunda–domingo |
| `app.rb` | Rotas Sinatra |
| `views/` | Layout + agendinha + CRUD (`_cal_event.erb` = chip do mês) |
| `test/` | Minitest + Faker + rack-test |

Não virar Rails. Não reintroduzir corrida.

O unit do Cleat usa `ProtectHome=true`, então o Ruby do mise em `/home/ubuntu` some na hora de subir. `release_command` copia o prefixo para `/opt/agenda-esportes/ruby` e `bin/boot` chama esse Ruby.
