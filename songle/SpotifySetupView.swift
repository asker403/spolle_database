//
//  SpotifySetupView.swift
//  songle
//
//  Created by Ümit BAĞ on 7/2/25.
//

import SwiftUI

struct SpotifySetupView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var spotifyService = SpotifyService.shared
    @State private var clientId = ""
    @State private var clientSecret = ""
    @State private var showingInstructions = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "music.note.house")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("Spotify Integration")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Connect your app to Spotify's massive music database for the ultimate guessing experience!")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Benefits
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Benefits")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        FeatureRow(icon: "music.note", title: "Millions of Artists", description: "Access Spotify's complete artist database")
                        FeatureRow(icon: "photo", title: "Artist Images", description: "High-quality photos for every artist")
                        FeatureRow(icon: "waveform", title: "Preview Tracks", description: "Listen to 30-second song previews")
                        FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Real Popularity", description: "Live popularity scores and trending data")
                    }
                    .padding(.horizontal, 20)
                    
                    // Setup Form
                    VStack(spacing: 16) {
                        Text("Setup (Optional)")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text("To enable Spotify integration, you'll need to create a Spotify app and get your credentials.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        VStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Client ID")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                TextField("Enter your Spotify Client ID", text: $clientId)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Client Secret")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                SecureField("Enter your Spotify Client Secret", text: $clientSecret)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                        }
                        
                        Button("Show Setup Instructions") {
                            showingInstructions = true
                        }
                        .foregroundColor(.green)
                        
                        Button("Save & Connect") {
                            saveCredentials()
                        }
                        .disabled(clientId.isEmpty || clientSecret.isEmpty)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 22)
                                .fill(clientId.isEmpty || clientSecret.isEmpty ? Color.gray.opacity(0.3) : Color.green)
                        )
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 20)
                    
                    // Skip Option
                    VStack(spacing: 12) {
                        Text("Not ready to set up Spotify?")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Button("Continue with Sample Data") {
                            dismiss()
                        }
                        .foregroundColor(.blue)
                    }
                    
                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingInstructions) {
            SpotifyInstructionsView()
        }
    }
    
    private func saveCredentials() {
        print("💾 Saving Spotify credentials...")
        print("📝 Client ID: \(clientId.prefix(10))...")
        print("📝 Client Secret: \(clientSecret.prefix(10))...")
        
        // Save credentials to UserDefaults
        UserDefaults.standard.set(clientId, forKey: "spotify_client_id")
        UserDefaults.standard.set(clientSecret, forKey: "spotify_client_secret")
        UserDefaults.standard.synchronize() // Force save
        
        print("✅ Credentials saved to UserDefaults")
        
        // Test reading back the credentials
        let savedClientId = UserDefaults.standard.string(forKey: "spotify_client_id") ?? ""
        let savedClientSecret = UserDefaults.standard.string(forKey: "spotify_client_secret") ?? ""
        print("🔄 Verified saved Client ID: \(savedClientId.prefix(10))...")
        print("🔄 Verified saved Client Secret: \(savedClientSecret.prefix(10))...")
        
        // Restart the Spotify service with new credentials
        Task {
            print("🎵 Starting Spotify authentication...")
            await spotifyService.reloadCredentialsAndAuthenticate()
            
            DispatchQueue.main.async {
                if self.spotifyService.isAuthenticated {
                    print("✅ Spotify authentication successful!")
                } else {
                    print("❌ Spotify authentication failed")
                }
                self.dismiss()
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.green)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct SpotifyInstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("How to Get Spotify Credentials")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.bottom, 10)
                    
                    InstructionStep(
                        number: 1,
                        title: "Visit Spotify Developer Dashboard",
                        description: "Go to https://developer.spotify.com/dashboard and log in with your Spotify account."
                    )
                    
                    InstructionStep(
                        number: 2,
                        title: "Create an App",
                        description: "Click 'Create an App' and fill in the required information. Choose any name and description you like."
                    )
                    
                    InstructionStep(
                        number: 3,
                        title: "Get Your Credentials",
                        description: "Once created, you'll see your Client ID immediately. Click 'Show Client Secret' to reveal your Client Secret."
                    )
                    
                    InstructionStep(
                        number: 4,
                        title: "Copy to App",
                        description: "Copy both the Client ID and Client Secret back to this app and tap 'Save & Connect'."
                    )
                    
                    Text("Note: These credentials allow the app to search Spotify's database but don't access your personal data or playlists.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 16)
                }
                .padding(20)
            }
            .navigationTitle("Setup Instructions")
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

struct InstructionStep: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.green))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
} 