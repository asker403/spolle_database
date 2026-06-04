//
//  AdMobManager.swift
//  Spolle
//
//  Created by Claude on 7/27/25.
//

import SwiftUI
import GoogleMobileAds

// MARK: - AdMob Manager
class AdMobManager: NSObject, ObservableObject, FullScreenContentDelegate {
    static let shared = AdMobManager()
    
    @Published var isInterstitialAdLoaded = false
    @Published var isShowingInterstitialAd = false
    
    private var interstitialAd: InterstitialAd?
    
    // Production Ad Unit IDs
    struct AdUnitIDs {
        // Test IDs (for testing):
        static let banner = "ca-app-pub-3940256099942544/2934735716" // Test banner ID
        static let interstitial = "ca-app-pub-3940256099942544/1033173712" // Test interstitial ID
        
        // Production IDs (uncomment for production):
        // static let banner = "ca-app-pub-7806799134566231/7652615887" // Production banner ID
        // static let interstitial = "ca-app-pub-7806799134566231/8385730169" // Production interstitial ID
    }
    
    override init() {
        super.init()
        // Don't load ads until after initialization
    }
    
    func initialize() {
        // Debug: Check if Info.plist has the AdMob key
        if let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path) {
            print("📱 Info.plist found with keys: \(plist.allKeys)")
            if let gadAppId = plist["GADApplicationIdentifier"] {
                print("✅ GADApplicationIdentifier found: \(gadAppId)")
            } else {
                print("❌ GADApplicationIdentifier NOT found in Info.plist")
            }
        } else {
            print("⚠️ Info.plist not found or cannot be read")
        }
        
        // Initialize the SDK
        MobileAds.shared.start(completionHandler: { [weak self] status in
            print("🎯 AdMob initialized with status: \(status)")
            // Load ads after initialization is complete
            DispatchQueue.main.async {
                self?.loadInterstitialAd()
            }
        })
    }
    
    // MARK: - Interstitial Ad
    func loadInterstitialAd() {
        let request = Request()
        InterstitialAd.load(with: AdUnitIDs.interstitial, request: request) { [weak self] ad, error in
            if let error = error {
                print("❌ Failed to load interstitial ad: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.isInterstitialAdLoaded = false
                }
                return
            }
            
            print("✅ Interstitial ad loaded successfully")
            DispatchQueue.main.async {
                self?.interstitialAd = ad
                self?.interstitialAd?.fullScreenContentDelegate = self
                self?.isInterstitialAdLoaded = true
            }
        }
    }
    
    func showInterstitialAd(from viewController: UIViewController, onDismiss: @escaping () -> Void) {
        guard let interstitialAd = interstitialAd else {
            print("❌ Interstitial ad not loaded")
            // If ad isn't loaded, still allow the action
            onDismiss()
            return
        }
        
        isShowingInterstitialAd = true
        
        // Store the callback for when ad is dismissed
        interstitialAdDismissCallback = onDismiss
        
        interstitialAd.present(from: viewController)
    }
    
    private var interstitialAdDismissCallback: (() -> Void)?
    
    // MARK: - FullScreenContentDelegate
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("🎯 Interstitial ad dismissed")
        isShowingInterstitialAd = false
        
        // Call the dismiss callback
        interstitialAdDismissCallback?()
        interstitialAdDismissCallback = nil
        
        // Load next ad
        loadInterstitialAd()
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("❌ Failed to present interstitial ad: \(error.localizedDescription)")
        isShowingInterstitialAd = false
        
        // Call the dismiss callback even on failure
        interstitialAdDismissCallback?()
        interstitialAdDismissCallback = nil
        
        // Load next ad
        loadInterstitialAd()
    }
    
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("🎯 Interstitial ad will present")
    }
}

// MARK: - Banner Ad View
struct AdMobBannerView: UIViewRepresentable {
    let adUnitID: String
    
    init(adUnitID: String = AdMobManager.AdUnitIDs.banner) {
        self.adUnitID = adUnitID
    }
    
    func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView(adSize: AdSizeBanner)
        bannerView.adUnitID = adUnitID
        
        // Get root view controller using modern approach
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            bannerView.rootViewController = window.rootViewController
        }
        
        let request = Request()
        bannerView.load(request)
        
        return bannerView
    }
    
    func updateUIView(_ uiView: BannerView, context: Context) {
        // Update if needed
    }
}

// MARK: - View Extension for Root View Controller
extension View {
    func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        return window.rootViewController
    }
}