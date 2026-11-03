import 'package:flutter_test/flutter_test.dart';
import 'package:it_management_portal/core/authentication/auth_service.dart';
import 'package:it_management_portal/core/authentication/sign_in_gateway.dart';
import 'package:it_management_portal/data/api/graph_client.dart';
import 'package:it_management_portal/data/repositories/employee_repository.dart';
import 'package:it_management_portal/data/repositories/profile_repository.dart';
import 'package:it_management_portal/models/employee.dart';
import 'package:it_management_portal/models/user_profile.dart';
import 'package:it_management_portal/services/session_service.dart';
import 'package:it_management_portal/services/session_state.dart';

class FakeAuth implements SignInGateway {
  bool hasSession = false;
  Exception? signInError;
  int signOutCalls = 0;

  @override
  Future<bool> trySilentSignIn() async => hasSession;

  @override
  Future<void> signIn() async {
    if (signInError != null) throw signInError!;
  }

  @override
  Future<void> signOut() async => signOutCalls++;
}

class FakeProfiles implements ProfileSource {
  Exception? error;

  @override
  Future<UserProfile> fetchMe() async {
    if (error != null) throw error!;
    return const UserProfile(
      objectId: 'oid-1',
      displayName: 'Ong',
      userPrincipalName: 'ong@sqlacc.onmicrosoft.com',
    );
  }
}

class FakeEmployees implements EmployeeLookup {
  Employee? result;

  @override
  Future<Employee?> findByEntraObjectId(String objectId) async => result;
}

Employee employee({bool active = true}) => Employee(
      itemId: '1',
      employeeId: '8888',
      name: 'Ong',
      email: 'ong@sqlacc.onmicrosoft.com',
      entraObjectId: 'oid-1',
      appRole: 'Employee',
      isActive: active,
    );

void main() {
  late FakeAuth auth;
  late FakeProfiles profiles;
  late FakeEmployees employees;
  late SessionService service;

  setUp(() {
    auth = FakeAuth();
    profiles = FakeProfiles();
    employees = FakeEmployees();
    service = SessionService(
      auth: auth,
      profiles: profiles,
      employees: employees,
    );
  });

  test('no saved session -> signed out', () async {
    expect(await service.restore(), isA<SessionSignedOut>());
  });

  test('saved session and active employee -> active', () async {
    auth.hasSession = true;
    employees.result = employee();
    final state = await service.restore();
    expect(state, isA<SessionActive>());
    expect((state as SessionActive).user.role, 'Employee');
  });

  test('unknown user is blocked and the session is cleared', () async {
    employees.result = null;
    final state = await service.signIn();
    expect(state, isA<SessionBlocked>());
    expect(auth.signOutCalls, 1);
  });

  test('inactive employee is blocked and the session is cleared', () async {
    employees.result = employee(active: false);
    final state = await service.signIn();
    expect(state, isA<SessionBlocked>());
    expect(auth.signOutCalls, 1);
  });

  test('HTTP 403 from SharePoint is blocked with a clear message', () async {
    profiles.error = GraphException(statusCode: 403, userMessage: 'Forbidden');
    final state = await service.signIn();
    expect(state, isA<SessionBlocked>());
    expect((state as SessionBlocked).message, contains('permission'));
    expect(auth.signOutCalls, 1);
  });

  test('server error is a failure, not a block, and keeps the session',
      () async {
    profiles.error = GraphException(statusCode: 500, userMessage: 'Try later');
    final state = await service.signIn();
    expect(state, isA<SessionFailed>());
    expect(auth.signOutCalls, 0);
  });

  test('cancelled or failed browser sign-in -> failed', () async {
    auth.signInError = AuthException('Sign-in timed out.');
    final state = await service.signIn();
    expect(state, isA<SessionFailed>());
    expect((state as SessionFailed).message, 'Sign-in timed out.');
  });
}
