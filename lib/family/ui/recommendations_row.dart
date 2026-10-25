import 'dart:async';

import 'package:flauncher/family/family_settings.dart';
import 'package:flauncher/family/recommendation_models.dart';
import 'package:flauncher/family/ui/recommendation_detail_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const double _kCardWidth = 160.0;
const double _kCardHeight = 290.0;
const double _kCardSpacing = 16.0;
const double _kItemExtent = _kCardWidth + _kCardSpacing;
const double _kPosterHeight = 190.0;

/// The "Recommended for you" row of info cards on the home screen.
///
/// Features D-pad navigation, idle auto-scrolling through person groups,
/// and smooth image rendering with hard memory caps.
class RecommendationsRow extends StatefulWidget {
  const RecommendationsRow({super.key});

  @override
  State<RecommendationsRow> createState() => _RecommendationsRowState();
}

class _RecommendationsRowState extends State<RecommendationsRow> {
  final ScrollController _scrollController = ScrollController();
  final FocusScopeNode _rowFocusScope = FocusScopeNode();

  Timer? _autoScrollTimer;
  Timer? _resumeTimer;
  int _currentGroupIndex = 0;
  bool _rowHasFocus = false;

  @override
  void initState() {
    super.initState();
    _rowFocusScope.addListener(_handleFocusChange);
    _startAutoScroll();
  }

  void _handleFocusChange() {
    final hasFocus = _rowFocusScope.hasFocus;
    if (_rowHasFocus == hasFocus) return;
    _rowHasFocus = hasFocus;

    if (hasFocus) {
      _stopAutoScroll();
    } else {
      _resumeTimer?.cancel();
      _resumeTimer = Timer(const Duration(seconds: 20), () {
        if (mounted && !_rowHasFocus) {
          _startAutoScroll();
        }
      });
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _scrollToNextGroup();
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _resumeTimer?.cancel();
    _resumeTimer = null;
  }

  void _scrollToNextGroup() {
    if (!mounted || !_scrollController.hasClients || _rowHasFocus) return;

    final feed = context.read<RecommendationFeed>();
    final items = feed.items;
    if (items.isEmpty) return;

    final groupIndices = <int>[];
    Person? lastPerson;
    for (int i = 0; i < items.length; i++) {
      if (items[i].person != lastPerson) {
        groupIndices.add(i);
        lastPerson = items[i].person;
      }
    }

    if (groupIndices.length <= 1) return;

    _currentGroupIndex = (_currentGroupIndex + 1) % groupIndices.length;
    final targetIndex = groupIndices[_currentGroupIndex];
    final targetOffset = targetIndex * _kItemExtent;

    final maxScroll = _scrollController.position.maxScrollExtent;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, maxScroll),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _rowFocusScope.removeListener(_handleFocusChange);
    _rowFocusScope.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<RecommendationFeed>();
    final items = feed.items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(context, feed),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Text(
              'No recommendations yet',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          )
        else
          SizedBox(
            height: _kCardHeight,
            child: FocusScope(
              node: _rowFocusScope,
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemExtent: _kItemExtent,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: _kCardSpacing),
                    child: _RecommendationCard(
                      item: item,
                      onSelected: () =>
                          showRecommendationDetail(context, item, feed),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, RecommendationFeed feed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Recommended for you',
            style:
                Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ) ??
                const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
          ),
          OutlinedButton(
            onPressed: feed.isRefreshing ? null : () => feed.refresh(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 13),
            ),
            child: Text(feed.isRefreshing ? 'Refreshing...' : 'Refresh'),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatefulWidget {
  final Recommendation item;
  final VoidCallback onSelected;

  const _RecommendationCard({required this.item, required this.onSelected});

  @override
  State<_RecommendationCard> createState() => _RecommendationCardState();
}

class _RecommendationCardState extends State<_RecommendationCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final providersText = item.providers.isNotEmpty
        ? item.providers.join(', ')
        : 'Not listed';

    return FocusableActionDetector(
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (intent) {
            widget.onSelected();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: widget.onSelected,
        child: Container(
          width: _kCardWidth,
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F23),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _focused ? primaryColor : Colors.white12,
              width: _focused ? 2.5 : 1.0,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: _kPosterHeight,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (item.posterUrl != null && item.posterUrl!.isNotEmpty)
                      Image.network(
                        item.posterUrl!,
                        cacheWidth: 300,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildPosterPlaceholder(),
                      )
                    else
                      _buildPosterPlaceholder(),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xBF000000),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white24, width: 0.5),
                        ),
                        child: Text(
                          item.person.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.year != null
                            ? '${item.title} (${item.year})'
                            : item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        providersText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Text(
                          item.reason,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPosterPlaceholder() {
    return Container(
      color: const Color(0xFF2B2B30),
      child: const Center(
        child: Icon(Icons.movie_outlined, color: Colors.white24, size: 36),
      ),
    );
  }
}
