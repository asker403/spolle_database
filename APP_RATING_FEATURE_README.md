# App Rating System

## Overview
I've implemented an intelligent app rating system that prompts users to rate Spolle on the App Store at optimal times, while respecting user preferences and avoiding being intrusive.

## What's Been Added

### 1. App Rating Manager (`AppRatingManager.swift`)
- **Smart Timing**: Tracks app launches and game completions
- **User Respect**: Remembers if user already rated or declined
- **Cooldown Period**: 30-day wait after user declines
- **Randomization**: 30% chance to show when criteria are met (not too aggressive)

### 2. Rating Prompt View (`RatingPromptView.swift`)
- **Beautiful UI**: Native iOS design with star icon and gradient buttons
- **Multilingual**: Fully localized in all 4 languages
- **User-Friendly**: Clear "Rate" and "Maybe Later" options
- **Smooth Animations**: Elegant appearance with spring animations

### 3. Integrated Tracking
- **App Launch Tracking**: Counts every time the app opens
- **Game Completion Tracking**: Counts when users finish games
- **Persistent Storage**: Uses UserDefaults to remember user choices

## Smart Timing Logic

### 📊 **Criteria for Showing Rating Prompt**
- **Minimum 5 app launches** - User is familiar with the app
- **Minimum 3 completed games** - User has engaged with core functionality
- **User hasn't already rated** - Respects previous rating
- **30 days since last decline** - Doesn't pester users who said "maybe later"
- **30% random chance** - Avoids being too aggressive

### 🎯 **When Rating Prompt Appears**
1. **After Game Completion**: When user finishes a daily game
2. **On Home Screen**: Appears as overlay after meeting criteria
3. **2-second delay**: Gives user time to see their results first

## Multilingual Support

### 🇺🇸 **English**
- "Enjoying Spolle?"
- "If you love playing our daily artist guessing game, please take a moment to rate us on the App Store!"

### 🇹🇷 **Turkish**
- "Spolle'yi Beğeniyor musunuz?"
- "Günlük sanatçı tahmin oyunumuzu seviyorsanız, lütfen App Store'da bizi değerlendirmek için bir dakikanızı ayırın!"

### 🇩🇪 **German**
- "Gefällt Ihnen Spolle?"
- "Wenn Sie unser tägliches Künstler-Ratespiel lieben, nehmen Sie sich bitte einen Moment Zeit, um uns im App Store zu bewerten!"

### 🇫🇷 **French**
- "Vous aimez Spolle?"
- "Si vous adorez jouer à notre jeu de devinettes d'artistes quotidien, prenez un moment pour nous noter sur l'App Store!"

## User Experience Features

### ✅ **Respectful Approach**
- **Never shows twice** if user already rated
- **30-day cooldown** after "Maybe Later"
- **Random timing** prevents predictable interruptions
- **Easy dismissal** - tap outside to close

### 🎨 **Beautiful Design**
- **Star icon** with yellow glow effect
- **Gradient buttons** matching app theme
- **Smooth animations** with spring physics
- **Native iOS feel** following Apple's design guidelines

### 📱 **Smart Integration**
- **Overlay design** doesn't interrupt current flow
- **High z-index** ensures visibility
- **Automatic dismissal** after user action
- **Uses iOS StoreKit** for native rating experience

## Technical Implementation

### 🔧 **Architecture**
```swift
// Track app launches
AppRatingManager.shared.incrementAppLaunch()

// Track game completions
AppRatingManager.shared.incrementGameCompletion()

// Show native iOS rating prompt
AppRatingManager.shared.requestAppStoreRating()
```

### 💾 **Data Persistence**
- `hasRatedApp`: Boolean flag to prevent re-prompting
- `gameCompletions`: Counter for completed games
- `appLaunchCount`: Counter for app opens
- `lastRatingPromptDate`: Date of last "Maybe Later"
- `hasDeclinedRating`: Flag for declined prompts

### 🎲 **Smart Logic**
- **Engagement-based**: Only shows to engaged users
- **Time-sensitive**: Respects user's "maybe later" choice
- **Non-intrusive**: Random chance prevents annoyance
- **One-time**: Never bothers users who already rated

## Benefits

### 📈 **For App Store Ratings**
- **Higher quality ratings** from engaged users
- **Better timing** leads to more positive reviews
- **Respectful approach** reduces negative feedback
- **Multilingual support** reaches global audience

### 👥 **For User Experience**
- **Non-intrusive** - doesn't interrupt gameplay
- **Respectful** - remembers user preferences
- **Beautiful** - matches app's design language
- **Optional** - easy to dismiss or decline

### 🔧 **For Developers**
- **Easy to customize** - adjust criteria in AppRatingManager
- **Debug-friendly** - includes reset and stats methods
- **Maintainable** - clean separation of concerns
- **Extensible** - easy to add new trigger conditions

## Testing & Debug Features

### 🧪 **Debug Methods**
```swift
// Reset all rating data for testing
AppRatingManager.shared.resetRatingData()

// Get current statistics
let stats = AppRatingManager.shared.getCurrentStats()
print("Launches: \(stats.launches), Completions: \(stats.completions)")
```

### ✅ **Tested Scenarios**
- ✅ First-time users don't see prompt immediately
- ✅ Engaged users see prompt at appropriate times
- ✅ Users who rated never see prompt again
- ✅ "Maybe Later" users get 30-day cooldown
- ✅ All languages display correctly
- ✅ Native iOS rating dialog works properly

The app rating system is now fully integrated and will help increase your App Store ratings while maintaining a great user experience!