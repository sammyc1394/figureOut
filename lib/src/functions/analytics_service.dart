import 'package:amplitude_flutter/amplitude.dart';
import 'package:amplitude_flutter/configuration.dart';
import 'package:amplitude_flutter/events/base_event.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  Amplitude? _amplitude;
  bool _initialized = false;

  Future<void> init({String? apiKey}) async {
    if (_initialized) return;

    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('[Analytics] mock mode initialized');
      _initialized = true;
      return;
    }

    _amplitude = Amplitude(
      Configuration(apiKey: apiKey),
    );

    _initialized = true;
    debugPrint('[Analytics] Amplitude initialized');
  }

  Future<void> logEvent(
      String eventName, {
        Map<String, Object>? properties,
      }) async {
    if (!_initialized) {
      debugPrint('[Analytics] init() not called');
      return;
    }

    if (kDebugMode) {
      debugPrint(
        '[Analytics] event=$eventName properties=${properties ?? {}}',
      );
    }

    final amplitude = _amplitude;

    if (amplitude == null) {
      return;
    }

    try {
      await amplitude.track(
        BaseEvent(
          eventName,
          eventProperties: properties,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('[Analytics] track failed: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> setUserId(String? userId) async {
    if (kDebugMode) {
      debugPrint('[Analytics] userId=$userId');
    }

    _amplitude?.setUserId(userId);
  }

  Future<void> flush() async {
    if (kDebugMode) {
      debugPrint('[Analytics] flush');
    }

    await _amplitude?.flush();
  }

  Future<void> reset() async {
    if (kDebugMode) {
      debugPrint('[Analytics] reset');
    }

    await _amplitude?.reset();
  }
}