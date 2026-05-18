import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_map_location_picker/generated/l10n.dart';
import 'package:google_map_location_picker/src/providers/location_provider.dart';
import 'package:google_map_location_picker/src/utils/loading_builder.dart';
import 'package:google_map_location_picker/src/utils/log.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'model/location_adress.dart';
import 'model/location_result.dart';
import 'platform/factory.dart';
import 'platform/interface.dart';
import 'utils/location_utils.dart';

class MapPicker extends StatefulWidget {
  const MapPicker(
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
    this.language,
    this.desiredAccuracy,
    this.embedded,
  }) : super(key: key);

  final String apiKey;

  /// Key específica para o Maps JavaScript API usado no WebView (desktop).
  /// Necessária no Windows/macOS/Linux porque a `apiKey` mobile costuma ter só
  /// Maps SDK Android/iOS habilitado, sem JS API. Se `null`, cai para `apiKey`.
  final String? webMapsApiKey;

  final LatLng? initialCenter;
  final double? initialZoom;

  final bool? requiredGPS;
  final bool? myLocationButtonEnabled;
  final bool? layersButtonEnabled;
  final bool? automaticallyAnimateToCurrentLocation;

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

  /// Renderiza o picker em modo compacto (sem Scaffold de fundo, FABs reposicionados,
  /// card de resultado menor). Tipicamente acionado pelo `LocationPicker` quando
  /// `embedded == true`.
  final bool? embedded;

  @override
  MapPickerState createState() => MapPickerState();
}

class MapPickerState extends State<MapPicker> {
  late final LocationPickerMapInterface mapImpl;

  MapType _currentMapType = MapType.normal;

  String? _mapStyle;

  LatLng? _lastMapPosition;

  Position? _currentPosition;

  String? _address;

  String? _placeId;

  LocationAdress? _locationAdress;

  void _onToggleMapTypePressed() {
    final MapType nextType = MapType.values[(_currentMapType.index + 1) % MapType.values.length];

    setState(() => _currentMapType = nextType);
    mapImpl.setMapType(nextType);
  }

  // this also checks for location permission.
  //
  // [forceAnimate] = true → sempre anima a câmera para a posição atual
  // (chamado pelo FAB "minha localização" e pelo path original com
  // automaticallyAnimateToCurrentLocation=true). Quando false (default),
  // respeita widget.automaticallyAnimateToCurrentLocation — evita resetar
  // o mapa para o GPS atual quando ele já está numa posição escolhida pelo
  // usuário (importante no modo embedded, onde initialCenter aponta para
  // a posição persistida do endereço).
  Future<void> _initCurrentLocation({bool forceAnimate = false}) async {
    Position? currentPosition;
    try {
      currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: widget.desiredAccuracy!),
      );
      d("position = $currentPosition");

      setState(() => _currentPosition = currentPosition);
    } catch (e) {
      currentPosition = null;
      d("_initCurrentLocation#e = $e");
    }

    if (!mounted) return;

    setState(() => _currentPosition = currentPosition);

    final bool shouldAnimate =
        forceAnimate || widget.automaticallyAnimateToCurrentLocation == true;
    if (currentPosition != null && shouldAnimate) {
      moveToCurrentLocation(LatLng(currentPosition.latitude, currentPosition.longitude));
    }
  }

  Future<void> moveToCurrentLocation(LatLng currentLocation) async {
    d('MapPickerState.moveToCurrentLocation "currentLocation = [$currentLocation]"');
    await mapImpl.animateCamera(currentLocation, 16);
  }

  @override
  void initState() {
    super.initState();
    mapImpl = LocationPickerMapFactory.create(
      apiKey: widget.webMapsApiKey ?? widget.apiKey,
    );

    if (widget.automaticallyAnimateToCurrentLocation! && !widget.requiredGPS!) _initCurrentLocation();

    if (widget.mapStylePath != null) {
      rootBundle.loadString(widget.mapStylePath!).then((string) {
        _mapStyle = string;
      });
    }
  }

  @override
  void dispose() {
    mapImpl.dispose();
    super.dispose();
  }

  bool get _isEmbedded => widget.embedded == true;

  @override
  Widget build(BuildContext context) {
    if (widget.requiredGPS!) {
      _checkGeolocationPermission();
      if (_currentPosition == null) _initCurrentLocation();
    }

    if (_currentPosition != null && dialogOpen != null) Navigator.of(context, rootNavigator: true).pop();

    final Widget body = Builder(
      builder: (context) {
        // No modo embedded nunca bloqueamos no spinner aguardando o GPS:
        // mostramos o mapa imediatamente no initialCenter e animamos para a
        // posição atual em background quando ela chegar (via _initCurrentLocation
        // → moveToCurrentLocation, controlado por automaticallyAnimateToCurrentLocation).
        // Em desktop/Windows o GPS pode demorar vários segundos e bloquear era
        // uma UX ruim — o pin sobre o mapa estático já é feedback suficiente.
        if (!_isEmbedded &&
            _currentPosition == null &&
            widget.automaticallyAnimateToCurrentLocation! &&
            widget.requiredGPS!) {
          return const Center(child: CircularProgressIndicator());
        }

        return buildMap();
      },
    );

    if (_isEmbedded) {
      // Sem SafeArea/Scaffold: o widget é desenhado inline dentro do layout do
      // consumidor (que controla padding/altura).
      return body;
    }

    return SafeArea(
      bottom: true,
      child: Scaffold(body: body),
    );
  }

  Widget buildMap() {
    // Em modo embedded, deixamos o widget de mapa vencer a arena de gestos
    // imediatamente — isso impede que um Scrollable pai roube gestos de pan/
    // zoom (notadamente scroll de dois dedos no touchpad, que vem como
    // PointerPanZoom*Event e não é capturado pelo onPointerSignal do Listener).
    final Set<Factory<OneSequenceGestureRecognizer>>? mapGestureRecognizers =
        _isEmbedded
            ? <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                ),
              }
            : null;

    return Center(
      child: Stack(
        children: <Widget>[
          mapImpl.buildWidget(
            initialCenter: widget.initialCenter!,
            initialZoom: widget.initialZoom!,
            mapType: _currentMapType,
            mapStyleJson: _mapStyle,
            myLocationEnabled: true,
            gestureRecognizers: mapGestureRecognizers,
            onCameraMove: (target) => _lastMapPosition = target,
            onCameraIdle: () {
              debugPrint("onCameraIdle#_lastMapPosition = $_lastMapPosition");
              LocationProvider.of(context, listen: false).setLastIdleLocation(_lastMapPosition);
            },
            onCameraMoveStarted: () {
              debugPrint("onCameraMoveStarted#_lastMapPosition = $_lastMapPosition");
            },
            onMapReady: () {
              _lastMapPosition = widget.initialCenter;
              LocationProvider.of(context, listen: false).setLastIdleLocation(_lastMapPosition);
            },
          ),
          _MapFabs(
            myLocationButtonEnabled: widget.myLocationButtonEnabled,
            layersButtonEnabled: widget.layersButtonEnabled,
            onToggleMapTypePressed: _onToggleMapTypePressed,
            onMyLocationPressed: () => _initCurrentLocation(forceAnimate: true),
            embedded: _isEmbedded,
          ),
          pin(),
          locationCard(),
        ],
      ),
    );
  }

  Widget locationCard() {
    final bool embedded = _isEmbedded;

    // Em modo embedded reservamos espaço à direita para os controles nativos
    // do Google Maps (zoom +/-, Street View, etc.) que ficam ancorados no
    // canto inferior direito.
    final EdgeInsets outerPadding = widget.resultCardPadding ??
        (embedded
            ? const EdgeInsets.only(left: 8, right: 64, top: 8, bottom: 8)
            : const EdgeInsets.all(16.0));

    final EdgeInsets innerPadding = embedded
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
        : const EdgeInsets.all(16.0);

    final double fontSize = embedded ? 13 : 18;
    final int maxLines = embedded ? 2 : 1;

    return Align(
      alignment: widget.resultCardAlignment ?? Alignment.bottomCenter,
      child: Padding(
        padding: outerPadding,
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Consumer<LocationProvider>(
            builder: (context, locationProvider, _) {
              final Widget confirmButton = embedded
                  ? SizedBox(
                      width: 40,
                      height: 40,
                      child: FloatingActionButton(
                        heroTag: 'mapPickerConfirm',
                        mini: true,
                        onPressed: () => _popResult(locationProvider),
                        child: widget.resultCardConfirmIcon ??
                            const Icon(Icons.arrow_forward, size: 20),
                      ),
                    )
                  : FloatingActionButton(
                      heroTag: 'mapPickerConfirm',
                      onPressed: () => _popResult(locationProvider),
                      child: widget.resultCardConfirmIcon ??
                          const Icon(Icons.arrow_forward),
                    );

              return Padding(
                padding: innerPadding,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Flexible(
                      flex: 20,
                      child: FutureLoadingBuilder<Map<String, String?>?>(
                        future: getAddress(locationProvider.lastIdleLocation),
                        mutable: true,
                        loadingIndicator: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[CircularProgressIndicator()],
                        ),
                        builder: (context, data) {
                          _address = data!["address"];
                          _placeId = data["placeId"];
                          return Text(
                            _address ?? S.of(context)?.unnamedPlace ?? 'Unnamed place',
                            style: TextStyle(fontSize: fontSize),
                            maxLines: maxLines,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ),
                    const Spacer(),
                    confirmButton,
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _popResult(LocationProvider locationProvider) {
    Navigator.of(context).pop({
      'location': LocationResult(
        latLng: locationProvider.lastIdleLocation,
        address: _address,
        placeId: _placeId,
        locationAdress: _locationAdress,
      ),
    });
  }

  Future<Map<String, String?>?> getAddress(LatLng? location) async {
    // Sem coordenadas (mapa ainda não emitiu onCameraIdle / onMapReady) não
    // faz sentido chamar a API — evita request inválida (latlng=null,null) e
    // o RangeError de acessar results[0] num response com results: [].
    if (location == null) {
      return {"placeId": null, "address": null};
    }

    try {
      final endpoint =
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=${location.latitude},${location.longitude}'
          '&key=${widget.apiKey}&language=${widget.language}';

      final response = jsonDecode(
        (await http.get(Uri.parse(endpoint), headers: await (LocationPickerUtils.getAppHeaders()))).body,
      );

      debugPrint("BLB data: $response ==> $endpoint");

      final List<dynamic>? results = response['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) {
        return {"placeId": null, "address": null};
      }

      final Map<String, dynamic> first = results[0] as Map<String, dynamic>;
      _locationAdress = LocationAdress.fromMap(first);

      return {
        "placeId": first['place_id'] as String?,
        "address": first['formatted_address'] as String?,
      };
    } catch (e) {
      debugPrint("BLB $e");
    }

    return {"placeId": null, "address": null};
  }

  Widget pin() {
    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.place, size: 56, color: widget.pinColor ?? Colors.black),
            Container(
              decoration: ShapeDecoration(
                shadows: [BoxShadow(blurRadius: 4, color: Colors.black38)],
                shape: CircleBorder(side: BorderSide(width: 4, color: Colors.transparent)),
              ),
            ),
            SizedBox(height: 56),
          ],
        ),
      ),
    );
  }

  var dialogOpen;

  Future _checkGeolocationPermission() async {
    final geolocationStatus = await Geolocator.checkPermission();
    d("geolocationStatus = $geolocationStatus");

    if (geolocationStatus == LocationPermission.denied && dialogOpen == null) {
      dialogOpen = _showDeniedDialog();
    } else if (geolocationStatus == LocationPermission.deniedForever && dialogOpen == null) {
      dialogOpen = _showDeniedForeverDialog();
    } else if (geolocationStatus == LocationPermission.whileInUse || geolocationStatus == LocationPermission.always) {
      d('GeolocationStatus.granted');

      if (dialogOpen != null) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = null;
      }
    }
  }

  Future _showDeniedDialog() {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        // ignore: deprecated_member_use
        return WillPopScope(
          onWillPop: () async {
            Navigator.of(context, rootNavigator: true).pop();
            Navigator.of(context, rootNavigator: true).pop();
            return true;
          },
          child: AlertDialog(
            title: Text(S.of(context)?.access_to_location_denied ?? 'Access to location denied'),
            content: Text(
              S.of(context)?.allow_access_to_the_location_services ?? 'Allow access to the location services.',
            ),
            actions: <Widget>[
              TextButton(
                child: Text(S.of(context)?.ok ?? 'Ok'),
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).pop();
                  _initCurrentLocation();
                  dialogOpen = null;
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future _showDeniedForeverDialog() {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        // ignore: deprecated_member_use
        return WillPopScope(
          onWillPop: () async {
            Navigator.of(context, rootNavigator: true).pop();
            Navigator.of(context, rootNavigator: true).pop();
            return true;
          },
          child: AlertDialog(
            title: Text(
              S.of(context)?.access_to_location_permanently_denied ?? 'Access to location permanently denied',
            ),
            content: Text(
              S.of(context)?.allow_access_to_the_location_services_from_settings ??
                  'Allow access to the location services for this App using the device settings.',
            ),
            actions: <Widget>[
              TextButton(
                child: Text(S.of(context)?.ok ?? 'Ok'),
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).pop();
                  Geolocator.openAppSettings();
                  dialogOpen = null;
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // // TODO: 9/12/2020 this is no longer needed, remove in the next release
  // Future _checkGps() async {
  //   if (!(await Geolocator.isLocationServiceEnabled())) {
  //     if (Theme.of(context).platform == TargetPlatform.android) {
  //       showDialog(
  //         context: context,
  //         barrierDismissible: false,
  //         builder: (BuildContext context) {
  //           return AlertDialog(
  //             title: Text(S.of(context)?.cant_get_current_location ??
  //                 "Can't get current location"),
  //             content: Text(S
  //                     .of(context)
  //                     ?.please_make_sure_you_enable_gps_and_try_again ??
  //                 'Please make sure you enable GPS and try again'),
  //             actions: <Widget>[
  //               TextButton(
  //                 child: Text('Ok'),
  //                 onPressed: () {
  //                   final AndroidIntent intent = AndroidIntent(
  //                       action: 'android.settings.LOCATION_SOURCE_SETTINGS');

  //                   intent.launch();
  //                   Navigator.of(context, rootNavigator: true).pop();
  //                 },
  //               ),
  //             ],
  //           );
  //         },
  //       );
  //     }
  //   }
  // }
}

class _MapFabs extends StatelessWidget {
  const _MapFabs({
    Key? key,
    required this.myLocationButtonEnabled,
    required this.layersButtonEnabled,
    required this.onToggleMapTypePressed,
    required this.onMyLocationPressed,
    this.embedded = false,
  }) : super(key: key);

  final bool? myLocationButtonEnabled;
  final bool? layersButtonEnabled;
  final bool embedded;

  final VoidCallback onToggleMapTypePressed;
  final VoidCallback onMyLocationPressed;

  @override
  Widget build(BuildContext context) {
    // Em modo embedded o SearchInput é renderizado como overlay (~56px de
    // altura) com 8px de margem do topo do mapa, então os fabs precisam
    // descer ~72px para não sobrepor o campo de busca nem os controles
    // nativos do Google Maps.
    final double topMargin = embedded ? 72 : kToolbarHeight + 80;

    return Container(
      alignment: Alignment.topRight,
      margin: EdgeInsets.only(top: topMargin, right: 8),
      child: Column(
        children: <Widget>[
          if (layersButtonEnabled!)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FloatingActionButton(
                onPressed: onToggleMapTypePressed,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                mini: true,
                child: const Icon(Icons.layers),
                heroTag: "layers",
              ),
            ),
          if (myLocationButtonEnabled!)
            FloatingActionButton(
              onPressed: onMyLocationPressed,
              materialTapTargetSize: MaterialTapTargetSize.padded,
              mini: true,
              child: const Icon(Icons.my_location),
              heroTag: "myLocation",
            ),
        ],
      ),
    );
  }
}
