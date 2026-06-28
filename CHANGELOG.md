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