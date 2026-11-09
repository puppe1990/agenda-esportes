# Agenda de esportes

Calendário tipo agenda: os jogos da TV aparecem no dia, clica no confronto e grava na agenda pessoal (SQLite). CRUD em `/agenda`. Futebol, NFL, NBA e automobilismo.

Host: https://agenda-esportes.sites.gestaobem.com  
Repo: [puppe1990/agenda-esportes](https://github.com/puppe1990/agenda-esportes)

## Stack

Sinatra + SQLite + Puma. Testes em Minitest com Faker. Sem Rails.

## Comandos

```bash
bundle install
bundle exec rake test
bundle exec puma -C config/puma.rb   # PORT=8791
```

O catálogo de esportes **não** inclui corrida. O slug é `automobilismo`.

## Deploy

Cleat runtime `rails` (instala Ruby via mise), app `agenda-esportes`. O systemd esconde `/home`, então o deploy copia o Ruby do mise para `/opt/agenda-esportes/ruby` e o processo sobe com `bash bin/boot`.

```
cleat__deploy app=agenda-esportes ref=main
```

SQLite fica em `DATABASE_PATH` (padrão: `$CLEAT_DATA_DIR/agenda.sqlite3`). `SESSION_SECRET` precisa ter pelo menos 64 bytes.
