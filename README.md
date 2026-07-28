Is a forked from [google_map_location_picker](https://pub.dev/packages/google_map_location_picker).

Location picker using the official [google_maps_flutter](https://pub.dev/packages/google_maps_flutter).

I made This plugin because google deprecated [Place Picker](https://developers.google.com/places/android-sdk/placepicker).

<p>
  <img src="https://raw.githubusercontent.com/humazed/google_map_location_picker/master/art/location_picker.gif" width=265/>
  <img src="https://raw.githubusercontent.com/humazed/google_map_location_picker/master/art/Screenshot_1.png" width=265 />
  <img src="https://raw.githubusercontent.com/humazed/google_map_location_picker/master/art/Screenshot_2.png" width=265 />
</p>

[![Demo](https://raw.githubusercontent.com/humazed/google_map_location_picker/master/art/ios_demo.png?raw=true)](https://www.youtube.com/watch?v=Ev1tqijch1o)

## Using

Pubspec changes:

```
      dependencies: 
      
        google_maps_flutter: ^0.5.30
        google_map_location_picker: ^3.3.4
        flutter_localizations:
          sdk: flutter
```


For message localization inside the library please add in `MaterialApp`

```dart
import 'package:google_map_location_picker/generated/l10n.dart' as location_picker;
import 'package:flutter_localizations/flutter_localizations.dart';

MaterialApp(
  localizationsDelegates: const [
    location_picker.S.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const <Locale>[
    Locale('en', ''),
    Locale('ar', ''),
  ],
  home: ...
)
```

```dart
import 'package:google_map_location_picker/google_map_location_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

LocationResult result = await showLocationPicker(context, apiKey);
```

## Getting Started

- Get an API key at <https://cloud.google.com/maps-platform/>.

- And don't forget to enable the following APIs in <https://console.cloud.google.com/google/maps-apis/>
  - Maps SDK for Android
  - Maps SDK for iOS
  - Places API
  - Geolocation API
  - Geocoding API

- And ensure to enable billing for the project.

### Android

Specify your API key in the application manifest `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest ...
  <application ...
    <meta-data android:name="com.google.android.geo.API_KEY"
               android:value="YOUR KEY HERE"/>
```

### iOS

Specify your API key in the application delegate `ios/Runner/AppDelegate.m`:

```objectivec
#include "AppDelegate.h"
#include "GeneratedPluginRegistrant.h"
#import "GoogleMaps/GoogleMaps.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  [GMSServices provideAPIKey:@"YOUR KEY HERE"];
  [GeneratedPluginRegistrant registerWithRegistry:self];
  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}
@end
```

Or in your swift code, specify your API key in the application delegate `ios/Runner/AppDelegate.swift`:

```swift
import UIKit
import Flutter
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR KEY HERE")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

you need also to define `NSLocationWhenInUseUsageDescription`

```
  <key>NSLocationWhenInUseUsageDescription</key>
  <string>This app needs your location to test the location feature of the Google Maps location picker plugin.</string>
```

### Note

The following permissions are not required to use Google Maps Android API v2, but are recommended.

`android.permission.ACCESS_COARSE_LOCATION` Allows the API to use WiFi or mobile cell data (or both) to determine the device's location. The API returns the location with an accuracy approximately equivalent to a city block.

`android.permission.ACCESS_FINE_LOCATION` Allows the API to determine as precise a location as possible from the available location providers, including the Global Positioning System (GPS) as well as WiFi and mobile cell data.

---

You must also explicitly declare that your app uses the android.hardware.location.network or android.hardware.location.gps hardware features if your app targets Android 5.0 (API level 21) or higher and uses the ACCESS_COARSE_LOCATION or ACCESS_FINE_LOCATION permission in order to receive location updates from the network or a GPS, respectively.

```xml
<uses-feature android:name="android.hardware.location.network" android:required="false" />
<uses-feature android:name="android.hardware.location.gps" android:required="false"  />
```

---

The following permissions are defined in the package manifest, and are automatically merged into your app's manifest at build time. You **don't** need to add them explicitly to your manifest:

`android.permission.INTERNET` Used by the API to download map tiles from Google Maps servers.

`android.permission.ACCESS_NETWORK_STATE` Allows the API to check the connection status in order to determine whether data can be downloaded.

## Restricting Autocomplete Search to Region

The `LocationResult`s returned can be restricted to certain countries by passing an array of country codes into the `countries` parameter of `showLocationPicker()`. Countries must be two character, `ISO 3166-1 Alpha-2` compatible.
You can find code information at [Wikipedia: List of ISO 3166 country codes](https://en.wikipedia.org/wiki/List_of_ISO_3166_country_codes) or the [ISO Online Browsing Platform](https://www.iso.org/obp/ui/#search).

The example below restricts Autocomplete Search to the United Arab Emirates and Nigeria

```dart
showLocationPicker(
context, "YOUR API KEY HERE",
initialCenter: LatLng(31.1975844, 29.9598339),
myLocationButtonEnabled: true,
layersButtonEnabled: true,
countries: ['AE', 'NG'],
);
```

## Usando um backend próprio em vez do Google

Toda a rede do pacote passa por uma interface só, `LocationPickerApi`. A
implementação padrão (`GoogleLocationPickerApi`) fala direto com as APIs do
Google.

Roteirizar por um backend próprio troca o cache por dispositivo por um cache
compartilhado entre todos os usuários — o primeiro que resolve um ponto paga,
os demais reaproveitam — e permite restringir a chave do Google embarcada no
app a Maps SDK / Maps JS API, sem Geocoding nem Places habilitados.

### Caminho pronto: `BackendLocationPickerApi`

Se o seu backend expõe os endpoints abaixo, não precisa escrever implementação
nenhuma:

| Método | Rota esperada |
|---|---|
| `reverseGeocode` | `GET /geocode/reverse?lat&lng&language` |
| `forwardGeocode` | `GET /geocode/forward?address&language` |
| `autocomplete` | `GET /geocode/autocomplete?input&language&sessionToken&countries&lat&lng` |
| `placeDetails` | `GET /geocode/place/{placeId}?language&sessionToken` |
| `resolveMapsUrl` | `GET /geocode/expand-url?url` |

```dart
void main() {
  LocationPickerApi.instance = BackendLocationPickerApi(
    baseUrl: 'https://api.exemplo.com',
    headers: () async => {'authorization': await pegarToken()},
  );
  runApp(const MyApp());
}
```

O `headers` é um **callback assíncrono**, não um `Map` fixo, porque um token de
autenticação expira e precisa ser renovado entre uma chamada e outra. Se ele
lançar, a chamada devolve `null` em vez de derrubar a tela.

Os endpoints devolvem o corpo cru (sem envelope), com este objeto de endereço
canônico em `reverse`, `forward` e `place`:

```json
{
  "latitude": -25.2521, "longitude": -52.0215,
  "formattedAddress": "R. XV de Novembro, 1200 - Centro, Turvo - PR",
  "placeId": "ChIJ...", "street": "R. XV de Novembro", "number": "1200",
  "neighborhood": "Centro", "city": "Turvo", "state": "Paraná",
  "stateCode": "PR", "country": "Brasil", "countryCode": "BR",
  "cep": "85150-000", "locationType": "ROOFTOP"
}
```

Convenções que a implementação assume:

- **`404` não é erro** — significa "não há endereço aqui" e vira `null`.
- **No `reverse`, a coordenada usada é a que você passou**, não a da resposta:
  servidores costumam arredondar num grid para cachear, e usar a arredondada
  deslocaria o pin do ponto marcado. No `forward` e no `place` vale a da
  resposta, porque ali a coordenada *é* o resultado.
- Autocomplete sem resultado devolve `200` com `suggestions: []`, nunca `404`.
- Todos os campos de endereço podem vir `null`.

### Caminho customizado

Se o seu backend tem outro formato, implemente a interface direto:

```dart
class MinhaApi extends LocationPickerApi {
  @override
  Future<LocationResult?> reverseGeocode({
    required String apiKey,      // pode ignorar: seu backend guarda a chave
    required LatLng latLng,
    required String language,
  }) async {
    final res = await meuHttp.get('/geocode/reverse', query: {
      'lat': latLng.latitude,
      'lng': latLng.longitude,
      'language': language,
    });
    if (res == null) return null;
    return LocationResult(
      latLng: latLng,
      address: res['address'],
      placeId: res['placeId'],
      locationAddress: LocationAddress(route: res['route'], /* ... */),
    );
  }

  // ... forwardGeocode, autocomplete, placeDetails, resolveMapsUrl
}

void main() {
  LocationPickerApi.instance = MinhaApi();
  runApp(const MyApp());
}
```

Nenhum widget precisa mudar — `showLocationPicker` e `LocationPicker` continuam
iguais.

Pontos que valem saber:

- **Cache e deduplicação ficam fora da interface.** `LocationPickerUtils`
  aplica cache por coordenada (~1 m) + idioma e single-flight por cima de
  qualquer implementação, então a sua não precisa reimplementá-los.
- **Os modelos são do pacote, não do Google.** `PlaceSuggestion` e
  `PlaceDetails` já vêm normalizados; você não precisa imitar
  `matched_substrings` nem `geometry.location`.
- **Devolva `null` (ou lista vazia) em falha**, não exceção — o picker trata
  ausência de resultado como estado normal.
- **`resolveMapsUrl` é o caso mais interessante de sobrescrever**: a
  implementação padrão segue redirects no cliente, o que não funciona no
  Flutter Web por CORS. Um backend resolve isso.
- Para trocar apenas o cliente HTTP (proxy, interceptador) sem reimplementar
  nada, use `GoogleLocationPickerApi.httpClient`.

## Credits

The google map from [Flutter's](https://github.com/flutter) [google_maps_flutter](https://pub.dev/packages/google_maps_flutter) package

current location and permission from [BaseflowIT's](https://github.com/BaseflowIT) [flutter-geolocator](https://github.com/baseflowit/flutter-geolocator) package.

The search bar from [Degreat's](https://github.com/blackmann) [locationpicker](https://github.com/blackmann/locationpicker) package.
