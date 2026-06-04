//
//  FirestoreService.swift
//  songle
//
//  Created by Assistant on 7/2/25.
//

import Foundation
import FirebaseFirestore
import Combine

// MARK: - Firestore Artist Model
struct FirestoreArtist: Codable, Identifiable {
    var id: String = "" // Document ID - set manually, not from Firestore data
    let isim: String // name
    let populerlik: Int // popularity ranking
    let cinsiyet: String // gender
    let resim_url: String // image URL
    let genre: String
    let ulke: String // country
    let cikis_yili: Int // debut year
    let tip: String // type (Solo/Grup)
    let audio_preview_url: String? // audio preview URL
    
    // Custom coding keys to exclude 'id' from decoding
    enum CodingKeys: String, CodingKey {
        case isim, populerlik, cinsiyet, resim_url, genre, ulke, cikis_yili, tip, audio_preview_url
    }
    
    // Convert to local Artist model
    func toArtist() -> Artist {
        let isSolo = tip.lowercased() == "solo"
        let artistId = "firestore-\(populerlik)" // Use popularity ranking as ID for consistency
        
        return Artist(
            id: artistId,
            name: isim,
            gender: translateGender(cinsiyet),
            country: translateCountry(ulke),
            debutYear: cikis_yili,
            genre: genre,
            isSolo: isSolo,
            spotifyPopularity: populerlik, // Use as ranking instead
            imageURL: resim_url.isEmpty ? nil : resim_url,
            previewURL: audio_preview_url?.isEmpty == false ? audio_preview_url : nil,
            spotifyId: nil
        )
    }
    
    private func translateGender(_ turkishGender: String) -> String {
        switch turkishGender.lowercased() {
        case "erkek": return "Male"
        case "kadın": return "Female"
        case "grup": return "Group"
        default: return turkishGender
        }
    }
    
    private func translateCountry(_ countryCode: String) -> String {
        let countryMap: [String: String] = [
            // Turkish translations
            "ABD": "United States",
            "İngiltere": "United Kingdom", 
            "Kanada": "Canada",
            "Güney Kore": "South Korea",
            "Porto Riko": "Puerto Rico",
            
            // Country codes from JSON data
            "US": "United States",
            "CA": "Canada", 
            "GB": "United Kingdom",
            "UK": "United Kingdom",
            "PR": "Puerto Rico",
            "KR": "South Korea",
            "AU": "Australia",
            "DE": "Germany",
            "FR": "France",
            "ES": "Spain",
            "IT": "Italy",
            "JP": "Japan",
            "BR": "Brazil",
            "MX": "Mexico",
            "AR": "Argentina",
            "CO": "Colombia",
            "CL": "Chile",
            "PE": "Peru",
            "VE": "Venezuela",
            "SE": "Sweden",
            "NO": "Norway",
            "DK": "Denmark",
            "FI": "Finland",
            "NL": "Netherlands",
            "BE": "Belgium",
            "CH": "Switzerland",
            "AT": "Austria",
            "IE": "Ireland",
            "NZ": "New Zealand",
            "ZA": "South Africa",
            "IN": "India",
            "CN": "China",
            "TH": "Thailand",
            "PH": "Philippines",
            "ID": "Indonesia",
            "MY": "Malaysia",
            "SG": "Singapore",
            "TW": "Taiwan",
            "HK": "Hong Kong",
            "PL": "Poland",
            "CZ": "Czech Republic",
            "HU": "Hungary",
            "RO": "Romania",
            "BG": "Bulgaria",
            "HR": "Croatia",
            "SI": "Slovenia",
            "SK": "Slovakia",
            "LT": "Lithuania",
            "LV": "Latvia",
            "EE": "Estonia",
            "IS": "Iceland",
            "PT": "Portugal",
            "GR": "Greece",
            "TR": "Turkey",
            "RU": "Russia",
            "UA": "Ukraine",
            "BY": "Belarus",
            "IL": "Israel",
            "EG": "Egypt",
            "MA": "Morocco",
            "TN": "Tunisia",
            "LB": "Lebanon",
            "JO": "Jordan",
            "SA": "Saudi Arabia",
            "AE": "United Arab Emirates",
            "QA": "Qatar",
            "KW": "Kuwait",
            "IQ": "Iraq",
            "IR": "Iran",
            "AF": "Afghanistan",
            "PK": "Pakistan",
            "BD": "Bangladesh",
            "LK": "Sri Lanka",
            "NP": "Nepal",
            "MM": "Myanmar",
            "KH": "Cambodia",
            "LA": "Laos",
            "VN": "Vietnam"
        ]
        return countryMap[countryCode] ?? countryCode
    }
}

// MARK: - Firestore Service
class FirestoreService: ObservableObject {
    static let shared = FirestoreService()
    
    private let db = Firestore.firestore()
    
    private let collectionName = "sanatcilar" // Turkish collection name for artists
    
    @Published var isConnected = false
    @Published var isLoading = false
    
    private init() {
        testConnection()
    }
    
    // MARK: - Connection Test
    private func testConnection() {
        Task {
            do {
                // Test connection by trying to fetch a small sample
                let snapshot = try await db.collection(collectionName).limit(to: 1).getDocuments()
                await MainActor.run {
                    isConnected = true
                    print("✅ Firestore connection successful - found \(snapshot.documents.count) documents")
                }
            } catch {
                await MainActor.run {
                    isConnected = false
                    print("❌ Firestore connection failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Fetch All Artists
    func fetchAllArtists() async -> [Artist] {
        await MainActor.run { isLoading = true }
        
        do {
            print("🔥 Fetching all artists from Firestore...")
            let snapshot = try await db.collection(collectionName).getDocuments()
            
            var artists: [Artist] = []
            for document in snapshot.documents {
                do {
                    var firestoreArtist = try document.data(as: FirestoreArtist.self)
                    firestoreArtist.id = document.documentID
                    artists.append(firestoreArtist.toArtist())
                } catch {
                    print("⚠️ Error parsing artist document \(document.documentID): \(error)")
                    continue
                }
            }
            
            await MainActor.run { isLoading = false }
            
            // Sort by popularity ranking (lower numbers = more popular)
            let sortedArtists = artists.sorted { $0.spotifyPopularity < $1.spotifyPopularity }
            print("✅ Successfully fetched \(sortedArtists.count) artists from Firestore")
            return sortedArtists
            
        } catch {
            await MainActor.run { isLoading = false }
            print("❌ Error fetching artists from Firestore: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Search Artists
    func searchArtists(query: String, limit: Int = 20) async -> [Artist] {
        guard !query.isEmpty else { return [] }
        
        do {
            print("🔍 Searching artists with query: '\(query)'")
            
            // Firestore doesn't support case-insensitive search directly, 
            // so we'll fetch all and filter locally for now
            // This could be optimized with Algolia or similar search service
            let snapshot = try await db.collection(collectionName).getDocuments()
            
            var matchingArtists: [Artist] = []
            let lowercaseQuery = query.lowercased()
            
            for document in snapshot.documents {
                do {
                    var firestoreArtist = try document.data(as: FirestoreArtist.self)
                    firestoreArtist.id = document.documentID
                    
                    // Check if artist name contains the query
                    if firestoreArtist.isim.lowercased().contains(lowercaseQuery) {
                        matchingArtists.append(firestoreArtist.toArtist())
                    }
                } catch {
                    print("⚠️ Error parsing artist document \(document.documentID): \(error)")
                    continue
                }
            }
            
            // Sort by popularity and limit results
            let sortedResults = matchingArtists
                .sorted { $0.spotifyPopularity < $1.spotifyPopularity }
                .prefix(limit)
            
            print("✅ Found \(sortedResults.count) matching artists for '\(query)'")
            return Array(sortedResults)
            
        } catch {
            print("❌ Error searching artists: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Get Artists by Genre
    func getArtistsByGenre(_ genre: String, limit: Int = 50) async -> [Artist] {
        do {
            print("🎵 Fetching artists for genre: '\(genre)'")
            
            // Map UI genres to database genres
            let databaseGenres = mapGenreToDatabase(genre)
            print("🎵 Mapped '\(genre)' to database genres: \(databaseGenres)")
            
            var allArtists: [Artist] = []
            
            // Query for each mapped genre
            for dbGenre in databaseGenres {
                let snapshot = try await db.collection(collectionName)
                    .whereField("genre", isEqualTo: dbGenre)
                    .getDocuments()
                
                for document in snapshot.documents {
                    do {
                        var firestoreArtist = try document.data(as: FirestoreArtist.self)
                        firestoreArtist.id = document.documentID
                        allArtists.append(firestoreArtist.toArtist())
                    } catch {
                        print("⚠️ Error parsing artist document \(document.documentID): \(error)")
                        continue
                    }
                }
            }
            
            // Remove duplicates and sort by popularity
            let uniqueArtists = Array(Set(allArtists.map { $0.id })).compactMap { id in
                allArtists.first { $0.id == id }
            }
            
            let sortedResults = uniqueArtists
                .sorted { $0.spotifyPopularity < $1.spotifyPopularity }
                .prefix(limit)
            
            print("✅ Found \(sortedResults.count) artists for genre '\(genre)' from \(databaseGenres.count) database genres")
            return Array(sortedResults)
            
        } catch {
            print("❌ Error fetching artists by genre: \(error.localizedDescription)")
            return []
        }
    }
    
    // Map UI genre names to actual database genre names
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
    
    // MARK: - Get Random Artists
    func getRandomArtists(limit: Int = 50) async -> [Artist] {
        do {
            print("🎲 Fetching random artists...")
            
            // Get all artists and shuffle them
            let allArtists = await fetchAllArtists()
            let randomArtists = Array(allArtists.shuffled().prefix(limit))
            
            print("✅ Selected \(randomArtists.count) random artists")
            return randomArtists
            
        } catch {
            print("❌ Error fetching random artists: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Get Artist by ID
    func getArtist(by id: String) async -> Artist? {
        do {
            print("🔍 Looking up artist with ID: \(id)")
            
            // Extract document ID from our custom ID format
            let documentId = id.replacingOccurrences(of: "firestore-", with: "")
            
            let document = try await db.collection(collectionName).document(documentId).getDocument()
            
            if document.exists {
                do {
                    var firestoreArtist = try document.data(as: FirestoreArtist.self)
                    firestoreArtist.id = document.documentID
                    let artist = firestoreArtist.toArtist()
                    print("✅ Found artist: \(artist.name)")
                    return artist
                } catch {
                    print("⚠️ Error parsing artist document: \(error)")
                    return nil
                }
            } else {
                print("⚠️ Artist not found with ID: \(id)")
                return nil
            }
            
        } catch {
            print("❌ Error fetching artist by ID: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Get Artist by Name
    func getArtistByName(_ name: String) async -> Artist? {
        do {
            print("🔍 Looking up artist by name: \(name)")
            
            let snapshot = try await db.collection(collectionName)
                .whereField("isim", isEqualTo: name)
                .getDocuments()
            
            if let document = snapshot.documents.first {
                do {
                    var firestoreArtist = try document.data(as: FirestoreArtist.self)
                    firestoreArtist.id = document.documentID
                    let artist = firestoreArtist.toArtist()
                    print("✅ Found artist by name: \(artist.name)")
                    return artist
                } catch {
                    print("⚠️ Error parsing artist document: \(error)")
                    return nil
                }
            } else {
                print("⚠️ Artist not found with name: \(name)")
                return nil
            }
            
        } catch {
            print("❌ Error fetching artist by name: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Add New Artist
    func addArtist(_ artist: FirestoreArtist) async -> Bool {
        do {
            print("➕ Adding new artist: \(artist.isim)")
            
            try await db.collection(collectionName).addDocument(data: [
                "isim": artist.isim,
                "populerlik": artist.populerlik,
                "cinsiyet": artist.cinsiyet,
                "resim_url": artist.resim_url,
                "genre": artist.genre,
                "ulke": artist.ulke,
                "cikis_yili": artist.cikis_yili,
                "tip": artist.tip,
                "audio_preview_url": artist.audio_preview_url ?? ""
            ])
            
            print("✅ Successfully added artist: \(artist.isim)")
            return true
            
        } catch {
            print("❌ Error adding artist: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Get Available Genres
    func getAvailableGenres() async -> [String] {
        do {
            print("🎵 Fetching available genres...")
            
            let snapshot = try await db.collection(collectionName).getDocuments()
            
            var genres: Set<String> = []
            for document in snapshot.documents {
                if let genre = document.data()["genre"] as? String {
                    genres.insert(genre)
                }
            }
            
            let sortedGenres = Array(genres).sorted()
            print("✅ Found \(sortedGenres.count) unique genres")
            return sortedGenres
            
        } catch {
            print("❌ Error fetching genres: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Multiplayer Session Functions
    
    // Create a new multiplayer session
    func createMultiplayerSession(_ session: MultiplayerGameSession) async throws {
        print("🎮 Creating multiplayer session with code: \(session.inviteCode)")
        
        let sessionData = try Firestore.Encoder().encode(session)
        try await db.collection("multiplayer_sessions")
            .document(session.id.uuidString)
            .setData(sessionData)
        
        print("✅ Successfully created multiplayer session")
    }
    
    // Find a multiplayer session by invite code
    func findMultiplayerSession(inviteCode: String) async throws -> MultiplayerGameSession? {
        print("🔍 Looking for multiplayer session with code: \(inviteCode)")
        
        let query = db.collection("multiplayer_sessions")
            .whereField("inviteCode", isEqualTo: inviteCode)
            .whereField("isCompleted", isEqualTo: false)
            .limit(to: 1)
        
        let snapshot = try await query.getDocuments()
        guard let document = snapshot.documents.first else {
            print("⚠️ No multiplayer session found with code: \(inviteCode)")
            return nil
        }
        
        let session = try document.data(as: MultiplayerGameSession.self)
        print("✅ Found multiplayer session: \(session.inviteCode)")
        return session
    }
    
    // Update an existing multiplayer session
    func updateMultiplayerSession(_ session: MultiplayerGameSession) async throws {
        print("🔄 Updating multiplayer session: \(session.inviteCode)")
        
        let sessionData = try Firestore.Encoder().encode(session)
        try await db.collection("multiplayer_sessions")
            .document(session.id.uuidString)
            .setData(sessionData)
        
        print("✅ Successfully updated multiplayer session")
    }
    
    // Listen for multiplayer session updates
    func listenToMultiplayerSession(sessionId: String, 
                                   completion: @escaping (MultiplayerGameSession?) -> Void) -> ListenerRegistration {
        print("👂 Starting to listen for session updates: \(sessionId)")
        
        return db.collection("multiplayer_sessions")
            .document(sessionId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Error listening to session updates: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                guard let document = snapshot, document.exists else {
                    print("⚠️ Session document not found or deleted")
                    completion(nil)
                    return
                }
                
                do {
                    let session = try document.data(as: MultiplayerGameSession.self)
                    print("🔄 Session updated: \(session.inviteCode)")
                    completion(session)
                } catch {
                    print("❌ Error parsing session update: \(error.localizedDescription)")
                    completion(nil)
                }
            }
    }
    
    // Clean up old completed sessions (called periodically)
    func cleanupCompletedSessions() async {
        print("🧹 Cleaning up old completed sessions...")
        
        do {
            // Delete sessions that are completed and older than 24 hours
            let twentyFourHoursAgo = Date().addingTimeInterval(-24 * 60 * 60)
            
            let query = db.collection("multiplayer_sessions")
                .whereField("isCompleted", isEqualTo: true)
                .whereField("createdAt", isLessThan: twentyFourHoursAgo)
            
            let snapshot = try await query.getDocuments()
            let batch = db.batch()
            
            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
            }
            
            try await batch.commit()
            print("✅ Cleaned up \(snapshot.documents.count) old sessions")
            
        } catch {
            print("❌ Error cleaning up sessions: \(error.localizedDescription)")
        }
    }
    
    // Manual refresh function for multiplayer sessions
    func getMultiplayerSession(sessionId: String) async throws -> MultiplayerGameSession? {
        print("🔄 Manually fetching session: \(sessionId)")
        
        let document = try await db.collection("multiplayer_sessions")
            .document(sessionId)
            .getDocument()
        
        if document.exists {
            let session = try document.data(as: MultiplayerGameSession.self)
            print("✅ Manual fetch successful: \(session.inviteCode)")
            return session
        } else {
            print("⚠️ Session not found during manual fetch")
            return nil
        }
    }
}