//
//  ContentView.swift
//  songle
//
//  Created by Ümit BAĞ on 7/2/25.
//

import SwiftUI
import SwiftData
import AVFoundation
import AVKit

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

// MARK: - Main View with Bottom Navigation
struct MainView: View {
    @State private var selectedTab = 0
    @StateObject private var themeManager = ThemeManager()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                }
                .tag(0)
            
            MusicView()
                .tabItem {
                    Image(systemName: "music.note")
                }
                .tag(1)
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle")
                }
                .tag(2)
        }
        .accentColor(.blue)
        .environmentObject(themeManager)
        .preferredColorScheme(themeManager.colorScheme)
    }
}

// MARK: - Home View (Main Screen)
struct HomeView: View {
    @StateObject private var spotifyService = SpotifyService.shared
    @State private var showGameView = false
    @State private var showHelpSheet = false
    @State private var showSpotifySetup = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    Spacer(minLength: 60)
                    
                    // Main Content
                    VStack(spacing: 30) {
                        // Title
                        Text("Guess the Artist")
                            .font(.system(size: 36, weight: .bold, design: .default))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        // Subtitle
                        Text("Challenge yourself with a new artist every day.\nCan you guess who it is?")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                    
                    Spacer()
                    
                    // Start Button
                    Button(action: {
                        showGameView = true
                    }) {
                        HStack {
                            if spotifyService.isAuthenticated {
                                Image(systemName: "music.note")
                                    .font(.system(size: 16, weight: .medium))
                            }
                        Text("Start Daily Guess")
                            .font(.system(size: 18, weight: .semibold))
                            if spotifyService.isAuthenticated {
                                Text("(Spotify)")
                                    .font(.system(size: 14, weight: .medium))
                                    .opacity(0.8)
                            }
                        }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                .fill(
                                    spotifyService.isAuthenticated 
                                    ? LinearGradient(colors: [Color.green, Color.blue], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [Color.blue, Color.blue], startPoint: .leading, endPoint: .trailing)
                                )
                            )
                            .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .padding(.horizontal, 40)
                    
                    // Spotify Setup Button
                    if !spotifyService.isAuthenticated {
                        Button(action: {
                            showSpotifySetup = true
                        }) {
                            HStack {
                                Image(systemName: "music.note.house")
                                    .font(.system(size: 16, weight: .medium))
                                Text("Connect Spotify")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 22)
                                    .stroke(Color.green, lineWidth: 1.5)
                            )
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 16)
                    }
                    
                    // Spotify Status and Refresh
                    HStack {
                        if spotifyService.isAuthenticated {
                            Text("🎵 Spotify Connected")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Text("🎵 Offline Mode")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        Button(action: {
                            print("🔄 Manual Spotify refresh triggered")
                            Task {
                                await spotifyService.reloadCredentialsAndAuthenticate()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 12)
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 30)
            }
            .navigationTitle("Daily Guess")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
            GameView()
        }
        .sheet(isPresented: $showHelpSheet) {
            HelpView()
        }
        .sheet(isPresented: $showSpotifySetup) {
            SpotifySetupView()
        }
    }
}

// MARK: - Game View
struct GameView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var gameManager: GameManager?
    @State private var searchText = ""
    @State private var showSuccessView = false
    @State private var searchResults: [Artist] = []
    @State private var showSearchResults = false
    @State private var animateHints = false
    @State private var refreshID = UUID()
    
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
                    
                    Button("Reset") {
                        print("🔴 Reset button tapped")
                        
                        // Reset UI state immediately
                        animateHints = false
                        searchText = ""
                        showSearchResults = false
                        
                        // Perform the game reset
                        gameManager?.resetTodaysGame()
                        
                        // Force view refresh and restart animations
                        refreshID = UUID()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                animateHints = true
                            }
                        }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                    }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Title Section
                        VStack(spacing: 12) {
                            Text("Guess the Artist")
                                .font(.system(size: 32, weight: .bold, design: .default))
                                .foregroundColor(.primary)
                                .opacity(animateHints ? 1 : 0)
                                .offset(y: animateHints ? 0 : -20)
                                .animation(.easeOut(duration: 0.8).delay(0.1), value: animateHints)
                            
                            Text("Guess the daily artist from Spotify")
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
                                    TextField("Enter your guess", text: $searchText)
                                        .font(.system(size: 16, weight: .medium))
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 16)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(25)
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
                                Text("Submit Guess")
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
                
                        // Remaining Guesses
                        if let game = gameManager?.currentGame {
                            Text("Remaining Guesses: \(game.attemptsRemaining)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                                .opacity(animateHints ? 1 : 0)
                                .offset(y: animateHints ? 0 : 20)
                                .animation(.easeOut(duration: 0.8).delay(0.5), value: animateHints)
                        }
                        

                        
                        // Previous Guesses
                        if let game = gameManager?.currentGame, !game.currentGuesses.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Your Guesses")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.primary)
                                    
                                    Text("🟢 Correct  🟡 Close  ⚪ Wrong")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 20)
                                
                                // Display guesses in reverse chronological order (newest first)
                                ForEach(0..<game.currentGuesses.count, id: \.self) { index in
                                    let reverseIndex = game.currentGuesses.count - 1 - index
                                    let guess = game.currentGuesses[reverseIndex]
                                    let guessNumber = reverseIndex + 1
                                    PreviousGuessView(guess: guess, index: guessNumber)
                                        .padding(.horizontal, 20)
                                }
                            }
                        }
                        
                        // Game Over Message
                        if let game = gameManager?.currentGame, game.isCompleted {
                            GameOverView(
                                isWon: game.isWon,
                                targetArtist: gameManager?.targetArtist,
                                onViewResult: { showSuccessView = true }
                            )
                            .padding(.horizontal, 20)
                        }
                        
                        Spacer(minLength: 40)
                    }
                }
            }
        }
        .onAppear {
            // Always create fresh GameManager to ensure clean state
            print("🎮 GameView appeared - creating fresh GameManager")
            gameManager = GameManager(modelContext: modelContext)
            
            // Trigger animations
            withAnimation {
                animateHints = true
            }
        }
        .fullScreenCover(isPresented: $showSuccessView) {
            if let targetArtist = gameManager?.targetArtist {
                SuccessView(
                    artist: targetArtist,
                    isWon: gameManager?.currentGame?.isWon ?? false
                )
            }
        }
        .onTapGesture {
            showSearchResults = false
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
        
        Task {
            if let guess = await gameManager?.submitGuess(searchText) {
                await MainActor.run {
                    searchText = ""
                    showSearchResults = false
                    
                    if guess.isCorrect {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
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
    @State private var showHints = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Guess Header
            HStack(spacing: 12) {
                // Index
                Text("\(index).")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
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
                    .font(.system(size: 18, weight: .bold))
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
                                title: key,
                                value: getValueFromHint(hintData),
                                matchType: getMatchTypeFromHint(hintData),
                                animationDelay: Double(Array(guess.hints.keys.sorted()).firstIndex(of: key) ?? 0) * 0.1
                            )
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showHints = true
                }
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
}

// MARK: - Guess Hint Card
struct GuessHintCard: View {
    let icon: String
    let title: String
    let value: String
    let matchType: HintMatchType
    let animationDelay: Double
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
        }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
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

// MARK: - Game Over View
struct GameOverView: View {
    let isWon: Bool
    let targetArtist: Artist?
    let onViewResult: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isWon ? "party.popper.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(isWon ? .green : .orange)
            
            VStack(spacing: 8) {
                Text(isWon ? "🎉 Congratulations!" : "Game Over!")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(isWon ? .green : .primary)
                
                if let targetArtist = targetArtist {
                    Text(isWon ? "You guessed \(targetArtist.name)!" : "The answer was: \(targetArtist.name)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Button("View Result") {
                onViewResult()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Success View
struct SuccessView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var spotifyService = SpotifyService.shared
    let artist: Artist
    let isWon: Bool
    
    // Convenience initializer for backward compatibility
    init(artistName: String, isWon: Bool) {
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
    }
    
    // Primary initializer with Artist object
    init(artist: Artist, isWon: Bool) {
        self.artist = artist
        self.isWon = isWon
    }
    
    @State private var artistImageURL: String?
    @State private var previewURL: String?
    @State private var isLoadingData = true
    @State private var audioPlayer: AVPlayer?
    @State private var isPlaying = false
    @State private var trackName: String?
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6).opacity(0.3)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
        VStack(spacing: 30) {
            Spacer()
            
            // Success/Failure Animation
            Image(systemName: isWon ? "checkmark.circle.fill" : "x.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(isWon ? .green : .red)
                .scaleEffect(1.2)
                .animation(.bouncy, value: true)
            
            VStack(spacing: 10) {
                Text(isWon ? "Congratulations!" : "Game Over!")
                    .font(.title)
                    .fontWeight(.bold)
                
                    Text(isWon ? "You guessed \(artist.name)!" : "The artist was \(artist.name)")
                    .font(.title2)
                    .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
            }
            
                // Artist Image and Music Preview
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
                                    VStack {
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                                        Text("No Image")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                )
                        }
                    }
                    
                    // Music Preview Controls
                    if let previewURL = previewURL, let trackName = trackName {
                        VStack(spacing: 12) {
                            Text("🎵 \(trackName)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                            
                            Button(action: togglePlayback) {
                                HStack {
                                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 16, weight: .medium))
                                    Text(isPlaying ? "Pause Preview" : "Play Preview")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .frame(width: 200, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 22)
                                        .fill(LinearGradient(
                                            colors: [Color.green, Color.blue],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ))
                                )
                                .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                        }
                    } else if !isLoadingData {
                        VStack(spacing: 8) {
                            Image(systemName: "speaker.slash")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                            Text("No Preview Available")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    }
            }
            
            Spacer()
            
            Button("Close") {
                    stopPlayback()
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
            stopPlayback()
        }
    }
    
    // MARK: - Helper Methods
    private func loadArtistData() {
        // First check if we already have the image and preview URLs stored
        if let storedImageURL = artist.imageURL, !storedImageURL.isEmpty {
            artistImageURL = storedImageURL
        }
        
        if let storedPreviewURL = artist.previewURL, !storedPreviewURL.isEmpty {
            previewURL = storedPreviewURL
            trackName = "Preview Track" // Default name
            isLoadingData = false
            return
        }
        
        guard spotifyService.isAuthenticated else {
            isLoadingData = false
            return
        }
        
        Task {
            var spotifyId: String?
            var imageURL: String?
            var trackPreviewURL: String?
            var songName: String?
            
            // If we have a Spotify ID, use it directly for more reliable data fetching
            if let existingSpotifyId = artist.spotifyId, !existingSpotifyId.isEmpty {
                spotifyId = existingSpotifyId
                print("🎯 Using stored Spotify ID: \(existingSpotifyId)")
                
                // Get artist details
                if let artistDetails = await spotifyService.getArtistDetails(id: existingSpotifyId) {
                    imageURL = artistDetails.images.first?.url
                }
                
                // Get top tracks for preview
                let topTracks = await spotifyService.getArtistTopTracks(artistId: existingSpotifyId)
                if let track = topTracks.first(where: { $0.preview_url != nil }) {
                    trackPreviewURL = track.preview_url
                    songName = track.name
                }
            } else {
                // Fallback to search by name
                print("🔍 Searching for artist by name: \(artist.name)")
                if let artistData = await spotifyService.searchArtistWithDetails(name: artist.name) {
                    spotifyId = artistData.artist.id
                    imageURL = artistData.imageURL
                    trackPreviewURL = artistData.previewURL
                    
                    // Get track name
                    if let id = spotifyId {
                        let topTracks = await spotifyService.getArtistTopTracks(artistId: id)
                        if let track = topTracks.first(where: { $0.preview_url != nil }) {
                            songName = track.name
                        }
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.artistImageURL = imageURL
                self.previewURL = trackPreviewURL
                self.trackName = songName
                self.isLoadingData = false
                
                print("✅ Loaded artist data:")
                print("   🖼️ Image URL: \(imageURL ?? "None")")
                print("   🎵 Preview URL: \(trackPreviewURL ?? "None")")
                print("   🎶 Track Name: \(songName ?? "None")")
                print("   🔐 Spotify Auth: \(spotifyService.isAuthenticated)")
            }
        }
    }
    
    private func togglePlayback() {
        print("🎵 Toggle playback - Preview URL: \(previewURL ?? "None")")
        guard let previewURL = previewURL, let url = URL(string: previewURL) else { 
            print("❌ No valid preview URL available")
            return 
        }
        
        if isPlaying {
            print("⏸️ Stopping playback")
            stopPlayback()
        } else {
            print("▶️ Starting playback from: \(url.absoluteString)")
            startPlayback(url: url)
        }
    }
    
    private func startPlayback(url: URL) {
        print("🎧 Creating AVPlayer with URL: \(url)")
        audioPlayer = AVPlayer(url: url)
        
        print("▶️ Starting playback...")
        audioPlayer?.play()
        isPlaying = true
        
        // Check player status after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let player = self.audioPlayer {
                print("📊 Player status: \(player.status.rawValue)")
                print("📊 Player rate: \(player.rate)")
                if let error = player.error {
                    print("❌ Player error: \(error)")
                }
                if let currentItem = player.currentItem {
                    print("📊 Current item status: \(currentItem.status.rawValue)")
                    if let itemError = currentItem.error {
                        print("❌ Current item error: \(itemError)")
                    }
                }
            }
        }
        
        // Stop playback after 30 seconds (Spotify preview length)
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            print("⏰ 30 seconds elapsed, stopping playback")
            stopPlayback()
        }
        
        // Monitor player status
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: audioPlayer?.currentItem,
            queue: .main
        ) { _ in
            print("🏁 Playback finished naturally")
            stopPlayback()
        }
    }
    
    private func stopPlayback() {
        print("⏹️ Stopping playback")
        audioPlayer?.pause()
        audioPlayer = nil
        isPlaying = false
        NotificationCenter.default.removeObserver(self)
        print("✅ Playback stopped and cleaned up")
    }
}

// MARK: - Help View
struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("How to Play")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.bottom)
                    
                    VStack(alignment: .leading, spacing: 15) {
                        HelpSectionView(
                            title: "Objective",
                            description: "Guess the daily featured artist in 10 attempts or less."
                        )
                        
                        HelpSectionView(
                            title: "Hints",
                            description: "After each guess, you'll receive hints about the artist including their gender, country, debut year, genre, whether they're solo or in a group, and their Spotify popularity ranking."
                        )
                        
                        HelpSectionView(
                            title: "Color Coding",
                            description: "🟢 Green: Correct information\n🟡 Yellow: Close but not exact\n⚪ Gray: Incorrect information"
                        )
                        
                        HelpSectionView(
                            title: "Daily Challenge",
                            description: "A new artist is featured every day. Come back tomorrow for a new challenge!"
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
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

// MARK: - Music View (Genre Selection)
struct MusicView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showGenreGame = false
    @State private var selectedGenre: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemGray6).opacity(0.3)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 12) {
                            Text("Select a genre")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.primary)
                                .padding(.top, 20)
                        }
                        
                        // Genre Grid
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 20) {
                            GenreCard(
                                title: "Pop",
                                gradient: LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.8, blue: 0.6), Color(red: 0.9, green: 0.7, blue: 0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                icon: "music.note",
                                description: "Natural Heartbeats"
                            ) {
                                selectedGenre = "Pop"
                                showGenreGame = true
                            }
                            
                            GenreCard(
                                title: "Rock",
                                gradient: LinearGradient(
                                    colors: [Color(red: 0.2, green: 0.1, blue: 0.1), Color(red: 0.4, green: 0.2, blue: 0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                icon: "bolt.fill",
                                description: "Rock Music"
                            ) {
                                selectedGenre = "Rock"
                                showGenreGame = true
                            }
                            
                            GenreCard(
                                title: "Hip Hop",
                                gradient: LinearGradient(
                                    colors: [Color(red: 0.1, green: 0.1, blue: 0.1), Color(red: 0.3, green: 0.3, blue: 0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                icon: "mic",
                                description: "Nunahop Natural"
                            ) {
                                selectedGenre = "Hip-Hop"
                                showGenreGame = true
                            }
                            
                            GenreCard(
                                title: "Electronic",
                                gradient: LinearGradient(
                                    colors: [Color(red: 0.8, green: 0.9, blue: 0.6), Color(red: 0.4, green: 0.7, blue: 0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                icon: "waveform",
                                description: "Digital Waves"
                            ) {
                                selectedGenre = "Electronic"
                                showGenreGame = true
                            }
                            
                            GenreCard(
                                title: "Classical",
                                gradient: LinearGradient(
                                    colors: [Color(red: 0.8, green: 0.6, blue: 0.3), Color(red: 0.9, green: 0.7, blue: 0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                icon: "music.quarternote.3",
                                description: "Classical Classics"
                            ) {
                                selectedGenre = "Classical"
                                showGenreGame = true
                            }
                            
                            GenreCard(
                                title: "Country",
                                gradient: LinearGradient(
                                    colors: [Color(red: 0.2, green: 0.3, blue: 0.2), Color(red: 0.4, green: 0.5, blue: 0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                icon: "leaf.fill",
                                description: "Country Vibes"
                            ) {
                                selectedGenre = "Country"
                                showGenreGame = true
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Music")
            .navigationBarTitleDisplayMode(.inline)
        }
        .fullScreenCover(isPresented: $showGenreGame) {
            GenreGameView(genre: selectedGenre)
        }
    }
}

// MARK: - Genre Card
struct GenreCard: View {
    let title: String
    let gradient: LinearGradient
    let icon: String
    let description: String
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                // Card Image Area
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(gradient)
                        .frame(height: 140)
                        .overlay(
            VStack {
                                Spacer()
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(title.uppercased())
                                            .font(.system(size: 12, weight: .bold, design: .default))
                                            .foregroundColor(.white)
                                        
                                        Text(description)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: icon)
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundColor(.white.opacity(0.9))
                                }
                                .padding(16)
                            }
                        )
                }
                
                // Genre Title
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Genre Game View
struct GenreGameView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let genre: String
    @State private var gameManager: GameManager?
    @State private var searchText = ""
    @State private var showSuccessView = false
    @State private var searchResults: [Artist] = []
    @State private var showSearchResults = false
    @State private var animateHints = false
    @State private var refreshID = UUID()
    
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
                    
                    Button("New Game") {
                        print("🔴 New Genre Game button tapped")
                        
                        // Reset UI state immediately
                        animateHints = false
                        searchText = ""
                        showSearchResults = false
                        
                        // Create new genre game
                        gameManager?.createNewGenreGame(genre: genre)
                        
                        // Force view refresh and restart animations
                        refreshID = UUID()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                animateHints = true
                            }
                        }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Title Section
                        VStack(spacing: 12) {
                            Text("Guess the \(genre) Artist")
                                .font(.system(size: 28, weight: .bold, design: .default))
                                .foregroundColor(.primary)
                                .opacity(animateHints ? 1 : 0)
                                .offset(y: animateHints ? 0 : -20)
                                .animation(.easeOut(duration: 0.8).delay(0.1), value: animateHints)
                            
                            Text("Can you identify this \(genre.lowercased()) artist?")
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
                                    TextField("Enter your guess", text: $searchText)
                                        .font(.system(size: 16, weight: .medium))
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 16)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(25)
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
                                Text("Submit Guess")
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
                        
                        // Remaining Guesses
                        if let game = gameManager?.currentGame {
                            Text("Remaining Guesses: \(game.attemptsRemaining)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                                .opacity(animateHints ? 1 : 0)
                                .offset(y: animateHints ? 0 : 20)
                                .animation(.easeOut(duration: 0.8).delay(0.5), value: animateHints)
        }
                        
                        // Previous Guesses
                        if let game = gameManager?.currentGame, !game.currentGuesses.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Your Guesses")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.primary)
                                    
                                    Text("🟢 Correct  🟡 Close  ⚪ Wrong")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 20)
                                
                                // Display guesses in reverse chronological order (newest first)
                                ForEach(0..<game.currentGuesses.count, id: \.self) { index in
                                    let reverseIndex = game.currentGuesses.count - 1 - index
                                    let guess = game.currentGuesses[reverseIndex]
                                    let guessNumber = reverseIndex + 1
                                    PreviousGuessView(guess: guess, index: guessNumber)
                                        .padding(.horizontal, 20)
                                }
                            }
                        }
                        
                        // Game Over Message
                        if let game = gameManager?.currentGame, game.isCompleted {
                            GameOverView(
                                isWon: game.isWon,
                                targetArtist: gameManager?.targetArtist,
                                onViewResult: { showSuccessView = true }
                            )
                            .padding(.horizontal, 20)
                        }
                        
                        Spacer(minLength: 40)
                    }
                }
            }
        }
        .onAppear {
            if gameManager == nil {
                gameManager = GameManager(modelContext: modelContext)
                gameManager?.createNewGenreGame(genre: genre)
            }
            
            // Trigger animations
            withAnimation {
                animateHints = true
            }
        }
        .fullScreenCover(isPresented: $showSuccessView) {
            if let targetArtist = gameManager?.targetArtist {
                SuccessView(
                    artist: targetArtist,
                    isWon: gameManager?.currentGame?.isWon ?? false
                )
            }
        }
        .onTapGesture {
            showSearchResults = false
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
            // Filter search results by genre
            let allResults = gameManager?.searchArtists(query: query) ?? []
            searchResults = allResults.filter { artist in
                artist.genre.lowercased().contains(genre.lowercased()) ||
                areGenresRelated(artist.genre, genre)
            }
            showSearchResults = !searchResults.isEmpty
        }
    }
    
    private func areGenresRelated(_ artistGenre: String, _ targetGenre: String) -> Bool {
        let relatedGenres: [String: [String]] = [
            "Pop": ["Pop", "Alternative", "Indie Pop", "Electropop"],
            "Rock": ["Rock", "Alternative Rock", "Indie Rock", "Pop Rock"],
            "Hip-Hop": ["Hip-Hop", "R&B", "Rap", "Soul"],
            "Electronic": ["Electronic", "Dance", "EDM", "House"],
            "Classical": ["Classical", "Jazz", "Blues", "Opera"],
            "Country": ["Country", "Folk", "Americana", "Bluegrass"]
        ]
        
        if let related = relatedGenres[targetGenre] {
            return related.contains(artistGenre)
        }
        return artistGenre.lowercased() == targetGenre.lowercased()
    }
    
    private func submitGuess() {
        guard !searchText.isEmpty else { return }
        
        Task {
            if let guess = await gameManager?.submitGuess(searchText) {
                await MainActor.run {
                    searchText = ""
                    showSearchResults = false
                    
                    if guess.isCorrect {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            showSuccessView = true
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var profileManager = UserProfileManager()
    @State private var userStats = UserStats()
    @State private var showEditProfile = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemGray6).opacity(0.3)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Profile Header
                        VStack(spacing: 20) {
                            // Avatar with Memoji
                            ZStack {
                                Circle()
                                    .fill(Color(.systemGray6))
                                    .frame(width: 120, height: 120)
                                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                
                                Text(profileManager.selectedMemoji)
                                    .font(.system(size: 60))
                                    .scaleEffect(1.1)
                            }
                            
                            // User Info
                            VStack(spacing: 8) {
                                Text(profileManager.username)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.primary)
                
                                Text("@\(profileManager.handle)")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            
                            // Edit Profile Button
                            Button(action: {
                                showEditProfile = true
                            }) {
                                Text("Edit Profile")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(22)
                            }
                            .padding(.horizontal, 40)
                        }
                        .padding(.top, 20)
                        
                        // Statistics Section
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                StatCard(
                                    value: "\(userStats.totalGames)",
                                    label: "Total Games"
                                )
                                
                                StatCard(
                                    value: "\(userStats.correctGuesses)",
                                    label: "Correct\nGuesses"
                                )
                                
                                StatCard(
                                    value: "\(userStats.winRate)%",
                                    label: "Win\nRate"
                                )
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Settings Section
                        VStack(spacing: 20) {
                            HStack {
                                Text("Settings")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            
                            // Dark Mode Toggle
                            VStack(spacing: 0) {
                                HStack {
                                    HStack(spacing: 12) {
                                        Image(systemName: themeManager.isDarkMode ? "moon.fill" : "sun.max.fill")
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundColor(themeManager.isDarkMode ? .blue : .orange)
                                        
                                        Text("Dark Mode")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.primary)
                                    }
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: $themeManager.isDarkMode)
                                        .labelsHidden()
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                            )
                            .padding(.horizontal, 20)
                        }
                        .padding(.top, 32)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            calculateUserStats()
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(profileManager: profileManager)
        }
    }
    
    private func calculateUserStats() {
        do {
            let descriptor = FetchDescriptor<GameState>()
            let allGames = try modelContext.fetch(descriptor)
            
            let totalGames = allGames.count
            let wonGames = allGames.filter { $0.isWon }.count
            let totalGuesses = allGames.flatMap { $0.currentGuesses }.count
            let correctGuesses = allGames.flatMap { $0.currentGuesses }.filter { $0.isCorrect }.count
            let winRate = totalGames > 0 ? Int((Double(wonGames) / Double(totalGames)) * 100) : 0
            
            userStats = UserStats(
                totalGames: totalGames,
                correctGuesses: correctGuesses,
                winRate: winRate,
                totalGuesses: totalGuesses,
                wonGames: wonGames
            )
        } catch {
            print("Error calculating stats: \(error)")
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - User Stats Model
struct UserStats {
    var totalGames: Int = 0
    var correctGuesses: Int = 0
    var winRate: Int = 0
    var totalGuesses: Int = 0
    var wonGames: Int = 0
}

// MARK: - User Profile Manager
class UserProfileManager: ObservableObject {
    @Published var username: String {
        didSet {
            UserDefaults.standard.set(username, forKey: "username")
        }
    }
    
    @Published var handle: String {
        didSet {
            UserDefaults.standard.set(handle, forKey: "handle")
        }
    }
    
    @Published var selectedMemoji: String {
        didSet {
            UserDefaults.standard.set(selectedMemoji, forKey: "selectedMemoji")
        }
    }
    
    init() {
        self.username = UserDefaults.standard.string(forKey: "username") ?? "MusicFan2023"
        self.handle = UserDefaults.standard.string(forKey: "handle") ?? "musicfan2023"
        self.selectedMemoji = UserDefaults.standard.string(forKey: "selectedMemoji") ?? "🧑‍💼"
    }
    
    static let availableMemojis = [
        // Business & Professional
        "🧑‍💼", "👨‍💼", "👩‍💼", "🕴️", "💼",
        
        // Creative & Artistic
        "🧑‍🎨", "👨‍🎨", "👩‍🎨", "🎭", "🎨", "🎤", "🎸", "🎹", "🎺", "🎻",
        
        // Casual & Fun
        "😊", "😎", "🤠", "🥳", "🤓", "😋", "🙃", "😇", "🤗", "🫡",
        
        // Animals & Characters
        "🐶", "🐱", "🐸", "🐹", "🦊", "🐻", "🐼", "🐨", "🦁", "🐯",
        
        // Music Related
        "🎵", "🎶", "🎼", "🎙️", "📻", "🎧", "🔊", "🎪", "🌟", "⭐",
        
        // Diverse People
        "👶", "🧒", "👦", "👧", "🧑", "👨", "👩", "🧓", "👴", "👵",
        
        // Hair Styles & Looks
        "👨‍🦰", "👩‍🦰", "👨‍🦱", "👩‍🦱", "👨‍🦳", "👩‍🦳", "👨‍🦲", "👩‍🦲",
        
        // Fun Objects
        "🎯", "🚀", "⚡", "🔥", "💎", "🏆", "🎮", "📱", "💻", "🎲"
    ]
}

// MARK: - Memoji Manager
class MemojiManager: ObservableObject {
    @Published var selectedMemoji: String {
        didSet {
            UserDefaults.standard.set(selectedMemoji, forKey: "selectedMemoji")
        }
    }
    
    init() {
        self.selectedMemoji = UserDefaults.standard.string(forKey: "selectedMemoji") ?? "🧑‍💼"
    }
    
    static let availableMemojis = [
        // Business & Professional
        "🧑‍💼", "👨‍💼", "👩‍💼", "🕴️", "💼",
        
        // Creative & Artistic
        "🧑‍🎨", "👨‍🎨", "👩‍🎨", "🎭", "🎨", "🎤", "🎸", "🎹", "🎺", "🎻",
        
        // Casual & Fun
        "😊", "😎", "🤠", "🥳", "🤓", "😋", "🙃", "😇", "🤗", "🫡",
        
        // Animals & Characters
        "🐶", "🐱", "🐸", "🐹", "🦊", "🐻", "🐼", "🐨", "🦁", "🐯",
        
        // Music Related
        "🎵", "🎶", "🎼", "🎙️", "📻", "🎧", "🔊", "🎪", "🌟", "⭐",
        
        // Diverse People
        "👶", "🧒", "👦", "👧", "🧑", "👨", "👩", "🧓", "👴", "👵",
        
        // Hair Styles & Looks
        "👨‍🦰", "👩‍🦰", "👨‍🦱", "👩‍🦱", "👨‍🦳", "👩‍🦳", "👨‍🦲", "👩‍🦲",
        
        // Fun Objects
        "🎯", "🚀", "⚡", "🔥", "💎", "🏆", "🎮", "📱", "💻", "🎲"
    ]
}

// MARK: - Memoji Picker View
struct MemojiPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var profileManager: UserProfileManager
    @State private var selectedMemoji: String
    
    init(profileManager: UserProfileManager) {
        self.profileManager = profileManager
        _selectedMemoji = State(initialValue: profileManager.selectedMemoji)
    }
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 5)
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Preview Section
                VStack(spacing: 16) {
                    Text("Preview")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // Large preview of selected memoji
                    Text(selectedMemoji)
                        .font(.system(size: 80))
                        .frame(width: 120, height: 120)
                        .background(
                            Circle()
                                .fill(Color(.systemGray6))
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        )
                        .scaleEffect(1.1)
                        .animation(.bouncy(duration: 0.3), value: selectedMemoji)
                }
                .padding(.top, 20)
                
                // Memoji Grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(UserProfileManager.availableMemojis, id: \.self) { memoji in
                            Button(action: {
                                selectedMemoji = memoji
                                HapticManager.impact(.light)
                            }) {
                                Text(memoji)
                                    .font(.system(size: 32))
                                    .frame(width: 56, height: 56)
                                    .background(
                                        Circle()
                                            .fill(selectedMemoji == memoji ? Color.blue.opacity(0.2) : Color(.systemGray6))
                                            .overlay(
                                                Circle()
                                                    .stroke(selectedMemoji == memoji ? Color.blue : Color.clear, lineWidth: 2)
                                            )
                                    )
                                    .scaleEffect(selectedMemoji == memoji ? 1.1 : 1.0)
                                    .animation(.bouncy(duration: 0.2), value: selectedMemoji)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Save Button
                Button(action: {
                    profileManager.selectedMemoji = selectedMemoji
                    HapticManager.impact(.medium)
                    dismiss()
                }) {
                    Text("Save Memoji")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(25)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Choose Memoji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Haptic Manager
struct HapticManager {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Edit Profile View
struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var profileManager: UserProfileManager
    @State private var showMemojiPicker = false
    @State private var tempUsername: String
    @State private var tempHandle: String
    
    init(profileManager: UserProfileManager) {
        self.profileManager = profileManager
        _tempUsername = State(initialValue: profileManager.username)
        _tempHandle = State(initialValue: profileManager.handle)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Avatar Section
                VStack(spacing: 16) {
                    Button(action: {
                        showMemojiPicker = true
                        HapticManager.impact(.light)
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray6))
                                .frame(width: 100, height: 100)
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                            
                            Text(profileManager.selectedMemoji)
                                .font(.system(size: 50))
                        }
                        .overlay(
                            // Edit indicator
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Image(systemName: "pencil")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                )
                                .offset(x: 30, y: 30)
                        )
                    }
                    
                    Text("Tap to change Memoji")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                }
                .padding(.top, 20)
                
                // Form Fields
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        TextField("Username", text: $tempUsername)
                            .font(.system(size: 16))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Handle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        TextField("Handle", text: $tempHandle)
                            .font(.system(size: 16))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Save Button
                Button("Save Changes") {
                    // Save the changes to the profile manager
                    profileManager.username = tempUsername
                    profileManager.handle = tempHandle
                    HapticManager.impact(.medium)
                    dismiss()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(25)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showMemojiPicker) {
            MemojiPickerView(profileManager: profileManager)
        }
    }
}

#Preview {
    MainView()
        .modelContainer(for: [Artist.self, Guess.self, GameState.self], inMemory: true)
}
