import 'dart:async';

import 'package:flutter/material.dart';
import 'package:topal_iptv/backend/settings_service.dart';
import 'package:topal_iptv/backend/epg_service.dart';
import 'package:topal_iptv/backend/sql.dart';
import 'package:topal_iptv/backend/utils.dart';
import 'package:topal_iptv/channel_widget_key.dart';
import 'package:topal_iptv/channel_variant_picker.dart';
import 'package:topal_iptv/channel_tile.dart';
import 'package:topal_iptv/loading.dart';
import 'package:topal_iptv/load_request_guard.dart';
import 'package:topal_iptv/live_browse.dart';
import 'package:topal_iptv/live_epg.dart';
import 'package:topal_iptv/models/browse_layout.dart';
import 'package:topal_iptv/models/channel.dart';
import 'package:topal_iptv/models/epg_program.dart';
import 'package:topal_iptv/models/filters.dart';
import 'package:topal_iptv/models/home_manager.dart';
import 'package:topal_iptv/models/media_type.dart';
import 'package:topal_iptv/models/mobile_section.dart';
import 'package:topal_iptv/models/no_push_animation_material_page_route.dart';
import 'package:topal_iptv/models/node.dart';
import 'package:topal_iptv/models/node_type.dart';
import 'package:topal_iptv/models/view_type.dart';
import 'package:topal_iptv/mobile_shell_nav.dart';
import 'package:topal_iptv/error.dart';
import 'package:topal_iptv/player_controls/live_channel_context.dart';
import 'package:topal_iptv/player.dart';
import 'package:topal_iptv/settings_view.dart';
import 'package:topal_iptv/whats_new_modal.dart';

class Home extends StatefulWidget {
  final HomeManager home;
  final bool refresh;
  final bool firstLaunch;
  final bool hasTouchScreen;
  final MobileSection? mobileSection;
  final bool globalSearch;
  const Home({
    super.key,
    required this.home,
    this.refresh = false,
    this.firstLaunch = false,
    this.hasTouchScreen = true,
    this.mobileSection,
    this.globalSearch = false,
  });
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  Timer? _debounce;
  bool reachedMax = false;
  final int pageSize = 36;
  List<Channel> channels = [];
  TextEditingController searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final LoadRequestGuard _loadGuard = LoadRequestGuard();
  bool isLoading = false;
  bool hasLoaded = false;
  bool blockSettings = false;
  int? previousScroll;
  bool scrolledDeepEnough = false;
  MobileSection _mobileSection = MobileSection.live;
  bool _globalSearch = false;
  bool epgLoading = false;
  Map<int, EpgNowNext> epgPrograms = {};
  Set<int> epgResolvedChannelIds = {};
  List<MediaType> _enabledMediaTypes = [
    MediaType.livestream,
    MediaType.movie,
    MediaType.serie,
  ];

  @override
  void initState() {
    super.initState();
    _mobileSection =
        widget.mobileSection ??
        mobileSectionFromMediaTypes(widget.home.filters.mediaTypes);
    _globalSearch = widget.globalSearch;
    _scrollController.addListener(_scrollListener);
    initializeAsync();
  }

  Future<void> initializeAsync() async {
    final settings = await SettingsService.getSettings();
    _enabledMediaTypes = settings.getMediaTypes();
    if (widget.home.filters.sourceIds == null) {
      final sources = await Sql.getEnabledSourcesMinimal();
      widget.home.filters.sourceIds = sources.map((x) => x.id).toList();
    }
    if (widget.home.filters.mediaTypes == null) {
      _mobileSection = widget.mobileSection == null
          ? firstEnabledMobileSection(_enabledMediaTypes)
          : _mobileSection;
      widget.home.filters.mediaTypes = _globalSearch
          ? _enabledMediaTypes
          : _mobileSection.mediaTypes;
    }
    await load();
    final String? version = await SettingsService.shouldShowWhatsNew();
    if (widget.firstLaunch && version != null) {
      await showWhatsNew(version);
    }
    if (widget.refresh) {
      Error.tryAsyncNoLoading(
        () async {
          setState(() {
            blockSettings = true;
          });
          await Utils.refreshAllSources();
        },
        context,
        true,
        "Refreshed all sources",
      );
      setState(() {
        blockSettings = false;
      });
    }
  }

  Future<void> showWhatsNew(String version) async {
    showDialog(
      context: context,
      builder: (context) => WhatsNewModal(version: version),
    );
  }

  void scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Future<void> load([bool more = false]) async {
    final bool loadingMore = more;
    if (loadingMore && !_loadGuard.tryBeginLoadMore()) return;
    final requestId = _loadGuard.begin();
    final targetPage = loadingMore ? widget.home.filters.page + 1 : 1;
    final requestFilters = copyFilters(widget.home.filters, page: targetPage);
    try {
      await Error.tryAsyncNoLoading(() async {
        List<Channel> channels = await Sql.search(requestFilters);
        if (!_loadGuard.isCurrent(requestId) || !mounted) return;
        if (!loadingMore) {
          setState(() {
            widget.home.filters.page = targetPage;
            this.channels = channels;
            hasLoaded = true;
            reachedMax = channels.length < pageSize;
            if (isLiveEpgView) {
              epgPrograms = {};
              epgResolvedChannelIds = {};
            }
          });
        } else {
          setState(() {
            widget.home.filters.page = targetPage;
            this.channels.addAll(channels);
            reachedMax = channels.length < pageSize;
          });
        }
      }, context);
    } finally {
      if (loadingMore) _loadGuard.endLoadMore();
    }
    if (isLiveEpgView) {
      unawaited(loadEpgForLoadedChannels());
    }
  }

  Filters copyFilters(Filters filters, {required int page}) {
    return Filters(
      query: filters.query,
      sourceIds: filters.sourceIds == null ? null : List.of(filters.sourceIds!),
      mediaTypes: filters.mediaTypes == null
          ? null
          : List.of(filters.mediaTypes!),
      viewType: filters.viewType,
      page: page,
      seriesId: filters.seriesId,
      groupId: filters.groupId,
      useKeywords: filters.useKeywords,
    );
  }

  bool get isLiveEpgView {
    return _mobileSection == MobileSection.live &&
        !_globalSearch &&
        getSecondaryView() == ViewType.epg;
  }

  Future<void> loadEpgForLoadedChannels() async {
    if (epgLoading || !isLiveEpgView || channels.isEmpty) return;
    final loadedChannels = List<Channel>.from(channels);
    final loadedChannelIds = loadedChannels
        .map((channel) => channel.id)
        .nonNulls
        .toSet();
    setState(() => epgLoading = true);
    Map<int, EpgNowNext>? nowNext;
    try {
      await refreshEpgForChannels(loadedChannels);
      nowNext = await Sql.getNowNextEpgForChannels(loadedChannels);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      if (nowNext != null) {
        epgPrograms = {...epgPrograms, ...nowNext};
        epgResolvedChannelIds = {...epgResolvedChannelIds, ...loadedChannelIds};
      }
      epgLoading = false;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _scrollListener() async {
    final bool shouldShow = _scrollController.offset > 200;

    if (scrolledDeepEnough != shouldShow) {
      setState(() => scrolledDeepEnough = shouldShow);
    }

    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.75 &&
        !isLoading &&
        !reachedMax) {
      setState(() {
        isLoading = true;
      });
      await load(true);
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  void clearSearch() {
    widget.home.filters.query = null;
    searchController.clear();
  }

  ViewType getSecondaryView() {
    if (widget.home.filters.groupId != null) {
      return ViewType.categories;
    }
    return widget.home.filters.viewType;
  }

  void updateSecondaryView(ViewType type) {
    Navigator.of(context).pushAndRemoveUntil(
      NoPushAnimationMaterialPageRoute(
        builder: (context) => Home(
          home: HomeManager(
            filters: Filters(
              viewType: type,
              mediaTypes: _mobileSection.mediaTypes,
              sourceIds: widget.home.filters.sourceIds,
            ),
          ),
          mobileSection: _mobileSection,
          globalSearch: false,
        ),
      ),
      (route) => false,
    );
  }

  void updateGlobalSearch() {
    Navigator.of(context).pushAndRemoveUntil(
      NoPushAnimationMaterialPageRoute(
        builder: (context) => Home(
          home: HomeManager(
            filters: Filters(
              viewType: ViewType.all,
              mediaTypes: _enabledMediaTypes,
              sourceIds: widget.home.filters.sourceIds,
            ),
          ),
          mobileSection: _mobileSection,
          globalSearch: true,
        ),
      ),
      (route) => false,
    );
  }

  void updateMobileSection(MobileSection section) {
    Navigator.of(context).pushAndRemoveUntil(
      NoPushAnimationMaterialPageRoute(
        builder: (context) => Home(
          home: HomeManager(
            filters: Filters(
              viewType: ViewType.categories,
              mediaTypes: section.mediaTypes,
              sourceIds: widget.home.filters.sourceIds,
            ),
          ),
          mobileSection: section,
          globalSearch: false,
        ),
      ),
      (route) => false,
    );
  }

  void openSettings() {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const SettingsView(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            child,
      ),
      (route) => false,
    );
  }

  void setNode(Node node) {
    final home = HomeManager(
      node: node,
      filters: Filters(
        viewType: ViewType.all,
        mediaTypes: widget.home.filters.mediaTypes,
        sourceIds: widget.home.filters.sourceIds,
      ),
    );
    if (widget.home.filters.groupId != null) {
      home.filters.groupId = widget.home.filters.groupId;
    } else if (node.type == NodeType.category) {
      home.filters.groupId = node.id;
    }
    if (node.type == NodeType.series) home.filters.seriesId = node.id;
    Navigator.of(context).push(
      NoPushAnimationMaterialPageRoute(
        builder: (context) => Home(
          home: home,
          mobileSection: _mobileSection,
          globalSearch: _globalSearch,
        ),
      ),
    );
  }

  Future<void> playLiveChannel(
    Channel channel,
    LiveChannelContext liveContext,
  ) async {
    await Error.tryAsyncNoLoading(() async {
      final selectedChannel = await chooseChannelVariant(context, channel);
      if (!mounted || selectedChannel == null) return;
      final settings = await SettingsService.getSettings();
      if (selectedChannel.id != null) {
        await Sql.addToHistory(selectedChannel.id!);
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Player(
            channel: selectedChannel,
            settings: settings,
            liveContext: liveContext,
          ),
        ),
      );
    }, context);
  }

  Widget secondaryFilterChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          if (!selected) onSelected();
        },
      ),
    );
  }

  String get searchHint {
    return _globalSearch
        ? 'Search all media...'
        : 'Search ${_mobileSection.label}...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.home.node != null
          ? AppBar(
              title: Text(widget.home.node.toString()),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
            )
          : null,
      body: Loading(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double width = constraints.maxWidth;
              final secondaryView = getSecondaryView();
              final hasQuery =
                  widget.home.filters.query?.trim().isNotEmpty == true;
              final browseLayout = BrowseLayout.forState(
                section: _mobileSection,
                viewType: secondaryView,
                hasQuery: hasQuery,
                globalSearch: _globalSearch,
              );
              final liveEmptyAction = liveEmptyActionFor(
                section: _mobileSection,
                viewType: secondaryView,
                globalSearch: _globalSearch,
              );
              final int crossAxisCount = browseLayout.crossAxisCount(width);
              return CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: TextField(
                              style: TextStyle(
                                fontSize: Theme.of(
                                  context,
                                ).textTheme.titleMedium?.fontSize!,
                              ),
                              controller: searchController,
                              onChanged: (query) {
                                _debounce?.cancel();
                                _debounce = Timer(
                                  const Duration(milliseconds: 500),
                                  () {
                                    widget.home.filters.query = query;
                                    load(false);
                                  },
                                );
                              },
                              decoration: InputDecoration(
                                hintText: searchHint,
                                hintStyle: TextStyle(
                                  fontSize: Theme.of(
                                    context,
                                  ).textTheme.titleMedium?.fontSize!,
                                ),
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    widget.home.filters.useKeywords =
                                        !widget.home.filters.useKeywords;
                                    load(false);
                                  },
                                  icon: Icon(
                                    widget.home.filters.useKeywords
                                        ? Icons.label
                                        : Icons.label_outline,
                                  ),
                                ),
                                filled: true,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                secondaryFilterChip(
                                  label: 'Browse',
                                  icon: Icons.dashboard,
                                  selected:
                                      !_globalSearch &&
                                      getSecondaryView() == ViewType.categories,
                                  onSelected: () =>
                                      updateSecondaryView(ViewType.categories),
                                ),
                                secondaryFilterChip(
                                  label: 'All',
                                  icon: Icons.list,
                                  selected:
                                      !_globalSearch &&
                                      getSecondaryView() == ViewType.all,
                                  onSelected: () =>
                                      updateSecondaryView(ViewType.all),
                                ),
                                secondaryFilterChip(
                                  label: 'All media',
                                  icon: Icons.manage_search,
                                  selected: _globalSearch,
                                  onSelected: updateGlobalSearch,
                                ),
                                if (shouldShowLiveEpgChip(
                                  section: _mobileSection,
                                  globalSearch: _globalSearch,
                                ))
                                  secondaryFilterChip(
                                    label: 'EPG',
                                    icon: Icons.event_note,
                                    selected:
                                        !_globalSearch &&
                                        getSecondaryView() == ViewType.epg,
                                    onSelected: () =>
                                        updateSecondaryView(ViewType.epg),
                                  ),
                                secondaryFilterChip(
                                  label: 'Favorites',
                                  icon: Icons.star,
                                  selected:
                                      !_globalSearch &&
                                      getSecondaryView() == ViewType.favorites,
                                  onSelected: () =>
                                      updateSecondaryView(ViewType.favorites),
                                ),
                                secondaryFilterChip(
                                  label: 'History',
                                  icon: Icons.history,
                                  selected:
                                      !_globalSearch &&
                                      getSecondaryView() == ViewType.history,
                                  onSelected: () =>
                                      updateSecondaryView(ViewType.history),
                                ),
                              ],
                            ),
                          ),
                          if (shouldShowLiveBrowseHeader(
                            section: _mobileSection,
                            globalSearch: _globalSearch,
                            insideNode: widget.home.node != null,
                          )) ...[
                            const SizedBox(height: 12),
                            LiveBrowseHeader(
                              mode: liveBrowseModeFor(
                                viewType: secondaryView,
                                hasQuery: hasQuery,
                              ),
                              onActionSelected: updateSecondaryView,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (isLiveEpgView)
                    LiveEpgList(
                      channels: channels,
                      nowNextByChannelId: epgPrograms,
                      resolvedChannelIds: epgResolvedChannelIds,
                      loading: epgLoading,
                      onChannelTap: (channel, index) => playLiveChannel(
                        channel,
                        LiveChannelContext(
                          channels: channels,
                          currentIndex: index,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(10, 5, 10, 10),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final channel = channels[index];
                          return ChannelTile(
                            key: channelWidgetKey(channel),
                            channel: channel,
                            parentContext: context,
                            setNode: setNode,
                            layout: browseLayout.tileLayout,
                            showMediaTypeLabel: browseLayout.showMediaTypeLabel,
                            liveContext:
                                browseLayout.tileLayout ==
                                        ChannelTileLayout.live &&
                                    channel.mediaType == MediaType.livestream
                                ? LiveChannelContext(
                                    channels: channels,
                                    currentIndex: index,
                                  )
                                : null,
                          );
                        }, childCount: channels.length),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisExtent: browseLayout.mainAxisExtent,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                      ),
                    ),
                  if (hasLoaded && channels.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: BrowseEmptyState(
                        message: browseLayout.emptyMessage(_mobileSection),
                        actionLabel: liveEmptyAction?.label,
                        onAction: liveEmptyAction == null
                            ? null
                            : () =>
                                  updateSecondaryView(liveEmptyAction.viewType),
                      ),
                    ),
                  if (isLoading && channels.isNotEmpty)
                    const BrowseLoadingFooter(),
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: widget.hasTouchScreen
          ? MobileShellNav(
              selectedSection: _mobileSection,
              blockSettings: blockSettings,
              onSectionSelected: updateMobileSection,
              onSettingsSelected: openSettings,
            )
          : null,
      floatingActionButton: IgnorePointer(
        ignoring: !scrolledDeepEnough,
        child: AnimatedOpacity(
          opacity: scrolledDeepEnough ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: FloatingActionButton(
            onPressed: scrollToTop,
            shape: const CircleBorder(),
            tooltip: 'Scroll to Top',
            child: const Icon(Icons.arrow_upward),
          ),
        ),
      ),
    );
  }
}
