import 'package:figureout/src/services/ad_manager.dart';
import 'package:figureout/src/services/ad_network.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ump/user_messaging_codec.dart';

void main() {
  testWidgets(
    'rewarded ads wait for eligibility and never auto-show the next ad',
    (tester) async {
      final ads = <RewardedAd>[];
      var shows = 0;
      final messenger = tester.binding.defaultBinaryMessenger;
      final ump = MethodChannel(
        'plugins.flutter.io/google_mobile_ads/ump',
        StandardMethodCodec(UserMessagingCodec()),
      );
      const connectivity = MethodChannel(
        'dev.fluttercommunity.plus/connectivity',
      );
      const connectivityEvents = MethodChannel(
        'dev.fluttercommunity.plus/connectivity_status',
      );

      messenger.setMockMethodCallHandler(ump, (call) async {
        return switch (call.method) {
          'ConsentInformation#getPrivacyOptionsRequirementStatus' => 0,
          'ConsentInformation#canRequestAds' => true,
          _ => null,
        };
      });
      messenger.setMockMethodCallHandler(connectivity, (_) async => ['wifi']);
      messenger.setMockMethodCallHandler(connectivityEvents, (_) async => null);
      messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
        if (call.method == 'MobileAds#initialize') {
          return InitializationStatus({});
        }
        if (call.method == 'loadRewardedAd') {
          ads.add(instanceManager.adFor(call.arguments['adId'])! as RewardedAd);
        }
        if (call.method == 'showAdWithoutView') shows++;
        return null;
      });
      addTearDown(() {
        for (final channel in [
          ump,
          connectivity,
          connectivityEvents,
          instanceManager.channel,
        ]) {
          messenger.setMockMethodCallHandler(channel, null);
        }
      });

      final manager = AdManager.instance;
      var unavailable = 0;
      manager.showRewardedAd(
        onUserEarnedReward: () => fail('No ad was shown'),
        onAdUnavailable: () => unavailable++,
      );
      expect(unavailable, 1);
      expect(shows, 0);

      // The normal initialization entry point is mobile-only. Drive the
      // foreground event with mocked SDK and connectivity channels on desktop.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      AdNetwork.instance.start();
      manager.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(ads, hasLength(1));
      final first = ads.single;
      first.rewardedAdLoadCallback.onAdLoaded(first);

      var grants = 0;
      var closed = 0;
      manager.showRewardedAd(
        onUserEarnedReward: () => grants++,
        onAdClosed: () => closed++,
      );
      manager.showRewardedAd(onUserEarnedReward: () => fail('Show is locked'));
      await tester.pump();
      expect(shows, 1);

      first.fullScreenContentCallback!.onAdShowedFullScreenContent!(first);
      await tester.pump();
      expect(ads, hasLength(2));
      final second = ads.last;
      second.rewardedAdLoadCallback.onAdLoaded(second);
      expect(shows, 1);
      expect(manager.isAdReady, isFalse);

      final earned = first.onUserEarnedRewardCallback!;
      first.fullScreenContentCallback!.onAdDismissedFullScreenContent!(first);
      first.fullScreenContentCallback!.onAdDismissedFullScreenContent!(first);
      earned(first, RewardItem(1, 'late'));
      earned(first, RewardItem(1, 'duplicate'));
      expect(grants, 1);
      expect(closed, 1);
      expect(manager.isAdReady, isTrue);

      manager.showRewardedAd(onUserEarnedReward: () => grants++);
      await tester.pump();
      expect(shows, 2);
      second.onUserEarnedRewardCallback!(second, RewardItem(1, 'second'));
      second.fullScreenContentCallback!.onAdDismissedFullScreenContent!(second);
      await tester.pump();
      expect(grants, 2);
    },
  );
}
