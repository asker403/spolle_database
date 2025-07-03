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
    @Published var spotifyArtists: [SpotifyArtist] = []
    @Published var isLoadingFromSpotify = false
    
    var modelContext: ModelContext
    private let spotifyService = SpotifyService.shared
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        print("🎮 Initializing GameManager...")
        
        // Load fallback artists first for immediate game setup
        loadFallbackArtists()
        
        // Debug: Print existing games
        debugPrintExistingGames()
        
        // Setup game with fallback data
        setupDailyGame()
        
        // Then load enhanced data from Spotify in background
        loadEnhancedArtistsFromSpotify()
    }
    
    // MARK: - Model Context Management
    func setModelContext(_ context: ModelContext) {
        if modelContext !== context {
            self.modelContext = context
            print("🔄 Updated model context")
            // Re-setup the game with new context
            setupDailyGame()
        }
    }
    
    // MARK: - Daily Game Setup
    func setupDailyGame() {
        let today = getTodayDateString()
        print("🗓️ Setting up daily game for: \(today)")
        
        // Check if we already have a game for today
        let descriptor = FetchDescriptor<GameState>(
            predicate: #Predicate<GameState> { $0.dateString == today }
        )
        
        do {
            let existingGames = try modelContext.fetch(descriptor)
            print("📋 Found \(existingGames.count) existing games for today")
            
            if let existingGame = existingGames.first {
                print("🎮 Using existing game: \(existingGame.dateString) - Completed: \(existingGame.isCompleted)")
                currentGame = existingGame
                targetArtist = getArtist(by: existingGame.targetArtistId)
                print("🎯 Target artist: \(targetArtist?.name ?? "Unknown")")
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
    
    private func createNewDailyGame(for dateString: String) {
        guard !allArtists.isEmpty else { 
            print("⚠️ No artists available to create game")
            return 
        }
        
        // Select a random artist for today's challenge
        let randomArtist = allArtists.randomElement()!
        print("🎯 Creating new game with target: \(randomArtist.name)")
        let newGame = GameState(dateString: dateString, targetArtistId: randomArtist.id)
        
        modelContext.insert(newGame)
        
        do {
            try modelContext.save()
            currentGame = newGame
            targetArtist = randomArtist
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
        guard let game = currentGame,
              let target = targetArtist,
              !game.isCompleted,
              game.attemptsRemaining > 0 else {
            return nil
        }
        
        let trimmedName = artistName.trimmingCharacters(in: .whitespacesAndNewlines)
        let isCorrect = trimmedName.lowercased() == target.name.lowercased()
        
        // Generate hints by comparing with a random artist or getting proximity hints
        let hints = generateHints(guessedName: trimmedName, target: target, isCorrect: isCorrect)
        
        // Fetch artist image from Spotify
        let artistImageURL = await fetchArtistImage(artistName: trimmedName)
        
        let guess = Guess(artistName: trimmedName, isCorrect: isCorrect, hints: hints, artistImageURL: artistImageURL)
        
        // Update game state
        await MainActor.run {
            game.currentGuesses.append(guess)
            game.attemptsRemaining -= 1
            
            if isCorrect {
                game.isCompleted = true
                game.isWon = true
            } else if game.attemptsRemaining <= 0 {
                game.isCompleted = true
                game.isWon = false
            }
            
            do {
                try modelContext.save()
            } catch {
                print("Error saving guess: \(error)")
            }
        }
        
        return guess
    }
    
    // MARK: - Enhanced Artist Data Fetching
    private func fetchArtistImage(artistName: String) async -> String? {
        // First check if we have the artist in our local cache with image
        if let localArtist = allArtists.first(where: { $0.name.lowercased() == artistName.lowercased() }),
           let imageURL = localArtist.imageURL, !imageURL.isEmpty {
            print("🖼️ Using cached image for \(artistName)")
            return imageURL
        }
        
        // If Spotify is authenticated, try to get enhanced data
        guard spotifyService.isAuthenticated else {
            print("⚠️ Spotify not authenticated, cannot fetch enhanced data for \(artistName)")
            return nil
        }
        
        print("🔍 Fetching enhanced artist data for: \(artistName)")
        
        // Use the enhanced data fetching method
        if let enhancedArtist = await spotifyService.getEnhancedArtistData(name: artistName) {
            print("✅ Got enhanced data for \(artistName): Country=\(enhancedArtist.country), Debut=\(enhancedArtist.debutYear)")
            
            // Update local cache with enhanced data
            await MainActor.run {
                if let localArtist = self.allArtists.first(where: { $0.name.lowercased() == artistName.lowercased() }) {
                    // Update with enhanced information
                    localArtist.imageURL = enhancedArtist.imageURL
                    localArtist.country = enhancedArtist.country
                    localArtist.debutYear = enhancedArtist.debutYear
                    localArtist.gender = enhancedArtist.gender
                    localArtist.previewURL = enhancedArtist.previewURL
                    localArtist.spotifyId = enhancedArtist.spotifyId
                    print("🔄 Updated local artist \(artistName) with enhanced data")
                } else {
                    // Add new artist to our collection
                    self.allArtists.append(enhancedArtist)
                    print("➕ Added new artist \(artistName) with enhanced data")
                }
            }
            
            return enhancedArtist.imageURL
        }
        
        // Fallback to basic search if enhanced fails
        print("⚠️ Enhanced data fetch failed, falling back to basic search for \(artistName)")
        let spotifyArtists = await spotifyService.searchArtists(query: artistName, limit: 1)
        
        if let spotifyArtist = spotifyArtists.first,
           let imageURL = spotifyArtist.images.first?.url {
            print("✅ Found basic image for \(artistName): \(imageURL)")
            
            // Update local cache with basic data
            await MainActor.run {
                if let localArtist = self.allArtists.first(where: { $0.name.lowercased() == artistName.lowercased() }) {
                    localArtist.imageURL = imageURL
                    localArtist.spotifyId = spotifyArtist.id
                }
            }
            
            return imageURL
        }
        
        print("❌ No image found for \(artistName)")
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
            hints["Debut Year"] = "\(guessedArtist.debutYear)|close"
        } else {
            hints["Debut Year"] = "\(guessedArtist.debutYear)|incorrect"
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
        
        // Popularity comparison (using global ranking by monthly listeners)
        let guessedRanking = getGlobalRanking(for: guessedArtist.name)
        let targetRanking = getGlobalRanking(for: target.name)
        
        if guessedRanking == targetRanking {
            hints["Popularity"] = "#\(guessedRanking)|correct"
        } else if abs(guessedRanking - targetRanking) <= 10 {
            hints["Popularity"] = "#\(guessedRanking)|close"
        } else {
            hints["Popularity"] = "#\(guessedRanking)|incorrect"
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
        return allArtists.first { $0.id == id }
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
    
    // MARK: - Refresh Unknown Data
    func refreshUnknownArtistData() async {
        print("🔄 Refreshing artists with unknown data...")
        
        guard spotifyService.isAuthenticated else {
            print("⚠️ Cannot refresh unknown data - Spotify not authenticated")
            return
        }
        
        let artistsWithUnknownData = allArtists.filter { artist in
            artist.country == "Unknown" || artist.gender == "Unknown" || artist.debutYear == 0
        }
        
        print("🔍 Found \(artistsWithUnknownData.count) artists with unknown data")
        
        for artist in artistsWithUnknownData.prefix(20) { // Limit to avoid rate limits
            await refreshArtistData(for: artist.name)
            
            // Small delay to avoid rate limits
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        }
        
        await MainActor.run {
            print("✅ Finished refreshing unknown artist data")
        }
    }
    
    // MARK: - Spotify Data Loading (Updated to use enhanced data when possible)
    func loadArtistsFromSpotify() {
        Task {
            await MainActor.run {
                isLoadingFromSpotify = true
            }
            
            // Authenticate with Spotify
            await spotifyService.authenticate()
            
            if spotifyService.isAuthenticated {
                print("🎵 Loading artists from Spotify with enhanced data where possible...")
                
                // Load popular artists from various genres with higher limits for better selection
                let genres = ["pop", "rock", "hip-hop", "electronic", "alternative", "r&b", "country", "indie", "latin", "metal"]
                var allSpotifyArtists: [SpotifyArtist] = []
                
                for genre in genres {
                    let artists = await spotifyService.getArtistsByGenre(genre, limit: 50)
                    allSpotifyArtists.append(contentsOf: artists)
                    print("📥 Loaded \(artists.count) \(genre) artists")
                }
                
                // Remove duplicates and filter by popularity (keep only top artists)
                let uniqueArtists = Array(Set(allSpotifyArtists.map { $0.id })).compactMap { id in
                    allSpotifyArtists.first { $0.id == id }
                }
                
                // Filter to keep only popular artists (popularity score 40+) and sort by popularity
                let popularArtists = uniqueArtists
                    .filter { $0.popularity >= 40 } // Only keep reasonably popular artists
                    .sorted { $0.popularity > $1.popularity } // Sort by popularity (highest first)
                    .prefix(150) // Take top 150 most popular artists
                
                // Convert to Artist objects, trying enhanced data for top artists
                var convertedArtists: [Artist] = []
                
                for (index, spotifyArtist) in popularArtists.enumerated() {
                    if index < 30 { // Get enhanced data for top 30 artists
                        if let enhancedArtist = await spotifyService.getEnhancedArtistData(name: spotifyArtist.name) {
                            convertedArtists.append(enhancedArtist)
                            print("✅ Enhanced: \(enhancedArtist.name) - \(enhancedArtist.country)")
                        } else {
                            convertedArtists.append(spotifyArtist.toArtist())
                        }
                        
                        // Small delay to avoid rate limits
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                    } else {
                        // Use basic conversion for remaining artists
                        convertedArtists.append(spotifyArtist.toArtist())
                    }
                }

                await MainActor.run {
                    self.spotifyArtists = Array(popularArtists)
                    self.allArtists = convertedArtists
                    self.isLoadingFromSpotify = false
                    print("✅ Loaded \(convertedArtists.count) artists from Spotify (top 30 with enhanced data)")
                    
                    // If we have a fresh game (no guesses yet), update it with a Spotify artist
                    if let currentGame = self.currentGame, 
                       currentGame.currentGuesses.isEmpty,
                       !self.allArtists.isEmpty {
                        print("🔄 Updating game with Spotify artist...")
                        let randomSpotifyArtist = self.allArtists.randomElement()!
                        currentGame.targetArtistId = randomSpotifyArtist.id
                        self.targetArtist = randomSpotifyArtist
                        
                        do {
                            try self.modelContext.save()
                            print("✅ Updated game target to: \(randomSpotifyArtist.name) from \(randomSpotifyArtist.country)")
                        } catch {
                            print("❌ Error updating game: \(error)")
                        }
                    }
                }
            } else {
                print("❌ Spotify authentication failed, using fallback data")
                await MainActor.run {
                    self.loadFallbackArtists()
                    self.isLoadingFromSpotify = false
                }
            }
        }
    }
    
    private func loadFallbackArtists() {
        // Enhanced fallback data with accurate information from the knowledge database
        let fallbackArtists = [
            Artist(id: "taylor-swift", name: "Taylor Swift", gender: "Female", country: "United States", debutYear: 2006, genre: "Pop", isSolo: true, spotifyPopularity: 95),
            Artist(id: "drake", name: "Drake", gender: "Male", country: "Canada", debutYear: 2009, genre: "Hip-Hop", isSolo: true, spotifyPopularity: 92),
            Artist(id: "billie-eilish", name: "Billie Eilish", gender: "Female", country: "United States", debutYear: 2016, genre: "Alternative", isSolo: true, spotifyPopularity: 88),
            Artist(id: "the-beatles", name: "The Beatles", gender: "Group", country: "United Kingdom", debutYear: 1960, genre: "Rock", isSolo: false, spotifyPopularity: 85),
            Artist(id: "bad-bunny", name: "Bad Bunny", gender: "Male", country: "Puerto Rico", debutYear: 2016, genre: "Hip-Hop", isSolo: true, spotifyPopularity: 94),
            Artist(id: "the-weeknd", name: "The Weeknd", gender: "Male", country: "Canada", debutYear: 2011, genre: "R&B", isSolo: true, spotifyPopularity: 91),
            Artist(id: "dua-lipa", name: "Dua Lipa", gender: "Female", country: "United Kingdom", debutYear: 2015, genre: "Pop", isSolo: true, spotifyPopularity: 89),
            Artist(id: "ed-sheeran", name: "Ed Sheeran", gender: "Male", country: "United Kingdom", debutYear: 2011, genre: "Pop", isSolo: true, spotifyPopularity: 87),
            Artist(id: "ariana-grande", name: "Ariana Grande", gender: "Female", country: "United States", debutYear: 2013, genre: "Pop", isSolo: true, spotifyPopularity: 86),
            Artist(id: "post-malone", name: "Post Malone", gender: "Male", country: "United States", debutYear: 2015, genre: "Hip-Hop", isSolo: true, spotifyPopularity: 84),
            Artist(id: "david-guetta", name: "David Guetta", gender: "Male", country: "France", debutYear: 2001, genre: "Electronic", isSolo: true, spotifyPopularity: 82),
            Artist(id: "bruno-mars", name: "Bruno Mars", gender: "Male", country: "United States", debutYear: 2010, genre: "Pop", isSolo: true, spotifyPopularity: 90),
            Artist(id: "adele", name: "Adele", gender: "Female", country: "United Kingdom", debutYear: 2008, genre: "Pop", isSolo: true, spotifyPopularity: 88),
            Artist(id: "eminem", name: "Eminem", gender: "Male", country: "United States", debutYear: 1996, genre: "Hip-Hop", isSolo: true, spotifyPopularity: 85),
            Artist(id: "rihanna", name: "Rihanna", gender: "Female", country: "Barbados", debutYear: 2005, genre: "Pop", isSolo: true, spotifyPopularity: 89),
            Artist(id: "coldplay", name: "Coldplay", gender: "Group", country: "United Kingdom", debutYear: 1996, genre: "Rock", isSolo: false, spotifyPopularity: 86),
            Artist(id: "lady-gaga", name: "Lady Gaga", gender: "Female", country: "United States", debutYear: 2008, genre: "Pop", isSolo: true, spotifyPopularity: 87),
            Artist(id: "justin-bieber", name: "Justin Bieber", gender: "Male", country: "Canada", debutYear: 2009, genre: "Pop", isSolo: true, spotifyPopularity: 88),
            Artist(id: "beyonce", name: "Beyoncé", gender: "Female", country: "United States", debutYear: 1997, genre: "R&B", isSolo: true, spotifyPopularity: 86),
            Artist(id: "kanye-west", name: "Kanye West", gender: "Male", country: "United States", debutYear: 2004, genre: "Hip-Hop", isSolo: true, spotifyPopularity: 83),
            Artist(id: "calvin-harris", name: "Calvin Harris", gender: "Male", country: "United Kingdom", debutYear: 2007, genre: "Electronic", isSolo: true, spotifyPopularity: 81),
            Artist(id: "imagine-dragons", name: "Imagine Dragons", gender: "Group", country: "United States", debutYear: 2008, genre: "Rock", isSolo: false, spotifyPopularity: 84),
            Artist(id: "maroon-5", name: "Maroon 5", gender: "Group", country: "United States", debutYear: 1994, genre: "Pop", isSolo: false, spotifyPopularity: 82),
            Artist(id: "shawn-mendes", name: "Shawn Mendes", gender: "Male", country: "Canada", debutYear: 2014, genre: "Pop", isSolo: true, spotifyPopularity: 80),
            Artist(id: "selena-gomez", name: "Selena Gomez", gender: "Female", country: "United States", debutYear: 2009, genre: "Pop", isSolo: true, spotifyPopularity: 81)
        ]
        
        allArtists = fallbackArtists
        print("📝 Using enhanced fallback artist data (\(fallbackArtists.count) artists with complete information)")
    }
    
    // MARK: - Artist Search
    func searchArtists(query: String) -> [Artist] {
        guard !query.isEmpty else { return [] }
        
        // First, search local cache
        let lowercasedQuery = query.lowercased()
        let localResults = allArtists.filter { artist in
            artist.name.lowercased().contains(lowercasedQuery)
        }.prefix(10).map { $0 }
        
        return Array(localResults)
    }
    
    // MARK: - Live Spotify Search
    func searchArtistsLive(query: String) async -> [Artist] {
        guard !query.isEmpty else { return [] }
        
        if spotifyService.isAuthenticated {
            let spotifyResults = await spotifyService.searchArtists(query: query, limit: 10)
            return spotifyResults.map { $0.toArtist() }
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
            let descriptor = FetchDescriptor<GameState>(
                predicate: #Predicate<GameState> { $0.dateString == today }
            )
            let todaysGames = try modelContext.fetch(descriptor)
            
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
        
        // Clear current game immediately
        self.currentGame = nil
        self.targetArtist = nil
        
        Task {
            // Try to get fresh artists from Spotify for the genre
            var genreArtists: [Artist] = []
            
            if spotifyService.isAuthenticated {
                let spotifyArtists = await spotifyService.getArtistsByGenre(genre, limit: 50)
                // Filter to only popular artists for better game experience
                let popularGenreArtists = spotifyArtists.filter { $0.popularity >= 35 }
                genreArtists = popularGenreArtists.map { $0.toArtist() }
                print("🎵 Loaded \(genreArtists.count) popular \(genre) artists from Spotify")
            }
            
            // Fallback to local cache if Spotify fails or returns no results
            if genreArtists.isEmpty {
                genreArtists = getArtistsByGenre(genre)
                print("📝 Using \(genreArtists.count) cached \(genre) artists")
            }
            
            guard !genreArtists.isEmpty else {
                print("❌ No artists found for genre: \(genre)")
                return
            }
            
            await MainActor.run {
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
                    print("✅ Created \(genre) game with target: \(randomArtist.name)")
                } catch {
                    print("❌ Error creating genre game: \(error)")
                }
            }
        }
    }
    
    private func getArtistsByGenre(_ genre: String) -> [Artist] {
        return allArtists.filter { artist in
            // Direct match
            if artist.genre.lowercased() == genre.lowercased() {
                return true
            }
            
            // Related genres
            let relatedGenres: [String: [String]] = [
                "Pop": ["Pop", "Alternative", "Indie Pop"],
                "Rock": ["Rock", "Alternative Rock", "Indie Rock"],
                "Hip Hop": ["Hip-Hop", "R&B", "Rap"],
                "Electronic": ["Electronic", "Dance", "EDM"],
                "Classical": ["Classical", "Jazz", "Blues"],
                "Country": ["Country", "Folk", "Americana"]
            ]
            
            if let related = relatedGenres[genre] {
                return related.contains(artist.genre)
            }
            
            return false
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
    
    // MARK: - Enhanced Artist Loading
    func loadEnhancedArtistsFromSpotify() {
        Task {
            await MainActor.run {
                isLoadingFromSpotify = true
            }
            
            // Authenticate with Spotify
            await spotifyService.authenticate()
            
            if spotifyService.isAuthenticated {
                print("🎵 Loading enhanced artist data from Spotify...")
                
                // Load popular artists from various genres
                let genres = ["pop", "rock", "hip-hop", "electronic", "alternative", "r&b", "country", "indie", "latin", "metal"]
                var enhancedArtists: [Artist] = []
                
                // Get a smaller initial set for enhanced processing (since it's more expensive)
                for genre in genres {
                    let spotifyArtists = await spotifyService.getArtistsByGenre(genre, limit: 20)
                    let popularArtists = spotifyArtists.filter { $0.popularity >= 50 }
                    
                    print("📥 Processing \(popularArtists.count) popular \(genre) artists for enhanced data...")
                    
                    // Process each artist to get enhanced data
                    for spotifyArtist in popularArtists.prefix(10) { // Limit to avoid rate limits
                        if let enhancedArtist = await spotifyService.getEnhancedArtistData(name: spotifyArtist.name) {
                            enhancedArtists.append(enhancedArtist)
                            print("✅ Enhanced: \(enhancedArtist.name) - \(enhancedArtist.country) (\(enhancedArtist.debutYear))")
                        } else {
                            // Fallback to basic conversion
                            enhancedArtists.append(spotifyArtist.toArtist())
                        }
                        
                        // Small delay to avoid rate limits
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                    }
                }
                
                // Sort by popularity and remove duplicates
                let uniqueArtists = Dictionary(grouping: enhancedArtists, by: { $0.name.lowercased() })
                    .compactMap { _, artists in artists.first }
                    .sorted { $0.spotifyPopularity > $1.spotifyPopularity }
                
                await MainActor.run {
                    self.allArtists = Array(uniqueArtists.prefix(100)) // Keep top 100
                    self.isLoadingFromSpotify = false
                    print("✅ Loaded \(self.allArtists.count) enhanced artists from Spotify")
                    
                    // Update current game if it has no guesses yet
                    self.updateGameWithEnhancedData()
                }
            } else {
                print("❌ Spotify authentication failed, using fallback data")
                await MainActor.run {
                    self.loadFallbackArtists()
                    self.isLoadingFromSpotify = false
                }
            }
        }
    }
    
    private func updateGameWithEnhancedData() {
        if let currentGame = self.currentGame, 
           currentGame.currentGuesses.isEmpty,
           !self.allArtists.isEmpty {
            print("🔄 Updating game with enhanced artist data...")
            let randomEnhancedArtist = self.allArtists.randomElement()!
            currentGame.targetArtistId = randomEnhancedArtist.id
            self.targetArtist = randomEnhancedArtist
            
            do {
                try self.modelContext.save()
                print("✅ Updated game target to enhanced artist: \(randomEnhancedArtist.name) from \(randomEnhancedArtist.country)")
            } catch {
                print("❌ Error updating game with enhanced data: \(error)")
            }
        }
    }
    
    // MARK: - Refresh Artist Data
    func refreshArtistData(for artistName: String) async {
        print("🔄 Refreshing data for artist: \(artistName)")
        
        guard spotifyService.isAuthenticated else {
            print("⚠️ Cannot refresh artist data - Spotify not authenticated")
            return
        }
        
        if let enhancedArtist = await spotifyService.getEnhancedArtistData(name: artistName) {
            await MainActor.run {
                if let index = self.allArtists.firstIndex(where: { $0.name.lowercased() == artistName.lowercased() }) {
                    // Update existing artist with enhanced data
                    self.allArtists[index] = enhancedArtist
                    print("✅ Refreshed artist data: \(enhancedArtist.name) - \(enhancedArtist.country) (\(enhancedArtist.debutYear))")
                } else {
                    // Add new artist if not found
                    self.allArtists.append(enhancedArtist)
                    print("➕ Added new enhanced artist: \(enhancedArtist.name)")
                }
            }
        }
    }
} 