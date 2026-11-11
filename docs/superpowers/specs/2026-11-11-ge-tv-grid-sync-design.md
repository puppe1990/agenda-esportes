# Sync da grade GE → Agenda Esportes

Data: 2026-11-11
Status: aprovado (design), aguardando plano de implementação

## Objetivo

A home deixa de ler confrontos de `lib/tv_grid.rb` (lista à mão) e passa a mostrar a grade do ge.globo.com, atualizada todo dia: **hoje + 6 dias** (Brasília), **todos os esportes que o GE mandar**. Clique no card continua gravando na agenda pessoal (SQLite).

## Contexto

A agenda do GE (`/agenda/#/mais-esportes`) é o app `delivery/agenda-esportiva`. O first paint injeta `window.dataSportsSchedule`; dia fora desse recorte vai em `POST https://geql.globo.com/graphql`. Duas queries públicas, sem login:

- futebol: `championshipsAgenda(filter: { date })` com `now` / `past` / `future`
- demais: `multisportQuery($date)` → `multisportTabAgenda` (basquete, vôlei, o que vier)

Escudos e `liveWatchSources` vêm no JSON. O job não abre o browser: só GraphQL.

Hoje o app tem catálogo congelado `futebol | nfl | nba | automobilismo`, pills e CSS `:has(#f-fut)` etc. hardcoded, e `TvGrid::ALL` com dezenas de `game(...)`.

## Escopo

### Dentro

- Cliente GraphQL + parser → eventos da janela.
- Tabela `tv_events` no mesmo SQLite de `agenda_items`.
- `POST /interno/ge-sync` autenticado + `rake ge:sync`.
- GitHub Action diária chamando o POST no host.
- Lazy sync na home se o extrato tiver mais de 20 h.
- `TvGrid.on(day)` lê o SQLite.
- Pills dinâmicas: um esporte por `sport.name` do GE que aparecer na janela; conta = jogos do dia selecionado.
- Catálogo aberto aos slugs que o sync (e a agenda pessoal) já viram.
- Testes Minitest + Faker com JSON fake; sem rede no CI.

### Fora (YAGNI)

- Time favorito (`userSportsData` / globoID).
- Trail de vídeos, mosaico de times, JSON-LD.
- Nota editorial à mão (o texto do GE é campeonato + rodada/fase).
- Atualizar item já salvo quando o GE muda horário/placar.
- SSR do HTML `window.dataSportsSchedule` (GraphQL cobre os 7 dias).
- NBB e NBA em pills separadas (são o mesmo esporte **Basquete**).
- Timer systemd no VPS (o cron é o GitHub Action).

## Decisões

| Tema | Decisão |
| --- | --- |
| Janela | Hoje 00:00 BRT até hoje+6 (7 datas). `TZ=America/Sao_Paulo`. |
| Esportes | Tudo que o GE mandar. Slug = nome do esporte, não o campeonato. |
| Pills | União dos esportes com ≥1 jogo na janela. Contagem = dia selecionado (pode ser 0). |
| Persistência | SQLite `tv_events`, upsert por `ge_id`. |
| Lista à mão | `TvGrid::ALL` some. Fixtures nos testes substituem os dias 8–15/11. |
| Filtro CSS | `data-s` e `id="f-#{slug}"` usam o slug inteiro (`futebol`, `basquete`). Sem `fut`/`auto`. |
| `where` | Nomes de `liveWatchSources` unidos com ` · `. Vazio se null. |
| `note` | `"{campeonato} · {fase ou rodada}"`. |
| Título | `"{first.popularName} x {second.popularName}"`. |
| Horário | `startDate` + `startHour` como `-03:00`. Sem hora → `timed: false`, clock vira `d mon`. |
| Identidade | `ge_id` = `String(match.id)`. Sem id → `"#{slug}\|#{start_iso}\|#{title}"`. |
| Prune | Depois do upsert, apaga `tv_events` fora da janela **ou** cujo `ge_id` não veio nesta rodada. |
| Agenda pessoal | Continua `agenda_items`. Match com a grade por `[starts_on, title]`. |
| Auth do POST | `Authorization: Bearer $GE_SYNC_TOKEN`. Sem token no env → rota 404. |
| Teste / CI | Lazy sync desligado (`RACK_ENV=test`). Stub HTTP. |
| Corrida | Não inventamos o slug. Se o GE mandar, entra. |

## Arquitetura

```
GitHub Action 09:00 UTC
        │ POST /interno/ge-sync
        ▼
   GeSync.call(now:)
        │ 7 × (championshipsAgenda + multisportQuery)
        ▼
   GeClient  →  GeParser  →  tv_events + sync_state
        │
        ▼
   TvGrid.on(day)  →  home / Grade / week-strip
```

Unidades (um propósito cada):

| Unidade | Faz | Depende de |
| --- | --- | --- |
| `lib/sport_slug.rb` | `"Vôlei"` → `volei`; `"Futebol americano"` → `futebol-americano` | nada |
| `lib/ge_client.rb` | POST JSON em `geql.globo.com/graphql`, timeout 8 s, 1 retry | `Net::HTTP` |
| `lib/ge_parser.rb` | Resposta GraphQL → array de hashes de evento | `sport_slug` |
| `lib/ge_sync.rb` | Janela, chama client+parser, upsert/prune, `stale?`, mutex | client, parser, store |
| `AgendaStore` | Tabelas `tv_events` e `sync_state`; queries por dia | SQLite |
| `TvGrid` | `on(day)`, `in_window(from, to)`, `Event#clock` | store |
| `SportsCatalog` | `find!` / `in_window` a partir dos slugs vistos | store |
| `POST /interno/ge-sync` | Auth + `GeSync.call` + JSON | env, GeSync |
| `.github/workflows/ge-sync.yml` | cron + `workflow_dispatch` | secret `GE_SYNC_TOKEN` |

A home e a Grade **não** falam com o GE. Só `TvGrid` / `GeSync`.

## Dados

### `tv_events`

```sql
CREATE TABLE IF NOT EXISTS tv_events (
  ge_id TEXT PRIMARY KEY,
  sport TEXT NOT NULL,
  sport_name TEXT NOT NULL,
  title TEXT NOT NULL,
  starts_at TEXT NOT NULL,
  timed INTEGER NOT NULL DEFAULT 1,
  competition TEXT,
  watch_on TEXT,
  note TEXT
);
CREATE INDEX IF NOT EXISTS tv_events_starts_at ON tv_events (starts_at);
CREATE INDEX IF NOT EXISTS tv_events_sport ON tv_events (sport);
```

`starts_at` é ISO-8601 com offset (`2026-11-11T19:30:00-03:00`). `sport` é o slug; `sport_name` é o rótulo da pill (`Basquete`).

### `sync_state`

Uma linha: `synced_at` (ISO), `event_count` inteiro, `error` texto ou null.

`stale?` = sem linha, ou `synced_at` < now − 20 h, ou `event_count = 0` e `error` preenchido há mais de 20 h. Snapshot com erro recente **não** é stale: a home mostra o que já tinha.

### Catálogo

`SportsCatalog.in_window` = esportes distintos em `tv_events` na janela, ordenados por nome. `find!(slug)` aceita:

1. slug presente em `tv_events` ou `agenda_items`;
2. senão `UnknownSport` com o valor recebido e a lista atual.

Itens antigos com `nba` / `nfl` continuam válidos na agenda pessoal. Não aparecem nas pills a menos que o GE mande um esporte cujo slug coincida.

## GraphQL

Endpoint: `https://geql.globo.com/graphql`. Headers: `content-type: application/json`, `apollographql-client-name: agenda-esportes`, `origin: https://ge.globo.com`. Sem cookie.

Por cada data `YYYY-MM-DD` na janela, dois POSTs. Falha de um dia (4xx/5xx/timeout depois do retry) loga e segue os outros; se **todos** falharem, `GeSync` levanta, não apaga `tv_events`, grava `sync_state.error`.

Parser aceita qualquer item com `firstContestant` e `secondContestant` que tenham `popularName` (`MatchEventKind`, `soccerEvent`, confronto). Sem os dois lados (medalha/dispute solto) cai fora.

`moment` PAST/NOW/FUTURE no dia de hoje entra todos; nos dias seguintes só o que o GE mandar nessa data.

## Job

### `GeSync.call(now: Time.now)`

1. Calcula `from = now.to_date`, `to = from + 6` em Brasília.
2. Busca as 7 datas × 2 queries.
3. Parse + upsert.
4. `DELETE` em `tv_events` onde `ge_id` not in lote **ou** `starts_at` fora de `[from, to+1)`.
5. Atualiza `sync_state`.

Mutex de processo: o segundo `call` espera até 8 s o primeiro terminar e reusa o snapshot. Não dispara outro lote de POSTs.

### HTTP

`POST /interno/ge-sync` (também aceita `GET` com o mesmo bearer, para o cron do `curl` simples).

- Sem `GE_SYNC_TOKEN` → 404 (a rota não existe).
- Bearer errado → 401.
- Sucesso → 200 `{ "ok": true, "from": "…", "to": "…", "upserted": n, "deleted": n, "synced_at": "…" }`.
- GE todo fora → 502 `{ "ok": false, "error": "…" }`; snapshot intacto.

`rake ge:sync` chama o mesmo `GeSync.call`.

### GitHub Action

`.github/workflows/ge-sync.yml`: `cron: "0 9 * * *"` (06:00 BRT) e `workflow_dispatch`. `curl -fsS -H "Authorization: Bearer …" https://agenda-esportes.sites.gestaobem.com/interno/ge-sync`. Secret do repo: `GE_SYNC_TOKEN`. O mesmo valor vai no env do Cleat.

### Lazy na home

Em `GET /` e `GET` da Grade (a própria `/`): se `GeSync.stale?` e `RACK_ENV != "test"`, chama `GeSync.call` com teto de 8 s. Timeout ou erro → log, renderiza snapshot. Não bloqueia POST da agenda.

## UI

- Pills na home: `Todos` + `SportsCatalog.in_window`. Cada uma `for="f-#{slug}"` e count do dia.
- Radios `#f-all` e `#f-#{slug}` gerados no layout. CSS de filtro gerado no mesmo ERB (`body:has(#f-basquete:checked) .game-card:not([data-s=basquete]){display:none}` e equivalentes para `.cal-event` / `.ev` / pill ativa). Sem JS.
- Dia sem jogos: empty state; os `.sport-card` de alta manual listam os esportes da janela (não as quatro fixas).
- Copy OG/meta: “Jogos da TV nos próximos 7 dias.” (sai a lista NFL/NBA).
- `/agenda` filtros da barra: os mesmos slugs da janela **união** slugs já salvos (pra filtrar item `nba` antigo).

## Erros e estados

| Situação | Comportamento |
| --- | --- |
| Nunca sincronizou | Home vazia, empty state. Lazy tenta na hora. |
| Sync ok | Grade da janela. |
| GE fora, há snapshot | Home mostra snapshot; `sync_state.error` preenchido; POST interno 502. |
| Dia da janela sem jogos daquele esporte | Pill permanece (está na união dos 7 dias); count 0; cards daquele esporte somem. |
| Jogo adiado / saiu do GE | Some no próximo sync (prune). Item salvo fica. |
| Título GE mudou | Novo `title`; item salvo com o título velho não casa mais o chip `is-saved`. |

## Testes

Um comando: `bundle exec rake test`.

- `sport_slug_test`: acentos, espaço, idempotência; Faker gera nomes.
- `ge_parser_test`: fixture JSON (futebol + NBA + NBB + vôlei); NBB e NBA → `basquete`; `where` Disney+; `ge_id`; evento sem contestantes ignorado.
- `ge_sync_test`: stub do client; 7 dias × 2 chamadas; upsert; prune de id ausente e de fora da janela; mutex; `stale?` 20 h; falha total não apaga tabela.
- `tv_grid_test`: `on(day)` a partir do store (Faker); vazio fora da janela. Cai a asserção nos jogos 8–15/11 hardcoded.
- `sports_catalog_test`: `in_window` só o que está em `tv_events`; `find!` aceita slug de `agenda_items`; rejeita slug inédito com o valor na mensagem. Some a lista fixa de quatro (e o “esperado: futebol, nfl…” vira a lista atual).
- `app_test`: home com fixture de sync mostra pills Basquete/Futebol; `data-s="basquete"`; POST `/interno/ge-sync` 404 sem token, 401 token ruim, 200 com stub; lazy não dispara em test.

## Riscos

- GraphQL do GE muda o schema: o parser quebra, snapshot permanece, Action 502. Ajuste o parser.
- Rate limit: 14 POSTs/dia é pouco; se bloquear, User-Agent + origin já vão no client.
- Pills demais num dia de Olimpíada: aceito nesta versão (sem agrupamento).
- Cleat sem `GE_SYNC_TOKEN`: só lazy na home; Action falha até o env existir.
