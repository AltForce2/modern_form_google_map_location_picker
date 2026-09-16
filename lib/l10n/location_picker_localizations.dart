import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'location_picker_localizations_ar.dart';
import 'location_picker_localizations_de.dart';
import 'location_picker_localizations_en.dart';
import 'location_picker_localizations_es.dart';
import 'location_picker_localizations_fr.dart';
import 'location_picker_localizations_it.dart';
import 'location_picker_localizations_pt.dart';
import 'location_picker_localizations_ru.dart';
import 'location_picker_localizations_sr.dart';
import 'location_picker_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of GoogleMapLocationPickerLocalizations
/// returned by `GoogleMapLocationPickerLocalizations.of(context)`.
///
/// Applications need to include `GoogleMapLocationPickerLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/location_picker_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: GoogleMapLocationPickerLocalizations.localizationsDelegates,
///   supportedLocales: GoogleMapLocationPickerLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the GoogleMapLocationPickerLocalizations.supportedLocales
/// property.
abstract class GoogleMapLocationPickerLocalizations {
  GoogleMapLocationPickerLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static GoogleMapLocationPickerLocalizations of(BuildContext context) {
    return Localizations.of<GoogleMapLocationPickerLocalizations>(
      context,
      GoogleMapLocationPickerLocalizations,
    )!;
  }

  static const LocalizationsDelegate<GoogleMapLocationPickerLocalizations>
  delegate = _GoogleMapLocationPickerLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
    Locale('pt'),
    Locale('ru'),
    Locale('sr'),
    Locale('tr'),
  ];

  /// Erro exibido no card de endereço quando o geocode falha por falta de conexão.
  ///
  /// In en, this message translates to:
  /// **'Please check your connection'**
  String get pleaseCheckYourConnection;

  /// Erro exibido no card de endereço quando o geocode falha por um motivo desconhecido.
  ///
  /// In en, this message translates to:
  /// **'Server error'**
  String get serverError;

  /// Erro exibido no lugar do mapa quando o HTML do mapa (WebView, usado no desktop e na web) não carrega.
  ///
  /// In en, this message translates to:
  /// **'Unable to load the map'**
  String get unableToLoadTheMap;

  /// Título do diálogo exibido quando o usuário nega a permissão de localização.
  ///
  /// In en, this message translates to:
  /// **'Access to location denied'**
  String get accessToLocationDenied;

  /// Mensagem do diálogo exibido quando o usuário nega a permissão de localização.
  ///
  /// In en, this message translates to:
  /// **'Allow access to the location services.'**
  String get allowAccessToTheLocationServices;

  /// Título do diálogo exibido quando a permissão de localização foi negada permanentemente.
  ///
  /// In en, this message translates to:
  /// **'Access to location permanently denied'**
  String get accessToLocationPermanentlyDenied;

  /// Mensagem do diálogo de permissão negada permanentemente, que manda liberar o acesso pelas configurações do aparelho.
  ///
  /// In en, this message translates to:
  /// **'Allow access to the location services for this App using the device settings.'**
  String get allowAccessToTheLocationServicesFromSettings;

  /// Rótulo do botão de confirmação dos diálogos de permissão de localização.
  ///
  /// In en, this message translates to:
  /// **'Ok'**
  String get ok;

  /// Aviso de que a localização atual não pôde ser obtida. Sem ponto de uso no pacote hoje, mantido porque já tem tradução nos dez idiomas do fork.
  ///
  /// In en, this message translates to:
  /// **'Can\'t get current location'**
  String get cantGetCurrentLocation;

  /// Complemento do aviso de localização indisponível. Sem ponto de uso no pacote hoje, mantido porque já tem tradução nos dez idiomas do fork.
  ///
  /// In en, this message translates to:
  /// **'Please make sure you enable GPS and try again'**
  String get pleaseMakeSureYouEnableGpsAndTryAgain;

  /// Placeholder do campo de busca de endereço, usado quando o widget não recebe `hintText`.
  ///
  /// In en, this message translates to:
  /// **'Search place'**
  String get searchPlace;

  /// Overlay exibido enquanto a coordenada ou o link do Maps colado na busca é resolvido.
  ///
  /// In en, this message translates to:
  /// **'Finding place...'**
  String get findingPlace;

  /// Item exibido na lista de sugestões quando a busca não devolve nenhum endereço.
  ///
  /// In en, this message translates to:
  /// **'No result found'**
  String get noResultFound;

  /// Texto do card de endereço quando o ponto selecionado não tem endereço conhecido.
  ///
  /// In en, this message translates to:
  /// **'Unnamed place'**
  String get unnamedPlace;
}

class _GoogleMapLocationPickerLocalizationsDelegate
    extends LocalizationsDelegate<GoogleMapLocationPickerLocalizations> {
  const _GoogleMapLocationPickerLocalizationsDelegate();

  @override
  Future<GoogleMapLocationPickerLocalizations> load(Locale locale) {
    return SynchronousFuture<GoogleMapLocationPickerLocalizations>(
      lookupGoogleMapLocationPickerLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'de',
    'en',
    'es',
    'fr',
    'it',
    'pt',
    'ru',
    'sr',
    'tr',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_GoogleMapLocationPickerLocalizationsDelegate old) => false;
}

GoogleMapLocationPickerLocalizations lookupGoogleMapLocationPickerLocalizations(
  Locale locale,
) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return GoogleMapLocationPickerLocalizationsAr();
    case 'de':
      return GoogleMapLocationPickerLocalizationsDe();
    case 'en':
      return GoogleMapLocationPickerLocalizationsEn();
    case 'es':
      return GoogleMapLocationPickerLocalizationsEs();
    case 'fr':
      return GoogleMapLocationPickerLocalizationsFr();
    case 'it':
      return GoogleMapLocationPickerLocalizationsIt();
    case 'pt':
      return GoogleMapLocationPickerLocalizationsPt();
    case 'ru':
      return GoogleMapLocationPickerLocalizationsRu();
    case 'sr':
      return GoogleMapLocationPickerLocalizationsSr();
    case 'tr':
      return GoogleMapLocationPickerLocalizationsTr();
  }

  throw FlutterError(
    'GoogleMapLocationPickerLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
