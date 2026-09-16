// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'location_picker_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class GoogleMapLocationPickerLocalizationsIt
    extends GoogleMapLocationPickerLocalizations {
  GoogleMapLocationPickerLocalizationsIt([String locale = 'it'])
    : super(locale);

  @override
  String get pleaseCheckYourConnection =>
      'Controlla la tua connessione di rete';

  @override
  String get serverError => 'Errore del server';

  @override
  String get unableToLoadTheMap => 'Unable to load the map';

  @override
  String get accessToLocationDenied => 'Accesso alla posizione rifiutato';

  @override
  String get allowAccessToTheLocationServices =>
      'Permetti l\'accesso ai servizi di localizzazione.';

  @override
  String get accessToLocationPermanentlyDenied =>
      'Accesso alla posizione rifiutato permanentemente';

  @override
  String get allowAccessToTheLocationServicesFromSettings =>
      'Consenti l\'accesso ai servizi di localizzazione per questa app utilizzando le impostazioni del dispositivo.';

  @override
  String get ok => 'Ok';

  @override
  String get cantGetCurrentLocation =>
      'Impossibile ottenere la posizione attuale';

  @override
  String get pleaseMakeSureYouEnableGpsAndTryAgain =>
      'Assicurati di aver attivato il GPS e prova di nuovo';

  @override
  String get searchPlace => 'Ricerca luogo';

  @override
  String get findingPlace => 'Cercando il luogo...';

  @override
  String get noResultFound => 'Nessun risultato trovato';

  @override
  String get unnamedPlace => 'Località senza nome';
}
