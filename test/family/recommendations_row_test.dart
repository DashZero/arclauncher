import 'package:flauncher/family/family_settings.dart';
import 'package:flauncher/family/recommendation_models.dart';
import 'package:flauncher/family/ui/recommendations_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:provider/provider.dart';

class FakeRecommendationFeed extends ChangeNotifier
    implements RecommendationFeed {
  List<Recommendation> _items = [];
  bool _isRefreshing = false;
  final List<({Recommendation item, bool up})> thumbs = [];
  int refreshCount = 0;

  @override
  List<Recommendation> get items => _items;
  set items(List<Recommendation> val) {
    _items = val;
    notifyListeners();
  }

  @override
  bool get isRefreshing => _isRefreshing;
  set isRefreshing(bool val) {
    _isRefreshing = val;
    notifyListeners();
  }

  @override
  Future<void> refresh() async {
    refreshCount++;
  }

  @override
  Future<void> thumb(Recommendation item, bool up) async {
    thumbs.add((item: item, up: up));
  }
}

Recommendation createTestItem({
  required String key,
  required String title,
  required Person person,
  int? year = 2024,
  String reason = 'Because you like fantasy',
  List<String> providers = const ['Netflix'],
}) {
  return Recommendation(
    key: key,
    title: title,
    year: year,
    type: 'tv',
    person: person,
    reason: reason,
    posterUrl: 'https://example.com/poster.jpg',
    backdropUrl: 'https://example.com/backdrop.jpg',
    overview: 'A test overview',
    rating: 8.5,
    providers: providers,
  );
}

Widget createTestApp(RecommendationFeed feed) {
  return ChangeNotifierProvider<RecommendationFeed>.value(
    value: feed,
    child: const MaterialApp(home: Scaffold(body: RecommendationsRow())),
  );
}

void main() {
  testWidgets('(a) three items render their titles and badges', (tester) async {
    await mockNetworkImagesFor(() async {
      final feed = FakeRecommendationFeed();
      feed.items = [
        createTestItem(key: '1', title: 'Anime Show', person: Person.dad),
        createTestItem(key: '2', title: 'K-Drama Romance', person: Person.mom),
        createTestItem(key: '3', title: 'Kid Adventure', person: Person.kid),
      ];

      await tester.pumpWidget(createTestApp(feed));
      await tester.pumpAndSettle();

      expect(find.text('Anime Show (2024)'), findsOneWidget);
      expect(find.text('K-Drama Romance (2024)'), findsOneWidget);
      expect(find.text('Kid Adventure (2024)'), findsOneWidget);

      expect(find.text('Dad'), findsOneWidget);
      expect(find.text('Mom'), findsOneWidget);
      expect(find.text('Kid'), findsOneWidget);
    });
  });

  testWidgets('(b) empty list shows "No recommendations yet"', (tester) async {
    await mockNetworkImagesFor(() async {
      final feed = FakeRecommendationFeed();
      feed.items = [];

      await tester.pumpWidget(createTestApp(feed));
      await tester.pumpAndSettle();

      expect(find.text('No recommendations yet'), findsOneWidget);
    });
  });

  testWidgets(
    '(c) selecting a card opens the detail dialog and no platform channel is called',
    (tester) async {
      await mockNetworkImagesFor(() async {
        final feed = FakeRecommendationFeed();
        final item = createTestItem(
          key: '1',
          title: 'Anime Show',
          person: Person.dad,
        );
        feed.items = [item];

        int channelCallCount = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/url_launcher'),
              (call) async {
                channelCallCount++;
                return null;
              },
            );

        await tester.pumpWidget(createTestApp(feed));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Anime Show (2024)'));
        await tester.pumpAndSettle();

        expect(find.byType(Dialog), findsOneWidget);
        expect(find.text('A test overview'), findsOneWidget);
        expect(channelCallCount, 0);
      });
    },
  );

  testWidgets('(d) tapping "Like" calls thumb(item, true) once', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      final feed = FakeRecommendationFeed();
      final item = createTestItem(
        key: '1',
        title: 'Anime Show',
        person: Person.dad,
      );
      feed.items = [item];

      await tester.pumpWidget(createTestApp(feed));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Anime Show (2024)'));
      await tester.pumpAndSettle();

      expect(find.text('Like'), findsOneWidget);
      await tester.tap(find.text('Like'));
      await tester.pumpAndSettle();

      expect(feed.thumbs.length, 1);
      expect(feed.thumbs.first.item.key, '1');
      expect(feed.thumbs.first.up, isTrue);
      expect(find.byType(Dialog), findsNothing);
    });
  });
}
