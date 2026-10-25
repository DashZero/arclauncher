import 'package:flauncher/family/family_settings.dart';
import 'package:flauncher/family/recommendation_models.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/settings/settings_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Settings page for configuring taste profiles and dislikes for family members.
class TasteProfilePage extends StatelessWidget {
  static const String routeName = "family_taste_profiles";

  const TasteProfilePage({super.key});

  static String _preview(String text) {
    if (text.length <= 60) return text;
    return '${text.substring(0, 60)}...';
  }

  static Future<void> _showEditDialog({
    required BuildContext context,
    required String title,
    required String initialValue,
    required Future<void> Function(String) onSave,
  }) async {
    final controller = TextEditingController(text: initialValue);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          maxLines: 8,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(dialogContext).colorScheme.primary,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: const Color(0x0DFFFFFF),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await onSave(controller.text);
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<FamilySettings>();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        const SettingsPageHeader(title: 'Taste profiles'),
        for (final person in Person.values)
          FocusableSettingsTile(
            title: Text(person.label),
            subtitle: Text(_preview(settings.profile(person))),
            showChevron: true,
            onPressed: () => _showEditDialog(
              context: context,
              title: '${person.label} profile',
              initialValue: settings.profile(person),
              onSave: (val) => settings.setProfile(person, val),
            ),
          ),
        FocusableSettingsTile(
          title: const Text('Dislikes (everyone)'),
          subtitle: Text(_preview(settings.dislikes)),
          showChevron: true,
          onPressed: () => _showEditDialog(
            context: context,
            title: 'Dislikes (everyone)',
            initialValue: settings.dislikes,
            onSave: (val) => settings.setDislikes(val),
          ),
        ),
        FocusableSettingsTile(
          leading: const Icon(Icons.refresh),
          title: const Text('Refresh recommendations'),
          subtitle: const Text('Ask Gemini for new recommendations now'),
          onPressed: () => context.read<RecommendationFeed>().refresh(),
        ),
      ],
    );
  }
}
