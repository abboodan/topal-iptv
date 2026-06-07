import 'package:flutter/material.dart';
import 'package:topal_iptv/models/mobile_section.dart';

class MobileShellNav extends StatelessWidget {
  final MobileSection selectedSection;
  final ValueChanged<MobileSection> onSectionSelected;
  final VoidCallback onSettingsSelected;
  final bool blockSettings;

  const MobileShellNav({
    super.key,
    required this.selectedSection,
    required this.onSectionSelected,
    required this.onSettingsSelected,
    this.blockSettings = false,
  });

  static const List<MobileSection> _sections = [
    MobileSection.live,
    MobileSection.movies,
    MobileSection.series,
    MobileSection.settings,
  ];

  int get _selectedIndex {
    final index = _sections.indexOf(selectedSection);
    return index == -1 ? 0 : index;
  }

  void _select(BuildContext context, int index) {
    final section = _sections[index];
    if (section == MobileSection.settings) {
      if (blockSettings) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings disabled while refreshing on start'),
          ),
        );
        return;
      }
      onSettingsSelected();
      return;
    }
    onSectionSelected(section);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceBright,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.surfaceBright,
            width: 1,
          ),
        ),
      ),
      child: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => _select(context, index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.live_tv), label: 'Live'),
          NavigationDestination(
            icon: Icon(Icons.local_movies),
            label: 'Movies',
          ),
          NavigationDestination(
            icon: Icon(Icons.video_library),
            label: 'Series',
          ),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
