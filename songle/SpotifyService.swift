//
//  SpotifyService.swift
//  songle
//
//  Created by Ümit BAĞ on 7/2/25.
//

import Foundation
import Combine

// MARK: - Spotify Service
class SpotifyService: ObservableObject {
    static let shared = SpotifyService()
    
    private var clientId: String {
        return UserDefaults.standard.string(forKey: "spotify_client_id") ?? ""
    }
    
    private var clientSecret: String {
        return UserDefaults.standard.string(forKey: "spotify_client_secret") ?? ""
    }
    private let baseURL = "https://api.spotify.com/v1"
    
    @Published var isAuthenticated = false
    private var accessToken: String?
    private var tokenExpiryDate: Date?
    
    private init() {
        // Check for existing credentials on startup
        if !clientId.isEmpty && !clientSecret.isEmpty {
            print("🎵 Found existing Spotify credentials on startup")
            print("📋 Client ID: \(clientId.prefix(10))...")
            print("📋 Client Secret: \(clientSecret.prefix(10))...")
            Task {
                await authenticate()
            }
        } else {
            print("⚠️ No Spotify credentials found on startup")
        }
    }
    
    // MARK: - Authentication
    func reloadCredentialsAndAuthenticate() async {
        print("🔄 Reloading Spotify credentials...")
        print("📝 Client ID: \(clientId.prefix(10))...")
        print("📝 Client Secret: \(clientSecret.prefix(10))...")
        
        // Reset current state
        DispatchQueue.main.async {
            self.isAuthenticated = false
            self.accessToken = nil
            self.tokenExpiryDate = nil
        }
        
        // Try to authenticate with the new credentials
        await authenticate()
    }
    
    func authenticate() async {
        print("🔐 Starting Spotify authentication...")
        print("📋 Client ID exists: \(!clientId.isEmpty)")
        print("📋 Client Secret exists: \(!clientSecret.isEmpty)")
        
        guard !clientId.isEmpty && !clientSecret.isEmpty else {
            print("⚠️ Spotify credentials not configured")
            DispatchQueue.main.async {
                self.isAuthenticated = false
            }
            return
        }
        
        print("🌐 Requesting access token from Spotify...")
        guard let token = await getAccessToken() else {
            print("❌ Failed to get Spotify access token")
            DispatchQueue.main.async {
                self.isAuthenticated = false
            }
            return
        }
        
        print("🎉 Received access token: \(token.prefix(10))...")
        DispatchQueue.main.async {
            self.accessToken = token
            self.isAuthenticated = true
            print("✅ Spotify authenticated successfully! Status: \(self.isAuthenticated)")
        }
    }
    
    private func getAccessToken() async -> String? {
        // Check if we have a valid token
        if let token = accessToken,
           let expiryDate = tokenExpiryDate,
           Date() < expiryDate {
            return token
        }
        
        // Request new token using Client Credentials flow
        guard let url = URL(string: "https://accounts.spotify.com/api/token") else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Basic Auth header
        let credentials = "\(clientId):\(clientSecret)"
        let credentialsData = credentials.data(using: .utf8)!
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        let body = "grant_type=client_credentials"
        request.httpBody = body.data(using: .utf8)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let tokenResponse = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
            
            // Store token and expiry
            self.tokenExpiryDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in - 300)) // 5 min buffer
            
            return tokenResponse.access_token
        } catch {
            print("❌ Spotify auth error: \(error)")
            return nil
        }
    }
    
    // MARK: - Artist Search
    func searchArtists(query: String, limit: Int = 20) async -> [SpotifyArtist] {
        guard !query.isEmpty else { return [] }
        
        // Ensure we're authenticated
        if !isAuthenticated {
            await authenticate()
        }
        
        guard let token = accessToken else { return [] }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(baseURL)/search?q=\(encodedQuery)&type=artist&limit=\(limit)"
        
        guard let url = URL(string: urlString) else { return [] }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let searchResponse = try JSONDecoder().decode(SpotifySearchResponse.self, from: data)
            return searchResponse.artists.items
        } catch {
            print("❌ Spotify search error: \(error)")
            return []
        }
    }
    
    // MARK: - Get Artists by Genre
    func getArtistsByGenre(_ genre: String, limit: Int = 50) async -> [SpotifyArtist] {
        let searchQuery = "genre:\(genre.lowercased())"
        return await searchArtists(query: searchQuery, limit: limit)
    }
    
    // MARK: - Get Random Popular Artists
    func getRandomPopularArtists(limit: Int = 50) async -> [SpotifyArtist] {
        let randomQueries = ["pop", "rock", "hip-hop", "electronic", "indie", "alternative", "r&b", "country"]
        let randomQuery = randomQueries.randomElement() ?? "pop"
        
        return await searchArtists(query: randomQuery, limit: limit)
    }
    
    // MARK: - Get Artist Details
    func getArtistDetails(id: String) async -> SpotifyArtistDetails? {
        guard let token = accessToken else { return nil }
        
        guard let url = URL(string: "\(baseURL)/artists/\(id)") else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let artistDetails = try JSONDecoder().decode(SpotifyArtistDetails.self, from: data)
            return artistDetails
        } catch {
            print("❌ Error fetching artist details: \(error)")
            return nil
        }
    }
    
    // MARK: - Get Artist Top Tracks (for audio preview)
    func getArtistTopTracks(artistId: String, market: String = "US") async -> [SpotifyTrack] {
        print("🎵 Fetching top tracks for artist ID: \(artistId)")
        guard let token = accessToken else { 
            print("❌ No access token available")
            return [] 
        }
        
        guard let url = URL(string: "\(baseURL)/artists/\(artistId)/top-tracks?market=\(market)") else { 
            print("❌ Invalid URL for top tracks")
            return [] 
        }
        
        print("🌐 Requesting: \(url.absoluteString)")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Response status: \(httpResponse.statusCode)")
            }
            
            let topTracksResponse = try JSONDecoder().decode(SpotifyTopTracksResponse.self, from: data)
            print("🎶 Found \(topTracksResponse.tracks.count) top tracks")
            
            let tracksWithPreviews = topTracksResponse.tracks.filter { $0.preview_url != nil }
            print("🎧 Tracks with preview: \(tracksWithPreviews.count)")
            
            for track in tracksWithPreviews.prefix(3) {
                print("   🎵 \(track.name) - Preview: \(track.preview_url ?? "None")")
            }
            
            return topTracksResponse.tracks
        } catch {
            print("❌ Error fetching top tracks: \(error)")
            if let data = try? await URLSession.shared.data(for: request).0,
               let errorString = String(data: data, encoding: .utf8) {
                print("❌ Response body: \(errorString)")
            }
            return []
        }
    }
    
    // MARK: - Get Artist Image URL
    func getArtistImageURL(artist: SpotifyArtist) -> String? {
        return artist.images.first?.url
    }
    
    // MARK: - Search Artist and Get Full Details
    func searchArtistWithDetails(name: String) async -> (artist: SpotifyArtist, imageURL: String?, previewURL: String?)? {
        // First search for the artist
        let artists = await searchArtists(query: name, limit: 1)
        guard let artist = artists.first else { return nil }
        
        // Get the image URL
        let imageURL = getArtistImageURL(artist: artist)
        
        // Get top tracks for preview
        let topTracks = await getArtistTopTracks(artistId: artist.id)
        let previewURL = topTracks.first(where: { $0.preview_url != nil })?.preview_url
        
        return (artist: artist, imageURL: imageURL, previewURL: previewURL)
    }
    
    // MARK: - Enhanced Artist Data Fetching
    func getEnhancedArtistData(name: String) async -> Artist? {
        print("🔍 Fetching enhanced data for: \(name)")
        
        // First, search for the artist
        let artists = await searchArtists(query: name, limit: 1)
        guard let spotifyArtist = artists.first else { 
            print("❌ Artist not found: \(name)")
            return nil 
        }
        
        // Get detailed artist information
        guard let artistDetails = await getArtistDetails(id: spotifyArtist.id) else {
            print("❌ Failed to get artist details for: \(name)")
            return spotifyArtist.toArtist()
        }
        
        // Get artist's albums to find debut year
        let debutYear = await getArtistDebutYear(artistId: spotifyArtist.id)
        
        // Get artist's country from their albums/markets
        let country = await getArtistCountry(artistId: spotifyArtist.id, artistName: name)
        
        // Enhanced gender detection
        let gender = enhancedGenderDetection(artistName: name, genres: artistDetails.genres)
        
        // Get image and preview
        let imageURL = getArtistImageURL(artist: spotifyArtist)
        let topTracks = await getArtistTopTracks(artistId: spotifyArtist.id)
        let previewURL = topTracks.first(where: { $0.preview_url != nil })?.preview_url
        
        print("✅ Enhanced data for \(name): Country=\(country), Debut=\(debutYear), Gender=\(gender)")
        
        return Artist(
            id: "spotify-\(spotifyArtist.id)",
            name: spotifyArtist.name,
            gender: gender,
            country: country,
            debutYear: debutYear,
            genre: spotifyArtist.primaryGenre,
            isSolo: determineSoloStatus(name: name, genres: artistDetails.genres),
            spotifyPopularity: spotifyArtist.popularity,
            imageURL: imageURL,
            previewURL: previewURL,
            spotifyId: spotifyArtist.id
        )
    }
    
    // MARK: - Get Artist Albums for Debut Year
    func getArtistAlbums(artistId: String) async -> [SpotifyAlbum] {
        guard let token = accessToken else { return [] }
        
        guard let url = URL(string: "\(baseURL)/artists/\(artistId)/albums?include_groups=album,single&market=US&limit=50") else { return [] }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let albumsResponse = try JSONDecoder().decode(SpotifyAlbumsResponse.self, from: data)
            return albumsResponse.items
        } catch {
            print("❌ Error fetching albums: \(error)")
            return []
        }
    }
    
    func getArtistDebutYear(artistId: String) async -> Int {
        let albums = await getArtistAlbums(artistId: artistId)
        
        // Find the earliest release date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var earliestYear = Calendar.current.component(.year, from: Date())
        
        for album in albums {
            if let releaseDate = dateFormatter.date(from: album.release_date) {
                let year = Calendar.current.component(.year, from: releaseDate)
                if year < earliestYear {
                    earliestYear = year
                }
            } else if album.release_date.count >= 4,
                      let year = Int(String(album.release_date.prefix(4))) {
                if year < earliestYear {
                    earliestYear = year
                }
            }
        }
        
        return earliestYear
    }
    
    // MARK: - Enhanced Country Detection
    func getArtistCountry(artistId: String, artistName: String) async -> String {
        // Try to determine country from various sources
        
        // 1. Check if artist name contains obvious country indicators
        let countryFromName = extractCountryFromName(artistName)
        if countryFromName != "Unknown" {
            return countryFromName
        }
        
        // 2. Use a curated database for well-known artists
        let knownCountry = getKnownArtistCountry(artistName)
        if knownCountry != "Unknown" {
            return knownCountry
        }
        
        // 3. Analyze markets where their music is most popular
        // This is a simplified approach - in reality, you'd need market analysis
        return "Unknown"
    }
    
    private func extractCountryFromName(_ name: String) -> String {
        let nameWords = name.lowercased().components(separatedBy: .whitespacesAndNewlines.union(.punctuationCharacters))
        
        let countryIndicators: [String: String] = [
            "american": "United States",
            "british": "United Kingdom",
            "english": "United Kingdom", 
            "irish": "Ireland",
            "scottish": "United Kingdom",
            "welsh": "United Kingdom",
            "canadian": "Canada",
            "australian": "Australia",
            "french": "France",
            "german": "Germany",
            "italian": "Italy",
            "spanish": "Spain",
            "swedish": "Sweden",
            "norwegian": "Norway",
            "danish": "Denmark",
            "korean": "South Korea",
            "japanese": "Japan",
            "chinese": "China"
        ]
        
        for word in nameWords {
            if let country = countryIndicators[word] {
                return country
            }
        }
        
        return "Unknown"
    }
    
    private func getKnownArtistCountry(_ name: String) -> String {
        // Curated database of well-known artists and their countries
        let artistCountries: [String: String] = [
            "taylor swift": "United States",
            "ed sheeran": "United Kingdom", 
            "adele": "United Kingdom",
            "drake": "Canada",
            "the weeknd": "Canada",
            "bruno mars": "United States",
            "ariana grande": "United States",
            "billie eilish": "United States",
            "david guetta": "France",
            "calvin harris": "United Kingdom",
            "martin garrix": "Netherlands",
            "avicii": "Sweden",
            "swedish house mafia": "Sweden",
            "daft punk": "France",
            "deadmau5": "Canada",
            "skrillex": "United States",
            "tiësto": "Netherlands",
            "diplo": "United States",
            "zedd": "Germany",
            "alan walker": "Norway",
            "marshmello": "United States",
            "chainsmokers": "United States",
            "eminem": "United States",
            "kanye west": "United States",
            "kendrick lamar": "United States",
            "j. cole": "United States",
            "travis scott": "United States",
            "post malone": "United States",
            "lil nas x": "United States",
            "dua lipa": "United Kingdom",
            "olivia rodrigo": "United States",
            "harry styles": "United Kingdom",
            "shawn mendes": "Canada",
            "justin bieber": "Canada",
            "selena gomez": "United States",
            "rihanna": "Barbados",
            "beyoncé": "United States",
            "lady gaga": "United States",
            "katy perry": "United States",
            "coldplay": "United Kingdom",
            "imagine dragons": "United States",
            "maroon 5": "United States",
            "onerepublic": "United States",
            "u2": "Ireland",
            "radiohead": "United Kingdom",
            "queen": "United Kingdom",
            "the beatles": "United Kingdom",
            "pink floyd": "United Kingdom",
            "led zeppelin": "United Kingdom",
            "ac/dc": "Australia",
            "metallica": "United States",
            "guns n' roses": "United States",
            "nirvana": "United States",
            "red hot chili peppers": "United States",
            "foo fighters": "United States",
            "green day": "United States",
            "linkin park": "United States",
            "bts": "South Korea",
            "blackpink": "South Korea",
            "twice": "South Korea",
            "bad bunny": "Puerto Rico",
            "j balvin": "Colombia",
            "shakira": "Colombia",
            "manu chao": "France",
            "stromae": "Belgium",
            "sia": "Australia",
            "tame impala": "Australia",
            "flume": "Australia",
            "kygo": "Norway",
            "robyn": "Sweden",
            "abba": "Sweden",
            "björk": "Iceland",
            "sigur rós": "Iceland",
            "madonna": "United States",
            "michael jackson": "United States",
            "prince": "United States",
            "whitney houston": "United States",
            "mariah carey": "United States",
            "celine dion": "Canada",
            "alanis morissette": "Canada"
        ]
        
        let lowercaseName = name.lowercased()
        return artistCountries[lowercaseName] ?? "Unknown"
    }
    
    // MARK: - Enhanced Gender Detection
    private func enhancedGenderDetection(artistName: String, genres: [String]) -> String {
        let lowercaseName = artistName.lowercased()
        
        // Check for obvious group indicators first
        let groupIndicators = ["band", "boys", "girls", "sisters", "brothers", "crew", "collective", "ensemble", "orchestra", "choir", "duo", "trio", "quartet", "quintet"]
        for indicator in groupIndicators {
            if lowercaseName.contains(indicator) {
                return "Group"
            }
        }
        
        // Check for conjunction words indicating multiple people
        if lowercaseName.contains(" & ") || lowercaseName.contains(" and ") || lowercaseName.contains(" + ") {
            return "Group"
        }
        
        // Genre-based hints for groups
        if genres.contains(where: { $0.lowercased().contains("metal") || $0.lowercased().contains("rock") }) {
            // Many metal/rock acts are bands
            if lowercaseName.contains("the ") {
                return "Group"
            }
        }
        
        // Enhanced name checking with more comprehensive lists
        return estimateGenderFromName(artistName)
    }
    
    private func determineSoloStatus(name: String, genres: [String]) -> Bool {
        let gender = enhancedGenderDetection(artistName: name, genres: genres)
        return gender != "Group"
    }
}

// MARK: - Spotify API Models
struct SpotifyTokenResponse: Codable {
    let access_token: String
    let token_type: String
    let expires_in: Int
}

struct SpotifySearchResponse: Codable {
    let artists: SpotifyArtistsResponse
}

struct SpotifyArtistsResponse: Codable {
    let items: [SpotifyArtist]
}

struct SpotifyArtist: Codable, Identifiable {
    let id: String
    let name: String
    let popularity: Int
    let genres: [String]
    let images: [SpotifyImage]
    let followers: SpotifyFollowers?
    
    var imageURL: String? {
        return images.first?.url
    }
    
    var primaryGenre: String {
        return genres.first ?? "Unknown"
    }
}

struct SpotifyArtistDetails: Codable {
    let id: String
    let name: String
    let popularity: Int
    let genres: [String]
    let images: [SpotifyImage]
    let followers: SpotifyFollowers
}

struct SpotifyImage: Codable {
    let url: String
    let height: Int?
    let width: Int?
}

struct SpotifyFollowers: Codable {
    let total: Int
}

struct SpotifyTopTracksResponse: Codable {
    let tracks: [SpotifyTrack]
}

struct SpotifyTrack: Codable {
    let id: String
    let name: String
    let preview_url: String?
    let popularity: Int
    let duration_ms: Int
    let external_urls: SpotifyExternalUrls
}

struct SpotifyExternalUrls: Codable {
    let spotify: String
}

// MARK: - Album Models for Enhanced Data
struct SpotifyAlbumsResponse: Codable {
    let items: [SpotifyAlbum]
}

struct SpotifyAlbum: Codable {
    let id: String
    let name: String
    let release_date: String
    let album_type: String
    let total_tracks: Int
}

// MARK: - Conversion Extensions
extension SpotifyArtist {
    func toArtist() -> Artist {
        // Better heuristic for solo vs group detection
        let isSolo = !self.name.contains(" & ") && 
                    !self.name.contains(" and ") && 
                    !self.name.lowercased().contains("band") &&
                    !self.name.lowercased().contains("boys") &&
                    !self.name.lowercased().contains("girls") &&
                    !self.name.lowercased().contains("sisters") &&
                    !self.name.lowercased().contains("brothers")
        
        // Generate a unique ID for the Artist model
        let artistId = "spotify-\(self.id)"
        
        return Artist(
            id: artistId,
            name: self.name,
            gender: estimateGenderFromName(name: self.name), // Updated function name
            country: "Unknown", // Will be enhanced with new function
            debutYear: estimateDebutYear(popularity: self.popularity), // Estimate based on popularity
            genre: self.primaryGenre,
            isSolo: isSolo,
            spotifyPopularity: self.popularity,
            imageURL: self.imageURL,
            previewURL: nil, // Will be populated when needed
            spotifyId: self.id // Store the original Spotify ID
        )
    }
    
    private func estimateGenderFromName(name: String) -> String {
        // Enhanced gender detection with comprehensive name lists
        let lowercaseName = name.lowercased()
        
        // Group indicators
        if lowercaseName.contains("band") || 
           lowercaseName.contains("boys") ||
           lowercaseName.contains("girls") ||
           lowercaseName.contains("sisters") ||
           lowercaseName.contains("brothers") ||
           lowercaseName.contains(" & ") ||
           lowercaseName.contains(" and ") ||
           lowercaseName.contains("crew") ||
           lowercaseName.contains("collective") {
            return "Group"
        }
        
        // Extended male names list
        let maleNames = ["john", "michael", "david", "james", "robert", "william", "richard", "thomas", "charles", "christopher", "daniel", "matthew", "anthony", "mark", "donald", "steven", "paul", "andrew", "joshua", "kenneth", "kevin", "brian", "george", "edward", "ronald", "timothy", "jason", "jeffrey", "ryan", "jacob", "gary", "nicholas", "eric", "jonathan", "stephen", "larry", "justin", "scott", "brandon", "benjamin", "samuel", "frank", "gregory", "raymond", "alexander", "patrick", "jack", "dennis", "jerry", "tyler", "aaron", "jose", "henry", "adam", "douglas", "nathan", "peter", "zachary", "noah", "carl", "arthur", "harold", "jordan", "lawrence", "ralph", "billy", "wayne", "roy", "eugene", "louis", "albert", "vincent", "mason", "liam", "elijah", "lucas", "sebastian", "aiden", "joseph", "carter", "owen", "wyatt", "luke", "jayden", "dylan", "grayson", "levi", "isaac", "gabriel", "julian", "mateo", "jaxon", "lincoln", "caleb", "asher", "theodore", "eli", "easton", "evan", "adrian", "colton", "christian", "greyson", "connor", "landon", "gavin", "joel", "miles", "kanye", "drake", "eminem", "justin", "bruno", "ed", "shawn", "post", "travis", "kendrick", "cole", "mac", "lil", "xxxtentacion", "juice", "calvin", "martin", "alan", "marshmello", "skrillex", "diplo", "zedd", "tiësto", "avicii", "deadmau5", "kygo", "flume", "miguel", "usher", "chris", "frank", "weeknd", "abel", "harry", "zayn", "louis", "niall", "liam"]
        
        // Extended female names list  
        let femaleNames = ["mary", "patricia", "jennifer", "linda", "elizabeth", "barbara", "susan", "jessica", "sarah", "karen", "nancy", "lisa", "betty", "helen", "sandra", "donna", "carol", "ruth", "sharon", "michelle", "laura", "kimberly", "deborah", "dorothy", "amy", "angela", "ashley", "brenda", "emma", "olivia", "cynthia", "marie", "janet", "catherine", "frances", "christine", "samantha", "debra", "rachel", "carolyn", "virginia", "maria", "heather", "diane", "julie", "joyce", "victoria", "kelly", "christina", "joan", "evelyn", "lauren", "judith", "megan", "cheryl", "andrea", "hannah", "jacqueline", "martha", "gloria", "sara", "janice", "julia", "kathryn", "alice", "teresa", "doris", "jane", "charlotte", "rebecca", "amelia", "ava", "sophia", "isabella", "mia", "harper", "camila", "gianna", "abigail", "luna", "ella", "sofia", "emily", "avery", "mila", "scarlett", "eleanor", "madison", "layla", "penelope", "aria", "chloe", "grace", "ellie", "nora", "hazel", "zoey", "riley", "lily", "aurora", "violet", "nova", "emilia", "zoe", "stella", "everly", "taylor", "rihanna", "beyonce", "beyoncé", "ariana", "selena", "demi", "katy", "lady", "adele", "billie", "lana", "lorde", "sia", "pink", "shakira", "madonna", "cher", "whitney", "mariah", "celine", "alicia", "nicki", "gaga", "swift", "grande", "eilish", "del", "rey", "dua", "lipa", "olivia", "rodrigo", "camila", "cabello", "halsey", "kesha", "miley", "cyrus", "britney", "spears", "christina", "aguilera", "alicia", "keys", "janet", "jackson", "lauryn", "hill", "amy", "winehouse", "björk", "robyn", "grimes", "fka", "twigs", "solange", "jhené", "aiko", "sza", "lianne", "la", "havas", "kali", "uchis"]
        
        // Check if any part of the name matches known names
        let nameWords = lowercaseName.components(separatedBy: .whitespacesAndNewlines.union(.punctuationCharacters)).filter { !$0.isEmpty }
        
        for word in nameWords {
            if maleNames.contains(word) {
                return "Male"
            }
            if femaleNames.contains(word) {
                return "Female"
            }
        }
        
        // Default fallback
        return "Unknown"
    }
    
    private func estimateDebutYear(popularity: Int) -> Int {
        // Estimate debut year based on popularity and current trends
        // More popular artists are often more recent, but also established artists maintain high popularity
        let currentYear = Calendar.current.component(.year, from: Date())
        
        switch popularity {
        case 90...100:
            return Int.random(in: (currentYear-10)...currentYear) // Very popular, likely recent or sustained
        case 80..<90:
            return Int.random(in: (currentYear-15)...(currentYear-5)) // High popularity, established
        case 70..<80:
            return Int.random(in: (currentYear-20)...(currentYear-8)) // Good popularity, mid-career
        case 60..<70:
            return Int.random(in: (currentYear-25)...(currentYear-10)) // Moderate popularity
        case 50..<60:
            return Int.random(in: (currentYear-30)...(currentYear-15)) // Lower popularity
        default:
            return Int.random(in: (currentYear-40)...(currentYear-20)) // Low popularity, likely older or niche
        }
    }
}

// MARK: - Global Helper Functions
func estimateGenderFromName(_ name: String) -> String {
    // Enhanced gender detection with comprehensive name lists
    let lowercaseName = name.lowercased()
    
    // Group indicators
    if lowercaseName.contains("band") || 
       lowercaseName.contains("boys") ||
       lowercaseName.contains("girls") ||
       lowercaseName.contains("sisters") ||
       lowercaseName.contains("brothers") ||
       lowercaseName.contains(" & ") ||
       lowercaseName.contains(" and ") ||
       lowercaseName.contains("crew") ||
       lowercaseName.contains("collective") {
        return "Group"
    }
    
    // Extended male names list
    let maleNames = ["john", "michael", "david", "james", "robert", "william", "richard", "thomas", "charles", "christopher", "daniel", "matthew", "anthony", "mark", "donald", "steven", "paul", "andrew", "joshua", "kenneth", "kevin", "brian", "george", "edward", "ronald", "timothy", "jason", "jeffrey", "ryan", "jacob", "gary", "nicholas", "eric", "jonathan", "stephen", "larry", "justin", "scott", "brandon", "benjamin", "samuel", "frank", "gregory", "raymond", "alexander", "patrick", "jack", "dennis", "jerry", "tyler", "aaron", "jose", "henry", "adam", "douglas", "nathan", "peter", "zachary", "noah", "carl", "arthur", "harold", "jordan", "lawrence", "ralph", "billy", "wayne", "roy", "eugene", "louis", "albert", "vincent", "mason", "liam", "elijah", "lucas", "sebastian", "aiden", "joseph", "carter", "owen", "wyatt", "luke", "jayden", "dylan", "grayson", "levi", "isaac", "gabriel", "julian", "mateo", "jaxon", "lincoln", "caleb", "asher", "theodore", "eli", "easton", "evan", "adrian", "colton", "christian", "greyson", "connor", "landon", "gavin", "joel", "miles", "kanye", "drake", "eminem", "justin", "bruno", "ed", "shawn", "post", "travis", "kendrick", "cole", "mac", "lil", "xxxtentacion", "juice", "calvin", "martin", "alan", "marshmello", "skrillex", "diplo", "zedd", "tiësto", "avicii", "deadmau5", "kygo", "flume", "miguel", "usher", "chris", "frank", "weeknd", "abel", "harry", "zayn", "louis", "niall", "liam"]
    
    // Extended female names list  
    let femaleNames = ["mary", "patricia", "jennifer", "linda", "elizabeth", "barbara", "susan", "jessica", "sarah", "karen", "nancy", "lisa", "betty", "helen", "sandra", "donna", "carol", "ruth", "sharon", "michelle", "laura", "kimberly", "deborah", "dorothy", "amy", "angela", "ashley", "brenda", "emma", "olivia", "cynthia", "marie", "janet", "catherine", "frances", "christine", "samantha", "debra", "rachel", "carolyn", "virginia", "maria", "heather", "diane", "julie", "joyce", "victoria", "kelly", "christina", "joan", "evelyn", "lauren", "judith", "megan", "cheryl", "andrea", "hannah", "jacqueline", "martha", "gloria", "sara", "janice", "julia", "kathryn", "alice", "teresa", "doris", "jane", "charlotte", "rebecca", "amelia", "ava", "sophia", "isabella", "mia", "harper", "camila", "gianna", "abigail", "luna", "ella", "sofia", "emily", "avery", "mila", "scarlett", "eleanor", "madison", "layla", "penelope", "aria", "chloe", "grace", "ellie", "nora", "hazel", "zoey", "riley", "lily", "aurora", "violet", "nova", "emilia", "zoe", "stella", "everly", "taylor", "rihanna", "beyonce", "beyoncé", "ariana", "selena", "demi", "katy", "lady", "adele", "billie", "lana", "lorde", "sia", "pink", "shakira", "madonna", "cher", "whitney", "mariah", "celine", "alicia", "nicki", "gaga", "swift", "grande", "eilish", "del", "rey", "dua", "lipa", "olivia", "rodrigo", "camila", "cabello", "halsey", "kesha", "miley", "cyrus", "britney", "spears", "christina", "aguilera", "alicia", "keys", "janet", "jackson", "lauryn", "hill", "amy", "winehouse", "björk", "robyn", "grimes", "fka", "twigs", "solange", "jhené", "aiko", "sza", "lianne", "la", "havas", "kali", "uchis"]
    
    // Check if any part of the name matches known names
    let nameWords = lowercaseName.components(separatedBy: .whitespacesAndNewlines.union(.punctuationCharacters)).filter { !$0.isEmpty }
    
    for word in nameWords {
        if maleNames.contains(word) {
            return "Male"
        }
        if femaleNames.contains(word) {
            return "Female"
        }
    }
    
    // Default fallback
    return "Unknown"
} 