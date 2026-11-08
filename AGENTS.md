# agenda-esportes

Sinatra + SQLite. TDD com Minitest e Faker. Um comando: `bundle exec rake test`.

## Invariantes

- Catálogo: `futebol`, `nfl`, `nba`, `automobilismo`. **Sem corrida.**
- `SportsCatalog.find!` recusa slug fora da lista e inclui o valor recebido na mensagem.
- Agenda pessoal em SQLite (`agenda_items`). A grade da TV é HTML em `views/index.erb`.
- CRUD de `agenda_items`: `GET /agenda`, `GET /agenda/:id`, `GET /agenda/:id/edit`, `POST /agenda`, `PATCH /agenda/:id`, `DELETE /agenda/:id`. Item ausente → 404. Esporte desconhecido → 422.
- A agendinha usa quatro `.sport-card` (um form cada). Clique grava o esporte no dia selecionado, sem `<select>` e sem botão “Colocar na agenda”. Sem título, o store usa o nome do catálogo.
- Calendário começa no domingo. Dia marcado = tem item naquele mês.
- Copy em português. `noindex`. Preview local fora da porta 8765 (use 8791).

## Layout

| Path | O quê |
| --- | --- |
| `lib/sports_catalog.rb` | Catálogo congelado |
| `lib/agenda_store.rb` | SQLite |
| `lib/month_grid.rb` | Células do mês |
| `app.rb` | Rotas Sinatra |
| `views/` | Layout + grade + agendinha |
| `test/` | Minitest + Faker + rack-test |

Não virar Rails. Não reintroduzir corrida.

O unit do Cleat usa `ProtectHome=true`, então o Ruby do mise em `/home/ubuntu` some na hora de subir. `release_command` copia o prefixo para `/opt/agenda-esportes/ruby` e `bin/boot` chama esse Ruby.
