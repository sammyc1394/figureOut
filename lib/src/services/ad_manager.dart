import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 리워드(보상형) 광고의 로드/노출을 담당하는 싱글턴.
/// 현재는 "하트 소진 시 광고 시청 -> 하트 1개 충전" 용도로만 사용한다.
class AdManager {
  static final AdManager _instance = AdManager._internal();
  static AdManager get instance => _instance;

  AdManager._internal();

  // TODO(release): 정식 배포 전 AdMob 콘솔에서 발급받은 실제 리워드 광고 단위 ID로 교체할 것.
  // 아래는 Google이 제공하는 테스트 전용 ID로, 실제 수익은 발생하지 않는다.
  // https://developers.google.com/admob/flutter/test-ads
  String get _rewardedAdUnitId {
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/1712485313';
    return 'ca-app-pub-3940256099942544/5224354917'; // Android
  }

  RewardedAd? _rewardedAd;
  bool _isLoading = false;
  bool _showing = false;
  DateTime? _loadedAt;
  Timer? _validityTimer;

  void _expireCachedAd() {
    if (_loadedAt == null || DateTime.now().difference(_loadedAt!) < const Duration(hours: 1)) return;
    _discardCachedAd();
  }

  void _discardCachedAd() {
    _validityTimer?.cancel();
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _loadedAt = null;
  }

  bool get isAdReady {
    _expireCachedAd();
    return !_showing && _rewardedAd != null;
  }

  /// Mobile Ads SDK 초기화 + 첫 리워드 광고 미리 로드.
  Future<void> init() async {
    if (kIsWeb) return;
    await MobileAds.instance.initialize();
    loadRewardedAd();
  }

  /// 다음에 보여줄 리워드 광고를 미리 로드해둔다.
  void loadRewardedAd() {
    _expireCachedAd();
    if (kIsWeb || _isLoading || _showing || _rewardedAd != null) return;
    _isLoading = true;

    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _loadedAt = DateTime.now();
          _validityTimer?.cancel();
          _validityTimer = Timer(const Duration(hours: 1), _discardCachedAd);
          _isLoading = false;
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isLoading = false;
          debugPrint('[AdManager] Rewarded ad failed to load: $error');
        },
      ),
    );
  }

  /// 리워드 광고를 노출한다.
  /// - [onUserEarnedReward]: 시청 완료(보상 획득) 시 호출.
  /// - [onAdClosed]: 광고가 닫혔을 때(보상 획득 여부와 무관하게) 호출.
  /// - [onAdUnavailable]: 아직 광고가 로드되지 않아 보여줄 수 없을 때 호출.
  void showRewardedAd({
    required VoidCallback onUserEarnedReward,
    VoidCallback? onAdClosed,
    VoidCallback? onAdUnavailable,
  }) {
    if (_showing || WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.inactive) {
      return;
    }
    _expireCachedAd();
    final ad = _rewardedAd;
    if (kIsWeb || ad == null) {
      onAdUnavailable?.call();
      loadRewardedAd();
      return;
    }

    // Reserve synchronously; callbacks belong to this immutable ad instance.
    _showing = true;
    _rewardedAd = null;
    _loadedAt = null;
    _validityTimer?.cancel();
    var earned = false;
    var closed = false;
    var failed = false;
    var opened = false;
    void fail(Object error) {
      if (closed || failed || earned || opened) return;
      failed = true;
      _showing = false;
      ad.dispose();
      debugPrint('[AdManager] Rewarded ad failed to show: $error');
      onAdUnavailable?.call();
      loadRewardedAd();
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (callbackAd) {
        if (identical(callbackAd, ad) && !closed && !failed) opened = true;
      },
      onAdDismissedFullScreenContent: (callbackAd) {
        if (!identical(callbackAd, ad) || closed || failed) return;
        closed = true;
        _showing = false;
        ad.dispose();
        onAdClosed?.call();
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (callbackAd, error) {
        if (identical(callbackAd, ad)) fail(error);
      },
    );
    unawaited(ad.show(
      onUserEarnedReward: (callbackAd, reward) {
        if (!identical(callbackAd, ad) || earned || failed) return;
        earned = true;
        onUserEarnedReward();
      },
    ).catchError((Object error) {
      if (error is PlatformException && error.code == 'AdShowError') {
        fail(error);
      } else {
        // An ambiguous rejection is not proof that the native window ended.
        debugPrint('[AdManager] Awaiting terminal ad callback after: $error');
      }
    }));
  }
}

