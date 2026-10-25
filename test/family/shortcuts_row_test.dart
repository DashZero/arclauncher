import 'package:flauncher/family/family_settings.dart';
import 'package:flauncher/family/ui/shortcuts_row.dart';
import 'package:flauncher/family/ui/shortcuts_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ShortcutsRow', () {
    Widget buildRowTestWidget(FamilySettings familySettings) {
      return ChangeNotifierProvider<FamilySettings>.value(
        value: familySettings,
        child: const MaterialApp(home: Scaffold(body: ShortcutsRow())),
      );
    }

    testWidgets(
      'default settings show six tiles with the labels of kDefaultShortcutIds',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final familySettings = FamilySettings(prefs);

        await tester.pumpWidget(buildRowTestWidget(familySettings));
        await tester.pumpAndSettle();

        final defsById = {for (final def in kShortcutDefs) def.id: def};
        for (final id in kDefaultShortcutIds) {
          final def = defsById[id]!;
          expect(find.text(def.label), findsOneWidget);
        }
      },
    );

    testWidgets('with showShortcuts false nothing renders', (tester) async {
      SharedPreferences.setMockInitialValues({'family_show_shortcuts': false});
      final prefs = await SharedPreferences.getInstance();
      final familySettings = FamilySettings(prefs);

      await tester.pumpWidget(buildRowTestWidget(familySettings));
      await tester.pumpAndSettle();

      final defsById = {for (final def in kShortcutDefs) def.id: def};
      for (final id in kDefaultShortcutIds) {
        final def = defsById[id]!;
        expect(find.text(def.label), findsNothing);
      }
      expect(find.byType(ShortcutsRow), findsOneWidget);
    });

    testWidgets('an unknown id in shortcutIds is skipped without error', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'family_shortcut_ids': [
          'unknown_id',
          'wifi',
          'another_bad_id',
          'display',
        ],
      });
      final prefs = await SharedPreferences.getInstance();
      final familySettings = FamilySettings(prefs);

      await tester.pumpWidget(buildRowTestWidget(familySettings));
      await tester.pumpAndSettle();

      expect(find.text('Wi-Fi'), findsOneWidget);
      expect(find.text('Display'), findsOneWidget);
      expect(find.text('unknown_id'), findsNothing);
      expect(find.text('another_bad_id'), findsNothing);
    });
  });

  group('ShortcutsSettingsPage', () {
    Widget buildSettingsTestWidget(FamilySettings familySettings) {
      return ChangeNotifierProvider<FamilySettings>.value(
        value: familySettings,
        child: const MaterialApp(home: Scaffold(body: ShortcutsSettingsPage())),
      );
    }

    testWidgets('renders header and toggles shortcut settings', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final familySettings = FamilySettings(prefs);

      await tester.pumpWidget(buildSettingsTestWidget(familySettings));
      await tester.pumpAndSettle();

      expect(find.text('Shortcut tiles'), findsOneWidget);
      expect(find.text('Show shortcut tiles'), findsOneWidget);

      // Verify toggling showShortcuts
      await tester.tap(find.text('Show shortcut tiles'));
      await tester.pumpAndSettle();
      expect(familySettings.showShortcuts, isFalse);

      // Verify toggling a shortcut off
      expect(familySettings.shortcutIds.contains('wifi'), isTrue);
      await tester.tap(find.text('Wi-Fi'));
      await tester.pumpAndSettle();
      expect(familySettings.shortcutIds.contains('wifi'), isFalse);

      // Verify toggling a shortcut back on appends to end
      await tester.tap(find.text('Wi-Fi'));
      await tester.pumpAndSettle();
      expect(familySettings.shortcutIds.contains('wifi'), isTrue);
      expect(familySettings.shortcutIds.last, equals('wifi'));
    });
  });
}
