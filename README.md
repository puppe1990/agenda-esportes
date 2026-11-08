# Agenda de esportes

Grade da semana (futebol, NFL, NBA e automobilismo) com uma agendinha: escolhe o esporte, clica no dia, grava no SQLite.

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

Cleat runtime `rails` (instala Ruby via mise), app `agenda-esportes`.

```
cleat__deploy app=agenda-esportes ref=main
```

SQLite fica em `DATABASE_PATH` (padrão: `$CLEAT_DATA_DIR/agenda.sqlite3`). `SESSION_SECRET` precisa ter pelo menos 64 bytes.
