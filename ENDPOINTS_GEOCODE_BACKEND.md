# Endpoints que faltam no backend para o picker parar de chamar o Google

> Continuação de [`REDUCAO_CUSTO_GEOCODING.md`](REDUCAO_CUSTO_GEOCODING.md). Aquele
> documento explica por que a Geocoding API custou R$ 2.444 em julho/2026. Este lista o que
> falta no `sales-force-optimizer-api` para fechar a história.

## Situação

O backend já expõe `GET /geocode/reverse` com cache global — documentado em
`sales-force-optimizer-api/docs/modulos/geocode/README.md`. O ganho medido lá é
substancial: **43.440 leituras de coordenadas colapsam em 13.685 pontos distintos**, ou
seja, 68% das consultas são repetição de um ponto que outra pessoa já pagou. O cache do
picker é por aparelho e não captura nada disso.

O picker está pronto para a troca. Desde a 10.0.0 toda a rede passa por uma interface
única, `LocationPickerApi`, e redirecionar tudo é uma linha no boot do app:

```dart
LocationPickerApi.instance = MinhaApi();
```

O bloqueio é de cobertura: o picker faz **cinco** operações de rede, e o backend cobre
**uma**.

| Operação do picker | Endpoint no backend |
|---|---|
| `reverseGeocode` | ✅ `GET /geocode/reverse` |
| `forwardGeocode` | ❌ existe internamente (`GoogleMapsGeocodingService.geocodeAddress`), sem rota HTTP |
| `autocomplete` | ❌ não existe |
| `placeDetails` | ❌ não existe |
| `resolveMapsUrl` | ❌ não existe |

Enquanto as quatro faltarem, o picker continua com a chave do Google no cliente e com
Places/Geocoding habilitados nela. A migração é tudo ou nada por um motivo prático: só
depois que as quatro existirem dá para restringir a chave embarcada a Maps SDK/JS API.

---

## Convenções

Extraídas do endpoint que já existe, para os novos ficarem consistentes:

- **Sem prefixo de path.** O router é montado na raiz (`src/index.ts`), então é
  `/geocode/...`, não `/api/v1/geocode/...`.
- **Corpo cru, sem envelope.** O controller atual faz `res.status(200).json(result)`.
- **Erro como `{ "error": "..." }`** nos 4xx do controller.
- **Guard igual ao do reverse:** `ResourceType.adresses`, que está na lista de
  `ignoreResourceTypes` — qualquer usuário autenticado passa, sem exigir permissão
  específica no userType.

### Objeto de endereço canônico

Os três primeiros endpoints devolvem **o mesmo shape que `/geocode/reverse` já devolve**.
Não vale inventar formato novo — o cliente já tem o parser pronto.

```json
{
  "latitude": -25.2521,
  "longitude": -52.0215,
  "formattedAddress": "R. XV de Novembro, 1200 - Centro, Turvo - PR, 85150-000",
  "placeId": "ChIJN1t_tDeuEmsRUsoyG83frY4",
  "street": "R. XV de Novembro",
  "number": "1200",
  "neighborhood": "Centro",
  "city": "Turvo",
  "state": "Paraná",
  "stateCode": "PR",
  "country": "Brasil",
  "countryCode": "BR",
  "cep": "85150-000",
  "locationType": "ROOFTOP"
}
```

Todos os campos de endereço podem vir `null` — o Google nem sempre devolve todos os
componentes.

---

## 1. `GET /geocode/forward`

Endereço em texto livre → coordenada.

### Parâmetros

| Parâmetro | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| `address` | string | sim | Endereço em texto livre |
| `language` | string | não | Padrão: `pt-BR` |

### Respostas

- **`200`** — objeto de endereço canônico.
- **`404`** — `{ "error": "Nenhum endereço encontrado." }`. Não é falha: é "não achei".
- **`400`** — `address` ausente ou vazio.

### ⚠️ `latitude`/`longitude` aqui NÃO devem ser arredondados no grid

Esta é a única diferença de comportamento em relação ao `/geocode/reverse`, e é
deliberada.

O reverse devolve a coordenada arredondada em 4 casas (~11 m) porque a entrada já era uma
coordenada — o arredondamento é a chave do cache e o cliente guarda a original do seu
lado. No forward a coordenada **é o resultado**: o cliente a usa para centralizar o mapa e
posicionar o pin. Devolver a versão do grid deslocaria o pin em até 11 metros do endereço
que o usuário buscou.

Cachear pelo endereço normalizado, devolver a coordenada exata do Google.

### Por que este é o mais barato de entregar

`GoogleMapsGeocodingService.geocodeAddress` já existe, já cacheia e já grava
`origin: 'forward'` na tabela `geocodingCache`. Hoje só é chamado como efeito colateral de
salvar cliente/pedido/orçamento. **Falta apenas expor a rota** — a lógica está pronta.

Bônus já observado no documento do backend: uma linha gravada pelo forward responde um
reverse do mesmo ponto pelo índice `(latGrid, lngGrid, language)`. Expor o forward
alimenta o cache do reverse de graça.

---

## 2. `GET /geocode/autocomplete`

Sugestões para o campo de busca do picker.

### Parâmetros

| Parâmetro | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| `input` | string | sim | O que o usuário digitou |
| `language` | string | não | Padrão: `pt-BR` |
| `sessionToken` | string | não | Ver "billing por sessão" abaixo |
| `countries` | string | não | CSV de códigos ISO 3166-1 alpha-2, **máximo 5** (limite do Google) |
| `lat`, `lng` | number | não | Viés de proximidade — o picker envia o centro atual do mapa |

### Resposta `200`

```json
{
  "suggestions": [
    {
      "id": "ChIJN1t_tDeuEmsRUsoyG83frY4",
      "description": "R. XV de Novembro, 1200 - Centro, Turvo - PR",
      "matchOffset": 0,
      "matchLength": 16
    }
  ]
}
```

| Campo | Descrição |
|---|---|
| `id` | Identificador para pedir os detalhes depois. No Google é o `place_id` |
| `description` | Texto exibido na lista |
| `matchOffset` / `matchLength` | Trecho de `description` a destacar (o que casou com a busca). Se não tiver a informação, mande `0`/`0` — a UI só deixa de destacar |

**Sem resultado devolve `200` com lista vazia, não `404`.** A UI mostra "Nenhum resultado
encontrado" como estado normal.

Isso mapeia 1:1 para o modelo `PlaceSuggestion` que o picker já tem.

### ⚠️ Billing por sessão — o detalhe que decide o custo

O Places Autocomplete cobra de duas formas: **por request** ou **por sessão**. A sessão só
fecha quando o mesmo `sessiontoken` é enviado no Autocomplete *e* no Place Details
seguinte. Sem isso, cada tecla digitada vira um request cobrado separadamente.

Duas formas de resolver, escolha uma e documente:

1. **Repassar o token do cliente** (preferível): o picker já gera um UUID por sessão e
   envia. O backend só encaminha ao Google, nos dois endpoints.
2. **Servidor gera o token**: precisa mantê-lo estável entre o autocomplete e o details da
   mesma busca — o que exige estado por sessão de usuário. Mais complicado sem ganho.

---

## 3. `GET /geocode/place/{placeId}`

Detalhes da sugestão que o usuário escolheu. É o que dá a coordenada para mover o mapa.

### Parâmetros

| Parâmetro | Onde | Obrigatório | Descrição |
|---|---|---|---|
| `placeId` | path | sim | O `id` devolvido por `/geocode/autocomplete` |
| `language` | query | não | Padrão: `pt-BR` |
| `sessionToken` | query | não | O mesmo enviado no autocomplete — fecha a sessão de billing |

### Respostas

- **`200`** — objeto de endereço canônico, com a coordenada **real** do lugar (mesma regra
  do forward: não arredondar).
- **`404`** — `placeId` não resolve.

### Nota

Dependendo do tipo do lugar (cidade, estabelecimento), o Places Details **não retorna
`address_components`** — então `street`, `number`, `neighborhood` e `cep` podem vir todos
`null` mesmo com `200`. É esperado. O picker trata isso fazendo um reverse geocode da
coordenada devolvida para obter os componentes completos, o que continua funcionando
porque o reverse tem cache.

---

## 4. `GET /geocode/expand-url`

Expande um link do Google Maps (inclusive encurtado) para uma coordenada.

### Parâmetros

| Parâmetro | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| `url` | string | sim | URL do Google Maps colada pelo usuário |

### Respostas

- **`200`** — `{ "latitude": -25.2521, "longitude": -52.0215 }`
- **`404`** — não foi possível extrair coordenada
- **`400`** — `url` ausente ou de domínio não permitido

### Por que vale existir

**Resolve o Flutter Web.** Links curtos (`maps.app.goo.gl`) só revelam a coordenada depois
de seguir o redirect e ler o header `Location`. O navegador bloqueia essa leitura por
CORS. O contorno atual é um proxy externo configurado em
`GoogleLocationPickerApi.corsProxy`, que busca a página final e varre o HTML atrás das
coordenadas — frágil, porque pode capturar a coordenada do *viewport* em vez da do pin.

Com este endpoint, o proxy de CORS pode ser aposentado por completo.

Também centraliza os padrões de extração, hoje duplicados como regex no cliente (`@lat,lng`,
`?q=`, `ll=`, `/maps/search|place|dir/`, `!3d!4d`).

### ⚠️ Isto é um fetcher de URL arbitrária — trate como SSRF

O parâmetro vem do usuário e o servidor vai buscá-lo. Sem cuidado, vira um proxy para a
rede interna: alguém manda `http://169.254.169.254/latest/meta-data/` ou
`http://localhost:5432` e usa a API como ponte.

Mínimo necessário:

- **Allowlist de domínio** antes de qualquer requisição: `maps.app.goo.gl`, `goo.gl/maps`,
  `maps.google.*`, `google.com/maps`. Rejeitar com `400` o que não casar.
- **Revalidar o domínio a cada salto** do redirect — um encurtador pode apontar para
  qualquer lugar. Não basta validar a URL de entrada.
- **Limite de saltos** (3 é o que o cliente usa hoje) e **timeout curto** (5 s por salto).
- Bloquear IPs privados/loopback no destino resolvido.

---

## Nota sobre cache: Places tem regra diferente de Geocoding

O backend já cacheia geocoding, e essa decisão está tomada. Para os dois endpoints novos
de **Places** (autocomplete e details) vale revisitar antes de aplicar a mesma política:
os Termos do Google tratam os dois produtos de forma diferente — o `place_id` pode ser
armazenado indefinidamente, os demais campos de Places não.

Não é bloqueio para implementar; é um ponto para o time decidir conscientemente em vez de
herdar a política do geocoding por inércia.

---

## O que o picker faz depois que isso existir

Uma implementação de `LocationPickerApi` (~150 linhas, com testes) apontando para estes
quatro endpoints mais o reverse que já existe. Nenhum widget muda.

Aí sim dá para **restringir a chave do Google embarcada no app** a Maps SDK / Maps JS API,
sem Geocoding nem Places habilitados.

Uma correção de expectativa que vale registrar: o documento do backend sugere "remover a
chave do Google do cliente". Para um seletor de **mapa** isso não é alcançável — renderizar
o mapa exige chave em todas as plataformas (`AndroidManifest.xml`/`AppDelegate` no mobile,
`index.html` no web, e injetada no HTML do WebView no desktop). O ganho real é reduzir o
escopo da chave: uma chave vazada passa a servir só para desenhar mapas, não para consumir
Geocoding e Places na nossa conta.
