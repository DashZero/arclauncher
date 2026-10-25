import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flauncher/family/family_settings.dart';

/// Tiny local web server so the owner can paste keys and the album link from a
/// phone. It runs only while the setup settings page is open, is reachable on the
/// home Wi-Fi only, and every request must carry a random token from the QR code.
/// Saved keys are never sent back to the browser.
class SetupServer {
  final FamilySettings _settings;
  HttpServer? _server;
  String? _token;
  String? _address;

  static const int _maxBody = 16 * 1024;

  final Future<String?> Function() _ipProvider;

  SetupServer(this._settings, {Future<String?> Function()? ipProvider}) : _ipProvider = ipProvider ?? _localIp;

  bool get isRunning => _server != null;

  /// Address to put in the QR code, e.g. http://192.168.1.20:8080/ab12cd34, or null when not running.
  String? get address => _address;

  Future<String?> start() async {
    if (_server != null) return _address;
    final ip = await _ipProvider();
    if (ip == null) return null;

    _token = _randomToken();
    HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
    } on SocketException {
      server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    }
    _server = server;
    _address = 'http://$ip:${server.port}/$_token';
    unawaited(_serve(server));
    return _address;
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _address = null;
    _token = null;
    await server?.close(force: true);
  }

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      try {
        await _handle(request);
      } catch (_) {
        try {
          request.response.statusCode = HttpStatus.internalServerError;
          await request.response.close();
        } catch (_) {}
      }
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final segments = request.uri.pathSegments;
    if (segments.isEmpty || segments.first != _token) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    if (request.method == 'POST' && segments.length == 2 && segments[1] == 'save') {
      final body = await _readBody(request);
      if (body == null) {
        request.response.statusCode = HttpStatus.requestEntityTooLarge;
        await request.response.close();
        return;
      }
      await _settings.applySetup(Uri.splitQueryString(body));
      await _send(request, _page('Saved. You can close this page.'));
      return;
    }

    if (request.method == 'GET' && segments.length == 1) {
      await _send(request, _page(null));
      return;
    }

    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  }

  Future<String?> _readBody(HttpRequest request) async {
    final bytes = <int>[];
    await for (final chunk in request) {
      bytes.addAll(chunk);
      if (bytes.length > _maxBody) return null;
    }
    return utf8.decode(bytes);
  }

  Future<void> _send(HttpRequest request, String html) async {
    request.response
      ..headers.contentType = ContentType.html
      ..headers.set('Cache-Control', 'no-store')
      ..write(html);
    await request.response.close();
  }

  String _status(String value) => value.isEmpty ? 'not set' : 'set';

  String _page(String? notice) => '''<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>TV launcher setup</title>
<style>body{font-family:sans-serif;max-width:480px;margin:1em auto;padding:0 1em}
label{display:block;margin-top:1em;font-weight:600}input{width:100%;padding:.6em;box-sizing:border-box}
button{margin-top:1.5em;padding:.8em 1.5em}small{color:#666;font-weight:400}</style></head><body>
<h2>TV launcher setup</h2>
${notice == null ? '<p><small>Home Wi-Fi only. Leave a field empty to keep its current value.</small></p>' : '<p><b>$notice</b></p>'}
<form method="post" action="/$_token/save">
<label>Google Photos album link <small>(${_status(_settings.albumUrl)})</small></label><input name="album" type="url">
<label>Gemini API key <small>(${_status(_settings.geminiKey)})</small></label><input name="gemini_key" type="password" autocomplete="off">
<label>Gemini model <small>(current: ${const HtmlEscape().convert(_settings.geminiModel)})</small></label><input name="gemini_model">
<label>TMDB API key <small>(${_status(_settings.tmdbKey)})</small></label><input name="tmdb_key" type="password" autocomplete="off">
<button type="submit">Save</button></form></body></html>''';

  static String _randomToken() {
    final rnd = Random.secure();
    return List.generate(16, (_) => rnd.nextInt(16).toRadixString(16)).join();
  }

  static Future<String?> _localIp() async {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
    for (final i in interfaces) {
      for (final a in i.addresses) {
        if (!a.isLoopback) return a.address;
      }
    }
    return null;
  }
}
