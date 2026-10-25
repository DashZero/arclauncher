import 'package:flauncher/family/family_settings.dart';
import 'package:flauncher/family/setup_server.dart';
import 'package:flauncher/widgets/settings/settings_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Shows a QR code for the phone setup page. The local server runs only while
/// this page is open.
class FamilySetupPage extends StatefulWidget {
  static const String routeName = "family_setup";

  final SetupServer? server;

  const FamilySetupPage({super.key, this.server});

  @override
  State<FamilySetupPage> createState() => _FamilySetupPageState();
}

class _FamilySetupPageState extends State<FamilySetupPage> {
  SetupServer? _server;
  String? _address;
  bool _starting = true;

  @override
  void initState() {
    super.initState();
    _server = widget.server ?? SetupServer(context.read<FamilySettings>());
    _server!.start().then((address) {
      if (!mounted) return;
      setState(() {
        _address = address;
        _starting = false;
      });
    });
  }

  @override
  void dispose() {
    _server?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SettingsPageHeader(title: 'Phone setup'),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _starting
                ? const Center(child: CircularProgressIndicator())
                : _address == null
                    ? const Center(child: Text('Could not find a Wi-Fi address. Connect the TV to your home network.'))
                    : Column(
                        children: [
                          const Text('Scan with your phone (same Wi-Fi) to enter the album link and keys.'),
                          const SizedBox(height: 16),
                          Container(
                            color: Colors.white,
                            padding: const EdgeInsets.all(12),
                            child: QrImageView(data: _address!, size: 220),
                          ),
                          const SizedBox(height: 12),
                          SelectableText(_address!),
                          const SizedBox(height: 12),
                          const Text(
                            'Local network only. The page stops when you leave this screen.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
          ),
        ),
      ],
    );
  }
}
