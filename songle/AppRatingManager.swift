//
//  AppRatingManager.swift
//  Spolle
//
//  Created by Kiro on 7/23/25.
//

import SwiftUI
import StoreKit

// MARK: - App Rating Manager
class AppRatingManager: ObservableObject {
    static let shared = AppRatingManager()
    
    @Published var shouldShowRatingPrompt = false
    
    // UserDefaults keys
    private let hasRatedAppKey = "hasRatedApp"
    private let gameCompletionsKey = "gameCompletions"
    private let appLaunchCountKey = "appLaunchCount"
    private let lastRatingPromptDateKey = "lastRatingPromptDate"
    private let hasDeclinedRatingKey = "hasDeclinedRating"
    
    // Rating criteria
    private let minGameCompletions = 1  // Show after just 1 game completion
    private let minAppLaunches = 1      // Show after just 1 app launch
    private let daysBetweenPrompts = 30
    
    private init() {}
    
    // MARK: - Public Methods
    
    func incrementAppLaunch() {
        let currentCount = UserDefaults.standard.integer(forKey: appLaunchCountKey)
        UserDefaults.standard.set(currentCount + 1, forKey: appLaunchCountKey)
        
        checkIfShouldPromptForRating()
    }
    
    func incrementGameCompletion() {
        let currentCount = UserDefaults.standard.integer(forKey: gameCompletionsKey)
        UserDefaults.standard.set(currentCount + 1, forKey: gameCompletionsKey)
        
        checkIfShouldPromptForRating()
    }
    
    func userRatedApp() {
        UserDefaults.standard.set(true, forKey: hasRatedAppKey)
        shouldShowRatingPrompt = false
    }
    
    func userDeclinedRating() {
        UserDefaults.standard.set(true, forKey: hasDeclinedRatingKey)
        UserDefaults.standard.set(Date(), forKey: lastRatingPromptDateKey)
        shouldShowRatingPrompt = false
    }
    
    func requestAppStoreRating() {
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
            userRatedApp() // Assume they rated after showing the system prompt
        }
    }
    
    // MARK: - Private Methods
    
    private func checkIfShouldPromptForRating() {
        // Don't prompt if user already rated
        if UserDefaults.standard.bool(forKey: hasRatedAppKey) {
            return
        }
        
        // Don't prompt if user declined recently
        if hasDeclinedRecently() {
            return
        }
        
        let gameCompletions = UserDefaults.standard.integer(forKey: gameCompletionsKey)
        let appLaunches = UserDefaults.standard.integer(forKey: appLaunchCountKey)
        
        // Check if criteria are met
        if gameCompletions >= minGameCompletions && appLaunches >= minAppLaunches {
            // Add some randomness to avoid being too aggressive
            if shouldPromptBasedOnRandomness() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.shouldShowRatingPrompt = true
                }
            }
        }
    }
    
    private func hasDeclinedRecently() -> Bool {
        guard UserDefaults.standard.bool(forKey: hasDeclinedRatingKey) else {
            return false
        }
        
        guard let lastPromptDate = UserDefaults.standard.object(forKey: lastRatingPromptDateKey) as? Date else {
            return false
        }
        
        let daysSinceLastPrompt = Calendar.current.dateComponents([.day], from: lastPromptDate, to: Date()).day ?? 0
        return daysSinceLastPrompt < daysBetweenPrompts
    }
    
    private func shouldPromptBasedOnRandomness() -> Bool {
        // 100% chance to show prompt when criteria are met (for testing)
        return true
    }
    
    // MARK: - Debug Methods (for testing)
    
    func resetRatingData() {
        UserDefaults.standard.removeObject(forKey: hasRatedAppKey)
        UserDefaults.standard.removeObject(forKey: gameCompletionsKey)
        UserDefaults.standard.removeObject(forKey: appLaunchCountKey)
        UserDefaults.standard.removeObject(forKey: lastRatingPromptDateKey)
        UserDefaults.standard.removeObject(forKey: hasDeclinedRatingKey)
    }
    
    func getCurrentStats() -> (launches: Int, completions: Int, hasRated: Bool) {
        return (
            launches: UserDefaults.standard.integer(forKey: appLaunchCountKey),
            completions: UserDefaults.standard.integer(forKey: gameCompletionsKey),
            hasRated: UserDefaults.standard.bool(forKey: hasRatedAppKey)
        )
    }
}