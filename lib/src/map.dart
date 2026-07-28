import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_map_location_picker/generated/l10n.dart';
import 'package:google_map_location_picker/src/providers/location_provider.dart';
import 'package:google_map_location_picker/src/utils/debouncer.dart';
import 'package:google_map_location_picker/src/utils/loading_builder.dart';
import 'package:google_map_location_picker/src/utils/log.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import 'model/location_result.dart';
import 'platform/factory.dart';
import 'platform/interface.dart';
import 'utils/location_utils.dart';

class MapPicker extends StatefulWidget {
  const MapPicker(
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
    this.language = 'en',
    this.desiredAccuracy = LocationAccuracy.best,
    this.embedded = false,
    this.cameraIdleDebounce = const Duration(milliseconds: 400),
  });

  final String apiKey;

  /// Key específica para o Maps JavaScript API usado no WebView (desktop).
  /// Necessária no Windows/macOS/Linux porque a `apiKey` mobile costuma ter só
  /// Maps SDK Android/iOS habilitado, sem JS API. Se `null`, cai para `apiKey`.
  final String? webMapsApiKey;

  final LatLng initialCenter;
  final double initialZoom;

  final bool requiredGPS;
  final bool myLocationButtonEnabled;
  final bool layersButtonEnabled;
  final bool automaticallyAnimateToCurrentLocation;

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

  /// Renderiza o picker em modo compacto (sem Scaffold de fundo, FABs reposicionados,
  /// card de resultado menor). Tipicamente acionado pelo `LocationPicker` quando
  /// `embedded == true`.
  final bool embedded;

  /// Quanto tempo a câmera precisa ficar parada antes de o endereço ser
  /// consultado.
  ///
  /// Arrastar o mapa em etapas dispara um `onCameraIdle` por pausa, e cada um
  /// deles é um geocode cobrado. Com o atraso, só a posição onde o usuário de
  /// fato parou é consultada.
  ///
  /// O custo é o endereço aparecer esse tanto mais tarde depois de cada
  /// parada. Use `Duration.zero` para consultar imediatamente, como antes.
  ///
  /// Confirmar a seleção não espera o prazo: a consulta pendente é executada
  /// na hora, para o resultado bater com o pin na tela.
  final Duration cameraIdleDebounce;

  @override
  MapPickerState createState() => MapPickerState();
}

class MapPickerState extends State<MapPicker> {
  late final LocationPickerMapInterface mapImpl;

  MapType _currentMapType = MapType.normal;

  String? _mapStyle;

  LatLng? _lastMapPosition;

  Position? _currentPosition;

  /// Coordenada para a qual [_geocodeFuture] foi criada. O `build` roda muitas
  /// vezes por coordenada (troca de map type, chegada do GPS, rebuild do
  /// provider); sem memoizar, cada um desses rebuilds criaria uma future nova e
  /// o `FutureBuilder` voltaria ao estado `waiting`, piscando o spinner.
  LatLng? _geocodedFor;
  Future<LocationResult?>? _geocodeFuture;

  /// Segura a consulta de endereço até a câmera ficar parada de verdade.
  /// Arrastar o mapa em etapas dispara um `onCameraIdle` por pausa.
  late final Debouncer _idleDebouncer = Debouncer(widget.cameraIdleDebounce);

  /// Publica a coordenada corrente, o que dispara o geocode via rebuild.
  void _commitIdleLocation() {
    if (!mounted) return;
    LocationProvider.of(context, listen: false)
        .setLastIdleLocation(_lastMapPosition);
  }

  Future<LocationResult?> _addressFuture(LatLng? location) {
    if (_geocodeFuture == null || location != _geocodedFor) {
      _geocodedFor = location;
      _geocodeFuture = getAddress(location);
    }
    return _geocodeFuture!;
  }

  /// Tipos percorridos pelo FAB de camadas. `MapType.none` fica de fora de
  /// propósito: no mapa nativo ele renderiza uma tela em branco, enquanto o
  /// WebView o trata como `normal` — o mesmo clique dava resultados diferentes
  /// por plataforma.
  static const List<MapType> _cyclableMapTypes = <MapType>[
    MapType.normal,
    MapType.satellite,
    MapType.terrain,
    MapType.hybrid,
  ];

  void _onToggleMapTypePressed() {
    final int currentIndex = _cyclableMapTypes.indexOf(_currentMapType);
    final MapType nextType =
        _cyclableMapTypes[(currentIndex + 1) % _cyclableMapTypes.length];

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
        locationSettings: LocationSettings(accuracy: widget.desiredAccuracy),
      );
      d("position = $currentPosition");
    } catch (e) {
      currentPosition = null;
      d("_initCurrentLocation#e = $e");
    }

    if (!mounted) return;

    setState(() => _currentPosition = currentPosition);

    final bool shouldAnimate =
        forceAnimate || widget.automaticallyAnimateToCurrentLocation;
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

    if (widget.requiredGPS) {
      // Antes isto era disparado dentro do build(): a cada rebuild o picker
      // pedia permissão e uma nova leitura de GPS, e como _initCurrentLocation
      // chama setState o próprio rebuild se realimentava enquanto a posição
      // fosse nula.
      _ensureGpsPermissionAndLocation();
    } else if (widget.automaticallyAnimateToCurrentLocation) {
      _initCurrentLocation();
    }

    if (widget.mapStylePath != null) {
      rootBundle.loadString(widget.mapStylePath!).then((string) {
        if (!mounted) return;
        // setState porque o estilo chega depois do primeiro frame; sem ele o
        // mapa nativo só aplicaria o estilo num rebuild casual, e o WebView
        // (que só recebe o estilo no initializeMap) nunca o aplicaria.
        setState(() => _mapStyle = string);
      });
    }
  }

  /// Fluxo de GPS obrigatório: garante a permissão e, uma vez concedida, lê a
  /// posição atual. Roda uma única vez por montagem.
  Future<void> _ensureGpsPermissionAndLocation() async {
    await _checkGeolocationPermission();
    if (!mounted || _currentPosition != null) return;
    await _initCurrentLocation();
  }

  @override
  void dispose() {
    _idleDebouncer.dispose();
    mapImpl.dispose();
    super.dispose();
  }

  bool get _isEmbedded => widget.embedded;

  @override
  Widget build(BuildContext context) {
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
            widget.automaticallyAnimateToCurrentLocation &&
            widget.requiredGPS) {
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
            initialCenter: widget.initialCenter,
            initialZoom: widget.initialZoom,
            mapType: _currentMapType,
            mapStyleJson: _mapStyle,
            myLocationEnabled: true,
            gestureRecognizers: mapGestureRecognizers,
            onCameraMove: (target) => _lastMapPosition = target,
            onCameraIdle: () => _idleDebouncer.run(_commitIdleLocation),
            onCameraMoveStarted: () {
              // Voltou a se mover: a consulta agendada na pausa anterior não
              // interessa mais.
              _idleDebouncer.cancel();
            },
            onMapReady: () {
              // Primeira posição: sem espera, é o que o card precisa mostrar
              // assim que o mapa aparece.
              _lastMapPosition = widget.initialCenter;
              _commitIdleLocation();
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
    final EdgeInsetsGeometry outerPadding = widget.resultCardPadding ??
        (embedded
            ? const EdgeInsets.only(left: 8, right: 64, top: 8, bottom: 8)
            : const EdgeInsets.all(16.0));

    final EdgeInsetsGeometry innerPadding = embedded
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
                      child: FutureLoadingBuilder<LocationResult?>(
                        future: _addressFuture(locationProvider.lastIdleLocation),
                        mutable: true,
                        loadingIndicator: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[CircularProgressIndicator()],
                        ),
                        builder: (context, data) {
                          return Text(
                            data?.address ?? S.of(context)?.unnamedPlace ?? 'Unnamed place',
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

  Future<void> _popResult(LocationProvider locationProvider) async {
    // Confirmar dentro da janela de espera não pode devolver a posição
    // anterior: aplica agora a consulta pendente e aguarda o endereço, para o
    // resultado corresponder ao pin que está na tela.
    _idleDebouncer.flush();

    final LatLng? target = locationProvider.lastIdleLocation;
    final LocationResult? result = await _addressFuture(target);

    if (!mounted) return;

    Navigator.of(context).pop({
      'location': LocationResult(
        latLng: target,
        address: result?.address,
        placeId: result?.placeId,
        locationAddress: result?.locationAddress,
      ),
    });
  }

  /// Reverse geocode do centro do mapa. Devolve `null` quando não há
  /// coordenada, quando a API falha ou quando não há resultados — o card
  /// trata esse caso exibindo "Unnamed place".
  Future<LocationResult?> getAddress(LatLng? location) async {
    // Sem coordenadas (mapa ainda não emitiu onCameraIdle / onMapReady) não
    // faz sentido chamar a API — evita request inválida (latlng=null,null).
    if (location == null) return null;

    return LocationPickerUtils.reverseGeocode(
      apiKey: widget.apiKey,
      latLng: location,
      language: widget.language,
    );
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

  /// `true` enquanto um dos diálogos de permissão está na tela. Era um campo
  /// `dynamic` que guardava a `Future` do `showDialog` mas só era consultado
  /// como flag.
  bool _permissionDialogOpen = false;

  Future<void> _checkGeolocationPermission() async {
    final geolocationStatus = await Geolocator.checkPermission();
    d("geolocationStatus = $geolocationStatus");

    if (!mounted) return;

    if (geolocationStatus == LocationPermission.denied &&
        !_permissionDialogOpen) {
      _permissionDialogOpen = true;
      _showDeniedDialog();
    } else if (geolocationStatus == LocationPermission.deniedForever &&
        !_permissionDialogOpen) {
      _permissionDialogOpen = true;
      _showDeniedForeverDialog();
    } else if (geolocationStatus == LocationPermission.whileInUse ||
        geolocationStatus == LocationPermission.always) {
      d('GeolocationStatus.granted');
      _dismissPermissionDialog();
    }
  }

  /// Fecha o diálogo de permissão, se houver. Substitui o `Navigator.pop`
  /// condicional que rodava dentro do `build`.
  void _dismissPermissionDialog() {
    if (!_permissionDialogOpen) return;
    _permissionDialogOpen = false;
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _showDeniedDialog() {
    return _showPermissionDialog(
      title: S.of(context)?.access_to_location_denied ??
          'Access to location denied',
      message: S.of(context)?.allow_access_to_the_location_services ??
          'Allow access to the location services.',
      onConfirm: _initCurrentLocation,
    );
  }

  Future<void> _showDeniedForeverDialog() {
    return _showPermissionDialog(
      title: S.of(context)?.access_to_location_permanently_denied ??
          'Access to location permanently denied',
      message:
          S.of(context)?.allow_access_to_the_location_services_from_settings ??
              'Allow access to the location services for this App using the '
                  'device settings.',
      onConfirm: Geolocator.openAppSettings,
    );
  }

  /// Diálogo de permissão de localização. Os dois casos (negada e negada
  /// permanentemente) diferem só nos textos e na ação do botão.
  Future<void> _showPermissionDialog({
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _LocationPermissionDialog(
        title: title,
        message: message,
        confirmLabel: S.of(dialogContext)?.ok ?? 'Ok',
        onConfirm: onConfirm,
      ),
    ).whenComplete(() => _permissionDialogOpen = false);
  }

}

/// Diálogo de permissão de localização. Não pode ser dispensado pelo botão
/// voltar do Android sem sair do picker — daí o `PopScope` com `canPop: false`
/// que fecha o diálogo e a rota do picker.
class _LocationPermissionDialog extends StatelessWidget {
  const _LocationPermissionDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onConfirm,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        final NavigatorState navigator =
            Navigator.of(context, rootNavigator: true);
        // Fecha o diálogo e, em seguida, o próprio picker.
        navigator.pop();
        navigator.pop();
      },
      child: AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              onConfirm();
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }
}

class _MapFabs extends StatelessWidget {
  const _MapFabs({
    required this.myLocationButtonEnabled,
    required this.layersButtonEnabled,
    required this.onToggleMapTypePressed,
    required this.onMyLocationPressed,
    this.embedded = false,
  });

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
                heroTag: "layers",
                child: const Icon(Icons.layers),
              ),
            ),
          if (myLocationButtonEnabled!)
            FloatingActionButton(
              onPressed: onMyLocationPressed,
              materialTapTargetSize: MaterialTapTargetSize.padded,
              mini: true,
              heroTag: "myLocation",
              child: const Icon(Icons.my_location),
            ),
        ],
      ),
    );
  }
}
