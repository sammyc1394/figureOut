import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Connection availability is not proof that the ad server is reachable.
class AdNetwork extends ChangeNotifier with WidgetsBindingObserver {
  static final instance = AdNetwork._();
  AdNetwork._();
  final _connectivity = Connectivity();
  bool _started = false, _checked = false, _offline = false;
  int _revision = 0;
  bool get allowed => _checked && !_offline;
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _connectivity.onConnectivityChanged.listen((value) {
      _revision++;
      _publish(value);
    }, onError: (Object error) {
      _revision++;
      debugPrint('[Ads] Connectivity stream unavailable: $error');
      _publish(null);
    });
    unawaited(_refresh());
  }
  void _publish(List<ConnectivityResult>? value) {
    _checked = true;
    _offline = value != null && value.isNotEmpty &&
        value.every((item) => item == ConnectivityResult.none);
    notifyListeners();
  }
  Future<void> _refresh() async {
    final revision = ++_revision;
    try {
      final value = await _connectivity.checkConnectivity();
      if (revision == _revision) _publish(value);
    } catch (error) {
      debugPrint('[Ads] Connectivity query unavailable: $error');
      if (revision == _revision) _publish(null);
    }
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }
}
