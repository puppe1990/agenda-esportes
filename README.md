# Agenda de esportes

Faixa da semana (segunda a domingo) com os jogos da TV no dia. Clica no confronto e grava na agenda pessoal (SQLite). Lista é o padrão; Grade mostra o mês. O dia da home é `/?dia=8&mes=11&ano=2026`. CRUD em `/agenda` (filtra pelos mesmos params). A grade vem do GraphQL do ge.globo.com (segunda da semana até hoje + 6 dias, todos os esportes). Dark mint.

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

O seed do catálogo **não** inclui corrida. Slugs novos entram quando o GE manda o esporte (ex.: `basquete`). Pills e `data-s` usam o slug inteiro.

```bash
bundle exec rake ge:sync   # DATABASE_PATH=...
```

O cron diário (06:00 BRT) é o workflow `.github/workflows/ge-sync.yml`, que chama `GET /interno/ge-sync` com o secret `GE_SYNC_TOKEN`. O mesmo valor vai no env do Cleat. Sem o token a rota responde 404; a home ainda tenta um lazy sync se o snapshot tiver mais de 20 h.

Card Open Graph: `public/og.html` (dark mint, faixa da semana) rasteriza em `public/og.png` 1200×630.

```bash
bash scripts/render-og.sh
```

## Deploy

Cleat runtime `rails` (instala Ruby via mise), app `agenda-esportes`. O systemd esconde `/home`, então o deploy copia o Ruby do mise para `/opt/agenda-esportes/ruby` e o processo sobe com `bash bin/boot`.

```
cleat__deploy app=agenda-esportes ref=main
```

SQLite fica em `DATABASE_PATH` (padrão: `$CLEAT_DATA_DIR/agenda.sqlite3`). `SESSION_SECRET` precisa ter pelo menos 64 bytes.
