import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talento_digital/theme/adventure_theme.dart';

void main() {
  test('AdventureTheme themeModeNotifier alterna ciclicamente', () {
    AdventureTheme.themeModeNotifier.value = ThemeMode.system;

    AdventureTheme.alternarTemaRapido();
    expect(AdventureTheme.themeModeNotifier.value, ThemeMode.light);

    AdventureTheme.alternarTemaRapido();
    expect(AdventureTheme.themeModeNotifier.value, ThemeMode.dark);

    AdventureTheme.alternarTemaRapido();
    expect(AdventureTheme.themeModeNotifier.value, ThemeMode.system);
  });

  testWidgets('AdventureTheme lightTheme e darkTheme instanciam corretamente', (tester) async {
    final light = AdventureTheme.lightTheme;
    final dark = AdventureTheme.darkTheme;

    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.scaffoldBackgroundColor, AdventureTheme.surface);
    expect(dark.scaffoldBackgroundColor, AdventureTheme.darkSurface);
  });
}
