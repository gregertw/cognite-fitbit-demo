import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cognite_cdf_demo/mock/mockmap.dart';
import 'package:cognite_cdf_demo/generated/l10n.dart';
import 'package:cognite_cdf_sdk/cognite_cdf_sdk.dart';

import 'package:cognite_cdf_demo/globals.dart';

class AppStateModel with ChangeNotifier {
  bool _authenticated = true;
  String _userToken;
  String _idToken;
  String _refreshToken;
  DateTime _expires;
  String _email;
  String _name;
  String _locale;
  String _cdfProject;
  String _cdfTimeSeriesId;
  String _cdfApiKey;
  String _cdfURL;
  int _cdfProjectId;
  int _cdfApiKeyId;
  int _cdfNrOfDays = 10;
  StatusModel _cdfStatus;

  final SharedPreferences prefs;
  final FirebaseAnalytics analytics;
  // We use a mockmap to enable and disable mock functions/classes.
  // The mock should be injected as a dependency where external dependencies need
  // to be mocked as part of testing.
  MockMap _mocks = MockMap();

  bool get authenticated => _authenticated;
  String get userToken => _userToken ?? '';
  String get idToken => _idToken ?? '';
  String get refreshToken => _refreshToken ?? '';
  DateTime get expires => _expires;
  String get email => _email;
  String get name => _name;
  String get cdfProject => _cdfProject;
  int get cdfProjectId => _cdfProjectId;
  int get cdfApiKeyId => _cdfApiKeyId;
  set cdfProject(s) {
    _cdfProject = s;
    prefs.setString('cdfProject', s);
  }

  String get cdfApiKey => _cdfApiKey;
  set cdfApiKey(s) {
    _cdfApiKey = s;
    prefs.setString('cdfApiKey', s);
  }

  String get cdfURL => _cdfURL;
  set cdfURL(s) {
    _cdfURL = s;
    prefs.setString('cdfURL', s);
  }

  String get cdfTimeSeriesId => _cdfTimeSeriesId;
  set cdfTimeSeriesId(s) {
    _cdfTimeSeriesId = s;
    prefs.setString('cdfTimeSeriesId', s);
  }

  bool get cdfLoggedIn {
    if (_cdfStatus == null) {
      return false;
    }
    return _cdfStatus.loggedIn;
  }

  int get cdfNrOfDays => _cdfNrOfDays;
  set cdfNrOfDays(i) {
    _cdfNrOfDays = i;
    prefs.setInt('cdfNrOfDays', i);
  }

  MockMap get mocks => _mocks;
  String get locale => _locale ?? '';

  AppStateModel(this.prefs, [this.analytics]) {
    verifyCDF();
    // this will load locale from prefs
    // Note that you need to use
    // Intl.defaultLocale = appState.locale;
    // in your main page(s) builders to apply a loaded locale from prefs
    // as the widget tree will not automatically refresh until build time
    // See lib/ui/pages/home/index.dart for an example.
    setLocale(null);
  }

  void setLocale(String loc) {
    if (loc == null) {
      loc = prefs.getString('locale');
      if (loc == null) {
        loc = Intl.getCurrentLocale().substring(0, 2);
      }
    }
    _locale = loc;
    S.load(Locale(_locale));
    prefs.setString('locale', _locale);
    notifyListeners();
  }

  void switchLocale() {
    final _locales = S.delegate.supportedLocales;
    if (_locales.length == 1) {
      return;
    }
    int ind = 0;
    _locales.asMap().forEach((key, value) {
      if (value.languageCode == _locale) {
        ind = key + 1;
      }
    });
    if (ind >= _locales.length) {
      ind = 0;
    }
    setLocale(_locales[ind].languageCode);
  }

  Future<void> sendAnalyticsEvent(
      String name, Map<String, dynamic> params) async {
    if (this.analytics == null) {
      return;
    }
    await this.analytics.logEvent(
          name: name,
          parameters: params,
        );
    log.d('Sent analytics events: $name');
  }

  void verifyCDF() async {
    _cdfApiKey = prefs.getString('cdfApiKey') ?? '';
    _cdfProject = prefs.getString('cdfProject') ?? 'publicdata';
    _cdfURL = prefs.getString('cdfURL') ?? 'https://api.cognitedata.com';
    _cdfTimeSeriesId = prefs.getString('cdfTimeSeriesId') ?? '';
    CDFApiClient client = _mocks.getMock('heartbeat') ??
        CDFApiClient(
            project: _cdfProject, apikey: _cdfApiKey, baseUrl: _cdfURL);
    try {
      _cdfStatus = await client.getStatus();
    } catch (e) {
      _cdfStatus = null;
    }
    if (_cdfStatus != null) {
      setUserInfo(Map.from({'email': _cdfStatus.user, 'name': 'N/A'}));
      _cdfApiKeyId = _cdfStatus.apiKeyId;
      _cdfProjectId = _cdfStatus.projectId;
    }
    sendAnalyticsEvent(
        'login', {'project': _cdfProject, 'timeseries': _cdfTimeSeriesId});
    notifyListeners();
  }

  void setUserInfo(data) {
    if (data == null) {
      return;
    }
    if (data.containsKey('email')) {
      prefs.setString('email', data['email']);
      _email = data['email'];
    }
    if (data.containsKey('name')) {
      prefs.setString('name', data['name']);
      _name = data['name'];
    }
    notifyListeners();
  }

  void logOut() {
    /* Here you can also close the sessions with the AuthClient
       (if supported). closeSessions() is not implemented here as it
       involves clearing cookies in the webview (for demo.identityprovider.io).
    */
    //AuthClient(authClient:_mocks.getMock('authClient')).closeSessions();
    _authenticated = false;
    _userToken = null;
    _idToken = null;
    _refreshToken = null;
    _expires = null;
    _cdfStatus = null;
    _cdfApiKey = null;
    _cdfApiKeyId = null;
    _cdfProject = null;
    _cdfProjectId = null;
    _cdfTimeSeriesId = null;
    prefs.clear();
    notifyListeners();
  }
}
