import 'package:fluent_ui/fluent_ui.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Light or dark. Dark is the default. The choice lasts until the app closes.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  void toggle() =>
      state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

/// True when the sidebar shows labels, false when it shows icons only.
class SidebarController extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final sidebarExpandedProvider =
    NotifierProvider<SidebarController, bool>(SidebarController.new);
