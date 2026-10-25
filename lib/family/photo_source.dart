import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flauncher/family/wallpaper_cache.dart';
import 'package:http/http.dart' as http;

/// Where family photos come from. The UI only knows this interface, so the
/// source can later be swapped (Drive, OneDrive) without touching it.
abstract class PhotoSource {
  /// Base URLs of the photos, without size suffixes.
  Future<List<String>> listPhotos();

  /// URL that serves [photo] at most [maxWidth] x [maxHeight].
  String urlFor(String photo, {int maxWidth = 3840, int maxHeight = 2160});
}

/// Reads a Google Photos shared album page. Google serves only about 25 photos
/// in the page itself and the rest lazy-load through unofficial endpoints that
/// can change, so this reads what the page contains and returns an empty list
/// if the format changes. It does not use the official Library API.
class GooglePhotosAlbumSource implements PhotoSource {
  final String albumUrl;
  final http.Client _client;

  GooglePhotosAlbumSource(this.albumUrl, {http.Client? client}) : _client = client ?? http.Client();

  static final _photoUrl = RegExp(r'https://lh3\.googleusercontent\.com/pw/[A-Za-z0-9_\-]{20,}');

  @override
  Future<List<String>> listPhotos() async {
    final uri = Uri.tryParse(albumUrl.trim());
    if (uri == null || !uri.hasScheme) return const [];
    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return const [];
      return _photoUrl.allMatches(response.body).map((m) => m.group(0)!).toSet().toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  String urlFor(String photo, {int maxWidth = 3840, int maxHeight = 2160}) => '$photo=w$maxWidth-h$maxHeight';
}

/// Photo wallpaper: random order, shown at original size and never upscaled.
class PhotoWallpaper {
  static const int screenWidth = 1920;
  static const int screenHeight = 1080;

  final Directory cacheDir;
  final PhotoSource source;
  final http.Client _client;
  List<String> _photos = [];

  PhotoWallpaper(this.cacheDir, this.source, {http.Client? client}) : _client = client ?? http.Client();

  Future<File?> next({required int capMb, Set<String> keep = const {}, Random? random}) async {
    final rnd = random ?? Random();
    if (_photos.isEmpty) _photos = await source.listPhotos();
    if (_photos.isEmpty) return null;

    final photo = _photos[rnd.nextInt(_photos.length)];
    try {
      final response = await _client.get(Uri.parse(source.urlFor(photo))).timeout(const Duration(seconds: 60));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) return null;

      final bytes = await padSmallPhoto(response.bodyBytes);
      await cacheDir.create(recursive: true);
      final file = File('${cacheDir.path}/${photo.hashCode.toRadixString(16)}.${bytes.$2}');
      await file.writeAsBytes(bytes.$1, flush: true);
      enforceCacheCap(cacheDir, capMb * 1024 * 1024, keep: {...keep, file.path});
      return file;
    } catch (_) {
      return null;
    }
  }
}

/// A photo already at least screen size is kept as it is (never upscaled, at
/// most 4K by the URL suffix). A smaller photo is centred at its original size
/// on a stretched, darkened copy of itself, so it is not blown up to fill the screen.
/// Returns the encoded bytes and the file extension.
Future<(Uint8List, String)> padSmallPhoto(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final w = image.width, h = image.height;
  if (w >= PhotoWallpaper.screenWidth && h >= PhotoWallpaper.screenHeight) {
    image.dispose();
    return (bytes, 'jpg');
  }

  const sw = PhotoWallpaper.screenWidth, sh = PhotoWallpaper.screenHeight;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, sw.toDouble(), sh.toDouble()));
  final src = ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());

  // Fill: the same photo scaled to cover the screen, blurred and darkened.
  final scale = max(sw / w, sh / h);
  final cover = ui.Rect.fromCenter(
      center: ui.Offset(sw / 2, sh / 2), width: w * scale, height: h * scale);
  canvas.drawImageRect(
    image,
    src,
    cover,
    ui.Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
  );
  canvas.drawRect(ui.Rect.fromLTWH(0, 0, sw.toDouble(), sh.toDouble()), ui.Paint()..color = const ui.Color(0x66000000));

  // The photo itself at original size, centred.
  final dst = ui.Rect.fromCenter(center: ui.Offset(sw / 2, sh / 2), width: w.toDouble(), height: h.toDouble());
  canvas.drawImageRect(image, src, dst, ui.Paint());

  final composed = await recorder.endRecording().toImage(sw, sh);
  final data = await composed.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  composed.dispose();
  return (data!.buffer.asUint8List(), 'png');
}
