import 'dart:math' as math;

import '../config.dart';

class RandomContext {
  final math.Random random;
  final Map<URDField, Map<String, List<int>>> pools = {};

  RandomContext({math.Random? random}) : random = random ?? math.Random();

  String resolveRandom(String str, URDField field) {
    if (!str.contains('RD')) return str;

    return str.replaceAllMapped(
      RegExp(r'(URD|RD)\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\)'),
      (match) {
        final type = match.group(1);
        final min = double.parse(match.group(2)!);
        final max = double.parse(match.group(3)!);

        if (type == 'RD') {
          final value = random.nextDouble() * ((max + 1) - min) + min;
          return value.truncate().toString();
        }

        if (type == 'URD') {
          return _getUnique(
            field,
            min.toInt(),
            max.toInt() + 1,
          ).toString();
        }

        return match.group(0)!;
      },
    );
  }

  int _getUnique(URDField field, int min, int max) {
    final rangeKey = '$min,$max';

    pools.putIfAbsent(field, () => {});
    pools[field]!.putIfAbsent(rangeKey, () {
      final list = List.generate(max - min + 1, (i) => min + i);
      list.shuffle(random);
      return list;
    });

    final pool = pools[field]![rangeKey]!;

    if (pool.isEmpty) {
      throw Exception('URD exhausted: $field ($rangeKey)');
    }

    return pool.removeLast();
  }
}
