import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/configuration/app_config.dart';
import 'state/providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.forEnvironment(itdmpEnvironment);
  final missing = config.missingSettings;
  if (missing.isNotEmpty) {
    // A half-filled config would fail later with confusing errors.
    runApp(_ConfigErrorApp(environment: config.environment, missing: missing));
    return;
  }
  runApp(const ProviderScope(child: ItdmpApp()));
}

/// Shown instead of the app when the build settings are incomplete.
class _ConfigErrorApp extends StatelessWidget {
  const _ConfigErrorApp({required this.environment, required this.missing});

  final String environment;
  final List<String> missing;

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      title: 'ITDMP',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: FluentThemeData(brightness: Brightness.dark),
      home: ScaffoldPage(
        content: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: InfoBar(
              title: Text('The $environment settings are incomplete'),
              content: Text(
                'Missing: ${missing.join(', ')}. Ask IT to fill them in '
                '(docs/AdminSetup-PROD.md) and rebuild the app.',
              ),
              severity: InfoBarSeverity.error,
              isLong: true,
            ),
          ),
        ),
      ),
    );
  }
}
