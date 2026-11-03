import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// PKCE helpers (RFC 7636). Pure functions, easy to unit test.

String base64UrlNoPadding(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

/// Random code verifier. 48 random bytes give 64 URL-safe characters.
String generateCodeVerifier([int byteLength = 48]) {
  final random = Random.secure();
  final bytes = List<int>.generate(byteLength, (_) => random.nextInt(256));
  return base64UrlNoPadding(bytes);
}

/// S256 code challenge for a verifier.
String codeChallengeFor(String verifier) =>
    base64UrlNoPadding(sha256.convert(ascii.encode(verifier)).bytes);

/// Random `state` value to tie the sign-in response to our request.
String generateState() => generateCodeVerifier(24);
