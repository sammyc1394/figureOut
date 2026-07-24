import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardEntry {
  final String uuid;
  final String nickname;
  final double score; // 버틴 시간 (초)
  final DateTime date;

  LeaderboardEntry({
    required this.uuid,
    required this.nickname,
    required this.score,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'uuid': uuid,
        'nickname': nickname,
        'score': score,
        'date': date.toIso8601String(),
      };

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) => LeaderboardEntry(
        uuid: json['uuid'] ?? '',
        nickname: json['nickname'] ?? '익명',
        score: (json['score'] as num?)?.toDouble() ?? 0.0,
        date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      );
}

class LeaderboardService {
  static const String _keyUuid = 'user_unique_uuid';
  static const String _keyNickname = 'user_random_nickname';
  static const String _keyHighScore = 'endless_high_score';
  static const String _keyLocalHistory = 'user_scores_history_json';

  static final List<String> _foods = [
    '피자',
    '치킨',
    '초밥',
    '라면',
    '버거',
    '떡볶이',
    '돈까스',
    '마라탕',
    '족발',
    '파스타',
    '스테이크',
    '짜장면',
  ];

  static final List<String> _animals = [
    '고양이',
    '호랑이',
    '사자',
    '강아지',
    '토끼',
    '곰',
    '여우',
    '늑대',
    '다람쥐',
    '펭귄',
    '수달',
    '판다',
  ];

  /// 사용자 고유 UUID 및 닉네임 가져오기 (없으면 무작위 생성)
  static Future<String> getOrCreateNickname({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    String? nickname = prefs.getString(_keyNickname);

    if (forceRefresh || nickname == null || nickname.isEmpty) {
      nickname = await generateRandomNickname();
    }
    return nickname;
  }

  /// 사용자 닉네임 직접 수정 및 저장
  static Future<void> updateNickname(String newNickname) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNickname, newNickname.trim());
  }

  /// 무작위 새로운 닉네임 생성 및 저장
  static Future<String> generateRandomNickname() async {
    final rand = math.Random();
    final food = _foods[rand.nextInt(_foods.length)];
    final animal = _animals[rand.nextInt(_animals.length)];
    final num = rand.nextInt(9000) + 1000;
    final nickname = '$food먹는 $animal$num';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNickname, nickname);
    return nickname;
  }

  /// 고유 UUID 생성/가져오기
  static Future<String> getOrCreateUuid() async {
    final prefs = await SharedPreferences.getInstance();
    String? uuid = prefs.getString(_keyUuid);

    if (uuid == null || uuid.isEmpty) {
      final rand = math.Random();
      uuid = 'usr_${DateTime.now().millisecondsSinceEpoch}_${rand.nextInt(99999)}';
      await prefs.setString(_keyUuid, uuid);
    }
    return uuid;
  }

  /// 로컬 최고 점수 가져오기
  static Future<double> getHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyHighScore) ?? 0.0;
  }

  static double _lastRunScore = 0.0;
  static double get lastRunScore => _lastRunScore;

  static bool _firebaseInitialized = false;

  static Future<bool> _ensureFirebaseInitialized() async {
    if (_firebaseInitialized) return true;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _firebaseInitialized = Firebase.apps.isNotEmpty;
      return _firebaseInitialized;
    } catch (e) {
      debugPrint('[Firebase Init Safeguard Error] $e');
      return false;
    }
  }

  /// 게임 판마다 점수 누적 저장 (로컬 히스토리 + Cloud Firestore 기록 생성)
  static Future<bool> saveScore(double score) async {
    _lastRunScore = score;
    final prefs = await SharedPreferences.getInstance();
    final currentHigh = prefs.getDouble(_keyHighScore) ?? 0.0;
    final isNewHigh = score > currentHigh;

    if (isNewHigh) {
      await prefs.setDouble(_keyHighScore, score);
    }
    await prefs.setDouble('last_run_score', score);

    final uuid = await getOrCreateUuid();
    final nickname = await getOrCreateNickname();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final entryId = '${uuid}_$timestamp';

    // 1. 로컬 히스토리에 누적 저장
    final historyJsonStr = prefs.getString(_keyLocalHistory);
    List<dynamic> historyList = [];
    if (historyJsonStr != null && historyJsonStr.isNotEmpty) {
      try {
        historyList = jsonDecode(historyJsonStr) as List<dynamic>;
      } catch (_) {}
    }

    final newEntryMap = {
      'uuid': entryId,
      'nickname': nickname,
      'score': score,
      'date': DateTime.now().toIso8601String(),
    };
    historyList.add(newEntryMap);
    await prefs.setString(_keyLocalHistory, jsonEncode(historyList));

    // 2. Cloud Firestore 온라인 랭킹 누적 저장
    try {
      if (await _ensureFirebaseInitialized()) {
        FirebaseFirestore.instance
            .collection('endless_leaderboard')
            .doc(entryId)
            .set({
          'uuid': uuid,
          'nickname': nickname,
          'score': score,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).catchError((e) {
          debugPrint('[Firestore Sync Error] $e');
        });
      }
    } catch (e) {
      debugPrint('[Firestore Save Error] $e');
    }

    return isNewHigh;
  }

  /// 내 점수의 파이어베이스 실시간 순위 구하기 (1위, 2위, 5위...)
  static Future<int> getPlayerRank(double score) async {
    try {
      if (await _ensureFirebaseInitialized()) {
        final snapshot = await FirebaseFirestore.instance
            .collection('endless_leaderboard')
            .get()
            .timeout(const Duration(seconds: 4));

        int higherCount = 0;
        for (final doc in snapshot.docs) {
          final docScore = (doc.data()['score'] as num?)?.toDouble() ?? 0.0;
          if (docScore > score) {
            higherCount++;
          }
        }
        return higherCount + 1;
      }
      return 1;
    } catch (e) {
      debugPrint('[Rank Fetch Error] $e');
      return 1;
    }
  }

  /// Top 50 리더보드 누적 순위 목록 가져오기
  static Future<List<LeaderboardEntry>> fetchTopScores({int limit = 50}) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJsonStr = prefs.getString(_keyLocalHistory);
    final localEntries = <LeaderboardEntry>[];

    if (historyJsonStr != null && historyJsonStr.isNotEmpty) {
      try {
        final List<dynamic> historyList = jsonDecode(historyJsonStr);
        for (final item in historyList) {
          localEntries.add(LeaderboardEntry.fromJson(Map<String, dynamic>.from(item)));
        }
      } catch (e) {
        debugPrint('[Local History Read Error] $e');
      }
    }

    // 글로벌 플레이어 기본 가상 경쟁 상대 (초기 랭킹용)
    final globalSampleEntries = [
      LeaderboardEntry(uuid: 'sample_1', nickname: '초밥먹는 사자1042', score: 110.5, date: DateTime.now()),
      LeaderboardEntry(uuid: 'sample_2', nickname: '라면먹는 토끼8821', score: 95.2, date: DateTime.now()),
      LeaderboardEntry(uuid: 'sample_3', nickname: '피자먹는 곰4491', score: 82.0, date: DateTime.now()),
      LeaderboardEntry(uuid: 'sample_4', nickname: '치킨먹는 여우5512', score: 68.4, date: DateTime.now()),
    ];

    try {
      if (await _ensureFirebaseInitialized()) {
        final snapshot = await FirebaseFirestore.instance
            .collection('endless_leaderboard')
            .get()
            .timeout(const Duration(seconds: 4));

        final docs = snapshot.docs.map((doc) {
          final data = doc.data();
          return LeaderboardEntry(
            uuid: data['uuid'] ?? doc.id,
            nickname: data['nickname'] ?? '익명',
            score: (data['score'] as num?)?.toDouble() ?? 0.0,
            date: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          );
        }).toList();

        final combined = <LeaderboardEntry>[...docs];
        for (final loc in localEntries) {
          if (!combined.any((e) => e.uuid == loc.uuid)) {
            combined.add(loc);
          }
        }
        for (final sample in globalSampleEntries) {
          if (!combined.any((e) => e.nickname == sample.nickname)) {
            combined.add(sample);
          }
        }

        combined.sort((a, b) => b.score.compareTo(a.score));
        return combined.take(limit).toList();
      }
    } catch (e) {
      debugPrint('[Leaderboard Fetch Error] $e');
    }

    final combinedLocal = <LeaderboardEntry>[...localEntries, ...globalSampleEntries];
    combinedLocal.sort((a, b) => b.score.compareTo(a.score));
    return combinedLocal.take(limit).toList();
  }
}
