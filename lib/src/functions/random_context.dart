import 'dart:math' as math;

import '../config.dart';

class RandomContext {
  final math.Random random = math.Random();

  final Map<URDField, Map<String, List<int>>> pools = {};

  String resolveRandom(String str, URDField field) {
    final match = RegExp(
      r'^(URD|RND|RD)\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\)$',
    ).firstMatch(str);

    // RD / RND / URD가 아니면 원본 그대로 반환
    if (match == null) {
      return str;
    }

    final type = match.group(1)!;
    final min = double.parse(match.group(2)!);
    final max = double.parse(match.group(3)!);

    // RD와 RND는 동일 동작
    if (type == 'RD' || type == 'RND') {
      final value =
          random.nextDouble() * ((max + 1) - min) + min;

      return value.floor().toString();
    }

    // URD
    if (type == 'URD') {
      final ret = _getUnique(
        field,
        min.toInt(),
        max.toInt(),
      );

      print(
        'URD run = (${min.toInt()}, ${max.toInt()}), '
            'field = $field, ret = $ret',
      );

      return ret.toString();
    }

    return str;
  }

  int _getUnique(
      URDField field,
      int min,
      int max,
      ) {
    final rangeKey = '$min,$max';

    pools.putIfAbsent(field, () => {});

    pools[field]!.putIfAbsent(rangeKey, () {
      final list =
      List.generate(max - min + 1, (i) => min + i);

      list.shuffle(random);

      return list;
    });

    final pool = pools[field]![rangeKey]!;

    if (pool.isEmpty) {
      throw Exception(
        'URD exhausted: $field ($rangeKey)',
      );
    }

    return pool.removeLast();
  }
}