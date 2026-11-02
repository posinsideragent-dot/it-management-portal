import 'package:flutter_test/flutter_test.dart';
import 'package:it_management_portal/core/authentication/pkce.dart';

void main() {
  group('PKCE', () {
    test('S256 challenge matches the RFC 7636 example', () {
      const verifier = 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk';
      expect(
        codeChallengeFor(verifier),
        'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
      );
    });

    test('verifier is 64 URL-safe characters and different each time', () {
      final a = generateCodeVerifier();
      final b = generateCodeVerifier();
      expect(a.length, 64);
      expect(RegExp(r'^[A-Za-z0-9\-_]+$').hasMatch(a), isTrue);
      expect(a, isNot(b));
    });

    test('state is URL-safe and different each time', () {
      final a = generateState();
      final b = generateState();
      expect(RegExp(r'^[A-Za-z0-9\-_]+$').hasMatch(a), isTrue);
      expect(a, isNot(b));
    });
  });
}
