import 'ad_network.dart';
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 리워드(보상형) 광고의 로드/노출을 담당하는 싱글턴.
/// 현재는 "하트 소진 시 광고 시청 -> 하트 1개 충전" 용도로만 사용한다.
class AdManager extends ChangeNotifier with WidgetsBindingObserver {
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

  static const _maxAge = Duration(hours: 1);
  static const _retryDelays = [Duration(seconds: 6), Duration(seconds: 12)];

  RewardedAd? _rewardedAd;
  Stopwatch? _adAge;
  Timer? _validityTimer;
  Timer? _retryTimer;
  final _clock = Stopwatch()..start();
  Duration? _retryAt;
  int _attempts = 0;
  bool _consentStarted = false;
  bool _consentBusy = false;
  bool _privacyRequired = false;
  bool _adsAllowed = false;
  Future<InitializationStatus>? _sdkInitialization;
  bool _isLoading = false;
  bool _discardPendingLoad = false;
  bool _showing = false;
  bool _expired = false;
  bool _preloadRequested = false;
  bool _popupExpiryPending = false;

  bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  bool get _canLoad => AdNetwork.instance.allowed && _foreground && _adsAllowed && !_consentBusy;
  bool get privacyOptionsRequired => _privacyRequired;
  bool get privacyOptionsAvailable =>
      _privacyRequired && !_consentBusy && !_showing && _foreground;
  bool get isAdReady => _canLoad && !_showing && _rewardedAd != null &&
      _adAge != null && _adAge!.elapsed < _maxAge;

  void _expireCachedAd() {
    if (_adAge == null || _adAge!.elapsed < _maxAge) return;
    _discardCachedAd();
    _expired = true;
    notifyListeners();
  }

  void _discardCachedAd() {
    _validityTimer?.cancel();
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _adAge = null;
  }

  void init() {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    WidgetsBinding.instance.addObserver(this);
    AdNetwork.instance.addListener(_networkChanged);
    AdNetwork.instance.start();
    if (_foreground) unawaited(_startConsent());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_startConsent());
      _expireCachedAd();
      _resumePreparation();
    } else {
      _retryTimer?.cancel();
      _retryTimer = null;
    }
    notifyListeners();
  }

  Future<void> _startConsent() async {
    if (_consentStarted) return;
    _consentStarted = true;
    await _resolveConsent(() async {
      final updated = Completer<FormError?>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () => updated.complete(null),
        updated.complete,
      );
      final updateError = await updated.future;
      if (updateError != null) {
        debugPrint('[AdManager] UMP update failed: $updateError');
        return;
      }
      final dismissed = Completer<FormError?>();
      await ConsentForm.loadAndShowConsentFormIfRequired(dismissed.complete);
      final formError = await dismissed.future;
      if (formError != null) debugPrint('[AdManager] UMP form failed: $formError');
    });
  }

  Future<void> showPrivacyOptions() async {
    if (!privacyOptionsAvailable) return;
    await _resolveConsent(() async {
      final dismissed = Completer<FormError?>();
      await ConsentForm.showPrivacyOptionsForm(dismissed.complete);
      final error = await dismissed.future;
      if (error != null) debugPrint('[AdManager] UMP privacy options failed: $error');
    });
  }

  Future<void> _resolveConsent(Future<void> Function() update) async {
    _consentBusy = true;
    _adsAllowed = false;
    _discardCachedAd();
    _expired = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAt = null;
    _preloadRequested = false;
    if (_isLoading) _discardPendingLoad = true;
    notifyListeners();
    try {
      try {
        await update();
      } catch (error) {
        debugPrint('[AdManager] UMP operation failed: $error');
      }
      final consent = ConsentInformation.instance;
      _privacyRequired = await consent.getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
      if (await consent.canRequestAds()) {
        await (_sdkInitialization ??= MobileAds.instance.initialize());
        _adsAllowed = true;
        _preloadRequested = true;
      }
    } catch (error) {
      debugPrint('[AdManager] Consent or ads initialization failed: $error');
    } finally {
      _consentBusy = false;
      _resumePreparation();
      notifyListeners();
    }
  }

  void prepareExpiredOnPopupOpen() {
    _expireCachedAd();
    if (_expired) _popupExpiryPending = true;
    if (!_expired || !_canLoad || _showing || _isLoading || _retryAt != null) return;
    _expired = false;
    _popupExpiryPending = false;
    _attempts = 0;
    unawaited(_requestAd());
  }

  void _networkChanged() {
    if (!AdNetwork.instance.allowed) { _retryTimer?.cancel(); _retryTimer = null; }
    else {
      if (_popupExpiryPending) prepareExpiredOnPopupOpen();
      _resumePreparation();
    }
    notifyListeners();
  }

  void _resumePreparation() {
    if (_popupExpiryPending && _canLoad) prepareExpiredOnPopupOpen();
    if (!_canLoad || _isLoading || _rewardedAd != null) return;
    final retryAt = _retryAt;
    if (retryAt != null) {
      _retryTimer ??= Timer(retryAt - _clock.elapsed, () {
        _retryTimer = null;
        if (!_canLoad) return;
        _retryAt = null;
        unawaited(_requestAd());
      });
    } else if (_preloadRequested) {
      _preloadRequested = false;
      _expired = false;
      _attempts = 0;
      unawaited(_requestAd());
    }
  }

  Future<void> _requestAd() async {
    if (!_canLoad || _isLoading || _rewardedAd != null) return;
    _isLoading = true;
    _popupExpiryPending = false;
    _attempts++;
    notifyListeners();

    var settled = false;
    void failed(Object error) {
      if (settled) return;
      settled = true;
      _isLoading = false;
      if (_discardPendingLoad) {
        _discardPendingLoad = false;
      } else if (_attempts <= _retryDelays.length) {
        _retryAt = _clock.elapsed + _retryDelays[_attempts - 1];
      }
      debugPrint('[AdManager] Rewarded ad failed to load: $error');
      _resumePreparation();
      notifyListeners();
    }

    try {
      await RewardedAd.load(
        adUnitId: _rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            if (settled) {
              ad.dispose();
              return;
            }
            settled = true;
            _isLoading = false;
            if (_discardPendingLoad || !_adsAllowed) {
              _discardPendingLoad = false;
              ad.dispose();
              _resumePreparation();
            } else {
              _rewardedAd = ad;
              _adAge = Stopwatch()..start();
              _validityTimer = Timer(_maxAge, _expireCachedAd);
            }
            notifyListeners();
          },
          onAdFailedToLoad: failed,
        ),
      );
    } catch (error) {
      failed(error);
    }
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
    _expireCachedAd();
    final ad = _rewardedAd;
    if (!isAdReady || ad == null) {
      onAdUnavailable?.call();
      return;
    }

    _showing = true;
    _rewardedAd = null;
    _adAge = null;
    _validityTimer?.cancel();
    notifyListeners();
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
      notifyListeners();
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (callbackAd) {
        if (!identical(callbackAd, ad) || closed || failed || opened) return;
        opened = true;
        _preloadRequested = true;
        _resumePreparation();
      },
      onAdDismissedFullScreenContent: (callbackAd) {
        if (!identical(callbackAd, ad) || closed || failed) return;
        closed = true;
        _showing = false;
        ad.dispose();
        onAdClosed?.call();
        notifyListeners();
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

