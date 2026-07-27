import 'dart:async';

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
import 'package:provider/provider.dart';

import 'api/location_picker_api.dart';
import 'model/location_result.dart';
import 'utils/location_utils.dart';

class LocationPicker extends StatefulWidget {
  const LocationPicker(
    this.apiKey, {
    super.key,
    this.webMapsApiKey,
    this.initialCenter = const LatLng(45.521563, -122.677433),
    this.initialZoom = 16,
    this.requiredGPS = false,
    this.myLocationButtonEnabled = false,
    this.layersButtonEnabled = false,
    this.automaticallyAnimateToCurrentLocation = true,
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
    this.language = 'en',
    this.desiredAccuracy = LocationAccuracy.best,
    this.searchInputEnabled = true,
    this.embedded = false,
    this.onAutoConfirm,
  });

  final String apiKey;

  /// Key específica para o Maps JavaScript API usado no WebView (desktop).
  /// Necessária no Windows/macOS/Linux porque a `apiKey` mobile costuma ter só
  /// Maps SDK Android/iOS habilitado, sem JS API. Se `null`, cai para `apiKey`.
  final String? webMapsApiKey;

  final LatLng initialCenter;
  final double initialZoom;
  final List<String>? countries;

  final bool requiredGPS;
  final bool myLocationButtonEnabled;
  final bool layersButtonEnabled;
  final bool automaticallyAnimateToCurrentLocation;
  final bool searchInputEnabled;

  final String? mapStylePath;

  final Color? appBarColor;
  final Color? pinColor;
  final BoxDecoration? searchBarBoxDecoration;
  final String? hintText;
  final Widget? resultCardConfirmIcon;
  final AlignmentGeometry? resultCardAlignment;
  final Decoration? resultCardDecoration;
  final EdgeInsetsGeometry? resultCardPadding;

  final String language;

  final LocationAccuracy desiredAccuracy;

  /// Quando `true`, renderiza o picker em modo compacto, sem `Scaffold`/`AppBar`,
  /// com bordas arredondadas, card de localização menor e absorção do scroll
  /// do mouse (evita que o scroll role um `Scrollable` pai no desktop/web).
  /// O `SearchInput` é movido para o topo do mapa como overlay.
  final bool embedded;

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

  /// Session token required for autocomplete API call
  String sessionToken = Uuid().generateV4();

  var mapKey = GlobalKey<MapPickerState>();

  var appBarKey = GlobalKey();

  /// Hides the autocomplete overlay
  void clearOverlay() {
    if (overlayEntry != null) {
      overlayEntry!.remove();
      overlayEntry = null;
    }
  }

  /// Exibe o overlay "Finding place..." com spinner enquanto uma operação
  /// assíncrona (autocomplete, resolução de URL) está em andamento.
  void _showFindingPlaceOverlay() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Size size = renderBox.size;
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
  }

  /// Move o mapa para [latLng], faz reverse geocode completo e chama
  /// [widget.onAutoConfirm] quando disponível. Reutilizado tanto pelo
  /// autocomplete de places quanto pelos novos resolvedores de
  /// coordenadas e URL do Google Maps.
  Future<void> selectResolvedLatLng(LatLng latLng) async {
    clearOverlay();

    // `moveToLocation` já faz o reverse geocode — reaproveitamos o resultado
    // em vez de pedir o mesmo ponto de novo.
    final LocationResult? result = await moveToLocation(latLng);

    if (!mounted || widget.onAutoConfirm == null) return;
    if (result != null) widget.onAutoConfirm!(result);
  }

  /// Begins the search process by displaying a "wait" overlay then
  /// proceeds to fetch the autocomplete list. The bottom "dialog"
  /// is hidden so as to give more room and better experience for the
  /// autocomplete list overlay.
  void searchPlace(String place) {
    clearOverlay();

    if (place.isEmpty) return;

    // Intercept 1: coordenadas lat/lng coladas — resolução imediata sem overlay.
    final LatLng? coordsLatLng = LocationPickerUtils.parseLatLng(place);
    if (coordsLatLng != null) {
      selectResolvedLatLng(coordsLatLng);
      return;
    }

    // Intercept 2: URL do Google Maps — seguir redirect e extrair coords.
    if (LocationPickerUtils.isGoogleMapsUrl(place)) {
      _showFindingPlaceOverlay();
      LocationPickerUtils.resolveGoogleMapsUrl(place).then((LatLng? latLng) {
        if (!mounted) return;
        if (latLng != null) {
          selectResolvedLatLng(latLng);
        } else {
          autoCompleteSearch(place);
        }
      }).catchError((_) {
        if (mounted) autoCompleteSearch(place);
      });
      return;
    }

    // Fluxo padrão: Places Autocomplete.
    _showFindingPlaceOverlay();
    autoCompleteSearch(place);
  }

  /// Geração da busca de autocomplete corrente. Uma resposta lenta de uma
  /// busca antiga não deve sobrescrever as sugestões de uma busca mais nova.
  int _autoCompleteGeneration = 0;

  /// Fetches the place autocomplete list with the query [place].
  Future<void> autoCompleteSearch(String place) async {
    final int generation = ++_autoCompleteGeneration;

    final List<PlaceSuggestion> suggestions =
        await LocationPickerApi.instance.autocomplete(
      apiKey: widget.apiKey,
      input: place,
      language: widget.language,
      sessionToken: sessionToken,
      countries: widget.countries,
      locationBias: locationResult?.latLng,
    );

    // Descarta resposta obsoleta (outra busca já saiu depois desta) e evita
    // tocar no context após o unmount. Sem o clearOverlay no caminho de erro,
    // o overlay "Finding place..." ficava preso na tela.
    if (!mounted || generation != _autoCompleteGeneration) return;

    displayAutoCompleteSuggestions(
      suggestions.isEmpty
          ? <RichSuggestion>[RichSuggestion(_noResultSuggestion(context), () {})]
          : suggestions
              .map((s) =>
                  RichSuggestion(s, () => decodeAndSelectPlace(s.id)))
              .toList(),
    );
  }

  PlaceSuggestion _noResultSuggestion(BuildContext context) => PlaceSuggestion(
        description: S.of(context)?.no_result_found ?? 'No result found',
      );

  /// To navigate to the selected place from the autocomplete list to the map,
  /// the lat,lng is required. This method fetches the lat,lng of the place and
  /// proceeds to moving the map to that location.
  Future<void> decodeAndSelectPlace(String? placeId) async {
    clearOverlay();
    if (placeId == null) return;

    final PlaceDetails? details = await LocationPickerApi.instance.placeDetails(
      apiKey: widget.apiKey,
      placeId: placeId,
      language: widget.language,
      sessionToken: sessionToken,
    );

    // Enviar o sessiontoken no Details fecha a sessão de billing aberta pelo
    // Autocomplete. A próxima busca precisa começar com um token novo.
    sessionToken = Uuid().generateV4();

    if (!mounted || details == null) return;

    // `moveToLocation` já faz o reverse geocode — reaproveitamos o resultado
    // em vez de consultar o mesmo ponto uma segunda vez.
    final LocationResult? geocoded = await moveToLocation(details.latLng);

    if (!mounted || widget.onAutoConfirm == null) return;
    // O geocode é preferido porque traz os `address_components` completos; o
    // Details não os retorna para alguns tipos de place (cidade,
    // estabelecimento). Se ele falhar, caímos no que veio do Details.
    widget.onAutoConfirm!(geocoded ?? details.toLocationResult());
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

  /// Resolve o endereço de [latLng] e guarda em [locationResult]. Delega para
  /// `LocationPickerUtils.reverseGeocode`, que aplica cache e single-flight —
  /// chamadas concorrentes do mesmo ponto custam uma única requisição.
  Future<LocationResult?> reverseGeocodeLatLng(LatLng latLng) async {
    final LocationResult? result = await LocationPickerUtils.reverseGeocode(
      apiKey: widget.apiKey,
      latLng: latLng,
      language: widget.language,
    );

    if (result == null || !mounted) return result;

    setState(() => locationResult = result);
    return result;
  }

  /// Moves the camera to the provided location and updates other UI features to
  /// match the location. Devolve o resultado do reverse geocode para quem
  /// precisar dele, evitando uma segunda consulta.
  Future<LocationResult?> moveToLocation(LatLng latLng) {
    mapKey.currentState!.mapImpl.animateCamera(latLng, 16);

    return reverseGeocodeLatLng(latLng);
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

  bool get _searchInputVisible => widget.searchInputEnabled;

  Widget _buildSearchInput() {
    return SearchInput(
      searchPlace,
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
  bool searchInputEnabled = true,
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
          resultCardAlignment: resultCardAlignment,
          resultCardPadding: resultCardPadding,
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
