import 'package:flauncher/family/recommendation_models.dart';
import 'package:flutter/material.dart';

/// Displays the details of a recommendation in a dialog.
///
/// Shows backdrop image (if available), title, year, rating, Thailand watch
/// providers, reason, and overview. Provides "Like" and "Not for us" actions
/// which update the user's taste profile via [feed.thumb].
Future<void> showRecommendationDetail(
  BuildContext context,
  Recommendation item,
  RecommendationFeed feed,
) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final primaryColor = Theme.of(dialogContext).colorScheme.primary;
      final providersText = item.providers.isNotEmpty
          ? item.providers.join(', ')
          : 'Not listed';

      return Dialog(
        backgroundColor: const Color(0xFF1E1E22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (item.backdropUrl != null && item.backdropUrl!.isNotEmpty)
                SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: Image.network(
                    item.backdropUrl!,
                    cacheWidth: 1280,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (item.year != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${item.year}',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (item.rating != null) ...[
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              item.rating!.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x33FFFFFF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.person.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Available on: $providersText',
                              style: TextStyle(
                                color: primaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (item.reason.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0x1AFFFFFF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.tips_and_updates_outlined,
                                color: Colors.amber,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.reason,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (item.overview.isNotEmpty) ...[
                        Text(
                          item.overview,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      autofocus: false,
                      onPressed: () {
                        feed.thumb(item, false);
                        Navigator.of(dialogContext).pop();
                      },
                      icon: const Icon(Icons.thumb_down_outlined, size: 16),
                      label: const Text('Not for us'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      autofocus: true,
                      onPressed: () {
                        feed.thumb(item, true);
                        Navigator.of(dialogContext).pop();
                      },
                      icon: const Icon(Icons.thumb_up_outlined, size: 16),
                      label: const Text('Like'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
