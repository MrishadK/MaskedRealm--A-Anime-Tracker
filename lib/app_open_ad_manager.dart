import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AppOpenAdManager {
  AppOpenAd? _appOpenAd;
  bool _isAdAvailable = false;

  /// Load an App Open Ad
  void loadAd() {
    AppOpenAd.load(
      adUnitId:
          'ca-app-pub-8355736208842576/5376859843', // Replace with your actual Ad Unit ID
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _isAdAvailable = true;
          debugPrint('✅ App Open Ad loaded successfully');
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ Failed to load App Open Ad: $error');
          _isAdAvailable = false;
        },
      ),
    );
  }

  /// Show the App Open Ad if it's available
  void showAdIfAvailable() {
    if (_isAdAvailable && _appOpenAd != null) {
      _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          debugPrint('✅ App Open Ad dismissed');
          ad.dispose();
          loadAd(); // Load next ad
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint('❌ Failed to show App Open Ad: $error');
          ad.dispose();
          loadAd();
        },
      );

      _appOpenAd!.show();
      _appOpenAd = null;
      _isAdAvailable = false;
    } else {
      debugPrint('⚠️ App Open Ad not available yet.');
      loadAd(); // Attempt to load again
    }
  }
}
