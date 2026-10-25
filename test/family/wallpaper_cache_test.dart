import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flauncher/family/photo_source.dart';
import 'package:flauncher/family/wallpaper_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('wallpaper_cache_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  File write(String name, int bytes, DateTime modified) {
    final f = File('${dir.path}/$name')..writeAsBytesSync(Uint8List(bytes));
    f.setLastModifiedSync(modified);
    return f;
  }

  test('cache never stays above the cap: oldest files are deleted first', () {
    final now = DateTime.now();
    write('old', 400, now.subtract(const Duration(minutes: 3)));
    write('mid', 400, now.subtract(const Duration(minutes: 2)));
    write('new', 400, now.subtract(const Duration(minutes: 1)));

    final removed = enforceCacheCap(dir, 1000);

    expect(removed, 1);
    expect(cacheSizeBytes(dir), lessThanOrEqualTo(1000));
    expect(File('${dir.path}/old').existsSync(), isFalse);
    expect(File('${dir.path}/new').existsSync(), isTrue);
  });

  test('the wallpaper on screen is never deleted, even if it is the oldest', () {
    final now = DateTime.now();
    final current = write('current', 600, now.subtract(const Duration(minutes: 9)));
    write('a', 600, now.subtract(const Duration(minutes: 2)));
    write('b', 600, now.subtract(const Duration(minutes: 1)));

    enforceCacheCap(dir, 1000, keep: {current.path});

    expect(current.existsSync(), isTrue);
    expect(cacheSizeBytes(dir), lessThanOrEqualTo(1200));
  });

  test('a cap larger than the content deletes nothing', () {
    write('a', 100, DateTime.now());
    expect(enforceCacheCap(dir, 1000), 0);
  });

  test('a missing directory is fine', () {
    expect(cacheSizeBytes(Directory('${dir.path}/nope')), 0);
    expect(enforceCacheCap(Directory('${dir.path}/nope'), 10), 0);
  });

  testWidgets('a small photo is centred at its original size on a 1080p canvas, not upscaled', (tester) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(0, 0, 640, 360), ui.Paint()..color = const ui.Color(0xFFFF0000));
      final small = await recorder.endRecording().toImage(640, 360);
      final png = (await small.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();

      final (bytes, ext) = await padSmallPhoto(png);
      final codec = await ui.instantiateImageCodec(bytes);
      final result = (await codec.getNextFrame()).image;

      expect(ext, 'png');
      expect(result.width, PhotoWallpaper.screenWidth);
      expect(result.height, PhotoWallpaper.screenHeight);
    });
  });

  testWidgets('a photo that already fills the screen is returned untouched', (tester) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(0, 0, 1920, 1080), ui.Paint()..color = const ui.Color(0xFF00FF00));
      final big = await recorder.endRecording().toImage(1920, 1080);
      final png = (await big.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();

      final (bytes, ext) = await padSmallPhoto(png);

      expect(ext, 'jpg');
      expect(bytes, png);
    });
  });
}
