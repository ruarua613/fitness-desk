import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'chat_message.dart';

/// 极简的大模型客户端。只依赖 dart:io，不引第三方包。
/// 走 OpenAI 兼容的 /chat/completions + SSE 流式，所以
/// DeepSeek / 智谱 / 月之暗面 / 通义 / OpenAI / 本地 Ollama 都能用。
class LlmException implements Exception {
  final String message;
  const LlmException(this.message);

  @override
  String toString() => message;
}

class LlmClient {
  LlmClient({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  final String baseUrl;
  final String apiKey;
  final String model;

  Uri get endpoint {
    var base = baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return Uri.parse('$base/chat/completions');
  }

  Future<String> chat({
    required String system,
    required List<ChatMsg> turns,
    void Function(String delta)? onDelta,
    Duration timeout = const Duration(seconds: 180),
  }) {
    if (apiKey.isEmpty) {
      return Future.error(const LlmException('还没填 API Key'));
    }
    return _request(system: system, turns: turns, onDelta: onDelta)
        .timeout(timeout, onTimeout: () => throw const LlmException('响应超时，请再试一次'));
  }

  Future<String> _request({
    required String system,
    required List<ChatMsg> turns,
    void Function(String delta)? onDelta,
  }) async {
    final http = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await http.postUrl(endpoint);
      req.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
      req.headers.set('Authorization', 'Bearer $apiKey');
      req.headers.set('Accept', 'text/event-stream');
      req.write(jsonEncode({
        'model': model,
        'stream': true,
        'temperature': 0.3,
        'messages': [
          {'role': 'system', 'content': system},
          ...turns.map((t) => t.toJson()),
        ],
      }));

      final resp = await req.close();
      if (resp.statusCode != 200) {
        final text = await resp.transform(utf8.decoder).join();
        final brief = text.length > 240 ? text.substring(0, 240) : text;
        throw LlmException('请求失败 ${resp.statusCode}：$brief');
      }

      final buf = StringBuffer();
      await resp
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .forEach((line) {
        final t = line.trim();
        if (t.isEmpty || !t.startsWith('data:')) return;
        final data = t.substring(5).trim();
        if (data == '[DONE]') return;
        Map<String, dynamic> obj;
        try {
          obj = jsonDecode(data) as Map<String, dynamic>;
        } catch (_) {
          return;
        }
        final choices = obj['choices'];
        if (choices is List && choices.isNotEmpty) {
          final first = choices.first;
          if (first is Map) {
            final delta = first['delta'];
            if (delta is Map && delta['content'] is String) {
              final piece = delta['content'] as String;
              buf.write(piece);
              onDelta?.call(piece);
            }
          }
        }
      });
      return buf.toString();
    } on SocketException catch (e) {
      throw LlmException('连不上服务，检查地址和网络：$e');
    } on HandshakeException catch (e) {
      throw LlmException('地址不是可用的 HTTPS 接口：$e');
    } on LlmException {
      rethrow;
    } catch (e) {
      throw LlmException('生成失败：$e');
    } finally {
      http.close(force: true);
    }
  }
}

/// 从模型输出里挖出 JSON：容忍 ```json 围栏和前后废话。
String stripFences(String text) {
  var s = text.trim();
  s = s.replaceAll(RegExp(r'^```(?:json)?', multiLine: false), '').trim();
  final fence = RegExp(r'```(?:json)?([\s\S]*?)```', dotAll: true);
  final m = fence.firstMatch(s);
  if (m != null) return m.group(1)!.trim();
  final start = s.indexOf('{');
  final end = s.lastIndexOf('}');
  if (start >= 0 && end > start) return s.substring(start, end + 1);
  return s;
}
