import 'package:fluent_ui/fluent_ui.dart';

/// Fixed colours used for status indicators. They read well on dark and light.
class StatusColors {
  const StatusColors._();

  static const success = Color(0xFF3FB950);
  static const neutral = Color(0xFF8B949E);
  static const warning = Color(0xFFD29922);
  static const info = Color(0xFF58A6FF);
  static const active = Color(0xFF2DD4BF);
  static const danger = Color(0xFFF85149);
}

/// The one place that defines the look of the app. Dark is the default.
class AppTheme {
  const AppTheme._();

  static const _darkBackground = Color(0xFF0F1318);
  static const _darkSurface = Color(0xFF171C23);
  static const _darkPane = Color(0xFF12171D);
  static const _lightBackground = Color(0xFFF3F5F8);
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _lightPane = Color(0xFFE9EDF2);

  static FluentThemeData dark() => FluentThemeData(
        brightness: Brightness.dark,
        accentColor: Colors.blue,
        scaffoldBackgroundColor: _darkBackground,
        cardColor: _darkSurface,
        navigationPaneTheme: const NavigationPaneThemeData(
          backgroundColor: _darkPane,
        ),
      );

  static FluentThemeData light() => FluentThemeData(
        brightness: Brightness.light,
        accentColor: Colors.blue,
        scaffoldBackgroundColor: _lightBackground,
        cardColor: _lightSurface,
        navigationPaneTheme: const NavigationPaneThemeData(
          backgroundColor: _lightPane,
        ),
      );
}
