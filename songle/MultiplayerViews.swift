//
//  MultiplayerViews.swift
//  songle
//
//  Created by Ümit BAĞ on 7/2/25.
//

import SwiftUI
import SwiftData
import AVFoundation

// MARK: - Multiplayer Setup View
struct MultiplayerSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var gameManager: GameManager?
    @State private var multiplayerManager: MultiplayerGameManager?
    @State private var selectedMode: MultiplayerMode = .create
    @State private var showMultiplayerGame = false
    @State private var playerName = ""
    @State private var inviteCode = ""
    @State private var generatedCode = ""
    
    enum MultiplayerMode {
        case create, join
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                mainContent
            }
            .navigationTitle("Multiplayer Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .onAppear {
            // Initialize managers with environment's modelContext
            if gameManager == nil {
                gameManager = GameManager(modelContext: modelContext)
            }
            if multiplayerManager == nil {
                multiplayerManager = MultiplayerGameManager(gameManager: gameManager!, modelContext: modelContext)
            }
            
            playerName = multiplayerManager?.playerName ?? ""
            multiplayerManager?.resetSession()
        }
        .fullScreenCover(isPresented: $showMultiplayerGame) {
            if let manager = multiplayerManager {
                MultiplayerGameView(multiplayerManager: manager)
            }
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var mainContent: some View {
        VStack(spacing: 32) {
            headerSection
            modeSelectionSection
            playerNameInputSection
            
            // Mode-specific content
            if selectedMode == .create {
                createGameSection
            } else {
                joinGameSection
            }
            
            // Error message
            if let errorMessage = multiplayerManager?.errorMessage {
                errorMessageView(errorMessage)
            }
            
            Spacer()
        }
        .padding(.horizontal, 30)
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.blue)
                
                Text("Multiplayer")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 4) {
                Text("Challenge a friend to today's music puzzle!")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("👥 2 Players • 🎯 5 Guesses Each • 🎵 Same Song")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(20)
            }
            .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }
    
    private var modeSelectionSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                createModeButton
                joinModeButton
            }
            .background(Color(.systemGray6))
            .cornerRadius(22)
        }
    }
    
    private var createModeButton: some View {
        Button(action: { selectedMode = .create }) {
            VStack(spacing: 4) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20, weight: .medium))
                Text("Host Game")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(selectedMode == .create ? .white : .blue)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(createModeBackground)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
    
    private var joinModeButton: some View {
        Button(action: { selectedMode = .join }) {
            VStack(spacing: 4) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 20, weight: .medium))
                Text("Join Game")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(selectedMode == .join ? .white : .blue)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(joinModeBackground)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
    
    private var createModeBackground: some View {
        Group {
            if selectedMode == .create {
                LinearGradient(colors: [Color.blue, Color.purple], startPoint: .leading, endPoint: .trailing)
            } else {
                Color.clear
            }
        }
    }
    
    private var joinModeBackground: some View {
        Group {
            if selectedMode == .join {
                LinearGradient(colors: [Color.blue, Color.purple], startPoint: .leading, endPoint: .trailing)
            } else {
                Color.clear
            }
        }
    }
    
    private var playerNameInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Player Name")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            TextField("Enter your name", text: $playerName)
                .font(.system(size: 16, weight: .medium))
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    private func errorMessageView(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.red)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var createGameSection: some View {
        VStack(spacing: 16) {
            if generatedCode.isEmpty {
                Button(action: { createGame() }) {
                    HStack {
                        if multiplayerManager?.isLoading == true {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 16, weight: .medium))
                        }
                        Text(multiplayerManager?.isLoading == true ? "Creating..." : "Create Game")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(colors: [Color.blue, Color.purple], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(27)
                    .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .disabled(playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || multiplayerManager?.isLoading == true)
                .opacity(playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || multiplayerManager?.isLoading == true ? 0.6 : 1.0)
            } else {
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Text("🎯 Game Created!")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.green)
                        
                        Text("Share this code with your friend:")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    // Invite code display
                    VStack(spacing: 8) {
                        Text(generatedCode)
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        
                        Button(action: {
                            UIPasteboard.general.string = generatedCode
                        }) {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                Text("Copy Code")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                        }
                    }
                    
                    // Connection status
                    VStack(spacing: 4) {
                        HStack {
                            Circle()
                                .fill(connectionStatusColor)
                                .frame(width: 8, height: 8)
                            Text(connectionStatusText)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        // Debug info for connection status
                        if let manager = multiplayerManager {
                            Text(manager.getDebugInfo())
                                .font(.system(size: 8, weight: .regular))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                            
                            // Auto-refresh status indicator
                            Text("⏰ Auto-refresh active (every 5s)")
                                .font(.system(size: 10, weight: .regular))
                                .foregroundColor(.green)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Manual refresh button - show when connected but waiting or when there are 2 players
                        if (multiplayerManager?.connectionStatus == .connected && 
                            multiplayerManager?.currentSession?.players.count == 1) ||
                           (multiplayerManager?.currentSession?.players.count == 2 && 
                            multiplayerManager?.currentSession?.gameStarted == false) {
                            Button(action: refreshGameState) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 16, weight: .medium))
                                    Text("🔄 Refresh Game State")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(colors: [Color.orange, Color.red], startPoint: .leading, endPoint: .trailing)
                                )
                                .cornerRadius(20)
                                .shadow(color: .orange.opacity(0.3), radius: 5, x: 0, y: 2)
                            }
                            .padding(.top, 8)
                        }
                        
                        // Force refresh button for debugging
                        Button(action: forceRefreshGameState) {
                            HStack {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .font(.system(size: 16, weight: .medium))
                                Text("🔧 Force Refresh")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(colors: [Color.purple, Color.blue], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(20)
                            .shadow(color: .purple.opacity(0.3), radius: 5, x: 0, y: 2)
                        }
                        .padding(.top, 8)
                        
                        // Session validation button for debugging
                        Button(action: validateSession) {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 16, weight: .medium))
                                Text("🔍 Validate Session")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(colors: [Color.orange, Color.red], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(20)
                            .shadow(color: .orange.opacity(0.3), radius: 5, x: 0, y: 2)
                        }
                        .padding(.top, 8)
                    }
                    
                    // Show start button if game is ready OR if we have 2 players and game is started
                    if multiplayerManager?.connectionStatus == .gameReady || 
                       (multiplayerManager?.currentSession?.players.count == 2 && 
                        multiplayerManager?.currentSession?.gameStarted == true) {
                        Button(action: startMultiplayerGame) {
                            Text("🎮 Start Game!")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(
                                    LinearGradient(colors: [Color.green, Color.blue], startPoint: .leading, endPoint: .trailing)
                                )
                                .cornerRadius(27)
                        }
                    }
                }
            }
        }
    }
    
    private var joinGameSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Game Invite Code")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                TextField("Enter 6-digit code", text: $inviteCode)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                    .textCase(.uppercase)
                    .autocorrectionDisabled()
                    .onChange(of: inviteCode) { _, newValue in
                        // Limit to 6 characters
                        if newValue.count > 6 {
                            inviteCode = String(newValue.prefix(6))
                        }
                    }
            }
            
            Button(action: { joinGame() }) {
                HStack {
                    if multiplayerManager?.isLoading == true {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 16, weight: .medium))
                    }
                    Text(multiplayerManager?.isLoading == true ? "Joining..." : "Join Game")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    LinearGradient(colors: [Color.blue, Color.purple], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(27)
                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .disabled(playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
                     inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).count != 6 ||
                     multiplayerManager?.isLoading == true)
            .opacity((playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
                     inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).count != 6 ||
                     multiplayerManager?.isLoading == true) ? 0.6 : 1.0)
        }
    }
    
    private var connectionStatusColor: Color {
        switch multiplayerManager?.connectionStatus {
        case .disconnected: return .red
        case .connecting: return .orange
        case .connected: return .blue
        case .gameReady: return .green
        case .none: return .gray
        }
    }
    
    private var connectionStatusText: String {
        // Check actual game state first, then fall back to connection status
        if let session = multiplayerManager?.currentSession {
            if session.players.count == 2 && session.gameStarted {
                return "Ready to play! 🎮"
            } else if session.players.count == 2 && !session.gameStarted {
                return "Both players joined - Starting game... ⏳"
            } else if session.players.count == 1 {
                return "Waiting for friend... (Auto-refresh every 5s) 🔄"
            }
        }
        
        // Fallback to connection status
        switch multiplayerManager?.connectionStatus {
        case .disconnected: return "Disconnected ❌"
        case .connecting: return "Connecting... 🔗"
        case .connected: return "Connected - Waiting for friend... 🔄"
        case .gameReady: return "Ready to play! 🎮"
        case .none: return "Loading... ⏳"
        }
    }
    
    private func createGame() {
        Task {
            guard let manager = multiplayerManager else { return }
            manager.playerName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
            let code = await manager.createNewSession()
            if !code.isEmpty {
                await MainActor.run {
                    generatedCode = code
                }
            }
        }
    }
    
    private func joinGame() {
        Task {
            guard let manager = multiplayerManager else { return }
            manager.playerName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
            let success = await manager.joinSession(with: inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
            if success {
                await MainActor.run {
                    startMultiplayerGame()
                }
            }
        }
    }
    
    private func startMultiplayerGame() {
        showMultiplayerGame = true
    }
    
    private func refreshGameState() {
        Task {
            guard let manager = multiplayerManager else { return }
            await manager.refreshSession()
        }
    }
    
    private func forceRefreshGameState() {
        Task {
            guard let manager = multiplayerManager else { return }
            await manager.forceRefreshSession()
        }
    }
    
    private func validateSession() {
        Task {
            guard let manager = multiplayerManager else { return }
            let isValid = await manager.isSessionValid()
            await MainActor.run {
                if isValid {
                    print("✅ Session is valid")
                } else {
                    print("❌ Session is not valid")
                }
            }
        }
    }
}

// MARK: - Multiplayer Game View
struct MultiplayerGameView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var multiplayerManager: MultiplayerGameManager
    @State private var searchText = ""
    @State private var searchResults: [Artist] = []
    @State private var showSearchResults = false
    @State private var animateHints = false
    @State private var refreshID = UUID()
    @State private var showSuccessView = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                
                VStack(spacing: 0) {
                    gameHeaderSection
                    playersSection
                    gameContentSection
                }
            }
            .navigationTitle("Multiplayer Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Leave") {
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .onAppear {
            refreshGameData()
        }
        .onChange(of: searchText) { _, newValue in
            updateSearchResults(newValue)
        }
        .onChange(of: multiplayerManager.refreshID) { _, _ in
            print("📱 UI RefreshID changed - updating view")
            if let session = multiplayerManager.currentSession {
                print("📱 UI State: \(session.players.count) players, gameStarted: \(session.gameStarted)")
            }
        }
        .onChange(of: multiplayerManager.currentSession?.isCompleted) { _, isCompleted in
            if isCompleted == true {
                // Show success view after a brief delay when game ends
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showSuccessView = true
                }
            }
        }
        .sheet(isPresented: $showSuccessView) {
            if let targetArtist = multiplayerManager.targetArtist {
                MultiplayerSuccessView(
                    artist: targetArtist,
                    session: multiplayerManager.currentSession,
                    playerName: multiplayerManager.playerName
                )
            }
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var gameHeaderSection: some View {
        VStack(spacing: 12) {
            // Game status (with debug info)
            VStack(spacing: 4) {
                Text(getGameStatusText())
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(getGameStatusBackground())
                    .cornerRadius(20)
                
                // Debug info
                if let session = multiplayerManager.currentSession {
                    Text(multiplayerManager.getDebugInfo())
                        .font(.system(size: 8, weight: .regular))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }
            
            // Target artist hint (if game completed)
            if let session = multiplayerManager.currentSession, session.isCompleted {
                Text("The answer was: \(session.targetArtistName)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private func getGameStatusText() -> String {
        guard let session = multiplayerManager.currentSession else { return "Loading..." }
        
        if !session.gameStarted {
            return "Waiting for both players to join..."
        } else if session.isCompleted {
            if let winnerIndex = session.winnerPlayerIndex {
                let winner = session.players[winnerIndex]
                return multiplayerManager.getCurrentPlayerName() == winner.name ? "You won! 🎉" : "\(winner.name) won! 🎉"
            } else {
                return "It's a draw! 🤝"
            }
        } else {
            return "Game in progress - Take turns guessing!"
        }
    }
    
    private func getGameStatusBackground() -> Color {
        guard let session = multiplayerManager.currentSession else { return Color(.systemGray6) }
        
        if session.isCompleted {
            if let winnerIndex = session.winnerPlayerIndex {
                let winner = session.players[winnerIndex]
                return multiplayerManager.getCurrentPlayerName() == winner.name ? Color.green.opacity(0.2) : Color.red.opacity(0.2)
            } else {
                return Color.yellow.opacity(0.2)
            }
        } else if session.gameStarted {
            return Color.blue.opacity(0.1)
        } else {
            return Color(.systemGray6)
        }
    }
    
    private var playersSection: some View {
        HStack(spacing: 16) {
            ForEach(Array((multiplayerManager.currentSession?.players ?? []).enumerated()), id: \.element.id) { index, player in
                playerCard(player: player, isCurrentPlayer: index == multiplayerManager.currentSession?.currentPlayerIndex)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    private func playerCard(player: MultiplayerPlayer, isCurrentPlayer: Bool) -> some View {
        let isMyPlayer = multiplayerManager.getCurrentPlayerName() == player.name
        
        return VStack(spacing: 8) {
            // Player name and status
            HStack {
                Text(player.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                if isMyPlayer {
                    Text("(You)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                
                if player.isCorrect {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            // Turn indicator and guesses remaining
            VStack(spacing: 4) {
                if isCurrentPlayer && multiplayerManager.currentSession?.gameStarted == true && !multiplayerManager.currentSession!.isCompleted {
                    Text("🎯 Current Turn")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                }
                
                Text("\(player.remainingGuesses)/5 guesses left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            // Recent guesses (simple view for player cards)
            VStack(spacing: 4) {
                ForEach(player.guesses.suffix(3).reversed(), id: \.id) { guess in
                    SimpleGuessRowView(guess: guess)
                }
                
                if player.guesses.count > 3 {
                    Text("+ \(player.guesses.count - 3) more guesses")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isCurrentPlayer ? Color.blue : (isMyPlayer ? Color.green.opacity(0.5) : Color.clear), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    private var gameContentSection: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let session = multiplayerManager.currentSession, !session.isCompleted {
                    // Search section (moved to top for better accessibility)
                    searchSection
                    
                    // Search results
                    if showSearchResults {
                        searchResultsSection
                    }
                    
                    // All previous guesses section
                    allGuessesSection
                    
                    Spacer(minLength: 40)
                } else {
                    // Game completed section
                    gameCompletedSection
                    Spacer(minLength: 40)
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var searchSection: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Type artist name...", text: $searchText)
                    .font(.system(size: 16, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(multiplayerManager.isMyTurn() ? Color(.systemBackground) : Color(.systemGray5))
                    .cornerRadius(12)
                    .focused($isTextFieldFocused)
                    .disabled(!multiplayerManager.isMyTurn())
                
                Button(action: {
                    submitGuess()
                }) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(multiplayerManager.isMyTurn() ? .blue : .gray)
                }
                .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !multiplayerManager.isMyTurn())
            }
            
            // Turn indicator
            if let session = multiplayerManager.currentSession {
                if multiplayerManager.isMyTurn() {
                    if let myPlayer = multiplayerManager.getMyPlayer() {
                        Text("Your turn - \(myPlayer.remainingGuesses) guesses remaining")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                    }
                } else if session.gameStarted && !session.isCompleted {
                    if let currentPlayer = session.currentPlayer {
                        Text("\(currentPlayer.name)'s turn - Wait for your opponent")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.orange)
                    }
                } else if !session.gameStarted {
                    Text("Waiting for both players to join...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
            
            // Error message display
            if let errorMessage = multiplayerManager.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }
    
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Suggestions:")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            LazyVStack(spacing: 4) {
                ForEach(searchResults.prefix(5), id: \.id) { artist in
                    Button(action: {
                        selectArtist(artist)
                    }) {
                        HStack {
                            Text(artist.name)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(artist.country) • \(artist.genre)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var gameCompletedSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 48))
                .foregroundColor(.yellow)
            
            Text("Game Complete!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
            
            if let session = multiplayerManager.currentSession {
                if let winnerIndex = session.winnerPlayerIndex {
                    Text("\(session.players[winnerIndex].name) wins! 🎉")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.green)
                } else {
                    Text("It's a draw! 🤝")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    showSuccessView = true
                }) {
                    Text("View Result")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(24)
                }
                
                Button(action: {
                    dismiss()
                }) {
                    Text("Back to Menu")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(24)
                }
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
    
    private func updateSearchResults(_ query: String) {
        if query.count >= 2 {
            Task {
                let results = await multiplayerManager.searchArtistsAsync(query: query)
                await MainActor.run {
                    searchResults = results
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSearchResults = !results.isEmpty
                    }
                }
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                showSearchResults = false
            }
            searchResults = []
        }
    }
    
    private func selectArtist(_ artist: Artist) {
        searchText = artist.name
        withAnimation(.easeInOut(duration: 0.2)) {
            showSearchResults = false
        }
        isTextFieldFocused = false
    }
    
    private func submitGuess() {
        let guess = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !guess.isEmpty else { return }
        
        Task {
            let _ = await multiplayerManager.makeGuess(guess)
            await MainActor.run {
                searchText = ""
                showSearchResults = false
                isTextFieldFocused = false
                refreshID = UUID()
            }
        }
    }
    
    private func refreshGameData() {
        // Refresh game state
        refreshID = UUID()
    }
    
    private func getMostRecentGuess(from session: MultiplayerGameSession) -> MultiplayerGuess? {
        // Get the most recent guess from any player
        let allGuesses = session.players.flatMap { $0.guesses }
        return allGuesses.max(by: { $0.timestamp < $1.timestamp })
    }
    
    private var allGuessesSection: some View {
        VStack(spacing: 16) {
            if let session = multiplayerManager.currentSession {
                let allGuesses = getAllGuessesWithPlayerInfo(from: session)
                
                if !allGuesses.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("All Guesses")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 12) {
                                Text("🟢 Correct  🟡 Close  ⚪ Wrong")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("Latest guess shown first")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary.opacity(0.8))
                                    .italic()
                            }
                        }
                        
                        // Display guesses in reverse chronological order (newest first)
                        ForEach(Array(allGuesses.reversed().enumerated()), id: \.element.guess.id) { index, guessInfo in
                            let isLatest = index == 0 // First item in reversed array is the latest
                            
                            MultiplayerPreviousGuessView(
                                guess: guessInfo.guess,
                                playerName: guessInfo.playerName,
                                guessNumber: guessInfo.guessNumber,
                                isLatest: isLatest
                            )
                        }
                    }
                }
            }
        }
    }
    
    private func getAllGuessesWithPlayerInfo(from session: MultiplayerGameSession) -> [(guess: MultiplayerGuess, playerName: String, guessNumber: Int)] {
        var result: [(guess: MultiplayerGuess, playerName: String, guessNumber: Int)] = []
        
        for player in session.players {
            for (index, guess) in player.guesses.enumerated() {
                result.append((guess: guess, playerName: player.name, guessNumber: index + 1))
            }
        }
        
        // Sort by timestamp to show chronological order
        return result.sorted { $0.guess.timestamp < $1.guess.timestamp }
    }
    
    private func recentGuessHintsSection(guess: MultiplayerGuess) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 16))
                
                Text("Latest Guess Hints")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(spacing: 8) {
                // Guess header with artist image
                HStack {
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
                                    .stroke(guess.result == "correct" ? Color.green.opacity(0.6) : Color.red.opacity(0.4), lineWidth: 2.5)
                            )
                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
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
                                        .stroke(guess.result == "correct" ? Color.green.opacity(0.6) : Color.red.opacity(0.4), lineWidth: 2.5)
                                )
                                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                        }
                    }
                    
                    Text("\"\(guess.artistName)\"")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: guess.result == "correct" ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(guess.result == "correct" ? .green : .red)
                        .font(.system(size: 18))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Hints grid
                if !guess.hints.isEmpty {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(Array(guess.hints.keys.sorted()), id: \.self) { key in
                            LargeHintItemView(key: key, value: guess.hints[key] ?? "")
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Hint Match Type (for multiplayer)
enum MultiplayerHintMatchType {
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

// MARK: - Large Hint Item View (for main display)
struct LargeHintItemView: View {
    let key: String
    let value: String
    @State private var isFlipped = false
    @State private var animationDelay = 0.0
    
    private var hintData: (text: String, status: String) {
        let components = value.split(separator: "|", maxSplits: 1)
        let text = String(components.first ?? "")
        let status = components.count > 1 ? String(components[1]) : "incorrect"
        return (text, status)
    }
    
    private var matchType: MultiplayerHintMatchType {
        switch hintData.status {
        case "correct": return .correct
        case "close": return .close
        default: return .incorrect
        }
    }
    
    private var hintIcon: String {
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
    
    var body: some View {
        ZStack {
            // Back of card (shown before flip)
            VStack(spacing: 8) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(width: 20, height: 20)
                
                VStack(spacing: 4) {
                    Text(key)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("?")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90) // Fixed height for consistent design
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                    )
            )
            .opacity(isFlipped ? 0 : 1)
            .rotation3DEffect(
                .degrees(isFlipped ? 90 : 0),
                axis: (x: 0, y: 1, z: 0)
            )
            
            // Front of card (shown after flip)
            VStack(spacing: 8) {
                Image(systemName: hintIcon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(matchType.iconColor)
                    .frame(width: 20, height: 20)
                
                VStack(spacing: 4) {
                    Text(key)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text(hintData.text)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
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
            .opacity(isFlipped ? 1 : 0)
            .rotation3DEffect(
                .degrees(isFlipped ? 0 : -90),
                axis: (x: 0, y: 1, z: 0)
            )
        }
        .onAppear {
            // Calculate delay based on hint key to stagger animations
            let hintKeys = ["Genre", "Country", "Debut Year", "Gender", "Type", "Popularity"]
            if let index = hintKeys.firstIndex(of: key) {
                animationDelay = Double(index) * 0.2
            }
            
            // Start flip animation after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + animationDelay) {
                withAnimation(
                    .easeInOut(duration: 0.6)
                    .delay(0.1)
                ) {
                    isFlipped = true
                }
            }
        }
    }
} 

// MARK: - Simple Guess Row View (for player cards)
struct SimpleGuessRowView: View {
    let guess: MultiplayerGuess
    
    var body: some View {
        HStack {
            Text(guess.artistName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Spacer()
            
            Image(systemName: guess.result == "correct" ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(guess.result == "correct" ? .green : .red)
                .font(.system(size: 12))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Guess Card View with Hints (for detailed display)
struct GuessCardView: View {
    let guess: MultiplayerGuess
    @State private var isExpanded = false
    
    init(guess: MultiplayerGuess, autoExpand: Bool = false) {
        self.guess = guess
        self._isExpanded = State(initialValue: autoExpand)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main guess row
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(guess.artistName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        if !guess.hints.isEmpty {
                            Text("Tap for hints")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: guess.result == "correct" ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(guess.result == "correct" ? .green : .red)
                            .font(.system(size: 12))
                        
                        if !guess.hints.isEmpty {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded hints section
            if isExpanded && !guess.hints.isEmpty {
                VStack(spacing: 4) {
                    Divider()
                        .padding(.horizontal, 8)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 4) {
                        ForEach(Array(guess.hints.keys.sorted()), id: \.self) { key in
                            HintItemView(key: key, value: guess.hints[key] ?? "")
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isExpanded ? Color(.systemGray6) : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(guess.result == "correct" ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Hint Item View
struct HintItemView: View {
    let key: String
    let value: String
    
    private var hintData: (text: String, status: String) {
        let components = value.split(separator: "|", maxSplits: 1)
        let text = String(components.first ?? "")
        let status = components.count > 1 ? String(components[1]) : "incorrect"
        return (text, status)
    }
    
    private var matchType: MultiplayerHintMatchType {
        switch hintData.status {
        case "correct": return .correct
        case "close": return .close
        default: return .incorrect
        }
    }
    
    private var hintIcon: String {
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
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: hintIcon)
                    .font(.system(size: 8))
                    .foregroundColor(matchType.iconColor)
                
                Text(key)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer(minLength: 0)
            }
            
            Text(hintData.text)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(matchType.backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(matchType.borderColor, lineWidth: 1)
                )
        )
    }
}

// MARK: - Multiplayer Previous Guess View (like daily game format)
struct MultiplayerPreviousGuessView: View {
    let guess: MultiplayerGuess
    let playerName: String
    let guessNumber: Int
    let isLatest: Bool
    @State private var showHints = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Guess Header
            HStack(spacing: 8) {
                // Player info with guess number
                VStack(alignment: .leading, spacing: 2) {
                    Text(playerName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("#\(guessNumber)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.blue)
                }
                .frame(width: 50, alignment: .leading)
                
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
                                .stroke(guess.result == "correct" ? Color.green.opacity(0.6) : Color.red.opacity(0.4), lineWidth: 2.5)
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
                                    .stroke(guess.result == "correct" ? Color.green.opacity(0.6) : Color.red.opacity(0.4), lineWidth: 2.5)
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
                if guess.result == "correct" {
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
                            MultiplayerGuessHintCard(
                                icon: getIconForHint(key),
                                title: LanguageManager.shared.localizedString(for: key),
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
        return hint
    }
    
    private func getMatchTypeFromHint(_ hint: String) -> MultiplayerHintMatchType {
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
        return .incorrect
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
        
        return nil
    }
}

// MARK: - Multiplayer Guess Hint Card (reusing the flip animation)
struct MultiplayerGuessHintCard: View {
    let icon: String
    let title: String
    let value: String
    let matchType: MultiplayerHintMatchType
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

// MARK: - Multiplayer Success View
struct MultiplayerSuccessView: View {
    @Environment(\.dismiss) private var dismiss
    let artist: Artist
    let session: MultiplayerGameSession?
    let playerName: String
    
    @State private var artistImageURL: String?
    @State private var isLoadingData = true
    @State private var audioPlayer: AVPlayer?
    @State private var isPlayingAudio = false
    @State private var audioLoadError: String?
    
    private var didPlayerWin: Bool {
        guard let session = session,
              let winnerIndex = session.winnerPlayerIndex else {
            return false
        }
        return session.players[winnerIndex].name == playerName
    }
    
    private var gameResult: String {
        guard let session = session else { return "Game Over" }
        
        if let winnerIndex = session.winnerPlayerIndex {
            let winner = session.players[winnerIndex]
            return winner.name == playerName ? "You Won!" : "\(winner.name) Won!"
        } else {
            return "It's a Draw!"
        }
    }
    
    private var gameResultColor: Color {
        guard let session = session else { return .gray }
        
        if session.winnerPlayerIndex == nil {
            return .blue // Draw
        } else {
            return didPlayerWin ? .green : .red
        }
    }
    
    private var gameResultIcon: String {
        guard let session = session else { return "x.circle.fill" }
        
        if session.winnerPlayerIndex == nil {
            return "equal.circle.fill" // Draw
        } else {
            return didPlayerWin ? "checkmark.circle.fill" : "x.circle.fill"
        }
    }
    
    private var formattedDebutYear: String {
        // Ensure debut year is formatted as a proper integer year
        let year = max(1900, min(2025, Int(artist.debutYear))) // Clamp to reasonable range
        return String(year)
    }
    
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
                    VStack(spacing: 40) {
                        Spacer(minLength: 40)
                        
                        // Success/Failure Animation with better spacing
                        VStack(spacing: 20) {
                            Image(systemName: gameResultIcon)
                                .font(.system(size: 80))
                                .foregroundColor(gameResultColor)
                                .scaleEffect(1.2)
                                .animation(.bouncy, value: true)
                            
                            VStack(spacing: 12) {
                                Text(gameResult)
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(gameResultColor)
                                
                                Text("The artist was \(artist.name)")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        
                        // Artist Image and Info - Redesigned like normal game
                        VStack(spacing: 30) {
                            // Artist Image (much better design)
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
                                            Image(systemName: "music.note")
                                                .font(.system(size: 60))
                                                .foregroundColor(.secondary)
                                        )
                                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                }
                            }
                            
                            // Artist Details - Better design
                            VStack(spacing: 20) {
                                Text(artist.name)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                
                                // Artist info grid
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                                    ArtistInfoCard(icon: "music.note", title: "Genre", value: artist.genre)
                                    ArtistInfoCard(icon: "globe", title: "Country", value: artist.country)
                                    ArtistInfoCard(icon: "calendar", title: "Debut Year", value: formattedDebutYear)
                                    ArtistInfoCard(icon: "person.fill", title: "Type", value: artist.isSolo ? "Solo Artist" : "Band")
                                }
                                
                                // Audio Controls - Better design
                                if audioPlayer != nil || audioLoadError != nil {
                                    VStack(spacing: 12) {
                                        if audioPlayer != nil {
                                            Button(action: toggleAudioPlayback) {
                                                HStack {
                                                    Image(systemName: isPlayingAudio ? "pause.circle.fill" : "play.circle.fill")
                                                        .font(.system(size: 24))
                                                    
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(isPlayingAudio ? "Playing preview..." : "Play preview")
                                                            .font(.system(size: 16, weight: .medium))
                                                        
                                                        Text("Audio from Spotify")
                                                            .font(.system(size: 14))
                                                            .foregroundColor(.secondary)
                                                    }
                                                    
                                                    Spacer()
                                                }
                                                .foregroundColor(.blue)
                                                .padding()
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color.blue.opacity(0.1))
                                                )
                                            }
                                        }
                                        
                                        if let errorMessage = audioLoadError {
                                            Text(errorMessage)
                                                .font(.caption)
                                                .foregroundColor(.red)
                                                .multilineTextAlignment(.center)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Game Statistics - Better design
                        if let session = session {
                            gameStatisticsSection(session: session)
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 30)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                }
            }
        }
        .onAppear {
            loadArtistData()
        }
        .onDisappear {
            stopAudioPlayback()
        }
    }
    
    private func gameStatisticsSection(session: MultiplayerGameSession) -> some View {
        VStack(spacing: 20) {
            Text("Game Results")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
            
            VStack(spacing: 16) {
                ForEach(Array(session.players.enumerated()), id: \.element.id) { index, player in
                    HStack(spacing: 16) {
                        // Player result icon
                        ZStack {
                            Circle()
                                .fill(index == session.winnerPlayerIndex ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
                                .frame(width: 50, height: 50)
                            
                            if index == session.winnerPlayerIndex {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 20))
                            } else if player.isCorrect {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 24))
                            } else {
                                Image(systemName: "x.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 24))
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(player.name)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                if index == session.winnerPlayerIndex {
                                    Text("WINNER")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.yellow)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.yellow.opacity(0.2))
                                        .cornerRadius(8)
                                }
                                
                                Spacer()
                            }
                            
                            HStack {
                                Text("\(player.guesses.count) guess\(player.guesses.count == 1 ? "" : "es")")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                if player.isCorrect {
                                    Text("• Correct")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(index == session.winnerPlayerIndex ? Color.green.opacity(0.3) : Color.clear, lineWidth: 2)
                            )
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6).opacity(0.3))
        )
    }
    
    private func loadArtistData() {
        print("🖼️ Loading artist data for: \(artist.name)")
        print("🔍 Artist imageURL: \(artist.imageURL ?? "nil")")
        print("🔍 Artist previewURL: \(artist.previewURL ?? "nil")")
        print("🔍 Artist ID: \(artist.id)")
        
        // Load image URL if available from artist object first
        if let storedImageURL = artist.imageURL, !storedImageURL.isEmpty {
            if storedImageURL.hasPrefix("http") || storedImageURL.hasPrefix("https") {
                print("🖼️ Using stored image URL: \(storedImageURL)")
                artistImageURL = storedImageURL
                isLoadingData = false
            } else {
                print("🖼️ Invalid stored image URL: \(storedImageURL)")
                // Try loading from Spotify since stored URL is invalid
                Task {
                    await loadArtistImageFromSpotify()
                    await MainActor.run {
                        isLoadingData = false
                    }
                }
            }
        } else {
            print("🖼️ No stored image URL, fetching from Spotify...")
            // Try to fetch from Spotify
            Task {
                await loadArtistImageFromSpotify()
                await MainActor.run {
                    isLoadingData = false
                }
            }
        }
        
        // Initialize audio player if preview URL is available
        if let previewURL = artist.previewURL, !previewURL.isEmpty {
            print("🎵 Setting up audio with URL: \(previewURL)")
            setupAudioPlayer(with: previewURL)
            // Auto-play audio after 1 second delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let player = audioPlayer {
                    player.play()
                    isPlayingAudio = true
                }
            }
        } else {
            print("🎵 No preview URL available for artist: \(artist.name)")
        }
    }
    
    private func loadArtistImageFromSpotify() async {
        print("🖼️ Fetching image from Spotify for: \(artist.name)")
        
        // Try to fetch from Spotify
        do {
            let results = try await SpotifyService.shared.searchArtists(query: artist.name, limit: 1)
            print("🖼️ Spotify search returned \(results.count) results")
            
            if let firstResult = results.first {
                print("🖼️ First result: \(firstResult.name)")
                print("🖼️ Number of images: \(firstResult.images.count)")
                
                if let imageURL = firstResult.images.first?.url {
                    print("🖼️ Found Spotify image: \(imageURL)")
                    await MainActor.run {
                        artistImageURL = imageURL
                        print("🖼️ Set artistImageURL to: \(artistImageURL ?? "nil")")
                    }
                } else {
                    print("🖼️ No image URL available for first result")
                }
            } else {
                print("🖼️ No results from Spotify search")
            }
        } catch {
            print("🖼️ Failed to fetch artist image from Spotify: \(error)")
        }
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
}

// MARK: - Artist Info Card Component
struct ArtistInfoCard: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 90)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
} 