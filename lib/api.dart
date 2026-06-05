// Slim Uellow API client for the Reviewers app — auth + reviewer endpoints.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  ApiException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

class RevApi {
  RevApi._();
  static final RevApi instance = RevApi._();

  static const baseUrl = String.fromEnvironment('UELLOW_API_BASE',
      defaultValue: 'https://www.uellow.com');

  String lang = 'ar';
  String? _token;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('rev_token');
    lang = prefs.getString('rev_lang') ?? 'ar';
  }

  bool get signedIn => _token != null && _token!.isNotEmpty;

  Future<void> setLang(String l) async {
    lang = l;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rev_lang', l);
  }

  Future<void> _saveToken(String? t) async {
    _token = t;
    final prefs = await SharedPreferences.getInstance();
    if (t == null) {
      await prefs.remove('rev_token');
    } else {
      await prefs.setString('rev_token', t);
    }
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Lang': lang,
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<Map<String, dynamic>> _req(String method, String path,
      {Map<String, dynamic>? query, Object? body}) async {
    var uri = Uri.parse('$baseUrl$path');
    if (query != null) {
      uri = uri.replace(
          queryParameters: query.map((k, v) => MapEntry(k, '$v')));
    }
    late http.Response r;
    if (method == 'GET') {
      r = await http.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 25));
    } else {
      r = await http.post(uri, headers: _headers,
              body: body == null ? null : jsonEncode(body))
          .timeout(const Duration(seconds: 25));
    }
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    if (j['success'] != true) {
      throw ApiException((j['code'] ?? 'ERROR').toString(),
          (j['error'] ?? 'Request failed').toString());
    }
    return j;
  }

  Future<Map<String, dynamic>> _get(String p,
          {Map<String, dynamic>? query}) => _req('GET', p, query: query);
  Future<Map<String, dynamic>> _post(String p, {Object? body}) =>
      _req('POST', p, body: body);

  // auth (same Uellow account)
  Future<void> login(String email, String password) async {
    final res = await _post('/api/mobile/v2/auth/login', body: {
      'email': email, 'password': password,
      'device_name': 'Reviewers app',
    });
    await _saveToken((res['data']?['token'] ?? '').toString());
  }

  Future<void> register(
      {required String name, required String email,
       required String password, String phone = ''}) async {
    final res = await _post('/api/mobile/v2/auth/register', body: {
      'name': name, 'email': email, 'password': password,
      if (phone.isNotEmpty) 'phone': phone,
    });
    await _saveToken((res['data']?['token'] ?? '').toString());
  }

  Future<void> logout() async {
    try { await _post('/api/mobile/v2/auth/logout'); } catch (_) {}
    await _saveToken(null);
  }

  // reviewer
  Future<Map<String, dynamic>> me() async =>
      ((await _get('/api/mobile/v2/reviewer/me'))['data'] as Map)
          .cast<String, dynamic>();

  Future<Map<String, dynamic>> apply(
      {String? name, String specialties = '', String bio = ''}) async {
    final res = await _post('/api/mobile/v2/reviewer/apply', body: {
      if (name != null) 'name': name,
      'specialties': specialties, 'bio': bio,
    });
    return (res['data'] as Map).cast<String, dynamic>();
  }

  Future<bool> toggleOnline() async {
    final res = await _post('/api/mobile/v2/reviewer/toggle-online');
    return (res['data']?['is_online'] ?? false) as bool;
  }

  Future<List<Map<String, dynamic>>> requests({String state = ''}) async {
    final res = await _get('/api/mobile/v2/reviewer/requests',
        query: {if (state.isNotEmpty) 'state': state});
    return List<Map<String, dynamic>>.from(
        (res['data']?['requests'] as List?) ?? const []);
  }

  Future<void> accept(int id) async =>
      _post('/api/mobile/v2/reviewer/requests/$id/accept');

  Future<void> complete(int id,
      {required String verdict, String notes = '',
       int quality = 0, int value = 0, int comfort = 0}) async {
    await _post('/api/mobile/v2/reviewer/requests/$id/complete', body: {
      'verdict': verdict, 'notes': notes,
      'quality': quality, 'value': value, 'comfort': comfort,
    });
  }

  Future<void> message(int id, String text) async =>
      _post('/api/mobile/v2/reviewer/requests/$id/message',
          body: {'text': text});

  Future<List<Map<String, dynamic>>> points() async {
    final res = await _get('/api/mobile/v2/reviewer/points');
    return List<Map<String, dynamic>>.from(
        (res['data']?['entries'] as List?) ?? const []);
  }

  Future<Map<String, dynamic>> redeem({int? points}) async {
    final res = await _post('/api/mobile/v2/reviewer/redeem',
        body: {if (points != null) 'points': points});
    return (res['data'] as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> payouts() async {
    final res = await _get('/api/mobile/v2/reviewer/payouts');
    return List<Map<String, dynamic>>.from(
        (res['data']?['payouts'] as List?) ?? const []);
  }

  Future<void> requestPayout(
      {required double amount, required String method,
       String details = ''}) async {
    await _post('/api/mobile/v2/reviewer/payouts',
        body: {'amount': amount, 'method': method, 'details': details});
  }

  Future<Map<String, dynamic>> leaderboard() async =>
      ((await _get('/api/mobile/v2/reviewer/leaderboard'))['data'] as Map)
          .cast<String, dynamic>();
}
