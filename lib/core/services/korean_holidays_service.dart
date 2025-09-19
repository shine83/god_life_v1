// lib/core/services/korean_holidays_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

// 간단한 공휴일 모델 클래스
class Holiday {
  final DateTime date;
  final String name;
  Holiday(this.date, this.name);
}

// 공휴일 데이터를 제공하는 서비스 클래스
class KoreanHolidaysService {
  // 메모리에 연도별 공휴일 정보를 저장해두는 '캐시'
  static final Map<int, List<Holiday>> _cache = {};

  // ✨ --- 1단계에서 발급받은 인증키를 여기에 붙여넣어 주세요 ---
  static const String _apiKey =
      '7EDIT%2Bx337SeEUqhTpsoO70sayPN2%2BJpKUTkgWy18S0%2BD8ZN76L%2B2s6Ndvljmvmy7q7cn7Oq%2FeBeRPQn%2FTWF6Q%3D%3D';

  static Future<List<Holiday>> getHolidays({required int year}) async {
    // 만약 캐시에 해당 연도 정보가 이미 있다면, API를 호출하지 않고 바로 반환
    if (_cache.containsKey(year)) {
      print('$year년 공휴일 정보는 캐시에서 불러옵니다.');
      return _cache[year]!;
    }

    print('$year년 공휴일 정보를 API로 요청합니다.');

    // 네트워크 요청 (한글이 깨지지 않도록 URL 인코딩이 필요 없습니다)
    final url = Uri.parse(
        'http://apis.data.go.kr/B090041/openapi/service/SpcdeInfoService/getRestDeInfo?solYear=$year&ServiceKey=$_apiKey&_type=json&numOfRows=100');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // 데이터가 없을 경우를 대비한 안전장치
        if (data['response']['body']['items'] == '') {
          _cache[year] = [];
          return [];
        }

        final items = data['response']['body']['items']['item'];
        final List<Holiday> holidays = [];

        // items가 단일 객체일 수도, 리스트일 수도 있어서 분기 처리
        if (items is List) {
          for (final item in items) {
            holidays.add(Holiday(
                DateTime.parse(item['locdate'].toString()), item['dateName']));
          }
        } else if (items is Map) {
          holidays.add(Holiday(
              DateTime.parse(items['locdate'].toString()), items['dateName']));
        }

        _cache[year] = holidays; // 파싱한 결과를 캐시에 저장
        return holidays;
      } else {
        throw Exception('공휴일 API 응답 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('공휴일 정보 파싱 오류: $e');
      return []; // 오류 발생 시 빈 리스트 반환
    }
  }
}
