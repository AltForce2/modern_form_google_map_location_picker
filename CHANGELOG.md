## 10.0.0

### Redução de custo da Geocoding API

* **`LocationPickerUtils.reverseGeocode` e `forwardGeocode` agora têm cache e single-flight.** O resultado é cacheado por coordenada arredondada a 4 casas (~11 m) + idioma; chamadas concorrentes do mesmo ponto compartilham uma única requisição. Resultados `null` não são cacheados, para não fixar falha temporária. Este era o problema documentado em `REDUCAO_CUSTO_GEOCODING.md`: o picker consultava a mesma coordenada 2–3 vezes, sem cache.
* **Os três caminhos redundantes de reverse geocode foram unificados.** `reverseGeocodeLatLng` deixou de montar a própria requisição HTTP e passou a usar `LocationPickerUtils.reverseGeocode`; `selectResolvedLatLng` e `decodeAndSelectPlace` reaproveitam o resultado que `moveToLocation` já produziu em vez de consultar de novo.
* **`getNearbyPlaces` removido.** Chamava a Places Nearby Search a cada movimento de mapa e escrevia em `nearbyPlaces`, que ninguém lia — o único consumidor era um método comentado desde 2020. O modelo `NearbyPlace` foi removido junto.
* **O card de endereço não refaz mais o geocode a cada rebuild.** A future é memoizada por coordenada; antes qualquer rebuild (troca de tipo de mapa, chegada do GPS) criava uma nova e disparava outra requisição cobrada.
* **O `sessiontoken` do Places passou a ser enviado no Details e renovado a cada seleção**, fechando a sessão de billing do Autocomplete — antes cada request era cobrado individualmente.

### Breaking changes

* `LocationAdress` → **`LocationAddress`** (grafia corrigida), arquivo `location_adress.dart` → `location_address.dart`, e `LocationResult.locationAdress` → `locationAddress`. Os campos passaram de `snake_case` para `camelCase` (`street_number` → `streetNumber`, etc.). **As chaves de `toMap()` continuam em `snake_case`** — são formato de fio e quebrariam dados já persistidos.
* `MapPicker.getAddress` retorna `Future<LocationResult?>` em vez de `Future<Map<String, String?>?>`.
* Parâmetros de `LocationPicker`/`MapPicker` que eram nulos com force-unwrap (`requiredGPS`, `initialCenter`, `initialZoom`, `language`, `desiredAccuracy`, `embedded`, …) agora são não-nulos com default. Usar `LocationPicker(apiKey)` diretamente estourava em `map.dart`.
* `resultCardAlignment` e `resultCardPadding` aceitam `AlignmentGeometry`/`EdgeInsetsGeometry`; o cast interno para `Alignment`/`EdgeInsets` quebrava com as variantes direcionais.
* `moveToLocation` e `reverseGeocodeLatLng` retornam `Future<LocationResult?>`.
* Removidos: `LocationPickerMapFactory.isUsingWebView()/isUsingNative()`, `PlaceholderWidget`, `SearchInput.searchInputKey`.
* **Removidos `autoCompleteWebUrl` e `detailsWebUrl`.** Eram uma URL pré-proxiada por endpoint, configurada no formato `X = "$proxy$X"` — que duplicava o prefixo se o inicializador rodasse duas vezes e deixava o geocoding de fora. Substituídos por `GoogleLocationPickerApi.corsProxy`, que cobre os três de uma vez e é idempotente:

  ```dart
  // antes
  LocationPickerUtils.corsProxy = proxy;
  LocationPickerUtils.autoCompleteWebUrl = '$proxy${LocationPickerUtils.autoCompleteWebUrl}';
  LocationPickerUtils.detailsWebUrl = '$proxy${LocationPickerUtils.detailsWebUrl}';

  // agora
  GoogleLocationPickerApi.corsProxy = proxy;
  ```
* `AutoCompleteItem` (arquivo `auto_comp_iete_item.dart`) removido, substituído por `PlaceSuggestion` da camada de API — eram o mesmo modelo. `RichSuggestion` passou a receber `PlaceSuggestion`.
* `LocationPickerUtils.httpClient`, `geocodeUrl`, `autoCompleteUrl`, `detailsUrl` e `getAppHeaders()` movidos para `GoogleLocationPickerApi`, onde a rede de fato acontece.

### Novidades

* **Adicionado `BackendLocationPickerApi`** — implementação pronta de `LocationPickerApi` para backends que expõem `/geocode/{reverse,forward,autocomplete,place/:id,expand-url}`. Instalar é uma linha no boot (`LocationPickerApi.instance = BackendLocationPickerApi(baseUrl: ..., headers: ...)`) e nenhum widget muda. Os headers são um callback assíncrono, para cobrir token que expira; se ele lançar, a chamada devolve `null` em vez de derrubar a tela. Detalhes de contrato: `404` vira `null` (não é erro), o `reverse` usa a coordenada **de entrada** — não a arredondada que o servidor devolve para cachear — e o `forward`/`place` usam a da resposta. Link longo do Maps é resolvido localmente, sem round-trip.

* **`LocationAddress` ganhou `stateCode`, `countryCode` e `locationType`.** Os dois primeiros vêm do `short_name` de `administrative_area_level_1` e `country`; o terceiro do `geometry.location_type` — que o parser ignorava, mesmo já recebendo o `results[0]` inteiro. O `locationType` (`ROOFTOP`, `RANGE_INTERPOLATED`, `GEOMETRIC_CENTER`, `APPROXIMATE`) permite sinalizar na interface quando o endereço é aproximado e pode estar a centenas de metros do ponto. As chaves de `toMap()` são aditivas (`state_code`, `country_code`, `location_type`), então dados serializados antes continuam legíveis.

* **Grid do cache de geocoding alinhado em 4 casas decimais (~11 m)**, o mesmo do backend de geocoding. Antes eram 5 casas (~1 m): dois pontos a poucos metros geravam duas chaves locais e dois round-trips que o servidor responderia do mesmo registro.

* Adicionado `ENDPOINTS_GEOCODE_BACKEND.md` — especificação dos quatro endpoints que faltavam no backend para o picker parar de chamar o Google diretamente. `RETORNO_BACKEND_GEOCODE.md` registra a entrega dos quatro.

* **Toda a rede passou para uma interface única e trocável: `LocationPickerApi`.** As cinco chamadas do pacote (reverse geocode, forward geocode, autocomplete, place details e resolução de link do Maps) passam por ela, e o `package:http` existe em um único arquivo — `GoogleLocationPickerApi`, a implementação padrão. Para deixar de bater direto no Google, implemente a interface e atribua `LocationPickerApi.instance = MinhaApi()` antes de abrir o picker; nenhum widget precisa mudar.
  * Os modelos de retorno (`PlaceSuggestion`, `PlaceDetails`) são do pacote, não o JSON cru do Google — uma implementação alternativa não precisa imitar `matched_substrings` nem `geometry.location`.
  * **Cache e single-flight ficam acima da interface**, em `LocationPickerUtils`, então valem para qualquer implementação sem que ela os reimplemente.
  * `LocationPickerUtils` não faz mais requisição: sobrou o cache e o parsing puro (`parseLatLng`, `isGoogleMapsUrl`, `extractCoordsFromUrl`).

* **`myLocationEnabled` passou a funcionar no desktop (WebView).** O Maps JS API não tem equivalente ao `myLocationEnabled` do SDK nativo, então o ponto azul simplesmente não existia no Windows/macOS/Linux. Agora o adapter WebView assina `Geolocator.getPositionStream` (filtro de 5 m) e desenha o marcador e o círculo de precisão via JS, com o mesmo rastreamento contínuo do nativo. A assinatura é cancelada no `dispose`.

### Correções

* **O `corsProxy` passou a valer para todas as chamadas REST do Google no Flutter Web**, não só para a expansão de link curto. As APIs de Geocoding e Places não enviam cabeçalhos CORS, então o navegador bloqueia a chamada direta; antes só autocomplete e details tinham como ser proxiados (via `autoCompleteWebUrl`/`detailsWebUrl`, um por endpoint) e o **geocoding não tinha variante Web nenhuma** — falhava por CORS no navegador.
* **Parsing defensivo em todas as respostas do Google.** `results[0]`, `predictions`, `matched_substrings[0]` e `geometry.location` eram acessados sem guarda; o Google devolve HTTP 200 com `results: []` em `ZERO_RESULTS`/`REQUEST_DENIED`/`OVER_QUERY_LIMIT`. O `status` do corpo agora é checado e logado com `error_message`.
* `LocationAddress.fromMap` tolera `address_components` ausente — o Places Details não retorna o campo para alguns tipos de place.
* `RichSuggestion` recorta os offsets de `matched_substrings` contra o tamanho real do texto, em vez de estourar `RangeError` no `substring`.
* **`MapPicker.build()` não tem mais efeitos colaterais.** Pedia permissão de localização, lia o GPS e chamava `Navigator.pop` a cada rebuild — e como a leitura do GPS chama `setState`, o rebuild se realimentava. Movido para `initState`.
* `catchError((error) => debugPrint(error))` lançava `TypeError` dentro do próprio handler de erro (`debugPrint` espera `String?`).
* O overlay "Finding place..." não fica mais preso quando a busca falha, e respostas obsoletas do autocomplete não sobrescrevem mais sugestões novas.
* `getAppHeaders()` só chama `PackageInfo.fromPlatform()` em Android/iOS. Em desktop o resultado era descartado e a chamada podia lançar, derrubando a requisição inteira.
* Vazamentos corrigidos: `StreamSubscription` do teclado e `Timer` de debounce no `SearchInput` não eram cancelados; o handler JS do WebView não era removido no `dispose`.
* `MapType.none` saiu do ciclo do botão de camadas — renderizava tela em branco no nativo e era tratado como `normal` no WebView.
* O estilo de mapa carregado de `mapStylePath` agora dispara `setState`; sem isso podia nunca ser aplicado.
* `WillPopScope` (deprecado) → `PopScope`.

### Interno

* `flutter_lints` ativado (o `include` estava comentado, então nenhum lint rodava). `flutter analyze` limpo.
* Camada de rede de Places extraída para `PlacesService`, fora do `State`. URLs montadas com `Uri` (o autocomplete enviava `input={texto}` com as chaves literais e não escapava acentos), `http.Client` injetável e timeout de 15 s em todas as chamadas.
* Diálogos de permissão unificados em `_LocationPermissionDialog`; protocolo do bridge WebView extraído para `MapBridgeProtocol`.
* Divergências remanescentes entre as implementações nativa e WebView documentadas em `LocationPickerMapInterface`: `onCameraMoveStarted` só dispara em `dragstart` no WebView, e o WebView emite um `onCameraIdle` extra logo após o primeiro render.
* Dependências: `android_intent_plus` removido (sem uso), `plugin_platform_interface` declarado (era usado só transitivamente).
* Testes: 45 casos cobrindo cache/single-flight de geocoding, `parseLatLng`, extração de coordenadas de URL, `LocationAddress` e o contrato do bridge. O teste que estava quebrado foi corrigido.
* CI: `flutter analyze` + `flutter test` em todo push e PR; publicação só em tag `v*` (antes publicava em todo push com os testes desativados).

> Inclui tudo de 9.5.1, 9.5.2 e 9.6.0. Com a rede centralizada em
> `LocationPickerApi`, o `corsProxy` passou a viver em
> `GoogleLocationPickerApi.corsProxy` — `LocationPickerUtils.corsProxy`
> continua funcionando como atalho `@Deprecated`, então quem já o configura via
> `InitHelper` não quebra.

## 9.5.2

* `_extractCoordsFromUrl` agora reconhece coordenadas no **path** de URLs do Google Maps (`/maps/search/lat,lng`, `/maps/place/lat,lng`, `/maps/dir/lat,lng`) — antes só cobria `@lat,lng`, `q=`/`query=`, `ll=` e `!3d!4d`, então um link como `https://www.google.com/maps/search/-24.737106,+-53.740050?...` caía no autocomplete e dava "Nenhum resultado encontrado".
* Separador de coordenadas tolerante a espaço URL-encoded após a vírgula (`+`, `%20` ou espaço literal) nos padrões `q=`/`query=` e no novo padrão de path — cobre links de busca compartilhados que trazem `lat,+lng`. Afeta web e nativo (path direto, independe do `corsProxy`).

## 9.5.1

* Resolução de link curto do Google Maps (`maps.app.goo.gl`) agora funciona no **Flutter Web** quando um proxy de CORS está configurado. Adicionado `LocationPickerUtils.corsProxy` (default vazio = comportamento atual): o app injeta o prefixo via `InitHelper`, espelhando o que já é feito com `autoCompleteWebUrl`/`detailsWebUrl`.
* Em `resolveGoogleMapsUrl`, o early-return de web foi substituído por um ramo via proxy: quando `corsProxy` está vazio mantém-se o `null` (degradação para autocomplete); com proxy, a requisição passa pelo proxy — que segue o redirect server-side e devolve a página final do Maps com CORS liberado — e as coords são extraídas do corpo da resposta (ou do header `X-Final-Url`, quando o proxy ecoa a URL pós-redirect). O caminho nativo (seguir o header `Location` manualmente) permanece inalterado.

## 9.5.0

* Campo de busca do `LocationPicker` agora reconhece coordenadas lat/lng coladas (ex.: `-23.5505, -46.6333`) e as resolve diretamente no mapa com reverse geocode completo, sem passar pelo Places Autocomplete.
* Adicionado suporte a colar links do Google Maps (`maps.app.goo.gl`, `goo.gl/maps`, `maps.google.*`, `google.com/maps`): o picker extrai as coords dos padrões `@lat,lng`, `?q=lat,lng`, `ll=lat,lng` e `!3dlat!4dlng`; para links curtos segue o redirect HTTP e inspeciona o header `Location` (funcional em Android/iOS/desktop; no Flutter Web a resolução de link curto é pulada por restrições de CORS, caindo para o autocomplete).
* Adicionado `LocationPickerUtils.parseLatLng(String)` — parser de coordenadas ancorado no texto completo (evita disparar em digitação parcial de endereços) com suporte a notação européia de vírgula decimal.
* Adicionado `LocationPickerUtils.isGoogleMapsUrl(String)` e `LocationPickerUtils.resolveGoogleMapsUrl(String)` — helper público e resolvedor assíncrono de URL do Google Maps.
* Método `selectResolvedLatLng(LatLng)` extraído em `LocationPickerState`: centraliza mover câmera + reverse geocode + chamar `onAutoConfirm` (reutilizado pelo fluxo de places e pelos novos resolvedores).
* Overlay "Finding place..." extraído para `_showFindingPlaceOverlay()`, eliminando duplicação de código.

## 9.1.0

* Adicionada flag `embedded` em `LocationPicker`/`MapPicker` para renderizar o picker inline (sem `Scaffold`/`AppBar`, com bordas arredondadas, `SearchInput` como overlay, card de resultado compacto, FABs reposicionados e absorção de `PointerScrollEvent` para não rolar o `Scrollable` pai no desktop/web).
* Adicionado parâmetro `gestureRecognizers` em `LocationPickerMapInterface.buildWidget` (propagado para `GoogleMap` e `InAppWebView`). Em modo embedded, o `MapPicker` injeta um `EagerGestureRecognizer` + `ScaleGestureRecognizer`/`PanGestureRecognizer` (limitados a `PointerDeviceKind.trackpad`) para impedir que `Scrollable` pais roubem gestos de pinch/two-finger scroll do touchpad.
* `_initCurrentLocation` agora respeita `automaticallyAnimateToCurrentLocation`: só anima a câmera para a posição do GPS automaticamente quando essa flag é `true`. O FAB "minha localização" continua sempre animando (via novo parâmetro interno `forceAnimate`). Corrige o bug em que o mapa "saltava" para a localização atual depois que o usuário selecionava um endereço em modo embedded.
* Em modo embedded, o `MapPicker` não bloqueia mais no `CircularProgressIndicator` enquanto aguarda o GPS — o mapa aparece imediatamente no `initialCenter` e a animação para a posição atual acontece em background quando o GPS responde (importante no desktop/Windows onde o GPS pode demorar vários segundos).
* `MapPicker.getAddress` agora retorna early quando `location == null` e trata respostas com `results: []` sem estourar `RangeError` — corrige o crash com `latlng=null,null` quando o card de localização renderiza antes do mapa emitir `onMapReady`/`onCameraIdle`.

## 4.1.7

* Updated deps to work with flutter stable 2.0.1

## 4.1.6

* use  `http: '>=0.12.2 <=0.13.0-nullsafety.0'`

## 4.1.5

* remove the upper bound for flutter

## 4.1.4

* remove `intl_translation` because it was not needed and was blocking migrating to nullsafety.
* updated `intl` so support nullsafety.

## 4.1.3

* Updated deps.

## 4.1.2+1

* Fixed an issue with the sample app.

## 4.1.2

* Added serbian language thanks to @aleksandar-radivojevic

## 4.1.1

* Remove io.flutter.embedded_views_preview requirement from readme and example

## 4.1.0

* Updated `geolocator: ^6.1.6`
* Added german translation thanks to @pwiesinge.

## 4.0.0

* Updated `google_maps_flutter: ^1.0.2`
* Added `desiredAccuracy` from `geolocator` package.

## 4.0.0-rc.3

* Improve the behavior when `requiredGPS` is set to true and the location permission id denied.

## 4.0.0-rc.2

* requiredGPS now defaults to false, because the permission handling is sufficient.

## 4.0.0-rc.1

* Updated to geolocator: 6.0.0 which provides better location handling.

## 3.3.5

* Added language parameter thanks to @JFtechOfficial.
* Add placeId to Location Result thanks to @Faizaan.
* Fixed: without supplying 'countries' autoCompleteSearch crashes while country is not mandatory #103.

## 3.3.4

* Added Italian language thanks to @JFtechOfficial.
* Added Region filter thanks to @Zamorite.
* migrated to flutter_intl for localization.
* updated deps.

## 3.3.3

* Made the initialZoom configurable thanks to @alfredjingle.
* updated deps.

## 3.3.2

* Added Spanish language thanks to @ppgcharge.
* updated deps.

## 3.3.1

* updated intl and intl_translation.

## 3.3.0

* Fix search hint not working.
* Replace resultCardConfirmWidget with resultCardConfirmIcon
* Updated deps.

## 3.2.2

* Prepare for 1.0.0 version of sensors and package_info. ([dart_lsc](http://github.com/amirh/dart_lsc))

## 3.2.1+2

* Updated deps.

## 3.2.1+1

* Fixing the wrong example README.MD.
* Updated deps.

## 3.2.1

* Updated deps.

## 3.2.0

* Restricted api key that is used in dart code, only implemented on the android side.
* Updated deps.

## 3.1.0

* Added `automaticallyAnimateToCurrentLocation` to fix https://github.com/humazed/google_map_location_picker/issues/24

## 3.0.1

* updated readme to reflect the changes in 3.0.0
* updated deps
* fix some issues relating to upgrading to provider: ^4.0.1 

## 3.0.0

* **Breaking change**. make `LocationPicker.pickLocation` to top level function
   and change the name to `showLocationPicker` to mach the style of time and date pickers.
* change the zoom level to 16 in the entire library to improve the UX.
* Added dark mode support.
* enabled custom map style
* enabled transparent appbar
* enabled custom confirm button
* enabled custom result card

## 2.1.2+1

* Updated deps.

## 2.1.2

* specify swift version to make integration with objc more easy.
Note: you also need to edit your `Podfile`
```
target 'Runner' do
  use_frameworks! # <--- add this
  ...
end
```

## 2.1.1

* Updated deps.
* improved ios integration instructions in README.

## 2.1.0

* Make location permission optional, required by default. 

## 2.0.2+2

* Fix NPE when the user forget to initialize localization.

## 2.0.2+1

* fix minor typo in Portuguese translation.

## 2.0.2

* added Portuguese translation thanks @mariosemedo.

## 2.0.1

* I added Turkish language file thanks @furkankurt.

## 2.0.0+3

* updated Readme to reflect the latest version of the lib.

## 2.0.0+2

* updated dependencies to the latest version.

## 2.0.0+1

* updated dependencies to the latest version.

## 2.0.0

* Fix permission error dialog.
* Added arabic lionization.

## 1.0.5+3

* updated dependencies to the latest version.

## 1.0.5+2

* updated google_maps_flutter: ^0.5.20+2

## 1.0.5+1

* updated google_maps_flutter: ^0.5.19+2

## 1.0.5

* updated google_maps_flutter: ^0.5.19

## 1.0.4

* remove ConstrainedBox around address card as the font changes sometimes cutouts happen.

## 1.0.3

* remove some useless logging.

## 1.0.2

* fix the address card mix height it and sometimes it's cutout.

## 1.0.1

* remove unused code.

## 1.0.0

* fix bug with requesting location permission
* fix the address card mix height it and sometimes it's cutout. 
* added library and export only the important parts

## 0.2.0

* now retuning the address plus LatLng
* do the reverse geocoding with google web api instead of the native lib. 

## 0.1.1

* Updated min dart version to 2.2.2.
* fix some formatting issues.

## 0.1.0

* Added place search feature.

## 0.0.5

* updated deps

## 0.0.4

* remove permissions from package AndroidManifest.xml as it's already added by google maps.
* improved README

## 0.0.2

* added the permissions to the package directly.


## 0.0.1

* initial release.