import 'dart:convert';
import 'dart:io';

import 'package:flauncher/family/family_settings.dart';
import 'package:flauncher/family/setup_server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late FamilySettings settings;
  late SetupServer server;
  late Uri base;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = FamilySettings(await SharedPreferences.getInstance());
    server = SetupServer(settings, ipProvider: () async => '127.0.0.1');
    final address = await server.start();
    base = Uri.parse(address!);
  });

  tearDown(() => server.stop());

  Future<HttpClientResponse> send(String method, Uri uri, {String? body}) async {
    final client = HttpClient();
    final request = await client.openUrl(method, uri);
    if (body != null) {
      request.headers.contentType = ContentType('application', 'x-www-form-urlencoded');
      request.write(body);
    }
    return request.close();
  }

  test('a wrong token gets 404 and saves nothing', () async {
    final wrong = base.replace(path: '/not-the-token/save');
    final response = await send('POST', wrong, body: 'tmdb_key=stolen');
    await response.drain();
    expect(response.statusCode, 404);
    expect(settings.tmdbKey, isNot('stolen'));
  });

  test('the form saves keys with the right token', () async {
    final response = await send('POST', base.replace(path: '${base.path}/save'),
        body: 'tmdb_key=abc&gemini_key=def&gemini_model=m1&album=https%3A%2F%2Fexample.com%2Fa');
    await response.drain();
    expect(response.statusCode, 200);
    expect(settings.tmdbKey, 'abc');
    expect(settings.geminiKey, 'def');
    expect(settings.geminiModel, 'm1');
    expect(settings.albumUrl, 'https://example.com/a');
  });

  test('the page never shows saved keys back', () async {
    await settings.setGeminiKey('super-secret-key');
    final response = await send('GET', base);
    final html = await utf8.decodeStream(response);
    expect(response.statusCode, 200);
    expect(html, isNot(contains('super-secret-key')));
    expect(html, contains('set'));
  });

  test('stop closes the server', () async {
    await server.stop();
    expect(server.isRunning, isFalse);
    expect(() => send('GET', base), throwsA(isA<SocketException>()));
  });
}
