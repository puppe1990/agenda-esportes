# agenda-esportes

Sinatra + SQLite. TDD com Minitest e Faker. Um comando: `bundle exec rake test`.

## Invariantes

- Catálogo: `futebol`, `nfl`, `nba`, `automobilismo`. **Sem corrida.**
- `SportsCatalog.find!` recusa slug fora da lista e inclui o valor recebido na mensagem.
- Agenda pessoal em SQLite (`agenda_items`). A grade da TV é HTML em `views/index.erb`.
- POST `/agenda` grava e redireciona para `/?dia=YYYY-MM-DD`. Esporte desconhecido → 422.
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
