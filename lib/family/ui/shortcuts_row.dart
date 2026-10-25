import 'package:flauncher/actions.dart';
import 'package:flauncher/family/family_settings.dart';
import 'package:flauncher/flauncher_channel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Returns a suitable Material icon for the given shortcut id.
IconData iconForShortcut(String id) {
  switch (id) {
    case 'wifi':
      return Icons.wifi;
    case 'display':
      return Icons.tv;
    case 'storage':
      return Icons.storage;
    case 'apps':
      return Icons.apps;
    case 'bluetooth':
      return Icons.bluetooth;
    case 'inputs':
      return Icons.settings_input_component;
    case 'play':
      return Icons.shop;
    case 'settings':
    default:
      return Icons.settings;
  }
}

/// Horizontal row of configurable shortcut tiles (Wi-Fi, Display, etc.)
/// that launch Android settings or apps.
class ShortcutsRow extends StatelessWidget {
  /// True when this is the top row on the home screen, so Up goes to the settings icon.
  final bool handleUpNavigationToSettings;

  const ShortcutsRow({super.key, this.handleUpNavigationToSettings = false});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<FamilySettings>();
    if (!settings.showShortcuts || settings.shortcutIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final defsById = {for (final def in kShortcutDefs) def.id: def};
    final activeDefs = <ShortcutDef>[];
    for (final id in settings.shortcutIds) {
      final def = defsById[id];
      if (def != null) {
        activeDefs.add(def);
      }
    }

    if (activeDefs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(left: 40.0),
      child: SizedBox(
        height: 80,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < activeDefs.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                _ShortcutTile(
                  def: activeDefs[i],
                  handleUpNavigationToSettings: handleUpNavigationToSettings,
                  onSelect: () => _launchShortcut(activeDefs[i]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchShortcut(ShortcutDef def) async {
    try {
      if (def.action != null) {
        await FLauncherChannel().launchActivityFromAction(def.action!);
      } else if (def.packageName != null) {
        await FLauncherChannel().launchApp(def.packageName!);
      }
    } catch (_) {
      // Ignored: never throw or show an error dialog.
    }
  }
}

class _ShortcutTile extends StatefulWidget {
  final ShortcutDef def;
  final VoidCallback onSelect;
  final bool handleUpNavigationToSettings;

  const _ShortcutTile({required this.def, required this.onSelect, this.handleUpNavigationToSettings = false});

  @override
  State<_ShortcutTile> createState() => _ShortcutTileState();
}

class _ShortcutTileState extends State<_ShortcutTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasNavFocus) {
        setState(() {
          _focused = hasNavFocus;
        });
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.gameButtonA ||
              event.logicalKey == LogicalKeyboardKey.space) {
            widget.onSelect();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp && widget.handleUpNavigationToSettings) {
            Actions.invoke(context, const MoveFocusToSettingsIntent());
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onSelect,
        child: Container(
          width: 150,
          height: 80,
          decoration: BoxDecoration(
            color: _focused ? const Color(0x33FFFFFF) : const Color(0x14FFFFFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _focused ? Colors.white : Colors.white24,
              width: _focused ? 2.0 : 1.0,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                iconForShortcut(widget.def.id),
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(height: 6),
              Text(
                widget.def.label,
                style: TextStyle(
                  color: _focused
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: _focused ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
