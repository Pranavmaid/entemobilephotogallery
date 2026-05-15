import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AiEditService {
  static const String model = 'gemini-2.5-flash-image';
  static const String _apiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  static bool get isConfigured => _apiKey.isNotEmpty;

  static Future<Uint8List> edit({
    required Uint8List imageBytes,
    required String mimeType,
    required String prompt,
  }) async {
    if (_apiKey.isEmpty) {
      throw const AiEditException(
        title: 'API key missing',
        body: 'GEMINI_API_KEY is not set.\n\n'
            'Re-run the app with:\n'
            'flutter run --dart-define=GEMINI_API_KEY=<your-key>\n\n'
            'For a release APK:\n'
            'flutter build apk --release --dart-define=GEMINI_API_KEY=<your-key>',
      );
    }
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$model:generateContent?key=$_apiKey',
    );
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Encode(imageBytes),
              }
            },
          ],
        }
      ],
      'generationConfig': {
        'responseModalities': ['IMAGE', 'TEXT'],
      },
    });
    http.Response res;
    try {
      res = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 90));
    } on SocketException catch (e) {
      throw AiEditException(
        title: 'No network',
        body: 'Could not reach Gemini.\n${e.message}',
      );
    } on TimeoutException {
      throw const AiEditException(
        title: 'Request timed out',
        body: 'Gemini did not respond within 90 seconds. '
            'Check your connection and try again.',
      );
    } catch (e) {
      throw AiEditException(
        title: 'Network error',
        body: e.toString(),
      );
    }
    debugPrint('[ai-edit] status=${res.statusCode} bytes=${res.body.length}');
    if (res.statusCode != 200) {
      throw AiEditException(
        title: _titleForStatus(res.statusCode),
        body: _formatErrorBody(res.body),
      );
    }
    Map<String, dynamic> data;
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      throw AiEditException(
        title: 'Bad response',
        body: 'Could not parse Gemini response:\n${res.body}',
      );
    }
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      final promptFeedback = data['promptFeedback'];
      throw AiEditException(
        title: 'No candidates',
        body: promptFeedback != null
            ? 'Gemini returned no candidates.\npromptFeedback: '
                '${const JsonEncoder.withIndent('  ').convert(promptFeedback)}'
            : 'Gemini returned no candidates and no feedback.\n\nRaw:\n${res.body}',
      );
    }
    final parts = (candidates.first['content']?['parts'] as List?) ?? const [];
    for (final p in parts) {
      final inline = p['inline_data'] ?? p['inlineData'];
      if (inline is Map && inline['data'] is String) {
        return base64Decode(inline['data'] as String);
      }
    }
    final finishReason = candidates.first['finishReason'];
    final safety = candidates.first['safetyRatings'];
    throw AiEditException(
      title: 'No image in response',
      body: 'Gemini did not return an image part.\n'
          'finishReason: $finishReason\n'
          '${safety != null ? 'safetyRatings: ${const JsonEncoder.withIndent('  ').convert(safety)}\n' : ''}'
          '\nRaw response:\n${res.body}',
    );
  }

  static String _titleForStatus(int code) {
    switch (code) {
      case 400:
        return 'Bad request (400)';
      case 401:
        return 'Unauthorized (401)';
      case 403:
        return 'Forbidden (403)';
      case 404:
        return 'Model not found (404)';
      case 429:
        return 'Quota exceeded (429)';
      case 500:
      case 502:
      case 503:
      case 504:
        return 'Gemini server error ($code)';
      default:
        return 'HTTP $code';
    }
  }

  static String _formatErrorBody(String raw) {
    try {
      final j = jsonDecode(raw);
      return const JsonEncoder.withIndent('  ').convert(j);
    } catch (_) {
      return raw;
    }
  }
}

class AiEditException implements Exception {
  final String title;
  final String body;
  const AiEditException({required this.title, required this.body});
  @override
  String toString() => '$title\n\n$body';
}
