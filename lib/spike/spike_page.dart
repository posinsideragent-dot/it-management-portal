import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/authentication/auth_service.dart';
import '../core/configuration/app_config.dart';
import '../data/api/graph_client.dart';
import '../data/repositories/employee_repository.dart';
import '../data/repositories/poc_test_repository.dart';

/// Throwaway test page for Phase 1 (steps 5, 7, 8, 9).
/// Each button runs one gate check and logs the result with its time.
/// The real application shell replaces this page in step 6.
/// The log never contains tokens.
class SpikePage extends StatefulWidget {
  const SpikePage({super.key, required this.config});

  final AppConfig config;

  @override
  State<SpikePage> createState() => _SpikePageState();
}

class _SpikePageState extends State<SpikePage> {
  late final AuthService _auth;
  late final GraphClient _graph;
  late final EmployeeRepository _employees;
  late final PocTestRepository _poc;

  final List<String> _log = [];
  bool _busy = false;
  PocItem? _item;
  String? _oldEtag;

  @override
  void initState() {
    super.initState();
    _auth = AuthService(widget.config);
    _graph = GraphClient(_auth);
    _employees = EmployeeRepository(_graph, widget.config);
    _poc = PocTestRepository(_graph, widget.config);
    _run('Restore saved session', () async {
      final ok = await _auth.trySilentSignIn();
      return ok ? 'Signed in from the saved session.' : 'No saved session.';
    });
  }

  Future<void> _run(String label, Future<String> Function() action) async {
    setState(() => _busy = true);
    final watch = Stopwatch()..start();
    String line;
    try {
      final message = await action();
      line = '$label: OK (${watch.elapsedMilliseconds} ms) $message';
    } on AuthException catch (e) {
      line = '$label: SIGN-IN PROBLEM. $e';
    } on GraphException catch (e) {
      line = '$label: FAILED (${watch.elapsedMilliseconds} ms) $e';
    } on Object catch (e) {
      // Last stop for the test page: show the error instead of hiding it.
      line = '$label: UNEXPECTED ERROR. $e';
    }
    if (!mounted) return;
    setState(() {
      _log.insert(0, '[${DateTime.now().toIso8601String()}] $line');
      _busy = false;
    });
  }

  Future<String> _signIn() async {
    await _auth.signIn();
    return 'Signed in.';
  }

  Future<String> _whoAmI() async {
    final me = await _graph.get('/me', query: {
      r'$select': 'id,displayName,userPrincipalName',
    });
    final objectId = me['id'] as String;
    final upn = me['userPrincipalName'];
    final employee = await _employees.findByEntraObjectId(objectId);
    if (employee == null) {
      return 'DENIED: $upn is not registered in IT_Employees '
          '(Object ID $objectId).';
    }
    if (!employee.isActive) {
      return 'DENIED: ${employee.name} is inactive.';
    }
    return 'ALLOWED: ${employee.name}, role ${employee.appRole}, '
        'Object ID $objectId matches IT_Employees.';
  }

  Future<String> _readEmployees() async {
    final rows = (await _employees.listPage()).items;
    final names = rows.map((e) => '${e.employeeId}/${e.name}').join(', ');
    return '${rows.length} row(s): $names';
  }

  Future<String> _createItem() async {
    final created = await _poc.create(
      title: 'PoC ${DateTime.now().toUtc().toIso8601String()}',
      note: 'Created by the Phase 1 spike.',
    );
    _item = created;
    _oldEtag = null;
    return 'Created item ${created.id}. ETag ${created.etag}';
  }

  Future<String> _updateItem() async {
    final item = _item;
    if (item == null) return 'Create a test item first.';
    final updated = await _poc.update(
      item: item,
      etag: item.etag,
      note: 'Updated by the Phase 1 spike.',
    );
    _oldEtag = item.etag;
    _item = updated;
    return 'Updated item ${updated.id} using its ETag. New ETag ${updated.etag}';
  }

  Future<String> _staleUpdate() async {
    final item = _item;
    final stale = _oldEtag;
    if (item == null || stale == null) {
      return 'Create an item and update it once first.';
    }
    try {
      await _poc.update(item: item, etag: stale, note: 'Stale ETag test.');
    } on GraphException catch (e) {
      if (e.isPreconditionFailed) {
        return 'PASS: the old ETag was rejected with HTTP 412, as it should be.';
      }
      rethrow;
    }
    return 'UNEXPECTED: update with an old ETag succeeded. '
        'ETag checks are NOT enforced. Tell the developer.';
  }

  Future<String> _signOut() async {
    await _auth.signOut();
    _item = null;
    _oldEtag = null;
    return 'Signed out and saved session removed.';
  }

  @override
  Widget build(BuildContext context) {
    final busy = _busy;
    return Scaffold(
      appBar: AppBar(
        title: Text('ITDMP Phase 1 spike (${widget.config.environment})'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _button('1. Sign in', busy, () => _run('Sign in', _signIn)),
                _button('2. Who am I', busy, () => _run('Who am I', _whoAmI)),
                _button('3. Read employees', busy,
                    () => _run('Read employees', _readEmployees)),
                _button('4. Create test item', busy,
                    () => _run('Create item', _createItem)),
                _button('5. Update with ETag', busy,
                    () => _run('Update item', _updateItem)),
                _button('6. Update with old ETag (expect 412)', busy,
                    () => _run('Old ETag update', _staleUpdate)),
                _button('Sign out', busy, () => _run('Sign out', _signOut)),
                _button('Copy log', false, () async {
                  await Clipboard.setData(
                    ClipboardData(text: _log.reversed.join('\n')),
                  );
                }),
              ],
            ),
            const SizedBox(height: 12),
            if (busy) const LinearProgressIndicator(),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _log.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: SelectableText(
                    _log[index],
                    style: const TextStyle(fontFamily: 'Consolas'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _button(String label, bool disabled, VoidCallback onPressed) =>
      ElevatedButton(
        onPressed: disabled ? null : onPressed,
        child: Text(label),
      );
}
