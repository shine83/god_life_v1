// lib/services/ai_service.dart
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Supabase Edge Function(secure-gemini) 호출 헬퍼
class AIService {
  // 예: https://xxxxx.supabase.co/functions/v1/secure-gemini
  static final String _functionUrl =
      '${dotenv.env['SUPABASE_URL']!}/functions/v1/secure-gemini';

  // anon key
  static final String _supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']!;

  Future<String> getResponse(String prompt) async {
    try {
      final url = Uri.parse(_functionUrl);

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'apikey': _supabaseAnonKey,
          // ★ 권장: Authorization 헤더도 같이 전달 (일부 정책에서 필수)
          'Authorization': 'Bearer $_supabaseAnonKey',
        },
        body: json.encode({'prompt': prompt}),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        return decoded['response'] ?? '응답 텍스트를 받아오지 못했습니다.';
      } else {
        // 함수 오류가 JSON이 아닐 수도 있으니 방어적으로 처리
        String msg;
        try {
          final d = json.decode(response.body);
          msg = (d['error'] ?? d['message'] ?? 'Unknown error').toString();
        } catch (_) {
          msg = 'HTTP ${response.statusCode}: ${response.reasonPhrase}';
        }
        throw Exception(msg);
      }
    } catch (e) {
      // 네트워크/호스트/DNS 등의 원인 메시지 그대로 노출(디버깅에 유용)
      throw Exception('AI 서버 통신 실패: $e');
    }
  }
}
