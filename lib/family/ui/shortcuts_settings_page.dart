import 'package:flauncher/family/family_settings.dart';
import 'package:flauncher/family/ui/shortcuts_row.dart';
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flauncher/widgets/settings/settings_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Settings page allowing the user to enable or disable shortcut tiles on the home screen.
class ShortcutsSettingsPage extends StatelessWidget {
  static const String routeName = 'family_shortcuts';

  const ShortcutsSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final familySettings = context.watch<FamilySettings>();

    return Column(
      children: [
        const SettingsPageHeader(title: 'Shortcut tiles'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              RoundedSwitchListTile(
                autofocus: true,
                value: familySettings.showShortcuts,
                onChanged: (value) => familySettings.setShowShortcuts(value),
                title: Text(
                  'Show shortcut tiles',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                secondary: const Icon(Icons.widgets),
              ),
              for (final def in kShortcutDefs)
                RoundedSwitchListTile(
                  value: familySettings.shortcutIds.contains(def.id),
                  onChanged: (enabled) {
                    final current = familySettings.shortcutIds;
                    if (enabled) {
                      if (!current.contains(def.id)) {
                        familySettings.setShortcutIds([...current, def.id]);
                      }
                    } else {
                      familySettings.setShortcutIds(
                        current.where((id) => id != def.id).toList(),
                      );
                    }
                  },
                  title: Text(
                    def.label,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  secondary: Icon(iconForShortcut(def.id)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
