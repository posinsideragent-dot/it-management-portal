import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/authentication/auth_service.dart';
import '../../core/configuration/app_config.dart';

/// Error from Microsoft Graph with a message that is safe to show.
class GraphException implements Exception {
  GraphException({
    required this.statusCode,
    required this.userMessage,
    this.code,
  });

  /// HTTP status. 0 means the request never got a response.
  final int statusCode;
  final String userMessage;
  final String? code;

  bool get isForbidden => statusCode == 403;
  bool get isPreconditionFailed => statusCode == 412;

  @override
  String toString() =>
      'HTTP $statusCode${code == null ? '' : ' ($code)'}: $userMessage';
}

/// One reusable client for Microsoft Graph.
///
/// - Adds the bearer token. The token is never logged.
/// - Retries only GET requests on 429/503, and respects Retry-After.
/// - Never retries POST or PATCH, to avoid duplicate records.
class GraphClient {
  GraphClient(this._auth, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final AuthService _auth;
  final http.Client _http;

  /// Time taken by the last call, including retries. Used for the speed test.
  Duration lastDuration = Duration.zero;

  static const _timeout = Duration(seconds: 30);
  static const _maxRetries = 3;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
  }) =>
      _send('GET', path, query: query, headers: headers, canRetry: true);

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) =>
      _send('POST', path, body: body, headers: headers, canRetry: false);

  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) =>
      _send('PATCH', path, body: body, headers: headers, canRetry: false);

  /// Follows an `@odata.nextLink` returned by Graph.
  /// The link must point to Graph itself, so the token is never sent elsewhere.
  Future<Map<String, dynamic>> getUrl(String url) {
    if (!isTrustedGraphUrl(url)) {
      throw GraphException(
        statusCode: 0,
        userMessage: 'Unexpected paging link was ignored.',
      );
    }
    return _sendUri('GET', Uri.parse(url), canRetry: true);
  }

  /// True only for https links on the Graph host.
  static bool isTrustedGraphUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && uri.scheme == 'https' && uri.host == 'graph.microsoft.com';
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    required bool canRetry,
  }) =>
      _sendUri(
        method,
        _buildUri(path, query),
        body: body,
        headers: headers,
        canRetry: canRetry,
      );

  Future<Map<String, dynamic>> _sendUri(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    required bool canRetry,
  }) async {
    final watch = Stopwatch()..start();
    var attempt = 0;

    while (true) {
      attempt++;
      final token = await _auth.getAccessToken();
      final request = http.Request(method, uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['Accept'] = 'application/json';
      headers?.forEach((key, value) => request.headers[key] = value);
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }

      final http.Response response;
      try {
        final streamed = await _http.send(request).timeout(_timeout);
        response = await http.Response.fromStream(streamed);
      } on TimeoutException {
        throw GraphException(
          statusCode: 0,
          userMessage: 'The request timed out.',
        );
      } on SocketException {
        throw GraphException(
          statusCode: 0,
          userMessage: 'No network connection.',
        );
      } on http.ClientException {
        throw GraphException(
          statusCode: 0,
          userMessage: 'No network connection.',
        );
      }

      final throttled = response.statusCode == 429 || response.statusCode == 503;
      if (canRetry && throttled && attempt <= _maxRetries) {
        final retryAfter = int.tryParse(response.headers['retry-after'] ?? '');
        final waitSeconds = (retryAfter ?? (1 << attempt)).clamp(1, 30).toInt();
        await Future<void>.delayed(Duration(seconds: waitSeconds));
        continue;
      }

      watch.stop();
      lastDuration = watch.elapsed;
      return _handle(response);
    }
  }

  // Build the query by hand. Dart's queryParameters writes spaces as "+",
  // and SharePoint $filter values need %20.
  Uri _buildUri(String path, Map<String, String>? query) {
    final buffer = StringBuffer('${AppConfig.graphBaseUrl}$path');
    if (query != null && query.isNotEmpty) {
      buffer
        ..write('?')
        ..write(query.entries
            .map((e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
            .join('&'));
    }
    return Uri.parse(buffer.toString());
  }

  Map<String, dynamic> _handle(http.Response response) {
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      if (response.body.isEmpty) {
        return <String, dynamic>{};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    String? code;
    var detail = '';
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final error = json['error'] as Map<String, dynamic>?;
      code = error?['code'] as String?;
      detail = (error?['message'] as String?) ?? '';
    } on FormatException {
      // Body is not JSON. Use the status text only.
    } on TypeError {
      // Body is JSON but not the Graph error shape. Use the status text only.
    }

    throw GraphException(
      statusCode: status,
      code: code,
      userMessage: _messageFor(status, detail),
    );
  }

  String _messageFor(int status, String detail) {
    final base = switch (status) {
      401 => 'Your session expired. Sign in again.',
      403 => 'You do not have permission for this SharePoint data. '
          'Ask an administrator.',
      404 => 'The item or list was not found.',
      409 => 'Conflict: the item changed or the value already exists.',
      412 => 'The item was changed by someone else. Reload and try again.',
      429 => 'Microsoft is limiting requests. Try again soon.',
      >= 500 => 'Microsoft service problem. Try again later.',
      _ => 'The request was not accepted.',
    };
    return detail.isEmpty ? base : '$base Details: $detail';
  }
}
