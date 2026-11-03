import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:figureout/src/services/ad_manager.dart';

void main() {
  testWidgets('reward deduplication, late callbacks, show lock and cache expiry', (tester) async {
    final ads = <RewardedAd>[];
    var shows = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
      if (call.method == 'MobileAds#initialize') return InitializationStatus({});
      if (call.method == 'loadRewardedAd') ads.add(instanceManager.adFor(call.arguments['adId'])! as RewardedAd);
      if (call.method == 'showAdWithoutView') shows++;
      return null;
    });
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final manager = AdManager.instance;
    await manager.init(); await tester.pump();
    expect(ads, hasLength(1));
    final first = ads.first;
    first.rewardedAdLoadCallback.onAdLoaded(first);
    var grants = 0;
    var closed = 0;
    manager.showRewardedAd(onUserEarnedReward: () => grants++, onAdClosed: () => closed++);
    manager.showRewardedAd(onUserEarnedReward: () => grants++);
    await tester.pump(); expect(shows, 1);
    final earned = first.onUserEarnedRewardCallback!;
    first.fullScreenContentCallback!.onAdDismissedFullScreenContent!(first);
    first.fullScreenContentCallback!.onAdDismissedFullScreenContent!(first);
    earned(first, RewardItem(1, 'late')); earned(first, RewardItem(1, 'duplicate'));
    expect(grants, 1); expect(closed, 1);
    await tester.pump(); expect(ads, hasLength(2));
    final second = ads.last;
    second.rewardedAdLoadCallback.onAdLoaded(second);
    await tester.pump(const Duration(hours: 1));
    expect(manager.isAdReady, false);
    var unavailable = 0;
    manager.showRewardedAd(onUserEarnedReward: () => grants++, onAdUnavailable: () => unavailable++);
    await tester.pump();
    expect(shows, 1); expect(unavailable, 1); expect(ads, hasLength(3));
    final third = ads.last;
    third.rewardedAdLoadCallback.onAdLoaded(third);
    manager.showRewardedAd(onUserEarnedReward: () => grants++);
    await tester.pump(); expect(shows, 2);
    third.onUserEarnedRewardCallback!(third, RewardItem(1, 'second'));
    third.fullScreenContentCallback!.onAdDismissedFullScreenContent!(third);
    await tester.pump(); expect(grants, 2);
    expect(shows, 2, reason: 'loading never automatically presents');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(instanceManager.channel, null);
  });
}
