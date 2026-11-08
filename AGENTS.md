# agenda-esportes

Sinatra + SQLite. TDD com Minitest e Faker. Um comando: `bundle exec rake test`.

## Invariantes

- Catálogo: `futebol`, `nfl`, `nba`, `automobilismo`. **Sem corrida.**
- `SportsCatalog.find!` recusa slug fora da lista e inclui o valor recebido na mensagem.
- Agenda pessoal em SQLite (`agenda_items`). Confrontos da TV em `lib/tv_grid.rb`. A home é o sistema: calendário, cards de jogo e a agenda.
- CRUD de `agenda_items`: `GET /agenda`, `GET /agenda/:id`, `GET /agenda/:id/edit`, `POST /agenda`, `PATCH /agenda/:id`, `DELETE /agenda/:id`. Item ausente → 404. Esporte desconhecido → 422.
- A agendinha usa `.game-card` (um form cada, com `sport` + `title` + `kicks_at` + `note` + `watch` do confronto). Cada card mostra onde assistir (`where`) e um comentário (`note`: posição ou se é decisivo). Clique grava o jogo no dia selecionado, com horário e comentário. Dia sem grade cai nos quatro `.sport-card`. Sem `<select>` e sem botão “Colocar na agenda”. Sem título, o store usa o nome do catálogo. A lista mostra esporte, título, horário, canal e comentário, na ordem do horário.
- Calendário começa no domingo. Dia marcado = tem item naquele mês.
- Copy em português. `noindex`. Preview local fora da porta 8765 (use 8791).

## Layout

| Path | O quê |
| --- | --- |
| `lib/sports_catalog.rb` | Catálogo congelado |
| `lib/tv_grid.rb` | Confrontos da TV por dia |
| `lib/agenda_store.rb` | SQLite |
| `lib/month_grid.rb` | Células do mês |
| `app.rb` | Rotas Sinatra |
| `views/` | Layout + agendinha + CRUD |
| `test/` | Minitest + Faker + rack-test |

Não virar Rails. Não reintroduzir corrida.

O unit do Cleat usa `ProtectHome=true`, então o Ruby do mise em `/home/ubuntu` some na hora de subir. `release_command` copia o prefixo para `/opt/agenda-esportes/ruby` e `bin/boot` chama esse Ruby.
