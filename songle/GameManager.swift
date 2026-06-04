//
//  GameManager.swift
//  songle
//
//  Created by Ümit BAĞ on 7/2/25.
//

import Foundation
import SwiftData

class GameManager: ObservableObject {
    @Published var currentGame: GameState?
    @Published var targetArtist: Artist?
    @Published var allArtists: [Artist] = []
    @Published var isLoadingFromFirestore = false
    
    var modelContext: ModelContext
    private let firestoreService = FirestoreService.shared
    private var gameType: GameType = .daily
    
    enum GameType {
        case daily
        case genre(String)
    }
    
    init(modelContext: ModelContext, gameType: GameType = .daily) {
        self.modelContext = modelContext
        self.gameType = gameType
        print("🎮 Initializing GameManager for game type: \(gameType)...")
        
        // Load fallback artists first for immediate game setup
        loadFallbackArtists()
        
        // Debug: Print existing games
        debugPrintExistingGames()
        
        // Setup game with fallback data
        switch gameType {
        case .daily:
            setupDailyGame()
        case .genre(let genre):
            createNewGenreGame(genre: genre)
        }
        
        // Then load from Firestore in background and potentially refresh
        loadArtistsFromFirestore()
    }
    
    // MARK: - Model Context Management
    func setModelContext(_ context: ModelContext) {
        print("🔄 Setting model context...")
        if modelContext !== context {
            self.modelContext = context
            print("✅ Updated model context")
            
            // Re-setup the game with new context to ensure proper state restoration
            setupDailyGame()
        } else {
            print("ℹ️ Model context unchanged, but ensuring game state is loaded")
            
            // Ensure we have artists loaded
            if allArtists.isEmpty {
                print("⚠️ No artists loaded, loading fallback data")
                loadFallbackArtists()
            }
            
            // Even if context is the same, ensure we have a valid current game
            if currentGame == nil {
                print("⚠️ No current game found, setting up daily game")
                setupDailyGame()
            } else {
                print("✅ Current game exists: \(currentGame?.dateString ?? "unknown"), completed: \(currentGame?.isCompleted ?? false)")
                
                // Critical: Verify the target artist is loaded
                if targetArtist == nil, let game = currentGame {
                    print("🎯 Loading target artist for existing game")
                    targetArtist = getArtist(by: game.targetArtistId)
                    
                    if targetArtist == nil {
                        print("⚠️ Target artist still not found, attempting replacement")
                        if let replacementArtist = findReplacementArtist(for: game.targetArtistId) {
                            targetArtist = replacementArtist
                            game.targetArtistId = replacementArtist.id
                            do {
                                try modelContext.save()
                                print("✅ Updated game with replacement target: \(replacementArtist.name)")
                            } catch {
                                print("❌ Error saving replacement target: \(error)")
                            }
                        } else {
                            print("❌ No replacement found, will setup new game")
                            currentGame = nil
                            setupDailyGame()
                            return
                        }
                    }
                    
                    print("🎯 Target artist confirmed: \(targetArtist?.name ?? "still unknown")")
                } else if let target = targetArtist {
                    print("✅ Target artist already loaded: \(target.name)")
                }
            }
        }
    }
    
    // MARK: - Daily Game Setup
    func setupDailyGame() {
        let today = getTodayDateString()
        print("🗓️ Setting up daily game for: \(today)")
        
        // Ensure we have some artists available first
        if allArtists.isEmpty {
            print("⚠️ No artists loaded yet, loading fallback data first")
            loadFallbackArtists()
        }
        
        // Check if we already have a game for today
        do {
            let descriptor = FetchDescriptor<GameState>()
            let allGames = try modelContext.fetch(descriptor)
            let existingGames = allGames.filter { $0.dateString.hasPrefix(today) }
            print("📋 Found \(existingGames.count) existing games for today")
            
            if let existingGame = existingGames.first {
                print("🎮 Using existing game: \(existingGame.dateString) - Completed: \(existingGame.isCompleted)")
                currentGame = existingGame
                
                // Critical: Always ensure target artist is loaded
                targetArtist = getArtist(by: existingGame.targetArtistId)
                
                if targetArtist == nil {
                    print("⚠️ Target artist not found for ID: \(existingGame.targetArtistId)")
                    print("🔄 Attempting to find or create replacement target artist")
                    
                    // Try to find any artist with similar ID or name
                    if let replacementArtist = findReplacementArtist(for: existingGame.targetArtistId) {
                        targetArtist = replacementArtist
                        existingGame.targetArtistId = replacementArtist.id
                        try modelContext.save()
                        print("✅ Updated game with replacement target: \(replacementArtist.name)")
                    } else {
                        print("❌ No replacement found, creating new game")
                        // Delete the problematic game and create a new one
                        modelContext.delete(existingGame)
                        try modelContext.save()
                        createNewDailyGame(for: today)
                        return
                    }
                }
                
                print("🎯 Target artist confirmed: \(targetArtist?.name ?? "Unknown")")
            } else {
                print("🆕 No game found for today, creating new one")
                createNewDailyGame(for: today)
            }
            
            // Also clean up old games (keep only last 7 days)
            cleanupOldGames()
        } catch {
            print("❌ Error fetching game: \(error)")
            createNewDailyGame(for: today)
        }
    }
    
    private func createNewDailyGame(for dateString: String? = nil) {
        guard !allArtists.isEmpty else {
            print("⚠️ No artists available to create game")
            return
        }

        // Fetch all previously used artist IDs
        let descriptor = FetchDescriptor<GameState>()
        var usedArtistIds: Set<String> = []
        do {
            let allGames = try modelContext.fetch(descriptor)
            usedArtistIds = Set(allGames.map { $0.targetArtistId })
            print("[DEBUG] Used artist IDs (", usedArtistIds.count, "): ", usedArtistIds)
        } catch {
            print("❌ Error fetching all games for exclusion: \(error)")
        }

        // Exclude all previously used artists
        let availableArtists = allArtists.filter { !usedArtistIds.contains($0.id) }
        print("[DEBUG] Available artists for selection (", availableArtists.count, "): ", availableArtists.map { $0.name })
        let artistPool = availableArtists.isEmpty ? allArtists : availableArtists

        // Select a random artist for today's challenge
        let randomArtist = artistPool.randomElement()!
        print("🎯 Creating new game with target: \(randomArtist.name)")

        // Always use a unique date string for each new game
        let uniqueDateString = (dateString ?? getTodayDateString()) + "-" + UUID().uuidString.prefix(8)
        let newGame = GameState(dateString: String(uniqueDateString), targetArtistId: randomArtist.id)
        newGame.currentGuesses = [] // Extra safeguard: ensure guesses are empty

        modelContext.insert(newGame)

        do {
            try modelContext.save()
            currentGame = newGame
            targetArtist = randomArtist
            self.objectWillChange.send() // Notify UI of new game
            print("✅ Successfully created new daily game")
        } catch {
            print("❌ Error saving new game: \(error)")
        }
    }
    
    // MARK: - Cleanup Old Games
    private func cleanupOldGames() {
        do {
            let allDescriptor = FetchDescriptor<GameState>()
            let allGames = try modelContext.fetch(allDescriptor)
            
            // Get current date and calculate 7 days ago
            let calendar = Calendar.current
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            
            var deletedCount = 0
            for game in allGames {
                // Skip genre games (they have different date format)
                if game.dateString.hasPrefix("genre-") {
                    continue
                }
                
                // Parse the date and check if it's older than 7 days
                if let gameDate = formatter.date(from: game.dateString), gameDate < sevenDaysAgo {
                    modelContext.delete(game)
                    deletedCount += 1
                }
            }
            
            if deletedCount > 0 {
                try modelContext.save()
                print("🗑️ Cleaned up \(deletedCount) old games")
            }
        } catch {
            print("⚠️ Error cleaning up old games: \(error)")
        }
    }
    
    private func getTodayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    // MARK: - Game Logic
    func submitGuess(_ artistName: String) async -> Guess? {
        print("🎯 Attempting to submit guess: '\(artistName)'")
        
        // Safety check to ensure game state is complete
        if !ensureGameStateIsComplete() {
            print("❌ Game state is incomplete, cannot submit guess")
            return nil
        }
        
        guard let game = currentGame else {
            print("❌ No current game found")
            return nil
        }
        
        guard let target = targetArtist else {
            print("❌ No target artist found")
            return nil
        }
        
        guard !game.isCompleted else {
            print("❌ Game is already completed")
            return nil
        }
        
        guard game.attemptsRemaining > 0 else {
            print("❌ No attempts remaining")
            return nil
        }
        
        print("✅ All conditions met, processing guess...")
        print("📊 Game state: completed=\(game.isCompleted), attempts=\(game.attemptsRemaining), guesses=\(game.currentGuesses.count)")
        
        let trimmedName = artistName.trimmingCharacters(in: .whitespacesAndNewlines)
        let isCorrect = trimmedName.lowercased() == target.name.lowercased()
        
        print("🎯 Target: \(target.name), Guess: \(trimmedName), Correct: \(isCorrect)")
        
        // Generate hints by comparing with a random artist or getting proximity hints
        let hints = generateHints(guessedName: trimmedName, target: target, isCorrect: isCorrect)
        
        // Fetch artist image from Spotify
        let artistImageURL = await fetchArtistImage(artistName: trimmedName)
        
        let guess = Guess(artistName: trimmedName, isCorrect: isCorrect, hints: hints, artistImageURL: artistImageURL)
        
        // Update game state
        await MainActor.run {
            print("🔄 Adding guess to array: \(guess.artistName) with ID: \(guess.id)")
            print("📊 Before adding: \(game.currentGuesses.count) guesses")
            
            game.currentGuesses.append(guess)
            game.attemptsRemaining -= 1
            
            print("📊 After adding: \(game.currentGuesses.count) guesses")
            print("📋 Current guess order: \(game.currentGuesses.enumerated().map { "\($0.offset + 1): \($0.element.artistName)" }.joined(separator: ", "))")
            
            if isCorrect {
                game.isCompleted = true
                game.isWon = true
            } else if game.attemptsRemaining <= 0 {
                game.isCompleted = true
                game.isWon = false
            }
            
            // If game is completed, ensure target artist has audio preview data
            if game.isCompleted {
                Task {
                    await ensureTargetArtistHasAudioPreview()
                }
            }
            
            // Force UI update - notify SwiftUI that the game state has changed
            self.objectWillChange.send()
            
            print("💾 Saving guess to database...")
            do {
                try modelContext.save()
                print("✅ Guess saved successfully")
                
                // Additional UI update after save to ensure consistency
                self.objectWillChange.send()
                
            } catch {
                print("❌ Error saving guess: \(error)")
            }
        }
        
        print("🎮 Guess processed successfully")
        return guess
    }
    
    // MARK: - Game State Validation
    private func ensureGameStateIsComplete() -> Bool {
        print("🔍 Validating game state completeness...")
        
        // Check if we have artists loaded
        if allArtists.isEmpty {
            print("⚠️ No artists loaded, loading fallback data")
            loadFallbackArtists()
        }
        
        // Check if we have a current game
        guard let game = currentGame else {
            print("⚠️ No current game, setting up daily game")
            setupDailyGame()
            return currentGame != nil && targetArtist != nil
        }
        
        // Check if we have a target artist
        if targetArtist == nil {
            print("⚠️ No target artist, attempting to load")
            targetArtist = getArtist(by: game.targetArtistId)
            
            if targetArtist == nil {
                print("⚠️ Target artist not found, looking for replacement")
                if let replacement = findReplacementArtist(for: game.targetArtistId) {
                    targetArtist = replacement
                    game.targetArtistId = replacement.id
                    do {
                        try modelContext.save()
                        print("✅ Updated game with replacement target: \(replacement.name)")
                    } catch {
                        print("❌ Error saving replacement: \(error)")
                        return false
                    }
                } else {
                    print("❌ No replacement found")
                    return false
                }
            }
        }
        
        let isComplete = currentGame != nil && targetArtist != nil && !allArtists.isEmpty
        print("🎯 Game state validation result: \(isComplete ? "✅ Complete" : "❌ Incomplete")")
        
        if let target = targetArtist {
            print("🎯 Target confirmed: \(target.name)")
        }
        
        return isComplete
    }
    
    // MARK: - Artist Image Fetching
    private func fetchArtistImage(artistName: String) async -> String? {
        // First check if we have the artist in our local cache with image
        if let localArtist = allArtists.first(where: { $0.name.lowercased() == artistName.lowercased() }),
           let imageURL = localArtist.imageURL, !imageURL.isEmpty {
            print("🖼️ Using cached image for \(artistName)")
            return imageURL
        }
        
        // Use image from Firestore data if available
        if let localArtist = allArtists.first(where: { $0.name.lowercased() == artistName.lowercased() }),
           let imageURL = localArtist.imageURL {
            print("✅ Found cached image for \(artistName): \(imageURL)")
            return imageURL
        }
        
        print("⚠️ No image available for \(artistName)")
        return nil
    }
    
    private func generateHints(guessedName: String, target: Artist, isCorrect: Bool) -> [String: String] {
        // Find the guessed artist
        guard let guessedArtist = allArtists.first(where: { $0.name.lowercased() == guessedName.lowercased() }) else {
            // If artist not found, return basic hints
            return [
                "Genre": "Unknown|incorrect",
                "Country": "Unknown|incorrect",
                "Debut Year": "Unknown|incorrect",
                "Gender": "Unknown|incorrect",
                "Type": "Unknown|incorrect",
                "Popularity": "0|incorrect"
            ]
        }
        
        var hints: [String: String] = [:]
        
        // If the guess is correct, all hints should be correct
        if isCorrect {
            hints["Genre"] = "\(guessedArtist.genre)|correct"
            hints["Country"] = "\(guessedArtist.country)|correct"
            hints["Debut Year"] = "\(guessedArtist.debutYear)|correct"
            hints["Gender"] = "\(guessedArtist.gender)|correct"
            hints["Type"] = "\(guessedArtist.isSolo ? "Solo" : "Group")|correct"
            hints["Popularity"] = "#\(guessedArtist.spotifyPopularity)|correct"
            return hints
        }
        
        // Genre comparison
        if guessedArtist.genre == target.genre {
            hints["Genre"] = "\(guessedArtist.genre)|correct"
        } else if areGenresClose(guessedArtist.genre, target.genre) {
            hints["Genre"] = "\(guessedArtist.genre)|close"
        } else {
            hints["Genre"] = "\(guessedArtist.genre)|incorrect"
        }
        
        // Country comparison
        if guessedArtist.country == target.country {
            hints["Country"] = "\(guessedArtist.country)|correct"
        } else if areCountriesClose(guessedArtist.country, target.country) {
            hints["Country"] = "\(guessedArtist.country)|close"
        } else {
            hints["Country"] = "\(guessedArtist.country)|incorrect"
        }
        
        // Debut Year comparison
        if guessedArtist.debutYear == target.debutYear {
            hints["Debut Year"] = "\(guessedArtist.debutYear)|correct"
        } else if abs(guessedArtist.debutYear - target.debutYear) <= 5 {
            let direction = guessedArtist.debutYear > target.debutYear ? "lower" : "higher"
            hints["Debut Year"] = "\(guessedArtist.debutYear)|close|\(direction)"
        } else {
            let direction = guessedArtist.debutYear > target.debutYear ? "lower" : "higher"
            hints["Debut Year"] = "\(guessedArtist.debutYear)|incorrect|\(direction)"
        }
        
        // Gender comparison
        if guessedArtist.gender == target.gender {
            hints["Gender"] = "\(guessedArtist.gender)|correct"
        } else {
            hints["Gender"] = "\(guessedArtist.gender)|incorrect"
        }
        
        // Solo/Group comparison
        let guessedType = guessedArtist.isSolo ? "Solo" : "Group"
        let targetType = target.isSolo ? "Solo" : "Group"
        if guessedType == targetType {
            hints["Type"] = "\(guessedType)|correct"
        } else {
            hints["Type"] = "\(guessedType)|incorrect"
        }
        
        // Popularity comparison (using database ranking)
        let guessedRanking = guessedArtist.spotifyPopularity
        let targetRanking = target.spotifyPopularity
        
        if guessedRanking == targetRanking {
            hints["Popularity"] = "#\(guessedRanking)|correct"
        } else if abs(guessedRanking - targetRanking) <= 5 {
            let direction = guessedRanking > targetRanking ? "higher" : "lower" // Lower number = higher popularity
            hints["Popularity"] = "#\(guessedRanking)|close|\(direction)"
        } else {
            let direction = guessedRanking > targetRanking ? "higher" : "lower" // Lower number = higher popularity
            hints["Popularity"] = "#\(guessedRanking)|incorrect|\(direction)"
        }
        
        return hints
    }
    
    private func areGenresClose(_ genre1: String, _ genre2: String) -> Bool {
        let similarGenres = [
            ["Pop", "Alternative", "Indie Pop", "Electropop"],
            ["Rock", "Alternative Rock", "Indie Rock", "Pop Rock"],
            ["Hip-Hop", "R&B", "Rap", "Soul"],
            ["Electronic", "Dance", "EDM", "House"],
            ["Country", "Folk", "Americana", "Bluegrass"],
            ["Jazz", "Blues", "Soul", "Funk"]
        ]
        
        for group in similarGenres {
            if group.contains(genre1) && group.contains(genre2) {
                return true
            }
        }
        return false
    }
    
    private func areCountriesClose(_ country1: String, _ country2: String) -> Bool {
        let similarCountries = [
            ["United States", "Canada"],
            ["United Kingdom", "Ireland"],
            ["Australia", "New Zealand"],
            ["Germany", "Austria", "Switzerland"],
            ["Sweden", "Norway", "Denmark"]
        ]
        
        for group in similarCountries {
            if group.contains(country1) && group.contains(country2) {
                return true
            }
        }
        return false
    }
    
    private func getArtist(by id: String) -> Artist? {
        // 1. Try to find by ID (case-insensitive)
        if let localArtist = allArtists.first(where: { $0.id.lowercased() == id.lowercased() }) {
            return localArtist
        }
        // 2. Try to find by name (case-insensitive, ignoring 'firestore-' prefix and dashes/underscores)
        let normalizedId = id
            .replacingOccurrences(of: "firestore-", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if let byName = allArtists.first(where: { $0.name.lowercased().replacingOccurrences(of: "-", with: " ").trimmingCharacters(in: .whitespacesAndNewlines) == normalizedId }) {
            return byName
        }
        // 3. Try to find by name contains (for partial matches)
        if let byPartial = allArtists.first(where: { $0.name.lowercased().contains(normalizedId) }) {
            return byPartial
        }
        // 4. Not found
        print("⚠️ getArtist(by:) could not find artist for id: \(id)")
        return nil
    }
    
    // MARK: - Global Ranking System
    private func getGlobalRanking(for artistName: String) -> Int {
        // Updated with real current Spotify global monthly listeners rankings
        let globalRankings: [String: Int] = [
            // Top 50 - Current Real Rankings
            "Bruno Mars": 1,
            "The Weeknd": 2,
            "Lady Gaga": 3,
            "Ed Sheeran": 4,
            "Billie Eilish": 5,
            "Coldplay": 6,
            "Rihanna": 7,
            "Taylor Swift": 8,
            "Bad Bunny": 9,
            "Justin Bieber": 10,
            "Kendrick Lamar": 11,
            "Drake": 12,
            "David Guetta": 13,
            "Ariana Grande": 14,
            "Calvin Harris": 15,
            "SZA": 16,
            "Sabrina Carpenter": 17,
            "Maroon 5": 18,
            "J Balvin": 19,
            "Dua Lipa": 20,
            "Post Malone": 21,
            "Katy Perry": 22,
            "Shakira": 23,
            "Eminem": 24,
            "Pitbull": 25,
            "Sia": 26,
            "Travis Scott": 27,
            "Kanye West": 28,
            "Chris Brown": 29,
            "Miley Cyrus": 30,
            "Lana Del Rey": 31,
            "Beyoncé": 32,
            "Black Eyed Peas": 33,
            "Imagine Dragons": 34,
            "Benson Boone": 35,
            "Tate McRae": 36,
            "KAROL G": 37,
            "Daddy Yankee": 38,
            "Marshmello": 39,
            "Arctic Monkeys": 40,
            "Future": 41,
            "Adele": 42,
            "Alex Warren": 43,
            "OneRepublic": 44,
            "Linkin Park": 45,
            "Doja Cat": 46,
            "Teddy Swims": 47,
            "Khalid": 48,
            "Sam Smith": 49,
            "Lil Wayne": 50,
            
            // Top 51-100
            "Queen": 51,
            "Rauw Alejandro": 52,
            "The Chainsmokers": 53,
            "Halsey": 54,
            "Harry Styles": 55,
            "Playboi Carti": 56,
            "Sean Paul": 57,
            "Elton John": 58,
            "Arijit Singh": 59,
            "Michael Jackson": 60,
            "Nicki Minaj": 61,
            "Kesha": 62,
            "Camila Cabello": 63,
            "Hozier": 64,
            "Selena Gomez": 65,
            "Olivia Rodrigo": 66,
            "Ozuna": 67,
            "Pritam": 68,
            "sombr": 69,
            "Justin Timberlake": 70,
            "Shreya Ghoshal": 71,
            "Maluma": 72,
            "Shawn Mendes": 73,
            "Ellie Goulding": 74,
            "Ne-Yo": 75,
            "USHER": 76,
            "One Direction": 77,
            "JENNIE": 78,
            "Wiz Khalifa": 79,
            "Tyler, The Creator": 80,
            "Peso Pluma": 81,
            "Fleetwood Mac": 82,
            "A.R. Rahman": 83,
            "DJ Snake": 84,
            "Metro Boomin": 85,
            "Don Omar": 86,
            "21 Savage": 87,
            "Gracie Abrams": 88,
            "Britney Spears": 89,
            "Chappell Roan": 90,
            "Red Hot Chili Peppers": 91,
            "Flo Rida": 92,
            "ROSÉ": 93,
            "Farruko": 94,
            "Charlie Puth": 95,
            "Morgan Wallen": 96,
            "Madonna": 97,
            "Ty Dolla $ign": 98,
            "Myke Towers": 99,
            "Tiësto": 100,
            
            // Top 101-150
            "Beéle": 101,
            "Avicii": 102,
            "The Neighbourhood": 103,
            "50 Cent": 104,
            "Feid": 105,
            "The Kid LAROI": 106,
            "Lola Young": 107,
            "Charli xcx": 108,
            "Pharrell Williams": 109,
            "Ovy On The Drums": 110,
            "A$AP Rocky": 111,
            "Fuerza Regida": 112,
            "Nicky Jam": 113,
            "P!nk": 114,
            "Green Day": 115,
            "Radiohead": 116,
            "Frank Ocean": 117,
            "James Arthur": 118,
            "Kali Uchis": 119,
            "Swae Lee": 120,
            "The Police": 121,
            "Doechii": 122,
            "Diplo": 123,
            "Manuel Turizo": 124,
            "Empire Of The Sun": 125,
            "Anuel AA": 126,
            "Akon": 127,
            "PARTYNEXTDOOR": 128,
            "ABBA": 129,
            "Twenty One Pilots": 130,
            "JAY-Z": 131,
            "Bebe Rexha": 132,
            "Enrique Iglesias": 133,
            "Guns N' Roses": 134,
            "d4vd": 135,
            "Grupo Frontera": 136,
            "Nirvana": 137,
            "XXXTENTACION": 138,
            "J. Cole": 139,
            "Sachin-Jigar": 140,
            "Disney": 141,
            "Don Toliver": 142,
            "Tom Odell": 143,
            "Lorde": 144,
            "Romeo Santos": 145,
            "Cris MJ": 146,
            "Jason Derulo": 147,
            "Anne-Marie": 148,
            "Alicia Keys": 149,
            "The Beatles": 150,
            
            // Top 151-200
            "Anitta": 151,
            "The Goo Goo Dolls": 152,
            "Gunna": 153,
            "AC/DC": 154,
            "Jennifer Lopez": 155,
            "Ava Max": 156,
            "The Marías": 157,
            "Daniel Caesar": 158,
            "Billy Joel": 159,
            "Mariah Carey": 160,
            "Lil Baby": 161,
            "Mark Ronson": 162,
            "Macklemore": 163,
            "Kygo": 164,
            "Cardi B": 165,
            "Neton Vega": 166,
            "Tyla": 167,
            "Lord Huron": 168,
            "Christina Aguilera": 169,
            "Udit Narayan": 170,
            "Bon Jovi": 171,
            "RAYE": 172,
            "Jelly Roll": 173,
            "Nelly Furtado": 174,
            "Amitabh Bhattacharya": 175,
            "Gorillaz": 176,
            "Ravyn Lenae": 177,
            "Snoop Dogg": 178,
            "Robin Schulz": 179,
            "Creedence Clearwater Revival": 180,
            "Lil Tecca": 181,
            "Metallica": 182,
            "Juice WRLD": 183,
            "Demi Lovato": 184,
            "Vishal-Shekhar": 185,
            "Whitney Houston": 186,
            "F1 The Album": 187,
            "Young Thug": 188,
            "Quevedo": 189,
            "Major Lazer": 190,
            "Lewis Capaldi": 191,
            "Lost Frequencies": 192,
            "Cigarettes After Sex": 193,
            "The Script": 194,
            "Bob Marley & The Wailers": 195,
            "JHAYCO": 196,
            "Paramore": 197,
            "BTS": 198,
            "Carín León": 199,
            "Tame Impala": 200
        ]
        
        // Return ranking if found, otherwise estimate based on popularity score
        if let ranking = globalRankings[artistName] {
            return ranking
        }
        
        // For artists not in our curated list, estimate ranking based on Spotify popularity
        if let artist = allArtists.first(where: { $0.name.lowercased() == artistName.lowercased() }) {
            switch artist.spotifyPopularity {
            case 90...100: return Int.random(in: 151...300)
            case 80...89: return Int.random(in: 301...500)
            case 70...79: return Int.random(in: 501...800)
            case 60...69: return Int.random(in: 801...1200)
            case 50...59: return Int.random(in: 1201...2000)
            case 40...49: return Int.random(in: 2001...3000)
            default: return Int.random(in: 3001...5000)
            }
        }
        
        return 999 // Default for unknown artists
    }
    
    // MARK: - Spotify Data Loading
    func loadArtistsFromFirestore() {
        Task {
            await MainActor.run {
                isLoadingFromFirestore = true
            }
            
            print("🔥 Loading artists from Firestore...")
            let firestoreArtists = await firestoreService.fetchAllArtists()
            
            await MainActor.run {
                if !firestoreArtists.isEmpty {
                    self.allArtists = firestoreArtists.sorted { $0.spotifyPopularity < $1.spotifyPopularity } // Sort by popularity ranking
                    self.isLoadingFromFirestore = false
                    print("✅ Loaded \(firestoreArtists.count) artists from Firestore")
                    
                    // IMPORTANT: Only update target for completely new games, not restored ones
                    // Check if we have a restored game that already has a valid target
                    if let currentGame = self.currentGame, 
                       currentGame.currentGuesses.isEmpty,
                       !self.allArtists.isEmpty {
                        
                        // Check if the current target artist exists
                        if let existingTarget = self.targetArtist {
                            let fallbackIds = ["taylor-swift", "drake", "bts", "billie-eilish", "ed-sheeran", "ariana-grande", "imagine-dragons", "dua-lipa", "bad-bunny", "blackpink"]
                            
                            if fallbackIds.contains(existingTarget.id) {
                                // Target was a fallback artist, replace it with a real Firestore artist
                                print("🆕 Replacing fallback target '\(existingTarget.name)' with a real Firestore artist")
                                let randomFirestoreArtist = self.allArtists.randomElement()!
                                self.targetArtist = randomFirestoreArtist
                                currentGame.targetArtistId = randomFirestoreArtist.id
                                do {
                                    try self.modelContext.save()
                                    print("✅ Set new game target to: \(randomFirestoreArtist.name)")
                                } catch {
                                    print("❌ Error setting new game target: \(error)")
                                }
                            } else {
                                // Target is already a real Firestore artist, update the reference to include full details (like audio previewURL)
                                if let firestoreVersion = self.allArtists.first(where: { $0.id == existingTarget.id }) {
                                    print("✅ Existing Firestore target '\(firestoreVersion.name)' found, updating reference")
                                    self.targetArtist = firestoreVersion
                                }
                            }
                        } else {
                            // Truly new game with no target set yet
                            print("🆕 No existing target found, setting new Firestore target for fresh game")
                            let randomFirestoreArtist = self.allArtists.randomElement()!
                            currentGame.targetArtistId = randomFirestoreArtist.id
                            self.targetArtist = randomFirestoreArtist
                            
                            do {
                                try self.modelContext.save()
                                print("✅ Set new game target to: \(randomFirestoreArtist.name)")
                            } catch {
                                print("❌ Error setting new game target: \(error)")
                            }
                        }
                    }
                } else {
                    print("❌ No artists found in Firestore, using fallback data")
                    self.loadFallbackArtists()
                    self.isLoadingFromFirestore = false
                }
            }
        }
    }
    
    private func loadFallbackArtists() {
        // Load from local JSON instead of hardcoded list
        if let url = Bundle.main.url(forResource: "artists", withExtension: "json") ?? URL(string: "swiftdb/artists.json"),
           let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            // Map JSON to Artist objects (adjust keys as needed)
            let loadedArtists: [Artist] = json.compactMap { dict in
                guard let name = dict["isim"] as? String,
                      let id = dict["isim"] as? String, // Use name as id if no id field
                      let genre = dict["genre"] as? String,
                      let country = dict["ulke"] as? String,
                      let debutYear = dict["cikis_yili"] as? Int,
                      let gender = dict["cinsiyet"] as? String,
                      let isSolo = dict["tip"] as? String,
                      let popularity = dict["populerlik"] as? Int else { return nil }
                let audioPreview = dict["audio_preview_url"] as? String
                return Artist(
                    id: id,
                    name: name,
                    gender: gender,
                    country: country,
                    debutYear: debutYear,
                    genre: genre,
                    isSolo: isSolo.lowercased().contains("solo"),
                    spotifyPopularity: popularity,
                    previewURL: audioPreview
                )
            }
            allArtists = loadedArtists
            print("📝 Loaded \(loadedArtists.count) artists from local JSON")
        } else {
            // Fallback to hardcoded list if JSON fails
            allArtists = [
                Artist(id: "taylor-swift", name: "Taylor Swift", gender: "Female", country: "United States", debutYear: 2006, genre: "Pop", isSolo: true, spotifyPopularity: 1),
                Artist(id: "drake", name: "Drake", gender: "Male", country: "Canada", debutYear: 2009, genre: "Hip Hop", isSolo: true, spotifyPopularity: 2),
                Artist(id: "bts", name: "BTS", gender: "Group", country: "South Korea", debutYear: 2013, genre: "K-pop", isSolo: false, spotifyPopularity: 3),
                Artist(id: "billie-eilish", name: "Billie Eilish", gender: "Female", country: "United States", debutYear: 2016, genre: "Alternative Pop", isSolo: true, spotifyPopularity: 4),
                Artist(id: "ed-sheeran", name: "Ed Sheeran", gender: "Male", country: "United Kingdom", debutYear: 2011, genre: "Pop", isSolo: true, spotifyPopularity: 5),
                Artist(id: "ariana-grande", name: "Ariana Grande", gender: "Female", country: "United States", debutYear: 2013, genre: "Pop", isSolo: true, spotifyPopularity: 6),
                Artist(id: "imagine-dragons", name: "Imagine Dragons", gender: "Group", country: "United States", debutYear: 2012, genre: "Rock", isSolo: false, spotifyPopularity: 7),
                Artist(id: "dua-lipa", name: "Dua Lipa", gender: "Female", country: "United Kingdom", debutYear: 2015, genre: "Pop", isSolo: true, spotifyPopularity: 8),
                Artist(id: "bad-bunny", name: "Bad Bunny", gender: "Male", country: "Puerto Rico", debutYear: 2016, genre: "Latin Trap", isSolo: true, spotifyPopularity: 9),
                Artist(id: "blackpink", name: "BLACKPINK", gender: "Group", country: "South Korea", debutYear: 2016, genre: "K-pop", isSolo: false, spotifyPopularity: 10)
            ]
            print("📝 Using fallback popular artist data (\(allArtists.count) artists)")
        }
    }
    

    
    // MARK: - Artist Search
    func searchArtists(query: String) -> [Artist] {
        guard !query.isEmpty else { return [] }
        
        // Search local cache first
        let lowercasedQuery = query.lowercased()
        let localResults = allArtists.filter { artist in
            artist.name.lowercased().contains(lowercasedQuery)
        }.prefix(10).map { $0 }
        
        return Array(localResults)
    }
    
    // MARK: - Live Firestore Search
    func searchArtistsLive(query: String) async -> [Artist] {
        guard !query.isEmpty else { return [] }
        
        // Use Firestore search if available, otherwise fall back to local search
        if firestoreService.isConnected {
            return await firestoreService.searchArtists(query: query, limit: 10)
        } else {
            return searchArtists(query: query)
        }
    }
    
    // MARK: - Reset Game (for testing)
    func resetTodaysGame() {
        print("🔄 Resetting today's game...")
        
        // Ensure we're on the main thread for all operations
        if Thread.isMainThread {
            performReset()
        } else {
            DispatchQueue.main.sync {
                performReset()
            }
        }
    }
    
    private func performReset() {
        // Clear current game references first
        self.currentGame = nil
        self.targetArtist = nil
        
        // Delete ALL existing games for a clean slate
        do {
            let descriptor = FetchDescriptor<GameState>()
            let allGames = try modelContext.fetch(descriptor)
            
            for game in allGames {
                modelContext.delete(game)
            }
            
            print("🗑️ Deleted \(allGames.count) existing games")
            
            try modelContext.save()
            print("💾 Saved changes to database")
            
            // Create a completely new game immediately
            self.setupDailyGame()
            print("✅ Reset complete - new game with target: \(self.targetArtist?.name ?? "Unknown")")
            
        } catch {
            print("❌ Error during reset: \(error)")
            // Even if there's an error, try to create a new game
            self.setupDailyGame()
        }
    }
    
    // MARK: - Force Refresh Daily Game
    func forceRefreshDailyGame() {
        print("🔄 Force refreshing daily game...")
        let today = getTodayDateString()
        
        // Delete only today's games to start fresh
        do {
            let descriptor = FetchDescriptor<GameState>()
            let allGames = try modelContext.fetch(descriptor)
            let todaysGames = allGames.filter { $0.dateString.hasPrefix(today) }
            
            for game in todaysGames {
                modelContext.delete(game)
            }
            
            if !todaysGames.isEmpty {
                try modelContext.save()
                print("🗑️ Deleted \(todaysGames.count) existing games for today")
            }
            
        } catch {
            print("❌ Error deleting today's games: \(error)")
        }
        
        // Create a fresh game for today
        DispatchQueue.main.async {
            self.currentGame = nil
            self.targetArtist = nil
            self.setupDailyGame()
            print("✅ Created fresh daily game with target: \(self.targetArtist?.name ?? "Unknown")")
        }
    }
    
    // MARK: - Quick Reset (for testing)
    func quickReset() {
        print("⚡ Quick reset...")
        DispatchQueue.main.async {
            // Create a new game with current date + random suffix for uniqueness
            let uniqueDateString = self.getTodayDateString() + "-\(UUID().uuidString.prefix(8))"
            
            // Select a random artist
            guard !self.allArtists.isEmpty else { return }
            let randomArtist = self.allArtists.randomElement()!
            
            // Create new game
            let newGame = GameState(dateString: uniqueDateString, targetArtistId: randomArtist.id)
            self.modelContext.insert(newGame)
            
            do {
                try self.modelContext.save()
                self.currentGame = newGame
                self.targetArtist = randomArtist
                print("✅ Quick reset complete - target: \(randomArtist.name)")
            } catch {
                print("❌ Quick reset error: \(error)")
            }
        }
    }
    
    // MARK: - Genre Game Creation
    func createNewGenreGame(genre: String) {
        print("🎵 Creating new \(genre) game...")
        
        // CRITICAL: Force clear ALL daily game state for complete isolation
        self.currentGame = nil
        self.targetArtist = nil
        
        // Force UI update to clear any daily game UI state
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        Task {
            // Ensure artists are loaded first with timeout fallback
            var loadAttempts = 0
            while self.allArtists.isEmpty && loadAttempts < 3 {
                print("🔄 Attempt \(loadAttempts + 1): Artists not loaded yet, loading from Firestore...")
                await self.loadArtistsFromFirestore()
                
                if self.allArtists.isEmpty {
                    // Wait briefly and try fallback data
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    await MainActor.run {
                        if self.allArtists.isEmpty {
                            print("⚠️ Firestore load failed, using fallback artists")
                            self.loadFallbackArtists()
                        }
                    }
                }
                loadAttempts += 1
            }
            
            // Double-check we have artists
            if self.allArtists.isEmpty {
                print("❌ Critical: No artists available even after fallback")
                return
            }
            
            print("✅ Artists available: \(self.allArtists.count)")
            print("📊 Available genres: \(Set(self.allArtists.map { $0.genre }).sorted())")
            
            // Get artists from Firestore for the genre
            let firestoreArtists = await FirestoreService.shared.getArtistsByGenre(genre, limit: 50)
            var genreArtists: [Artist] = []
            
            if !firestoreArtists.isEmpty {
                genreArtists = firestoreArtists
                print("� Loaded \(genreArtists.count) \(genre) artists from Firestore")
            } else {
                genreArtists = getArtistsByGenre(genre)
                print("📝 Using \(genreArtists.count) cached \(genre) artists")
            }
            
            // Enhanced fallback strategy
            if genreArtists.isEmpty {
                print("⚠️ No genre-specific artists found, using enhanced fallback strategy...")
                
                // Try partial genre matching
                let partialMatches = self.allArtists.filter { artist in
                    artist.genre.lowercased().contains(genre.lowercased()) ||
                    genre.lowercased().contains(artist.genre.lowercased())
                }
                
                if !partialMatches.isEmpty {
                    genreArtists = partialMatches
                    print("🔍 Found \(genreArtists.count) artists with partial genre matching")
                } else {
                    // Use any available artist as absolute fallback
                    if let fallbackArtist = self.allArtists.randomElement() {
                        genreArtists = [fallbackArtist]
                        print("🔄 Using random fallback artist: \(fallbackArtist.name)")
                    }
                }
            }
            
            await MainActor.run {
                guard !genreArtists.isEmpty else {
                    print("❌ No artists available at all, cannot create genre game")
                    return
                }
                
                // Create a unique game ID for genre games
                let uniqueGameId = "genre-\(genre.lowercased())-\(UUID().uuidString.prefix(8))"
                
                // Select a random artist from the genre
                let randomArtist = genreArtists.randomElement()!
                
                // Create new game
                let newGame = GameState(dateString: uniqueGameId, targetArtistId: randomArtist.id)
                self.modelContext.insert(newGame)
                
                do {
                    try self.modelContext.save()
                    self.currentGame = newGame
                    self.targetArtist = randomArtist
                    
                    // Force UI refresh to show the new game state
                    self.objectWillChange.send()
                    
                    print("✅ Created \(genre) game with target: \(randomArtist.name) (genre: \(randomArtist.genre))")
                    print("✅ Game state: isolated from daily game, fresh start")
                } catch {
                    print("❌ Error creating genre game: \(error)")
                }
            }
        }
    }
    
    private func getArtistsByGenre(_ genre: String) -> [Artist] {
        return allArtists.filter { artist in
            // Use the same mapping as FirestoreService
            let mappedGenres = mapGenreToDatabase(genre)
            
            // Check if artist's genre matches any of the mapped genres
            for mappedGenre in mappedGenres {
                if artist.genre.lowercased() == mappedGenre.lowercased() {
                    return true
                }
            }
            
            // Also check broader related genres for fallback
            let relatedGenres: [String: [String]] = [
                "Alternative": ["Alternative", "Alternative Rock", "Indie Rock", "Indie", "Grunge"],
                "Electronic": ["Electronic", "Dance", "EDM", "Edm", "House", "Techno", "Dubstep", "Tropical House", "Afro House"],
                "Hip Hop": ["Hip-Hop", "Hip Hop", "Rap", "Melodic Rap", "Trap", "Urban", "Argentine Trap"],
                "Pop": ["Pop", "Soft Pop", "Indie Pop", "Electropop", "Teen Pop", "Dance Pop", "Bedroom Pop", "Latin Pop"],
                "R&B": ["R&B", "RnB", "Soul", "Neo-Soul", "Contemporary R&B"],
                "Rock": ["Rock", "Classic Rock", "Hard Rock", "Punk Rock", "Metal"]
            ]
            
            if let related = relatedGenres[genre] {
                return related.contains(artist.genre)
            }
            
            return false
        }
    }
    
    private func getArtistsByGenreBroader(_ genre: String) -> [Artist] {
        return allArtists.filter { artist in
            // Very broad genre matching for fallback
            let artistGenre = artist.genre.lowercased()
            let targetGenre = genre.lowercased()
            
            // Direct match
            if artistGenre == targetGenre {
                return true
            }
            
            // Contains match
            if artistGenre.contains(targetGenre) || targetGenre.contains(artistGenre) {
                return true
            }
            
            // Very broad related genres
            let broadRelatedGenres: [String: [String]] = [
                "pop": ["pop", "dance", "electronic", "indie pop", "electropop", "teen pop", "dance pop", "bedroom pop", "latin pop", "soft pop"],
                "rock": ["rock", "metal", "punk", "hard rock", "classic rock", "punk rock", "indie rock", "alternative rock"],
                "hip hop": ["hip hop", "rap", "trap", "urban", "melodic rap", "argentine trap", "hip-hop"],
                "electronic": ["electronic", "dance", "edm", "house", "techno", "dubstep", "tropical house", "afro house"],
                "alternative": ["alternative", "indie", "grunge", "indie rock", "alternative rock"],
                "r&b": ["r&b", "rnb", "soul", "neo-soul", "contemporary r&b"]
            ]
            
            if let related = broadRelatedGenres[targetGenre] {
                return related.contains(artistGenre)
            }
            
            return false
        }
    }
    
    // Map UI genre names to actual database genre names (same as FirestoreService)
    private func mapGenreToDatabase(_ uiGenre: String) -> [String] {
        switch uiGenre.lowercased() {
        case "pop":
            return ["Pop", "Soft Pop", "Bedroom Pop", "Latin Pop"]
        case "hip hop":
            return ["Rap", "Melodic Rap", "Argentine Trap"]
        case "r&b":
            return ["R&B"]
        case "rock":
            return ["Rock", "Classic Rock"]
        case "electronic":
            return ["Edm", "Tropical House", "Afro House"]
        case "alternative":
            return ["Indie", "Alternative", "Alternative Rock"] // These might not exist much in DB
        default:
            return [uiGenre] // Fallback to exact match
        }
    }
    
    // MARK: - Debug Methods
    func debugPrintExistingGames() {
        do {
            let descriptor = FetchDescriptor<GameState>()
            let allGames = try modelContext.fetch(descriptor)
            
            print("🔍 DEBUG: Found \(allGames.count) existing games in database:")
            for (index, game) in allGames.enumerated() {
                print("  \(index + 1). Date: \(game.dateString), Target: \(game.targetArtistId), Completed: \(game.isCompleted), Guesses: \(game.currentGuesses.count)")
            }
            
            let today = getTodayDateString()
            let todaysGames = allGames.filter { $0.dateString == today }
            print("🗓️ Games for today (\(today)): \(todaysGames.count)")
            
        } catch {
            print("❌ Error fetching games for debug: \(error)")
        }
    }
    
    // MARK: - Reset Game (for testing)
    func resetGame() {
        print("🔄 Resetting game for testing...")
        
        // Delete current game
        if let currentGame = currentGame {
            modelContext.delete(currentGame)
            print("🗑️ Deleted current game")
        }
        
        // Clear target artist
        targetArtist = nil
        
        // Save changes
        do {
            try modelContext.save()
            print("✅ Game reset successfully")
        } catch {
            print("❌ Error resetting game: \(error)")
        }
        
        // Setup new game
        setupDailyGame()
    }
    
    // MARK: - Replacement Artist Logic
    private func findReplacementArtist(for targetId: String) -> Artist? {
        // First try exact match (shouldn't happen if we got here, but just in case)
        if let exactMatch = allArtists.first(where: { $0.id == targetId }) {
            return exactMatch
        }
        
        // Try to find by name if the ID contains a recognizable name pattern
        let nameFromId = targetId.replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .lowercased()
        
        if let nameMatch = allArtists.first(where: { 
            $0.name.lowercased().contains(nameFromId) || nameFromId.contains($0.name.lowercased())
        }) {
            print("🔍 Found artist by name pattern: \(nameMatch.name)")
            return nameMatch
        }
        
        // If all else fails, pick a random popular artist
        let popularArtists = allArtists.filter { $0.spotifyPopularity >= 70 }
        if let randomPopular = popularArtists.randomElement() {
            print("🎲 Selected random popular artist as replacement: \(randomPopular.name)")
            return randomPopular
        }
        
        // Last resort: any artist
        return allArtists.randomElement()
    }
    
    private func ensureTargetArtistHasAudioPreview() async {
        guard let target = targetArtist else { return }
        
        // If target artist already has audio preview, no need to fetch
        if let previewURL = target.previewURL, !previewURL.isEmpty {
            print("🎵 Target artist already has audio preview: \(previewURL)")
            return
        }
        
        print("🎵 Target artist missing audio preview, fetching from Firestore...")
        
        // Try to get the artist from Firestore by name since ID formats might differ
        if let firestoreArtist = await firestoreService.getArtistByName(target.name) {
            await MainActor.run {
                if let previewURL = firestoreArtist.previewURL, !previewURL.isEmpty {
                    print("🎵 Found audio preview in Firestore: \(previewURL)")
                    // Update the target artist with Firestore data
                    self.targetArtist = firestoreArtist
                } else {
                    print("🎵 No audio preview found in Firestore for: \(target.name)")
                }
            }
        } else {
            print("🎵 Could not fetch artist from Firestore: \(target.name)")
        }
    }
}
