import 'package:flutter/material.dart';
import 'package:topal_iptv/backend/settings_service.dart';

class WhatsNewModal extends StatelessWidget {
  final String version;
  const WhatsNewModal({super.key, required this.version});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("What's new: update $version"),
      actions: [
        TextButton(
          onPressed: () async {
            await SettingsService.updateLastSeenVersion();
            Navigator.pop(context, true);
          },
          child: const Text("Don't show again"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Close"),
        ),
      ],
      content: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Text('''
Here's what's new in Topal IPTV $version:

- Improved UI
- Fixed Xtream importing bugs
- Improved Android TV support
'''),
          ),
        ),
      ),
    );
  }
}
