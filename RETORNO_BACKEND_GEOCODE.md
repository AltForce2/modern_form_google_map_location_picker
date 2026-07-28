# Retorno: os endpoints pedidos estão implementados

Resposta a [`ENDPOINTS_GEOCODE_BACKEND.md`](ENDPOINTS_GEOCODE_BACKEND.md). Os quatro
endpoints que faltavam foram implementados no `sales-force-optimizer-api`, seguindo as
convenções e os avisos daquele documento.

**Ainda não está em produção** — ver "Antes de vocês começarem" no fim.

## Cobertura

| Operação do picker | Endpoint | Status |
|---|---|---|
| `reverseGeocode` | `GET /geocode/reverse` | já existia |
| `forwardGeocode` | `GET /geocode/forward` | ✅ novo |
| `autocomplete` | `GET /geocode/autocomplete` | ✅ novo |
| `placeDetails` | `GET /geocode/place/:placeId` | ✅ novo |
| `resolveMapsUrl` | `GET /geocode/expand-url` | ✅ novo |

5/5. Dá para implementar o `LocationPickerApi` completo e reduzir o escopo da chave
embarcada.

---

## Contratos

Todos com guard `ResourceType.adresses`, corpo cru sem envelope e `{ "error": "..." }` nos
4xx — como vocês especificaram.

### `GET /geocode/forward`

| Parâmetro | Tipo | Obrigatório |
|---|---|---|
| `address` | string | sim |
| `language` | string | não (padrão `pt-BR`) |

`200` → objeto de endereço canônico · `404` → `Nenhum endereço encontrado.` · `400` →
`address` vazio.

**A coordenada NÃO é arredondada no grid**, conforme vocês pediram. Implementado como um
método separado (`geocodeAddressFull`) que devolve a coordenada exata do Google. O
single-flight é compartilhado com o forward interno — os dois resolvem o mesmo texto, então
chamadas concorrentes se aproveitam.

### `GET /geocode/autocomplete`

| Parâmetro | Tipo | Obrigatório |
|---|---|---|
| `input` | string | sim |
| `language` | string | não |
| `sessionToken` | string | não |
| `countries` | CSV ISO alpha-2 | não (truncado em 5) |
| `lat`, `lng` | number | não (viés de proximidade, raio 50 km) |

```json
{ "suggestions": [
  { "id": "ChIJ...", "description": "R. XV de Novembro, 1200 - Centro, Turvo - PR",
    "matchOffset": 0, "matchLength": 16 }
] }
```

Sem resultado → `200` com `suggestions: []`, nunca `404`. `matchOffset`/`matchLength` vêm
de `matched_substrings[0]`; quando ausente, `0`/`0`.

**Billing por sessão: adotamos a opção 1** — o `sessionToken` é repassado do cliente. O
picker gera o UUID e manda; o backend só encaminha ao Google, no autocomplete e no details.
Vocês continuam donos do ciclo da sessão, que é onde a informação existe.

### `GET /geocode/place/:placeId`

| Parâmetro | Onde | Obrigatório |
|---|---|---|
| `placeId` | path | sim |
| `language` | query | não |
| `sessionToken` | query | não — mande o mesmo do autocomplete |

`200` → objeto canônico com a coordenada real (não arredondada) · `404` → não resolve.

Restringimos os `fields` a `geometry`, `formatted_address`, `place_id` e
`address_component`: o Places cobra por categoria de campo, e pedir tudo encareceria sem
uso. Se precisarem de algum campo a mais, é só avisar.

Como vocês anteciparam, `street`/`number`/`neighborhood`/`cep` podem vir todos `null` num
`200` — o Places Details não devolve `address_components` para certos tipos de lugar. O
fallback de vocês (reverse geocode da coordenada) continua valendo e é barato, porque o
reverse tem cache.

### `GET /geocode/expand-url`

| Parâmetro | Tipo | Obrigatório |
|---|---|---|
| `url` | string | sim |

`200` → `{ "latitude": -25.2521, "longitude": -52.0215 }` · `404` → não extraiu · `400` →
`url` vazia ou domínio fora da allowlist.

Não consome API do Google — é só HTTP seguindo redirect. Links longos, que já trazem a
coordenada na própria URL, são resolvidos **sem nenhuma requisição**.

O alerta de SSRF foi levado a sério. Implementado e verificado com casos reais:

| Recusado | Aceito |
|---|---|
| `169.254.169.254` (metadados de instância) | `maps.app.goo.gl` |
| `localhost:5432`, `127.0.0.1` | `google.com/maps/@...` |
| `10.0.0.5`, `192.168.1.1` | `maps.google.com.br` |
| `evil.com/maps` | |
| `accounts.google.com` (domínio Google fora de `/maps`) | |
| `file:///etc/passwd` | |

Allowlist antes de qualquer requisição, revalidação a cada salto, máximo 3 saltos, timeout
de 5 s, e `Location` relativo resolvido antes de validar.

### Objeto de endereço canônico

O mesmo que `/geocode/reverse` já devolve — nenhum formato novo, como vocês pediram:

```json
{
  "latitude": -25.2521, "longitude": -52.0215, "language": "pt-BR",
  "formattedAddress": "R. XV de Novembro, 1200 - Centro, Turvo - PR, 85150-000",
  "placeId": "ChIJ...", "street": "R. XV de Novembro", "number": "1200",
  "neighborhood": "Centro", "city": "Turvo", "state": "Paraná", "stateCode": "PR",
  "country": "Brasil", "countryCode": "BR", "cep": "85150-000", "locationType": "ROOFTOP"
}
```

---

## Places não é cacheado — decisão registrada

Vocês levantaram que os Termos do Google tratam Places diferente de Geocoding. Está certo,
e a decisão foi **não cachear** autocomplete nem details, com o motivo escrito no
cabeçalho do serviço para não se perder.

É a escolha conservadora. Se o custo de Places pesar, a mudança deve ser uma decisão
explícita do time — não herdar a política do geocoding por inércia, que era exatamente o
risco apontado.

## Sobre a chave do Google: vocês estavam certos

A doc do backend dizia "remova a chave do Google do cliente". Isso não é alcançável num
seletor de mapa — renderizar o mapa exige chave em toda plataforma. **Corrigimos a
documentação** para falar em reduzir o escopo da chave (Maps SDK / JS API, sem Geocoding
nem Places), que é o ganho real e verificável.

---

## Antes de vocês começarem

**Nada foi para produção ainda.** A sequência do lado do backend:

1. `yarn build && yarn migrate` — a migration adiciona as colunas de endereço, o `origin` e
   o índice de grid
2. Script de backfill — popula o cache a partir dos endereços já cadastrados, sem custo
3. Deploy

O passo 2 importa para vocês por um motivo concreto: **o `/geocode/forward` trata linhas de
cache legadas como miss**. As linhas antigas guardam só lat/lng, sem os componentes, e não
cumprem o contrato do endpoint — então a primeira consulta de cada endereço antigo chama o
Google. O backfill preenche a maior parte disso de graça, antes de o endpoint entrar no ar.

Avisaremos quando estiver publicado.

## As correções internas do picker continuam valendo

Os endpoints eliminam o custo de pontos repetidos **entre usuários**. Não consertam as
chamadas duplicadas dentro do próprio picker — elas passam a ser round-trips duplicados ao
backend em vez de chamadas duplicadas ao Google. Mais baratas, mas ainda desperdício.

O que está em [`REDUCAO_CUSTO_GEOCODING.md`](REDUCAO_CUSTO_GEOCODING.md) segue de pé:
unificar `reverseGeocodeLatLng`, cache local por coordenada arredondada, e deduplicar
chamadas concorrentes do mesmo ponto.

## Dúvidas em aberto do nosso lado

- Algum campo adicional necessário no `placeDetails` (`fields` está restrito)?
- O raio de 50 km do viés de proximidade no autocomplete atende?
- `countries` é truncado em 5 (limite do Google) — silenciosamente. Preferem `400` quando
  vierem mais?
