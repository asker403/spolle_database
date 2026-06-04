//
//  ContentView.swift
//  Spolle
//
//  Created by Ümit BAĞ on 7/2/25.
//

import SwiftUI
import SwiftData
import AVFoundation
import AVFoundation
import AVKit
import GoogleMobileAds



// MARK: - Theme Manager for Dark Mode
class ThemeManager: ObservableObject {
    @Published var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        }
    }
    
    init() {
        self.isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
    }
    
    var colorScheme: ColorScheme {
        return isDarkMode ? .dark : .light
    }
}

// MARK: - Main View (Single Page)
struct MainView: View {
    @StateObject private var themeManager = ThemeManager()
    
    var body: some View {
        HomeView()
            .environmentObject(themeManager)
            .preferredColorScheme(themeManager.colorScheme)
    }
}

// MARK: - Home View (Main Screen)
struct HomeView: View {
    @StateObject private var firestoreService = FirestoreService.shared
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var languageManager = LanguageManager.shared
    @ObservedObject private var ratingManager = AppRatingManager.shared
    @ObservedObject private var adMobManager = AdMobManager.shared
    @State private var showGameView = false
    @State private var showHelpSheet = false
    @State private var showLanguageSelection = false
    
    @State private var isDailyGameCompleted = false
    @State private var gameInstanceId = UUID()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Main Content - Centered
                    VStack {
                        Spacer()
                        
                        VStack(spacing: 40) {
                            // Logo
                            VStack(spacing: 8) {
                                Image("Logo")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 200)
                                    .shadow(color: Color(red: 0.7, green: 0.3, blue: 1.0).opacity(0.3), radius: 10, x: 0, y: 5)
                            }
                            
                            // Title and Subtitle
                            VStack(spacing: 16) {
                                Text(languageManager.localizedString(for: "guess_the_artist"))
                                    .font(.system(size: 36, weight: .bold, design: .default))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                
                                Text(languageManager.localizedString(for: "challenge_yourself"))
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(2)
                            }
                            
                            // Start Button
                            Button(action: {
                                showInterstitialAdAndStartGame()
                            }) {
                                HStack {
                                    if firestoreService.isConnected {
                                        Image(systemName: "music.note")
                                            .font(.system(size: 16, weight: .medium))
                                    }
                                    Text(languageManager.localizedString(for: "start_the_game"))
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 25)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(red: 0.7, green: 0.3, blue: 1.0), Color(red: 0.2, green: 0.6, blue: 1.0)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                                .shadow(color: Color(red: 0.7, green: 0.3, blue: 1.0).opacity(0.3), radius: 10, x: 0, y: 5)
                            }
                            .padding(.horizontal, 40)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 30)
                        
                        // Banner Ad at Bottom
                        AdMobBannerView()
                            .frame(height: 50)
                            .background(Color(.systemGray6))
                    }
                }
                .navigationTitle("")
#if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
#endif
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        HStack(spacing: 12) {
                            Button(action: {
                                themeManager.isDarkMode.toggle()
                            }) {
                                Image(systemName: themeManager.isDarkMode ? "sun.max.fill" : "moon.fill")
                                    .font(.title2)
                                    .foregroundColor(themeManager.isDarkMode ? .orange : .blue)
                            }
                            
                            Button(action: {
                                showLanguageSelection = true
                            }) {
                                HStack(spacing: 4) {
                                    Text(languageManager.currentLanguage.flag)
                                        .font(.system(size: 16))
                                    Image(systemName: "globe")
                                        .font(.system(size: 16))
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        // Help Button
                        Button(action: {
                            showHelpSheet = true
                        }) {
                            Image(systemName: "questionmark.circle")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showGameView) {
                GameView(isDailyGameCompleted: $isDailyGameCompleted, showGameView: $showGameView)
                    .id(gameInstanceId)
            }
            .sheet(isPresented: $showHelpSheet) {
                HelpView()
            }
            .sheet(isPresented: $showLanguageSelection) {
                LanguageSelectionView()
            }
            
            .overlay(
                // Rating prompt overlay
                Group {
                    if ratingManager.shouldShowRatingPrompt {
                        RatingPromptView()
                            .transition(.opacity.combined(with: .scale))
                            .zIndex(1000)
                    }
                }
            )
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("StartNewGameInstance"))) { _ in
                gameInstanceId = UUID()
            }
        }
    }
}
    // MARK: - HomeView Extensions
    extension HomeView {
        private func showInterstitialAdAndStartGame() {
            guard let rootViewController = getRootViewController() else {
                // If can't get root view controller, proceed without ad
                gameInstanceId = UUID()
                showGameView = true
                return
            }
            
            adMobManager.showInterstitialAd(from: rootViewController) {
                // This closure is called when the ad is dismissed or if ad fails to load
                DispatchQueue.main.async {
                    self.gameInstanceId = UUID()
                    self.showGameView = true
                }
            }
        }
    }
    
    // MARK: - Game View
    struct GameView: View {
        @Environment(\.dismiss) private var dismiss
        @Environment(\.modelContext) private var modelContext
        @ObservedObject private var languageManager = LanguageManager.shared
        @Binding var isDailyGameCompleted: Bool
        @State private var gameManager: GameManager?
        @State private var searchText = ""
        @State private var showSuccessView = false
        @State private var searchResults: [Artist] = []
        @State private var showSearchResults = false
        @State private var animateHints = false
        @State private var refreshID = UUID()
        @FocusState private var isTextFieldFocused: Bool
        @Binding var showGameView: Bool
        
        var body: some View {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemGray6).opacity(0.3)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with Close Button
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.primary)
                                .frame(width: 32, height: 32)
                                .background(Color(.systemGray5))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    ScrollView {
                        VStack(spacing: 32) {
                            // Title Section
                            VStack(spacing: 12) {
                                Text(languageManager.localizedString(for: "guess_the_artist"))
                                    .font(.system(size: 32, weight: .bold, design: .default))
                                    .foregroundColor(.primary)
                                    .opacity(animateHints ? 1 : 0)
                                    .offset(y: animateHints ? 0 : -20)
                                    .animation(.easeOut(duration: 0.8).delay(0.1), value: animateHints)
                                
                                Text(languageManager.localizedString(for: "guess_daily_artist_spotify"))
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .opacity(animateHints ? 1 : 0)
                                    .offset(y: animateHints ? 0 : -20)
                                    .animation(.easeOut(duration: 0.8).delay(0.2), value: animateHints)
                            }
                            .padding(.top, 20)
                            
                            // Input Section
                            VStack(spacing: 16) {
                                // Search Bar
                                VStack(alignment: .leading, spacing: 0) {
                                    HStack(spacing: 12) {
                                        TextField(languageManager.localizedString(for: "enter_your_guess"), text: $searchText)
                                            .font(.system(size: 16, weight: .medium))
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 16)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(25)
                                            .focused($isTextFieldFocused)
                                            .onChange(of: searchText) { _, newValue in
                                                updateSearchResults(newValue)
                                            }
                                            .onSubmit {
                                                submitGuess()
                                            }
                                            .opacity(animateHints ? 1 : 0)
                                            .offset(y: animateHints ? 0 : 20)
                                            .animation(.easeOut(duration: 0.8).delay(0.3), value: animateHints)
                                    }
                                    
                                    // Search Results Dropdown
                                    if showSearchResults && !searchResults.isEmpty {
                                        VStack(spacing: 0) {
                                            ForEach(searchResults, id: \.id) { artist in
                                                Button(action: {
                                                    searchText = artist.name
                                                    showSearchResults = false
                                                }) {
                                                    HStack {
                                                        Text(artist.name)
                                                            .font(.system(size: 16, weight: .medium))
                                                            .foregroundColor(.primary)
                                                        Spacer()
                                                    }
                                                    .padding(.horizontal, 20)
                                                    .padding(.vertical, 12)
                                                    .background(Color(.systemBackground))
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                                
                                                if artist.id != searchResults.last?.id {
                                                    Divider()
                                                        .padding(.horizontal, 20)
                                                }
                                            }
                                        }
                                        .background(Color(.systemBackground))
                                        .cornerRadius(12)
                                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                        .padding(.top, 8)
                                    }
                                }
                                
                                // Submit Button
                                Button(action: submitGuess) {
                                    Text(languageManager.localizedString(for: "submit_guess"))
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(submitButtonBackground)
                                        .scaleEffect(searchText.isEmpty ? 0.98 : 1.0)
                                        .animation(.easeInOut(duration: 0.2), value: searchText.isEmpty)
                                }
                                .disabled(searchText.isEmpty)
                                .opacity(animateHints ? 1 : 0)
                                .offset(y: animateHints ? 0 : 20)
                                .animation(.easeOut(duration: 0.8).delay(0.4), value: animateHints)
                            }
                            .padding(.horizontal, 20)
                            
                            // Remaining Guesses or Game Result
                            if let game = gameManager?.currentGame {
                                if game.isCompleted {
                                    // Show the answer prominently when game is over
                                    VStack(spacing: 12) {
                                        HStack(spacing: 12) {
                                            Image(systemName: game.isWon ? "checkmark.circle.fill" : "xmark.circle.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(game.isWon ? .green : .red)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(game.isWon ? languageManager.localizedString(for: "correct_celebration") : languageManager.localizedString(for: "game_over"))
                                                    .font(.system(size: 18, weight: .bold))
                                                    .foregroundColor(game.isWon ? .green : .primary)
                                                
                                                if let targetArtist = gameManager?.targetArtist {
                                                    let messageKey = game.isWon ? "you_guessed" : "answer_was"
                                                    let message = languageManager.localizedString(for: messageKey)
                                                    Text(String(format: message, targetArtist.name))
                                                        .font(.system(size: 16, weight: .medium))
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            Button(languageManager.localizedString(for: "view_result")) {
                                                showSuccessView = true
                                            }
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .fill(Color.blue)
                                            )
                                        }
                                    }
                                    .padding(16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(game.isWon ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(game.isWon ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                    .padding(.horizontal, 20)
                                    .opacity(animateHints ? 1 : 0)
                                    .offset(y: animateHints ? 0 : 20)
                                    .animation(.easeOut(duration: 0.8).delay(0.5), value: animateHints)
                                } else {
                                    Text("\(languageManager.localizedString(for: "remaining_guesses")): \(game.attemptsRemaining)")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .opacity(animateHints ? 1 : 0)
                                        .offset(y: animateHints ? 0 : 20)
                                        .animation(.easeOut(duration: 0.8).delay(0.5), value: animateHints)
                                }
                            }
                            
                            
                            
                            // Previous Guesses
                            if let game = gameManager?.currentGame, !game.currentGuesses.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(languageManager.localizedString(for: "your_guesses"))
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(.primary)
                                        
                                        HStack(spacing: 12) {
                                            Text("\(languageManager.localizedString(for: "correct"))  \(languageManager.localizedString(for: "close_match"))  \(languageManager.localizedString(for: "wrong"))")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.secondary)
                                            
                                            Spacer()
                                            
                                            Text(languageManager.localizedString(for: "latest_guess_first"))
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.secondary.opacity(0.8))
                                                .italic()
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    
                                    // Display guesses in reverse chronological order (newest first)
                                    // Sort by timestamp to ensure proper ordering, then use stable IDs
                                    ForEach(Array(game.currentGuesses.sorted(by: { $0.timestamp < $1.timestamp }).enumerated().reversed()), id: \.element.id) { (displayIndex, guess) in
                                        let sortedGuesses = game.currentGuesses.sorted(by: { $0.timestamp < $1.timestamp })
                                        let guessNumber = (sortedGuesses.firstIndex(where: { $0.id == guess.id }) ?? 0) + 1
                                        let latestGuess = sortedGuesses.last
                                        let isLatest = guess.id == latestGuess?.id
                                        
                                        // Debug logging for guess ordering in Daily Game
                                        let _ = print("🎯 Daily Game - Displaying guess: guessNumber=\(guessNumber), artist=\(guess.artistName), isLatest=\(isLatest), totalGuesses=\(game.currentGuesses.count), id=\(guess.id), timestamp=\(guess.timestamp)")
                                        
                                        PreviousGuessView(guess: guess, index: guessNumber, isLatest: isLatest)
                                            .padding(.horizontal, 20)
                                    }
                                }
                            }
                            
                            Spacer(minLength: 40)
                        }
                    }
                }
            }
            .onAppear {
                print("🎮 GameView onAppear triggered")
                
                // Clear any potential input issues by resetting the search text and focus
                searchText = ""
                showSearchResults = false
                isTextFieldFocused = false
                
                // Force a slight delay to ensure UI is settled before setting up game
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Only create GameManager if we don't have one, or ensure existing game is properly loaded
                    if gameManager == nil {
                        print("🎮 GameView appeared - creating new GameManager")
                        gameManager = GameManager(modelContext: modelContext, gameType: .daily)
                    } else {
                        print("🎮 GameView appeared - GameManager exists, ensuring game state is loaded")
                        // Ensure the existing GameManager has the right context and current game loaded
                        gameManager?.setModelContext(modelContext)
                        
                        // Double-check that we have a valid game loaded
                        if gameManager?.currentGame == nil {
                            print("⚠️ No current game found, setting up daily game")
                            gameManager?.setupDailyGame()
                        }
                    }
                    
                    // Verify we have a valid setup
                    if let game = gameManager?.currentGame, let target = gameManager?.targetArtist {
                        print("✅ Game state verified: date=\(game.dateString), target=\(target.name), completed=\(game.isCompleted), guesses=\(game.currentGuesses.count)")
                        
                        // Update the completion status
                        isDailyGameCompleted = game.isCompleted
                    } else {
                        print("⚠️ Game state incomplete after setup")
                    }
                }
                
                // Trigger animations
                withAnimation {
                    animateHints = true
                }
            }
            .sheet(isPresented: $showSuccessView) {
                if let targetArtist = gameManager?.targetArtist {
                    SuccessView(
                        artist: targetArtist,
                        isWon: gameManager?.currentGame?.isWon ?? false,
                        isDailyGameCompleted: $isDailyGameCompleted,
                        gameManager: gameManager,
                        showGameView: $showGameView
                    )
                }
            }
            .onTapGesture {
                showSearchResults = false
            }
            .onChange(of: gameManager?.currentGame?.isCompleted) { _, isCompleted in
                if let isCompleted = isCompleted {
                    isDailyGameCompleted = isCompleted
                    
                    // Dismiss keyboard when game is completed
                    if isCompleted {
                        isTextFieldFocused = false
                        AppRatingManager.shared.incrementGameCompletion()
                    }
                }
            }
            .id(refreshID)
        }
        
        // MARK: - Computed Properties
        private var submitButtonBackground: some View {
            let isDisabled = searchText.isEmpty
            
            return RoundedRectangle(cornerRadius: 25)
                .fill(
                    LinearGradient(
                        colors: isDisabled
                        ? [Color.gray.opacity(0.6), Color.gray.opacity(0.4)]
                        : [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        
        private func updateSearchResults(_ query: String) {
            if query.isEmpty {
                searchResults = []
                showSearchResults = false
            } else {
                searchResults = gameManager?.searchArtists(query: query) ?? []
                showSearchResults = !searchResults.isEmpty
            }
        }
        
        private func submitGuess() {
            guard !searchText.isEmpty else { return }
            
            // Dismiss keyboard immediately when guess is submitted
            isTextFieldFocused = false
            
            Task {
                if (await gameManager?.submitGuess(searchText)) != nil {
                    await MainActor.run {
                        searchText = ""
                        showSearchResults = false
                        
                        // Show success view when game ends (win or lose) after a brief delay
                        if gameManager?.currentGame?.isCompleted == true {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                showSuccessView = true
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Previous Guess View
    struct PreviousGuessView: View {
        let guess: Guess
        let index: Int
        let isLatest: Bool
        @ObservedObject private var languageManager = LanguageManager.shared
        @State private var showHints = false
        
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                // Guess Header
                HStack(spacing: 12) {
                    // Index with Latest Badge
                    HStack(spacing: 8) {
                        Text("\(index).")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        if isLatest {
                            Text(languageManager.localizedString(for: "latest"))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.blue)
                                )
                                .scaleEffect(0.9)
                        }
                    }
                    
                    // Artist Image
                    Group {
                        if let imageURL = guess.artistImageURL {
                            AsyncImage(url: URL(string: imageURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .tint(.blue)
                                    )
                            }
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(guess.isCorrect ? Color.green.opacity(0.6) : Color.red.opacity(0.4), lineWidth: 2.5)
                            )
                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                            .animation(.easeIn(duration: 0.3), value: imageURL)
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 56, height: 56)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(.secondary)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(guess.isCorrect ? Color.green.opacity(0.6) : Color.red.opacity(0.4), lineWidth: 2.5)
                                )
                                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                        }
                    }
                    
                    // Artist Name
                    Text(guess.artistName)
                        .font(.system(size: 18, weight: isLatest ? .bold : .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Result Icon
                    if guess.isCorrect {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 22))
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 22))
                    }
                }
                
                // Hint Cards
                if showHints {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                        ForEach(Array(guess.hints.keys.sorted()), id: \.self) { key in
                            if let hintData = guess.hints[key] {
                                GuessHintCard(
                                    icon: getIconForHint(key),
                                    title: languageManager.localizedString(for: key),
                                    value: getValueFromHint(hintData),
                                    matchType: getMatchTypeFromHint(hintData),
                                    animationDelay: Double(Array(guess.hints.keys.sorted()).firstIndex(of: key) ?? 0) * 0.1,
                                    comparisonIndicator: getComparisonIndicator(key: key, hintData: hintData)
                                )
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isLatest ? Color.blue.opacity(0.05) : Color(.systemGray6).opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isLatest ? Color.blue.opacity(0.2) : Color.clear, lineWidth: 1)
                    )
            )
            .scaleEffect(isLatest ? 1.02 : 1.0)
            .shadow(color: .black.opacity(isLatest ? 0.1 : 0.05), radius: isLatest ? 6 : 3, x: 0, y: 2)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isLatest)
            .onAppear {
                if isLatest {
                    // Animate latest guess entry
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        // Trigger any appearance animations
                    }
                    // Auto-show hints for latest guess after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeOut(duration: 0.5)) {
                            showHints = true
                        }
                    }
                }
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showHints.toggle()
                }
            }
        }
        
        private func getIconForHint(_ key: String) -> String {
            switch key {
            case "Genre": return "music.note"
            case "Country": return "globe"
            case "Debut Year": return "calendar"
            case "Gender": return "person"
            case "Type": return "person.2"
            case "Popularity": return "chart.bar.fill"
            default: return "questionmark"
            }
        }
        
        private func getValueFromHint(_ hint: String) -> String {
            // Handle new format with "|" separator
            if hint.contains("|") {
                return String(hint.split(separator: "|").first ?? "")
            }
            
            // Handle old format (e.g., "Not Very High", "❌ Not Pop")
            if hint.hasPrefix("❌ Not ") {
                return String(hint.dropFirst(6)) // Remove "❌ Not "
            } else if hint.hasPrefix("Not ") {
                return String(hint.dropFirst(4)) // Remove "Not "
            }
            
            return hint
        }
        
        private func getMatchTypeFromHint(_ hint: String) -> HintMatchType {
            // Handle new format with "|" separator
            if hint.contains("|") {
                let parts = hint.split(separator: "|")
                if parts.count > 1 {
                    switch String(parts[1]) {
                    case "correct": return .correct
                    case "close": return .close
                    default: return .incorrect
                    }
                }
            }
            
            // Handle old format - if it has "Not" or "❌", it's incorrect
            if hint.contains("Not ") || hint.contains("❌") {
                return .incorrect
            }
            
            // If it doesn't have separators or negative indicators, assume correct
            return .correct
        }
        
        private func getComparisonIndicator(key: String, hintData: String) -> String? {
            // Only show comparison indicators for debut year and popularity
            guard key == "Debut Year" || key == "Popularity" else { return nil }
            
            // Handle new format with "|" separator
            if hintData.contains("|") {
                let parts = hintData.split(separator: "|")
                if parts.count > 2 {
                    let comparison = String(parts[2])
                    if comparison == "higher" {
                        return "Higher"
                    } else if comparison == "lower" {
                        return "Lower"
                    }
                }
            }
            
            // Handle old format - extract comparison from hint text
            if key == "Debut Year" {
                if hintData.contains("Higher") {
                    return "Higher"
                } else if hintData.contains("Lower") {
                    return "Lower"
                }
            } else if key == "Popularity" {
                if hintData.contains("Higher") {
                    return "Higher"
                } else if hintData.contains("Lower") {
                    return "Lower"
                }
            }
            
            return nil
        }
    }
    
    // MARK: - Guess Hint Card
    struct GuessHintCard: View {
        let icon: String
        let title: String
        let value: String
        let matchType: HintMatchType
        let animationDelay: Double
        let comparisonIndicator: String? // New parameter for higher/lower indicators
        @State private var isVisible = false
        @State private var scale = 0.8
        
        var body: some View {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(matchType.iconColor)
                    .frame(width: 20, height: 20)
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text(value)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    // Show comparison indicator for debut year and popularity
                    if let indicator = comparisonIndicator {
                        HStack(spacing: 2) {
                            Image(systemName: indicator == "Higher" ? "chevron.up" : "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(indicatorColor)
                            
                            Text(indicator)
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(indicatorColor)
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(indicatorColor.opacity(0.2))
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90) // Fixed height for consistent design
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(matchType.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(matchType.borderColor, lineWidth: 2)
                    )
            )
            .scaleEffect(scale)
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6).delay(animationDelay)) {
                    isVisible = true
                    scale = 1.0
                }
            }
        }
        
        private var indicatorColor: Color {
            if let indicator = comparisonIndicator {
                if indicator.contains("Higher") {
                    return .red
                } else if indicator.contains("Lower") {
                    return .blue
                }
            }
            return .secondary
        }
    }
    
    // MARK: - Hint Match Type
    enum HintMatchType {
        case correct
        case close
        case incorrect
        
        var backgroundColor: Color {
            switch self {
            case .correct: return .green.opacity(0.2)
            case .close: return .yellow.opacity(0.2)
            case .incorrect: return .gray.opacity(0.1)
            }
        }
        
        var borderColor: Color {
            switch self {
            case .correct: return .green.opacity(0.6)
            case .close: return .yellow.opacity(0.6)
            case .incorrect: return .gray.opacity(0.3)
            }
        }
        
        var iconColor: Color {
            switch self {
            case .correct: return .green
            case .close: return .orange
            case .incorrect: return .gray
            }
        }
    }
    
    // MARK: - Success View
    struct SuccessView: View {
        @Environment(\.dismiss) private var dismiss
        @ObservedObject private var languageManager = LanguageManager.shared
        @ObservedObject private var ratingManager = AppRatingManager.shared
        @ObservedObject private var adMobManager = AdMobManager.shared
        let artist: Artist
        let isWon: Bool
        @Binding var isDailyGameCompleted: Bool
        let gameManager: GameManager?
        @Binding var showGameView: Bool
        
        // Convenience initializer for backward compatibility
        init(artistName: String, isWon: Bool, isDailyGameCompleted: Binding<Bool>, gameManager: GameManager?, showGameView: Binding<Bool>) {
            self.artist = Artist(
                id: "temp-\(UUID().uuidString)",
                name: artistName,
                gender: "Unknown",
                country: "Unknown",
                debutYear: 2000,
                genre: "Unknown",
                isSolo: true,
                spotifyPopularity: 50
            )
            self.isWon = isWon
            self._isDailyGameCompleted = isDailyGameCompleted
            self.gameManager = gameManager
            self._showGameView = showGameView
        }
        
        // Primary initializer with Artist object
        init(artist: Artist, isWon: Bool, isDailyGameCompleted: Binding<Bool>, gameManager: GameManager?, showGameView: Binding<Bool>) {
            self.artist = artist
            self.isWon = isWon
            self._isDailyGameCompleted = isDailyGameCompleted
            self.gameManager = gameManager
            self._showGameView = showGameView
        }
        
        @State private var artistImageURL: String?
        @State private var isLoadingData = true
        @State private var audioPlayer: AVPlayer?
        @State private var isPlayingAudio = false
        @State private var audioLoadError: String?
        
        var body: some View {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemGray6).opacity(0.3)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // Reset Button (Top Right) - Fixed positioning
                VStack {
                    HStack {
                        Spacer()
                        Button(action: showInterstitialAdAndReset) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 18, weight: .medium))
                                Text(languageManager.localizedString(for: "new_game"))
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(red: 0.7, green: 0.3, blue: 1.0), Color(red: 0.2, green: 0.6, blue: 1.0)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .shadow(color: Color(red: 0.7, green: 0.3, blue: 1.0).opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .padding(.trailing, 16)
                    }
                    .padding(.top, 16)
                    Spacer()
                }
                .safeAreaInset(edge: .top) { Color.clear.frame(height: 0) }
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    // Success/Failure Animation
                    Image(systemName: isWon ? "checkmark.circle.fill" : "x.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(isWon ? .green : .red)
                        .scaleEffect(1.2)
                        .animation(.bouncy, value: true)
                    
                    VStack(spacing: 10) {
                        Text(isWon ? languageManager.localizedString(for: "congratulations") : languageManager.localizedString(for: "game_over"))
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text({
                            let messageKey = isWon ? "you_guessed" : "the_artist_was"
                            return String(format: languageManager.localizedString(for: messageKey), artist.name)
                        }())
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    }
                    
                    // Artist Image and Info
                    VStack(spacing: 20) {
                        // Artist Image
                        Group {
                            if isLoadingData {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 200, height: 200)
                                    .overlay(
                                        ProgressView()
                                            .scaleEffect(1.5)
                                            .tint(.blue)
                                    )
                            } else if let imageURL = artistImageURL {
                                AsyncImage(url: URL(string: imageURL)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.3))
                                        .overlay(
                                            ProgressView()
                                                .scaleEffect(1.2)
                                                .tint(.blue)
                                        )
                                }
                                .frame(width: 200, height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 200, height: 200)
                                    .overlay(
                                        VStack(spacing: 8) {
                                            Image(systemName: "person.circle")
                                                .font(.system(size: 50))
                                                .foregroundColor(.gray)
                                            Text(languageManager.localizedString(for: "no_image"))
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    )
                            }
                        }
                        
                        // Artist Info
                        VStack(spacing: 8) {
                            Text("\(languageManager.localizedString(for: "genre_label")): \(artist.genre)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text("\(languageManager.localizedString(for: "country_label")): \(artist.country)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text("\(languageManager.localizedString(for: "debut_year_label")): \(formattedDebutYear)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            // Audio Preview Button
                            if let previewURL = artist.previewURL, !previewURL.isEmpty {
                                Button(action: toggleAudioPlayback) {
                                    HStack(spacing: 8) {
                                        Image(systemName: isPlayingAudio ? "pause.fill" : "play.fill")
                                            .font(.system(size: 16))
                                        Text(isPlayingAudio ? languageManager.localizedString(for: "pause_preview") : languageManager.localizedString(for: "play_preview"))
                                            .font(.system(size: 16, weight: .medium))
                                    }
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(20)
                                }
                                .disabled(audioLoadError != nil)
                            }
                            
                            // Audio Error Message
                            if let errorMessage = audioLoadError {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    }
                    
                    Spacer()
                    
                    Button(languageManager.localizedString(for: "close")) {
                        dismiss()
                    }
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.blue, lineWidth: 2)
                    )
                    .padding(.horizontal, 40)
                }
                .padding()
            }
            .onAppear {
                loadArtistData()
            }
            .onDisappear {
                stopAudioPlayback()
            }
        }
        
        // MARK: - Computed Properties
        private var formattedDebutYear: String {
            // Ensure debut year is formatted as a proper integer year
            let year = max(1900, min(2025, artist.debutYear)) // Clamp to reasonable range
            return String(year)
        }
        
        // MARK: - Helper Methods
        private func loadArtistData() {
            print("🎵 Loading artist data for: \(artist.name)")
            print("🎵 Artist previewURL: \(artist.previewURL ?? "nil")")
            
            // Load image URL if available from Firestore
            if let storedImageURL = artist.imageURL, !storedImageURL.isEmpty {
                // Validate URL format
                if storedImageURL.hasPrefix("http") || storedImageURL.hasPrefix("https") {
                    artistImageURL = storedImageURL
                    print("🖼️ Set artist image URL: \(storedImageURL)")
                }
            }
            
            // Initialize audio player if preview URL is available
            if let previewURL = artist.previewURL, !previewURL.isEmpty {
                print("🎵 Setting up audio player with URL: \(previewURL)")
                setupAudioPlayer(with: previewURL)
            } else {
                print("🎵 No preview URL available for artist: \(artist.name)")
            }
            
            isLoadingData = false
        }
        
        private func setupAudioPlayer(with urlString: String) {
            guard let url = URL(string: urlString) else {
                audioLoadError = "Invalid audio URL"
                return
            }
            
            audioPlayer = AVPlayer(url: url)
            audioLoadError = nil
            
            // Add observer for playback completion
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: audioPlayer?.currentItem,
                queue: .main
            ) { _ in
                isPlayingAudio = false
            }
        }
        
        private func toggleAudioPlayback() {
            guard let player = audioPlayer else { return }
            
            if isPlayingAudio {
                player.pause()
                isPlayingAudio = false
            } else {
                player.play()
                isPlayingAudio = true
            }
        }
        
        private func stopAudioPlayback() {
            audioPlayer?.pause()
            audioPlayer = nil
            isPlayingAudio = false
            NotificationCenter.default.removeObserver(self)
        }
        
        private func showInterstitialAdAndReset() {
            guard let rootViewController = getRootViewController() else {
                // If can't get root view controller, proceed without ad
                resetGame()
                return
            }
            
            adMobManager.showInterstitialAd(from: rootViewController) {
                // This closure is called when the ad is dismissed or if ad fails to load
                DispatchQueue.main.async {
                    self.resetGame()
                }
            }
        }
        
        private func resetGame() {
            // Reset the daily game completion state
            isDailyGameCompleted = false
            
            // Reset the game in GameManager
            gameManager?.resetGame()
            
            // Dismiss the success view and immediately present the new game
            dismiss()
            
            // Present the new game view after a short delay to ensure dismissal is complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Use NotificationCenter to notify HomeView to update gameInstanceId
                NotificationCenter.default.post(name: Notification.Name("StartNewGameInstance"), object: nil)
                showGameView = true
            }
        }
    }
    
    // MARK: - Help View
    struct HelpView: View {
        @Environment(\.dismiss) private var dismiss
        @ObservedObject private var languageManager = LanguageManager.shared
        
        var body: some View {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(languageManager.localizedString(for: "how_to_play"))
                            .font(.title)
                            .fontWeight(.bold)
                            .padding(.bottom)
                        
                        VStack(alignment: .leading, spacing: 15) {
                            HelpSectionView(
                                title: languageManager.localizedString(for: "objective"),
                                description: languageManager.localizedString(for: "objective_description")
                            )
                            
                            HelpSectionView(
                                title: languageManager.localizedString(for: "hints"),
                                description: languageManager.localizedString(for: "hints_description")
                            )
                            
                            HelpSectionView(
                                title: languageManager.localizedString(for: "color_coding"),
                                description: languageManager.localizedString(for: "color_coding_description")
                            )
                            
                            HelpSectionView(
                                title: languageManager.localizedString(for: "daily_challenge"),
                                description: languageManager.localizedString(for: "daily_challenge_description")
                            )
                        }
                    }
                    .padding()
                }
                .navigationTitle(languageManager.localizedString(for: "help"))
#if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
#endif
                .toolbar {
#if os(iOS)
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(languageManager.localizedString(for: "done")) {
                            dismiss()
                        }
                    }
#else
                    ToolbarItem(placement: .primaryAction) {
                        Button(languageManager.localizedString(for: "done")) {
                            dismiss()
                        }
                    }
#endif
                }
            }
        }
    }
    
    // MARK: - Help Section View
    struct HelpSectionView: View {
        let title: String
        let description: String
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    // MARK: - Previews
    struct ContentView_Previews: PreviewProvider {
        static var previews: some View {
            MainView()
        }
    }
