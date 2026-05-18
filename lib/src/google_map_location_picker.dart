import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_map_location_picker/generated/l10n.dart';
import 'package:google_map_location_picker/src/map.dart';
import 'package:google_map_location_picker/src/providers/location_provider.dart';
import 'package:google_map_location_picker/src/rich_suggestion.dart';
import 'package:google_map_location_picker/src/search_input.dart';
import 'package:google_map_location_picker/src/utils/uuid.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'model/auto_comp_iete_item.dart';
import 'model/location_adress.dart';
import 'model/location_result.dart';
import 'model/nearby_place.dart';
import 'utils/location_utils.dart';

class LocationPicker extends StatefulWidget {
  LocationPicker(
    this.apiKey, {
    Key? key,
    this.webMapsApiKey,
    this.initialCenter,
    this.initialZoom,
    this.requiredGPS,
    this.myLocationButtonEnabled,
    this.layersButtonEnabled,
    this.automaticallyAnimateToCurrentLocation,
    this.mapStylePath,
    this.appBarColor,
    this.pinColor,
    this.searchBarBoxDecoration,
    this.hintText,
    this.resultCardConfirmIcon,
    this.resultCardAlignment,
    this.resultCardDecoration,
    this.resultCardPadding,
    this.countries,
    this.language,
    this.desiredAccuracy,
    this.searchInputEnabled,
    this.embedded,
    this.onAutoConfirm,
  });

  final String apiKey;

  /// Key específica para o Maps JavaScript API usado no WebView (desktop).
  /// Necessária no Windows/macOS/Linux porque a `apiKey` mobile costuma ter só
  /// Maps SDK Android/iOS habilitado, sem JS API. Se `null`, cai para `apiKey`.
  final String? webMapsApiKey;

  final LatLng? initialCenter;
  final double? initialZoom;
  final List<String>? countries;

  final bool? requiredGPS;
  final bool? myLocationButtonEnabled;
  final bool? layersButtonEnabled;
  final bool? automaticallyAnimateToCurrentLocation;
  final bool? searchInputEnabled;

  final String? mapStylePath;

  final Color? appBarColor;
  final Color? pinColor;
  final BoxDecoration? searchBarBoxDecoration;
  final String? hintText;
  final Widget? resultCardConfirmIcon;
  final Alignment? resultCardAlignment;
  final Decoration? resultCardDecoration;
  final EdgeInsets? resultCardPadding;

  final String? language;

  final LocationAccuracy? desiredAccuracy;

  /// Quando `true`, renderiza o picker em modo compacto, sem `Scaffold`/`AppBar`,
  /// com bordas arredondadas, card de localização menor e absorção do scroll
  /// do mouse (evita que o scroll role um `Scrollable` pai no desktop/web).
  /// O `SearchInput` é movido para o topo do mapa como overlay.
  final bool? embedded;

  /// Disparado em modo `embedded` quando o usuário escolhe uma sugestão da
  /// busca de autocomplete — antes da animação do mapa terminar. Permite que
  /// o consumidor aplique imediatamente o endereço selecionado sem exigir um
  /// segundo clique no botão de confirmação.
  final ValueChanged<LocationResult>? onAutoConfirm;

  @override
  LocationPickerState createState() => LocationPickerState();
}

class LocationPickerState extends State<LocationPicker> {
  /// Result returned after user completes selection
  LocationResult? locationResult;

  /// Overlay to display autocomplete suggestions
  OverlayEntry? overlayEntry;

  List<NearbyPlace> nearbyPlaces = [];

  /// Session token required for autocomplete API call
  String sessionToken = Uuid().generateV4();

  var mapKey = GlobalKey<MapPickerState>();

  var appBarKey = GlobalKey();

  var searchInputKey = GlobalKey<SearchInputState>();

  bool hasSearchTerm = false;

  /// Hides the autocomplete overlay
  void clearOverlay() {
    if (overlayEntry != null) {
      overlayEntry!.remove();
      overlayEntry = null;
    }
  }

  /// Begins the search process by displaying a "wait" overlay then
  /// proceeds to fetch the autocomplete list. The bottom "dialog"
  /// is hidden so as to give more room and better experience for the
  /// autocomplete list overlay.
  void searchPlace(String place) {
    // if (context == null) return;

    clearOverlay();

    setState(() => hasSearchTerm = place.length > 0);

    if (place.length < 1) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    Size size = renderBox.size;

    final RenderBox? appBarBox =
        appBarKey.currentContext!.findRenderObject() as RenderBox?;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: appBarBox!.size.height,
        width: size.width,
        child: Material(
          elevation: 1,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Row(
              children: <Widget>[
                SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                SizedBox(width: 24),
                Expanded(
                  child: Text(
                    S.of(context)?.finding_place ?? 'Finding place...',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry!);

    autoCompleteSearch(place);
  }

  /// Fetches the place autocomplete list with the query [place].
  void autoCompleteSearch(String place) {
    place = place.replaceAll(" ", "+");

    String autoCompleteUrl = kIsWeb
        ? LocationPickerUtils.autoCompleteWebUrl
        : LocationPickerUtils.autoCompleteUrl;

    final countries = widget.countries;

    // Currently, you can use components to filter by up to 5 countries. from https://developers.google.com/places/web-service/autocomplete
    String regionParam = countries?.isNotEmpty == true
        ? "&components=country:${countries!.sublist(0, min(countries.length, 5)).join('|country:')}"
        : "";

    var endpoint = "$autoCompleteUrl?" +
        "key=${widget.apiKey}&" +
        "input={$place}$regionParam&sessiontoken=$sessionToken&" +
        "language=${widget.language}";

    if (locationResult != null) {
      endpoint += "&location=${locationResult!.latLng!.latitude}," +
          "${locationResult!.latLng!.longitude}";
    }

    debugPrint("endpoint --> $endpoint");

    LocationPickerUtils.getAppHeaders()
        .then((headers) => http.get(Uri.parse(endpoint), headers: headers))
        .then((response) {
      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);
        List<dynamic> predictions = data['predictions'];

        List<RichSuggestion> suggestions = [];

        if (predictions.isEmpty) {
          AutoCompleteItem aci = AutoCompleteItem();
          aci.text = S.of(context)?.no_result_found ?? 'No result found';
          aci.offset = 0;
          aci.length = 0;

          suggestions.add(RichSuggestion(aci, () {}));
        } else {
          for (dynamic t in predictions) {
            AutoCompleteItem aci = AutoCompleteItem();

            aci.id = t['place_id'];
            aci.text = t['description'];
            aci.offset = t['matched_substrings'][0]['offset'];
            aci.length = t['matched_substrings'][0]['length'];

            suggestions.add(RichSuggestion(aci, () {
              decodeAndSelectPlace(aci.id);
            }));
          }
        }

        displayAutoCompleteSuggestions(suggestions);
      }
    }).catchError((error) {
      debugPrint(error);
    });
  }

  /// To navigate to the selected place from the autocomplete list to the map,
  /// the lat,lng is required. This method fetches the lat,lng of the place and
  /// proceeds to moving the map to that location.
  void decodeAndSelectPlace(String? placeId) {
    clearOverlay();

    String detailsUrl = kIsWeb
        ? LocationPickerUtils.detailsWebUrl
        : LocationPickerUtils.detailsUrl;

    final endpoint = "$detailsUrl?key=${widget.apiKey}" +
        "&placeid=$placeId" +
        '&language=${widget.language}';

    LocationPickerUtils.getAppHeaders()
        .then((headers) => http.get(Uri.parse(endpoint), headers: headers))
        .then((response) {
      if (response.statusCode == 200) {
        final Map<String, dynamic> result =
            jsonDecode(response.body)['result'] as Map<String, dynamic>;
        final Map<String, dynamic> location =
            result['geometry']['location'] as Map<String, dynamic>;

        LatLng latLng = LatLng(location['lat'], location['lng']);

        moveToLocation(latLng);

        if (widget.onAutoConfirm != null) {
          _resolveAutoConfirmResult(
            latLng: latLng,
            detailsResult: result,
          ).then((LocationResult res) {
            if (!mounted) return;
            widget.onAutoConfirm!(res);
          });
        }
      }
    }).catchError((error) {
      debugPrint(error);
    });
  }

  /// Monta o `LocationResult` usado pelo callback `onAutoConfirm`. Faz reverse
  /// geocoding em `latLng` para obter `address_components` confiáveis (rua,
  /// número, bairro, CEP) — o Places Details, dependendo do tipo do place
  /// (cidade, estabelecimento), não retorna esses campos. Em caso de falha
  /// do geocode, cai para o que vier do próprio Places Details.
  Future<LocationResult> _resolveAutoConfirmResult({
    required LatLng latLng,
    required Map<String, dynamic> detailsResult,
  }) async {
    final LocationResult? geocoded = await LocationPickerUtils.reverseGeocode(
      apiKey: widget.apiKey,
      latLng: latLng,
      language: widget.language ?? 'en',
    );

    if (geocoded != null) return geocoded;

    return LocationResult(
      latLng: latLng,
      address: detailsResult['formatted_address'] as String?,
      placeId: detailsResult['place_id'] as String?,
      locationAdress: LocationAdress.fromMap(detailsResult),
    );
  }

  /// Display autocomplete suggestions with the overlay.
  void displayAutoCompleteSuggestions(List<RichSuggestion> suggestions) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    Size size = renderBox.size;

    final RenderBox? appBarBox =
        appBarKey.currentContext!.findRenderObject() as RenderBox?;

    clearOverlay();

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        top: appBarBox!.size.height,
        child: Material(elevation: 1, child: Column(children: suggestions)),
      ),
    );

    Overlay.of(context).insert(overlayEntry!);
  }

  /// Utility function to get clean readable name of a location. First checks
  /// for a human-readable name from the nearby list. This helps in the cases
  /// that the user selects from the nearby list (and expects to see that as a
  /// result, instead of road name). If no name is found from the nearby list,
  /// then the road name returned is used instead.
  //  String getLocationName() {
  //    if (locationResult == null) {
  //      return "Unnamed location";
  //    }
  //
  //    for (NearbyPlace np in nearbyPlaces) {
  //      if (np.latLng == locationResult.latLng) {
  //        locationResult.name = np.name;
  //        return np.name;
  //      }
  //    }
  //
  //    return "${locationResult.name}, ${locationResult.locality}";
  //  }

  /// Fetches and updates the nearby places to the provided lat,lng
  void getNearbyPlaces(LatLng latLng) {
    LocationPickerUtils.getAppHeaders().then((headers) {
      var endpoint =
          "https://maps.googleapis.com/maps/api/place/nearbysearch/json?" +
              "key=${widget.apiKey}&" +
              "location=${latLng.latitude},${latLng.longitude}&radius=150" +
              "&language=${widget.language}";

      return http.get(Uri.parse(endpoint), headers: headers);
    }).then((response) {
      if (response.statusCode == 200) {
        nearbyPlaces.clear();
        for (Map<String, dynamic> item
            in jsonDecode(response.body)['results']) {
          NearbyPlace nearbyPlace = NearbyPlace();

          nearbyPlace.name = item['name'];
          nearbyPlace.icon = item['icon'];
          double latitude = item['geometry']['location']['lat'];
          double longitude = item['geometry']['location']['lng'];

          LatLng _latLng = LatLng(latitude, longitude);

          nearbyPlace.latLng = _latLng;

          nearbyPlaces.add(nearbyPlace);
        }
      }

      // to update the nearby places
      setState(() {
        // this is to require the result to show
        hasSearchTerm = false;
      });
    }).catchError((error) {});
  }

  /// This method gets the human readable name of the location. Mostly appears
  /// to be the road name and the locality.
  Future reverseGeocodeLatLng(LatLng latLng) async {
    final endpoint =
        "https://maps.googleapis.com/maps/api/geocode/json?latlng=${latLng.latitude},${latLng.longitude}" +
            "&key=${widget.apiKey}" +
            "&language=${widget.language}";

    final response = await http.get(
      Uri.parse(endpoint),
      headers: await LocationPickerUtils.getAppHeaders(),
    );

    if (response.statusCode == 200) {
      Map<String, dynamic> responseJson = jsonDecode(response.body);

      String? road;

      String? placeId = responseJson['results'][0]['place_id'];

      if (responseJson['status'] == 'REQUEST_DENIED') {
        road = 'REQUEST DENIED = please see log for more details';
        debugPrint(responseJson['error_message']);
      } else {
        // road =
        //     responseJson['results'][0]['address_components'][0]['short_name'];
        road = responseJson['results'][0]['address_components'][0]['long_name'];
      }

      //      String locality =
      //          responseJson['results'][0]['address_components'][1]['short_name'];

      setState(() {
        locationResult = LocationResult();
        locationResult!.address = road;
        locationResult!.latLng = latLng;
        locationResult!.placeId = placeId;
      });
    }
  }

  /// Moves the camera to the provided location and updates other UI features to
  /// match the location.
  void moveToLocation(LatLng latLng) {
    mapKey.currentState!.mapImpl.animateCamera(latLng, 16);

    reverseGeocodeLatLng(latLng);

    getNearbyPlaces(latLng);
  }

  @override
  void dispose() {
    clearOverlay();
    super.dispose();
  }

  /// Absorve `PointerScrollEvent` (scroll do mouse no desktop/web) para que um
  /// `Scrollable` pai não role enquanto o usuário está dando zoom no mapa.
  /// No mobile o zoom é via pinch (gesture normal), então este filtro não
  /// interfere com o comportamento esperado.
  void _absorbWheelScroll(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      GestureBinding.instance.pointerSignalResolver.register(event, (_) {});
    }
  }

  /// Reivindica gestos de pan/scale originados no **trackpad** (two-finger
  /// scroll, pinch-to-zoom em notebooks). Sem isto, o `Scrollable` pai
  /// vence a arena e rola a tela em vez de deixar o mapa fazer o zoom.
  ///
  /// Limitar via `supportedDevices: {PointerDeviceKind.trackpad}` é
  /// proposital: em **mobile** o pinch chega via touch direto na superfície
  /// nativa do `GoogleMap` (platform view) e não passa pela gesture arena
  /// do Flutter, então mantemos o comportamento original; em **desktop/web**
  /// o mapa recebe pinch/scroll via WebView (JS Google Maps API), também
  /// fora da arena do Flutter — interceptar aqui só evita que o pai role.
  Map<Type, GestureRecognizerFactory> _trackpadClaimRecognizers() {
    return <Type, GestureRecognizerFactory>{
      ScaleGestureRecognizer: GestureRecognizerFactoryWithHandlers<
          ScaleGestureRecognizer>(
        () => ScaleGestureRecognizer(
          supportedDevices: const <PointerDeviceKind>{
            PointerDeviceKind.trackpad,
          },
        ),
        (ScaleGestureRecognizer recognizer) {
          recognizer
            ..onStart = (_) {}
            ..onUpdate = (_) {}
            ..onEnd = (_) {};
        },
      ),
      PanGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
        () => PanGestureRecognizer(
          supportedDevices: const <PointerDeviceKind>{
            PointerDeviceKind.trackpad,
          },
        ),
        (PanGestureRecognizer recognizer) {
          recognizer
            ..onStart = (_) {}
            ..onUpdate = (_) {}
            ..onEnd = (_) {};
        },
      ),
    };
  }

  bool get _searchInputVisible =>
      widget.searchInputEnabled == null || widget.searchInputEnabled == true;

  Widget _buildSearchInput() {
    return SearchInput(
      (input) => searchPlace(input),
      key: searchInputKey,
      boxDecoration: widget.searchBarBoxDecoration,
      hintText: widget.hintText,
    );
  }

  MapPicker _buildMapPicker() {
    return MapPicker(
      widget.apiKey,
      webMapsApiKey: widget.webMapsApiKey,
      initialCenter: widget.initialCenter,
      initialZoom: widget.initialZoom,
      requiredGPS: widget.requiredGPS,
      myLocationButtonEnabled: widget.myLocationButtonEnabled,
      layersButtonEnabled: widget.layersButtonEnabled,
      automaticallyAnimateToCurrentLocation:
          widget.automaticallyAnimateToCurrentLocation,
      mapStylePath: widget.mapStylePath,
      appBarColor: widget.appBarColor,
      pinColor: widget.pinColor,
      searchBarBoxDecoration: widget.searchBarBoxDecoration,
      hintText: widget.hintText,
      resultCardConfirmIcon: widget.resultCardConfirmIcon,
      resultCardAlignment: widget.resultCardAlignment,
      resultCardDecoration: widget.resultCardDecoration,
      resultCardPadding: widget.resultCardPadding,
      key: mapKey,
      language: widget.language,
      desiredAccuracy: widget.desiredAccuracy,
      embedded: widget.embedded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool embedded = widget.embedded == true;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocationProvider()),
      ],
      child: Builder(builder: (context) {
        if (embedded) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Listener(
              onPointerSignal: _absorbWheelScroll,
              child: RawGestureDetector(
                behavior: HitTestBehavior.translucent,
                gestures: _trackpadClaimRecognizers(),
                child: Stack(
                  children: [
                    Positioned.fill(child: _buildMapPicker()),
                    if (_searchInputVisible)
                      Positioned(
                        top: 8,
                        left: 8,
                        right: 8,
                        child: Container(
                          key: appBarKey,
                          child: Material(
                            color: Colors.transparent,
                            child: _buildSearchInput(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            iconTheme: Theme.of(context).iconTheme,
            elevation: 0,
            backgroundColor: widget.appBarColor,
            key: appBarKey,
            title: _searchInputVisible ? _buildSearchInput() : null,
          ),
          body: _buildMapPicker(),
        );
      }),
    );
  }
}

/// Returns a [LatLng] object of the location that was picked.
///
/// The [apiKey] argument API key generated from Google Cloud Console.
/// You can get an API key [here](https://cloud.google.com/maps-platform/)
///
/// [initialCenter] The geographical location that the camera is pointing
/// until the current user location is know if you want to change this
/// set [automaticallyAnimateToCurrentLocation] to false.
///
///
Future<LocationResult?> showLocationPicker(
  BuildContext context,
  String apiKey, {
  String? webMapsApiKey,
  LatLng initialCenter = const LatLng(45.521563, -122.677433),
  double initialZoom = 16,
  bool requiredGPS = false,
  List<String>? countries,
  bool myLocationButtonEnabled = false,
  bool layersButtonEnabled = false,
  bool automaticallyAnimateToCurrentLocation = true,
  String? mapStylePath,
  Color appBarColor = Colors.transparent,
  BoxDecoration? searchBarBoxDecoration,
  String? hintText,
  Widget? resultCardConfirmIcon,
  AlignmentGeometry? resultCardAlignment,
  EdgeInsetsGeometry? resultCardPadding,
  Decoration? resultCardDecoration,
  String language = 'en',
  LocationAccuracy desiredAccuracy = LocationAccuracy.best,
  Color? pinColor,
  bool? searchInputEnabled,
}) async {
  final results = await Navigator.of(context).push(
    MaterialPageRoute<dynamic>(
      builder: (BuildContext context) {
        // print('[LocationPicker] [countries] ${countries.join(', ')}');
        return LocationPicker(
          apiKey,
          webMapsApiKey: webMapsApiKey,
          initialCenter: initialCenter,
          initialZoom: initialZoom,
          requiredGPS: requiredGPS,
          myLocationButtonEnabled: myLocationButtonEnabled,
          layersButtonEnabled: layersButtonEnabled,
          automaticallyAnimateToCurrentLocation:
              automaticallyAnimateToCurrentLocation,
          mapStylePath: mapStylePath,
          appBarColor: appBarColor,
          hintText: hintText,
          searchBarBoxDecoration: searchBarBoxDecoration,
          resultCardConfirmIcon: resultCardConfirmIcon,
          resultCardAlignment: resultCardAlignment as Alignment?,
          resultCardPadding: resultCardPadding as EdgeInsets?,
          resultCardDecoration: resultCardDecoration,
          countries: countries,
          language: language,
          desiredAccuracy: desiredAccuracy,
          pinColor: pinColor,
          searchInputEnabled: searchInputEnabled,
        );
      },
    ),
  );

  if (results != null && results.containsKey('location')) {
    return results['location'];
  } else {
    return null;
  }
}
