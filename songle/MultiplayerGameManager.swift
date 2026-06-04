//
//  MultiplayerGameManager.swift
//  songle
//
//  Created by Ümit BAĞ on 7/2/25.
//

import Foundation
import SwiftData
import FirebaseFirestore

// MARK: - Multiplayer Game Models
struct MultiplayerPlayer: Codable, Identifiable {
    let id = UUID()
    let name: String
    var guesses: [MultiplayerGuess] = []
    var isCorrect = false
    let joinedAt = Date()
    
    var remainingGuesses: Int {
        return max(0, 5 - guesses.count)
    }
    
    var hasGuessesLeft: Bool {
        return remainingGuesses > 0 && !isCorrect
    }
    
    var lastGuessResult: String? {
        return guesses.last?.result
    }
}

struct MultiplayerGuess: Codable, Identifiable {
    let id = UUID()
    let artistName: String
    let timestamp = Date()
    let result: String // "correct", "incorrect"
    let hints: [String: String] // Detailed hint results
    let artistImageURL: String? // Artist profile image URL
    
    init(artistName: String, result: String, hints: [String: String] = [:], artistImageURL: String? = nil) {
        self.artistName = artistName
        self.result = result
        self.hints = hints
        self.artistImageURL = artistImageURL
    }
}

struct MultiplayerGameSession: Codable, Identifiable {
    let id = UUID()
    let inviteCode: String
    let dateString: String
    let targetArtistId: String
    let targetArtistName: String
    var players: [MultiplayerPlayer] = []
    var currentPlayerIndex = 0
    let createdAt = Date()
    var isCompleted = false
    var winnerPlayerIndex: Int?
    var gameStarted = false
    
    var currentPlayer: MultiplayerPlayer? {
        guard currentPlayerIndex < players.count else { return nil }
        return players[currentPlayerIndex]
    }
    
    var canStartGame: Bool {
        return players.count == 2 && !gameStarted
    }
    
    var canContinuePlaying: Bool {
        return gameStarted && !isCompleted && players.count == 2 && 
               (players.contains { $0.hasGuessesLeft } || players.contains { $0.isCorrect })
    }
    
    mutating func nextTurn() {
        if players.count == 2 {
            // Find next player who can play
            let nextIndex = (currentPlayerIndex + 1) % 2
            if players[nextIndex].hasGuessesLeft {
                currentPlayerIndex = nextIndex
            }
        }
    }
    
    mutating func checkGameCompletion() {
        // Game ends if someone wins or both players run out of guesses
        if let winnerIndex = players.firstIndex(where: { $0.isCorrect }) {
            isCompleted = true
            winnerPlayerIndex = winnerIndex
        } else if players.allSatisfy({ !$0.hasGuessesLeft }) {
            isCompleted = true
            winnerPlayerIndex = nil // Draw
        }
    }
    
    var gameStatus: String {
        if !gameStarted {
            return "Waiting for game to start..."
        } else if isCompleted {
            if let winnerIndex = winnerPlayerIndex {
                return "\(players[winnerIndex].name) wins! 🎉"
            } else {
                return "It's a draw! 🤝"
            }
        } else if let currentPlayer = currentPlayer {
            return "\(currentPlayer.name)'s turn"
        }
        return "Unknown status"
    }
}

// MARK: - Multiplayer Game Manager
class MultiplayerGameManager: ObservableObject {
    @Published var currentSession: MultiplayerGameSession?
    @Published var playerName: String = ""
    @Published var inviteCode: String = ""
    @Published var isHost = false
    @Published var targetArtist: Artist?
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var generatedCode: String = ""
    @Published var currentPlayerId: UUID?
    @Published var refreshID = UUID()
    
    enum ConnectionStatus {
        case disconnected, connecting, connected, gameReady
    }
    
    private let gameManager: GameManager
    private var modelContext: ModelContext
    private let spotifyService = SpotifyService.shared
    private let firestoreService = FirestoreService.shared
    private var sessionListener: ListenerRegistration?
    private var refreshTimer: Timer?
    
    init(gameManager: GameManager, modelContext: ModelContext) {
        self.gameManager = gameManager
        self.modelContext = modelContext
        
        // Load saved player name
        self.playerName = UserDefaults.standard.string(forKey: "MultiplayerPlayerName") ?? ""
        
        // Debug initialization
        print("🎮 MultiplayerGameManager initialized")
        print("📊 GameManager allArtists count: \(gameManager.allArtists.count)")
        print("🎯 GameManager target artist: \(gameManager.targetArtist?.name ?? "nil")")
        if gameManager.allArtists.count > 0 {
            print("🎵 Sample artists: \(gameManager.allArtists.prefix(5).map { $0.name })")
        } else {
            print("⚠️ NO ARTISTS LOADED IN GAME MANAGER!")
        }
        
        // Start automatic refresh timer
        startAutoRefreshTimer()
    }
    
    // MARK: - Session Management
    func createNewSession() async -> String {
        isLoading = true
        connectionStatus = .connecting
        errorMessage = nil
        
        let code = generateInviteCode()
        let todayString = getTodayDateString()
        
        guard !gameManager.allArtists.isEmpty else {
            await MainActor.run {
                errorMessage = "No artists available to create multiplayer session"
                isLoading = false
                connectionStatus = .disconnected
            }
            return ""
        }
        
        let randomTarget = gameManager.allArtists.randomElement()!
        print("🎯 Setting RANDOM target artist: \(randomTarget.name)")
        
        let hostPlayer = MultiplayerPlayer(name: playerName)
        var session = MultiplayerGameSession(
            inviteCode: code,
            dateString: todayString,
            targetArtistId: randomTarget.id,
            targetArtistName: randomTarget.name
        )
        session.players.append(hostPlayer)
        session.currentPlayerIndex = 0
        
        self.currentPlayerId = hostPlayer.id
        
        do {
            try await firestoreService.createMultiplayerSession(session)
            
            await MainActor.run {
                self.currentSession = session
                self.targetArtist = randomTarget
                self.isHost = true
                self.connectionStatus = .connected
                self.isLoading = false
                self.generatedCode = code
                
                UserDefaults.standard.set(self.playerName, forKey: "MultiplayerPlayerName")
                
                print("🎮 Created multiplayer session with code: \(code)")
                print("⏳ Waiting for second player to join...")
            }
            
            print("🔄 Host: Setting up real-time listener for session: \(session.id.uuidString)")
            await startListeningForUpdates(sessionId: session.id.uuidString)
            
            // Force refresh after a short delay to ensure Firebase sync
            try? await Task.sleep(for: .seconds(1))
            await refreshSessionFromFirebase()
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to create session: \(error.localizedDescription)"
                self.isLoading = false
                self.connectionStatus = .disconnected
            }
        }
        
        return code
    }
    
    func joinSession(with code: String) async -> Bool {
        isLoading = true
        connectionStatus = .connecting
        errorMessage = nil
        
        do {
            guard let existingSession = try await firestoreService.findMultiplayerSession(inviteCode: code) else {
                await MainActor.run {
                    self.errorMessage = "No session found with code: \(code)"
                    self.isLoading = false
                    self.connectionStatus = .disconnected
                }
                return false
            }
            
            if existingSession.players.count >= 2 {
                await MainActor.run {
                    self.errorMessage = "Session is full"
                    self.isLoading = false
                    self.connectionStatus = .disconnected
                }
                return false
            }
            
            // Check if this player is already in the session
            if existingSession.players.contains(where: { $0.name == playerName }) {
                await MainActor.run {
                    self.errorMessage = "You are already in this session"
                    self.isLoading = false
                    self.connectionStatus = .disconnected
                }
                return false
            }
            
            let targetArtist = gameManager.allArtists.first { $0.id == existingSession.targetArtistId }
            print("🎯 Using target artist from session: \(targetArtist?.name ?? "Unknown")")
            
            let newPlayer = MultiplayerPlayer(name: playerName)
            var updatedSession = existingSession
            updatedSession.players.append(newPlayer)
            
            self.currentPlayerId = newPlayer.id
            
            print("👤 Player joining details:")
            print("   - Player name: \(playerName)")
            print("   - Player ID: \(newPlayer.id)")
            print("   - Total players after join: \(updatedSession.players.count)")
            print("   - Existing players: \(existingSession.players.map { $0.name })")
            
            if updatedSession.players.count == 2 {
                updatedSession.gameStarted = true
                print("🎮 Starting game - 2 players joined!")
            }
            
            try await firestoreService.updateMultiplayerSession(updatedSession)
            
            await MainActor.run {
                self.currentSession = updatedSession
                self.targetArtist = targetArtist
                self.isHost = false
                self.connectionStatus = updatedSession.gameStarted ? .gameReady : .connected
                self.isLoading = false
                
                UserDefaults.standard.set(self.playerName, forKey: "MultiplayerPlayerName")
                self.refreshID = UUID()
                
                print("🎮 Joined multiplayer session: \(code)")
            }
            
            print("🔄 Joiner: Setting up real-time listener for session: \(updatedSession.id.uuidString)")
            await startListeningForUpdates(sessionId: updatedSession.id.uuidString)
            
            try? await Task.sleep(for: .seconds(1))
            await refreshSessionFromFirebase()
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to join session: \(error.localizedDescription)"
                self.isLoading = false
                self.connectionStatus = .disconnected
            }
            return false
        }
        
        return true
    }
    
    func makeGuess(_ guess: String) async -> Bool {
        guard var session = currentSession,
              let currentPlayerId = currentPlayerId,
              let currentPlayerIndex = session.players.firstIndex(where: { $0.id == currentPlayerId }),
              session.players[currentPlayerIndex].hasGuessesLeft,
              isMyTurn() else {
            await MainActor.run {
                if !isMyTurn() {
                    self.errorMessage = "It's not your turn! Wait for your opponent to guess."
                } else {
                    self.errorMessage = "Cannot make guess at this time."
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if self.errorMessage?.contains("It's not your turn") == true || self.errorMessage?.contains("Cannot make guess") == true {
                        self.errorMessage = nil
                    }
                }
            }
            return false
        }
        
        let isCorrect = guess.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == 
                       targetArtist?.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        let hints = generateHints(for: guess, isCorrect: isCorrect)
        let result = isCorrect ? "correct" : "incorrect"
        
        let artistImageURL = await fetchArtistImage(artistName: guess)
        
        let multiplayerGuess = MultiplayerGuess(
            artistName: guess,
            result: result,
            hints: hints,
            artistImageURL: artistImageURL
        )
        
        session.players[currentPlayerIndex].guesses.append(multiplayerGuess)
        
        if isCorrect {
            session.players[currentPlayerIndex].isCorrect = true
        }
        
        session.checkGameCompletion()
        
        if !session.isCompleted {
            session.nextTurn()
        }
        
        do {
            try await firestoreService.updateMultiplayerSession(session)
            
            await MainActor.run {
                self.currentSession = session
            }
            
            print("✅ Guess processed successfully")
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to submit guess: \(error.localizedDescription)"
            }
        }
        
        return isCorrect
    }
    
    // MARK: - Turn Management
    func isMyTurn() -> Bool {
        guard let session = currentSession,
              let currentPlayerId = currentPlayerId,
              let currentPlayerIndex = session.players.firstIndex(where: { $0.id == currentPlayerId }),
              session.gameStarted,
              !session.isCompleted else {
            return false
        }
        
        return session.currentPlayerIndex == currentPlayerIndex
    }
    
    func getCurrentPlayerName() -> String? {
        guard let session = currentSession,
              let currentPlayerId = currentPlayerId,
              let currentPlayer = session.players.first(where: { $0.id == currentPlayerId }) else {
            return nil
        }
        return currentPlayer.name
    }
    
    func getMyPlayer() -> MultiplayerPlayer? {
        guard let session = currentSession,
              let currentPlayerId = currentPlayerId else {
            return nil
        }
        return session.players.first(where: { $0.id == currentPlayerId })
    }
    
    // Get player by name (more reliable for debugging)
    func getMyPlayerByName() -> MultiplayerPlayer? {
        guard let session = currentSession else {
            return nil
        }
        return session.players.first(where: { $0.name == playerName })
    }
    
    // Debug method to get detailed session info
    func getDebugInfo() -> String {
        guard let session = currentSession else {
            return "No session"
        }
        
        // Check if we're in the session by name (more reliable than ID)
        let myPlayerByName = session.players.first(where: { $0.name == playerName })
        let myPlayerById = getMyPlayer()
        let isInSessionByName = myPlayerByName != nil
        let isInSessionById = myPlayerById != nil
        
        return """
        Session: \(session.inviteCode)
        Players: \(session.players.count) (\(session.players.map { $0.name }.joined(separator: ", ")))
        Game Started: \(session.gameStarted)
        My Player ID: \(currentPlayerId?.uuidString ?? "nil")
        I'm in session (by name): \(isInSessionByName)
        I'm in session (by ID): \(isInSessionById)
        My name: \(playerName)
        Host: \(isHost)
        """
    }
    
    // MARK: - Manual Refresh Functions
    func refreshSessionFromFirebase() async {
        guard let sessionId = currentSession?.id.uuidString else { 
            print("⚠️ No current session ID available for refresh")
            return 
        }
        
        print("🔄 Manually refreshing session from Firebase: \(sessionId)")
        
        do {
            if let session = try await firestoreService.getMultiplayerSession(sessionId: sessionId) {
                await MainActor.run {
                    print("🔄 Manual refresh - Session state:")
                    print("   - Players: \(session.players.count)")
                    print("   - Player names: \(session.players.map { $0.name })")
                    print("   - Game started: \(session.gameStarted)")
                    print("   - Connection status before: \(self.connectionStatus)")
                    print("   - My player ID before: \(self.currentPlayerId?.uuidString ?? "nil")")
                    
                    self.currentSession = session
                    
                    // Restore player ID if needed
                    if self.currentPlayerId == nil || !session.players.contains(where: { $0.id == self.currentPlayerId }) {
                        if let myPlayer = session.players.first(where: { $0.name == self.playerName }) {
                            self.currentPlayerId = myPlayer.id
                            print("🔗 Manual refresh: Restored player ID: \(myPlayer.id)")
                        }
                    }
                    
                    if session.gameStarted && session.players.count == 2 {
                        self.connectionStatus = .gameReady
                        print("🎮 Manual refresh: Status updated to GAME READY")
                    } else if session.players.count > 1 {
                        self.connectionStatus = .connected
                        print("🔗 Manual refresh: Status updated to CONNECTED")
                    }
                    
                    self.refreshID = UUID()
                    
                    print("   - Connection status after: \(self.connectionStatus)")
                    print("   - My player ID after: \(self.currentPlayerId?.uuidString ?? "nil")")
                    print("✅ Manual refresh completed")
                }
            } else {
                // Session not found - try to recover
                await handleSessionNotFound(sessionId: sessionId)
            }
        } catch {
            print("❌ Manual refresh failed: \(error.localizedDescription)")
            await handleSessionNotFound(sessionId: sessionId)
        }
    }
    
    // Handle session not found scenario
    private func handleSessionNotFound(sessionId: String) async {
        print("⚠️ Session not found during manual fetch - attempting recovery...")
        
        await MainActor.run {
            // If we have an invite code, try to find the session by code
            if let inviteCode = self.currentSession?.inviteCode {
                print("🔄 Attempting to find session by invite code: \(inviteCode)")
                
                Task {
                    do {
                        if let session = try await self.firestoreService.findMultiplayerSession(inviteCode: inviteCode) {
                            await MainActor.run {
                                print("✅ Session recovered by invite code!")
                                self.currentSession = session
                                
                                // Restore player ID
                                if let myPlayer = session.players.first(where: { $0.name == self.playerName }) {
                                    self.currentPlayerId = myPlayer.id
                                    print("🔗 Recovered player ID: \(myPlayer.id)")
                                }
                                
                                // Restart listener
                                Task {
                                    await self.startListeningForUpdates(sessionId: session.id.uuidString)
                                }
                                
                                if session.gameStarted && session.players.count == 2 {
                                    self.connectionStatus = .gameReady
                                } else if session.players.count > 1 {
                                    self.connectionStatus = .connected
                                }
                                
                                self.refreshID = UUID()
                            }
                        } else {
                            await MainActor.run {
                                print("❌ Session recovery failed - session may have been deleted")
                                self.errorMessage = "Session not found. The game may have ended or been cancelled."
                                self.connectionStatus = .disconnected
                            }
                        }
                    } catch {
                        await MainActor.run {
                            print("❌ Session recovery error: \(error.localizedDescription)")
                            self.errorMessage = "Failed to recover session: \(error.localizedDescription)"
                            self.connectionStatus = .disconnected
                        }
                    }
                }
            } else {
                print("❌ No invite code available for session recovery")
                self.errorMessage = "Session not found and no recovery information available."
                self.connectionStatus = .disconnected
            }
        }
    }
    
    func refreshSession() async {
        await refreshSessionFromFirebase()
    }
    
    // Force refresh and restore player state
    func forceRefreshSession() async {
        print("🔄 Force refreshing session state...")
        await refreshSessionFromFirebase()
        
        // Additional delay and refresh to ensure sync
        try? await Task.sleep(for: .seconds(1))
        await refreshSessionFromFirebase()
    }
    
    // Check if current session is still valid
    func isSessionValid() async -> Bool {
        guard let sessionId = currentSession?.id.uuidString else { return false }
        
        do {
            let session = try await firestoreService.getMultiplayerSession(sessionId: sessionId)
            return session != nil
        } catch {
            print("❌ Session validation failed: \(error.localizedDescription)")
            return false
        }
    }
    
    func resetSession() {
        print("🔄 Resetting multiplayer session")
        
        // Stop listener
        sessionListener?.remove()
        sessionListener = nil
        
        // Stop refresh timer
        refreshTimer?.invalidate()
        refreshTimer = nil
        
        // Clear state
        currentSession = nil
        targetArtist = nil
        isHost = false
        connectionStatus = .disconnected
        errorMessage = nil
        generatedCode = ""
        currentPlayerId = nil
        refreshID = UUID()
        
        print("✅ Session reset complete")
    }
    
    // MARK: - Real-time Listener
    private func startListeningForUpdates(sessionId: String) async {
        print("🔄 Started listening for updates on session: \(sessionId)")
        
        sessionListener?.remove()
        
        sessionListener = firestoreService.listenToMultiplayerSession(sessionId: sessionId) { [weak self] updatedSession in
            guard let self = self else { 
                print("❌ Session listener: No self reference")
                return 
            }
            
            guard let session = updatedSession else { 
                print("⚠️ Session listener: Session not found or deleted")
                Task { @MainActor in
                    self.errorMessage = "Session was deleted or not found. The game may have ended."
                    self.connectionStatus = .disconnected
                }
                return 
            }
            
            Task { @MainActor in
                print("📡 Real-time update received:")
                print("   - Players: \(session.players.count)")
                print("   - Player names: \(session.players.map { $0.name })")
                print("   - Game started: \(session.gameStarted)")
                print("   - Current player ID: \(self.currentPlayerId?.uuidString ?? "nil")")
                
                _ = self.currentSession // Store old session for potential future use
                self.currentSession = session
                
                // Ensure we maintain our player ID if we don't have one set or if it doesn't match
                if self.currentPlayerId == nil || !session.players.contains(where: { $0.id == self.currentPlayerId }) {
                    if let myPlayer = session.players.first(where: { $0.name == self.playerName }) {
                        self.currentPlayerId = myPlayer.id
                        print("🔗 Restored/Updated player ID from session: \(myPlayer.id)")
                    }
                }
                
                if self.errorMessage?.contains("It's not your turn") == true || self.errorMessage?.contains("Cannot make guess") == true {
                    self.errorMessage = nil
                }
                
                let oldStatus = self.connectionStatus
                let oldGameStarted = self.currentSession?.gameStarted ?? false
                
                if session.gameStarted && session.players.count == 2 {
                    self.connectionStatus = .gameReady
                    print("🎮 Status updated to: GAME READY")
                } else if session.players.count > 1 {
                    self.connectionStatus = .connected
                    print("🔗 Status updated to: CONNECTED")
                } else {
                    self.connectionStatus = .connected
                    print("⏳ Status updated to: CONNECTED (waiting)")
                }
                
                // Log game started status changes
                if oldGameStarted != session.gameStarted {
                    print("🎯 Game started status changed: \(oldGameStarted) → \(session.gameStarted)")
                }
                
                if oldStatus != self.connectionStatus {
                    print("📊 Connection status changed: \(oldStatus) → \(self.connectionStatus)")
                }
                
                self.refreshID = UUID()
                
                if session.players.count == 2 && session.gameStarted && self.connectionStatus != .gameReady {
                    print("⚠️ Still not game ready after update - scheduling additional refresh")
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        await self.refreshSessionFromFirebase()
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func generateInviteCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }
    
    private func getTodayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    private func generateHints(for guess: String, isCorrect: Bool) -> [String: String] {
        print("🔍 Generating hints for guess: '\(guess)'")
        
        guard let guessedArtist = gameManager.allArtists.first(where: { $0.name.lowercased() == guess.lowercased() }) else {
            print("❌ Artist not found: '\(guess)'")
            return [
                "Genre": "Unknown|incorrect",
                "Country": "Unknown|incorrect",
                "Debut Year": "Unknown|incorrect",
                "Gender": "Unknown|incorrect",
                "Type": "Unknown|incorrect",
                "Popularity": "0|incorrect"
            ]
        }
        
        let target = targetArtist ?? gameManager.targetArtist
        guard let target = target else {
            print("❌ No target artist available")
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
        
        // Popularity comparison
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
    
    private func fetchArtistImage(artistName: String) async -> String? {
        if let localArtist = gameManager.allArtists.first(where: { $0.name.lowercased() == artistName.lowercased() }),
           let imageURL = localArtist.imageURL, !imageURL.isEmpty {
            print("🖼️ Using cached image for \(artistName)")
            return imageURL
        }
        
        print("⚠️ No image available for \(artistName)")
        return nil
    }
    
    // MARK: - Search Functionality
    func searchArtists(query: String) -> [Artist] {
        guard !query.isEmpty else { return [] }
        
        let lowercasedQuery = query.lowercased()
        let localResults = gameManager.allArtists.filter { artist in
            artist.name.lowercased().contains(lowercasedQuery)
        }.prefix(10).map { $0 }
        
        print("🔍 Search for '\(query)' found \(localResults.count) results")
        return Array(localResults)
    }
    
    func searchArtistsAsync(query: String) async -> [Artist] {
        guard !query.isEmpty else { return [] }
        return searchArtists(query: query)
    }
    
    // MARK: - Automatic Refresh Timer
    private func startAutoRefreshTimer() {
        print("⏰ Starting automatic refresh timer (every 5 seconds)")
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task {
                await self?.autoRefreshSession()
            }
        }
    }
    
    private func stopAutoRefreshTimer() {
        print("⏰ Stopping automatic refresh timer")
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    private func autoRefreshSession() async {
        guard let sessionId = currentSession?.id.uuidString else { return }
        
        print("🔄 Auto-refresh: Checking session \(sessionId)")
        
        do {
            if let session = try await firestoreService.getMultiplayerSession(sessionId: sessionId) {
                await MainActor.run {
                    let oldStatus = self.connectionStatus
                    let oldPlayerCount = self.currentSession?.players.count ?? 0
                    let oldGameStarted = self.currentSession?.gameStarted ?? false
                    
                    self.currentSession = session
                    
                    // Update connection status based on session state
                    if session.players.count == 2 && session.gameStarted {
                        self.connectionStatus = .gameReady
                    } else if session.players.count == 2 && !session.gameStarted {
                        self.connectionStatus = .connected
                    } else if session.players.count == 1 {
                        self.connectionStatus = .connected
                    }
                    
                    // Force UI refresh
                    self.refreshID = UUID()
                    
                    // Log changes
                    if oldStatus != self.connectionStatus || 
                       oldPlayerCount != session.players.count || 
                       oldGameStarted != session.gameStarted {
                        print("🔄 Auto-refresh detected changes:")
                        print("   - Status: \(oldStatus) → \(self.connectionStatus)")
                        print("   - Players: \(oldPlayerCount) → \(session.players.count)")
                        print("   - Game started: \(oldGameStarted) → \(session.gameStarted)")
                    }
                }
            }
        } catch {
            print("❌ Auto-refresh error: \(error.localizedDescription)")
        }
    }
    
    deinit {
        sessionListener?.remove()
        refreshTimer?.invalidate()
        print("🗑️ MultiplayerGameManager deinitialized")
    }
} 