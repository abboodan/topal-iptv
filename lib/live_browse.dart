import 'package:flutter/material.dart';
import 'package:topal_iptv/models/mobile_section.dart';
import 'package:topal_iptv/models/view_type.dart';

class LiveBrowseMode {
  final String title;
  final String description;
  final String actionLabel;
  final IconData icon;
  final IconData actionIcon;
  final ViewType actionViewType;

  const LiveBrowseMode({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.icon,
    required this.actionIcon,
    required this.actionViewType,
  });
}

class LiveEmptyAction {
  final String label;
  final ViewType viewType;

  const LiveEmptyAction({required this.label, required this.viewType});
}

bool shouldShowLiveBrowseHeader({
  required MobileSection section,
  required bool globalSearch,
  required bool insideNode,
}) {
  return section == MobileSection.live && !globalSearch && !insideNode;
}

bool shouldShowLiveEpgChip({
  required MobileSection section,
  required bool globalSearch,
}) {
  return section == MobileSection.live && !globalSearch;
}

LiveBrowseMode liveBrowseModeFor({
  required ViewType viewType,
  required bool hasQuery,
}) {
  if (hasQuery) {
    return const LiveBrowseMode(
      title: 'Live search',
      description: 'Matching live channels from enabled sources.',
      actionLabel: 'Categories',
      icon: Icons.search,
      actionIcon: Icons.dashboard,
      actionViewType: ViewType.categories,
    );
  }

  switch (viewType) {
    case ViewType.categories:
      return const LiveBrowseMode(
        title: 'Live TV',
        description: 'Browse categories or jump straight into every channel.',
        actionLabel: 'All channels',
        icon: Icons.live_tv,
        actionIcon: Icons.list,
        actionViewType: ViewType.all,
      );
    case ViewType.all:
      return const LiveBrowseMode(
        title: 'All channels',
        description: 'Dense live rows built for fast scanning and playback.',
        actionLabel: 'Categories',
        icon: Icons.list,
        actionIcon: Icons.dashboard,
        actionViewType: ViewType.categories,
      );
    case ViewType.favorites:
      return const LiveBrowseMode(
        title: 'Favorite channels',
        description: 'Your saved live channels stay one tap away.',
        actionLabel: 'Categories',
        icon: Icons.star,
        actionIcon: Icons.dashboard,
        actionViewType: ViewType.categories,
      );
    case ViewType.history:
      return const LiveBrowseMode(
        title: 'Recent channels',
        description: 'Recently watched live channels appear first.',
        actionLabel: 'Categories',
        icon: Icons.history,
        actionIcon: Icons.dashboard,
        actionViewType: ViewType.categories,
      );
    case ViewType.epg:
      return const LiveBrowseMode(
        title: 'Live EPG',
        description: 'Now and next programs for loaded live channels.',
        actionLabel: 'All channels',
        icon: Icons.event_note,
        actionIcon: Icons.list,
        actionViewType: ViewType.all,
      );
    case ViewType.settings:
      return const LiveBrowseMode(
        title: 'Live TV',
        description: 'Browse live channels from enabled sources.',
        actionLabel: 'Categories',
        icon: Icons.live_tv,
        actionIcon: Icons.dashboard,
        actionViewType: ViewType.categories,
      );
  }
}

LiveEmptyAction? liveEmptyActionFor({
  required MobileSection section,
  required ViewType viewType,
  required bool globalSearch,
}) {
  if (section == MobileSection.live &&
      viewType == ViewType.favorites &&
      !globalSearch) {
    return const LiveEmptyAction(
      label: 'Browse live channels',
      viewType: ViewType.categories,
    );
  }
  return null;
}

class LiveBrowseHeader extends StatelessWidget {
  final LiveBrowseMode mode;
  final ValueChanged<ViewType> onActionSelected;

  const LiveBrowseHeader({
    super.key,
    required this.mode,
    required this.onActionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(mode.icon, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    mode.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              mode.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: OutlinedButton.icon(
                onPressed: () => onActionSelected(mode.actionViewType),
                icon: Icon(mode.actionIcon),
                label: Text(mode.actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BrowseEmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const BrowseEmptyState({
    super.key,
    required this.message,
    this.icon = Icons.search_off,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.dashboard),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class BrowseLoadingFooter extends StatelessWidget {
  const BrowseLoadingFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              const SizedBox(width: 10),
              Text(
                'Loading more',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
