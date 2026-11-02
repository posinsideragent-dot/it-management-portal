import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../configuration/app_config.dart';
import 'pkce.dart';

/// Error with a message that is safe to show to the user.
/// Never put tokens or codes in these messages.
class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Microsoft Entra sign-in for a Windows desktop app.
///
/// Flow: authorization code with PKCE, system browser, loopback redirect.
/// - No client secret and no embedded login form.
/// - The access token stays in memory only.
/// - The refresh token is kept in flutter_secure_storage.
/// - Tokens are never logged.
///
/// This replaces the Windows-native MSAL named in the spec, because no
/// maintained Flutter MSAL package supports Windows. See docs/Authentication.md.
class AuthService {
  AuthService(
    this._config, {
    FlutterSecureStorage? storage,
    http.Client? httpClient,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _http = httpClient ?? http.Client();

  final AppConfig _config;
  final FlutterSecureStorage _storage;
  final http.Client _http;

  String? _accessToken;
  DateTime? _accessTokenExpiresUtc;

  static const _signInTimeout = Duration(minutes: 3);
  static const _requestTimeout = Duration(seconds: 30);

  String get _refreshTokenKey => 'itdmp.${_config.environment}.refresh_token';

  bool get _hasFreshAccessToken =>
      _accessToken != null &&
      _accessTokenExpiresUtc != null &&
      DateTime.now().toUtc().isBefore(_accessTokenExpiresUtc!);

  /// Returns a valid access token. Refreshes it silently when needed.
  /// Throws [AuthException] when the user must sign in again.
  Future<String> getAccessToken() async {
    if (_hasFreshAccessToken) {
      return _accessToken!;
    }
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null) {
      throw AuthException('You are not signed in.');
    }
    await _tokenRequest({
      'client_id': _config.clientId,
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
      'scope': AppConfig.scopes.join(' '),
    });
    return _accessToken!;
  }

  /// True when a saved session exists and could be refreshed.
  Future<bool> trySilentSignIn() async {
    try {
      await getAccessToken();
      return true;
    } on AuthException {
      return false;
    }
  }

  /// Interactive sign-in in the system browser.
  Future<void> signIn() async {
    final verifier = generateCodeVerifier();
    final challenge = codeChallengeFor(verifier);
    final state = generateState();

    final server = await _bindLoopback();
    final codeCompleter = Completer<String>();
    server.listen((request) => _handleCallback(request, state, codeCompleter));

    try {
      // Entra ignores the port for http://localhost redirect URIs.
      final redirectUri = 'http://localhost:${server.port}';
      final authUri = Uri.https(
        'login.microsoftonline.com',
        '/${_config.tenantId}/oauth2/v2.0/authorize',
        {
          'client_id': _config.clientId,
          'response_type': 'code',
          'redirect_uri': redirectUri,
          'response_mode': 'query',
          'scope': AppConfig.scopes.join(' '),
          'state': state,
          'code_challenge': challenge,
          'code_challenge_method': 'S256',
          'prompt': 'select_account',
        },
      );

      final launched =
          await launchUrl(authUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw AuthException('Could not open the web browser for sign-in.');
      }

      final code = await codeCompleter.future.timeout(
        _signInTimeout,
        onTimeout: () => throw AuthException('Sign-in timed out. Try again.'),
      );

      await _tokenRequest({
        'client_id': _config.clientId,
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirectUri,
        'code_verifier': verifier,
        'scope': AppConfig.scopes.join(' '),
      });
    } finally {
      await server.close(force: true);
    }
  }

  /// Clears the saved session and the in-memory token.
  Future<void> signOut() async {
    _accessToken = null;
    _accessTokenExpiresUtc = null;
    await _storage.delete(key: _refreshTokenKey);
  }

  // Dual-stack loopback so both http://localhost -> ::1 and 127.0.0.1 work.
  Future<HttpServer> _bindLoopback() async {
    try {
      return await HttpServer.bind(
        InternetAddress.loopbackIPv6,
        0,
        v6Only: false,
      );
    } on SocketException {
      // IPv6 not available on this machine. Fall back to IPv4 only.
      return HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    }
  }

  Future<void> _handleCallback(
    HttpRequest request,
    String expectedState,
    Completer<String> completer,
  ) async {
    final params = request.uri.queryParameters;

    // Ignore unrelated requests such as /favicon.ico.
    if (!params.containsKey('code') && !params.containsKey('error')) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    // Static page only. Never echo request values into the HTML.
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..write(
        '<html><body style="font-family:sans-serif">'
        '<h3>ITDMP sign-in</h3>'
        '<p>You can close this window and return to the app.</p>'
        '</body></html>',
      );
    await request.response.close();

    if (completer.isCompleted) {
      return;
    }
    if (params['error'] != null) {
      completer.completeError(AuthException(
        'Sign-in failed: ${params['error_description'] ?? params['error']}',
      ));
    } else if (params['state'] != expectedState) {
      completer.completeError(AuthException(
        'The sign-in response did not match the request. Try again.',
      ));
    } else {
      completer.complete(params['code']!);
    }
  }

  Future<void> _tokenRequest(Map<String, String> body) async {
    final isRefresh = body['grant_type'] == 'refresh_token';
    final http.Response response;
    try {
      response = await _http
          .post(
            Uri.parse('${_config.authority}/oauth2/v2.0/token'),
            body: body,
          )
          .timeout(_requestTimeout);
    } on SocketException {
      throw AuthException('Cannot reach Microsoft sign-in. Check the network.');
    } on http.ClientException {
      throw AuthException('Cannot reach Microsoft sign-in. Check the network.');
    } on TimeoutException {
      throw AuthException('Microsoft sign-in did not respond in time.');
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw AuthException(
        'Unexpected response from Microsoft (HTTP ${response.statusCode}).',
      );
    }

    if (response.statusCode != 200) {
      final error = json['error'];
      if (isRefresh && error == 'invalid_grant') {
        // The saved session is no longer valid. Remove it.
        await signOut();
      }
      throw AuthException(
        'Sign-in failed ($error): ${json['error_description'] ?? ''}',
      );
    }

    _accessToken = json['access_token'] as String;
    final expiresIn = (json['expires_in'] as num).toInt();
    // Refresh 2 minutes early.
    _accessTokenExpiresUtc =
        DateTime.now().toUtc().add(Duration(seconds: expiresIn - 120));

    final newRefreshToken = json['refresh_token'] as String?;
    if (newRefreshToken != null) {
      await _storage.write(key: _refreshTokenKey, value: newRefreshToken);
    }
  }
}
