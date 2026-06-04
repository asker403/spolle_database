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
    private var lastRequestTime: Date = Date(timeIntervalSince1970: 0)
    private let minimumRequestInterval: TimeInterval = 0.1 // 100ms between requests
    
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
    
    // MARK: - Rate Limiting Helper
    private func waitForRateLimit() async {
        let timeSinceLastRequest = Date().timeIntervalSince(lastRequestTime)
        if timeSinceLastRequest < minimumRequestInterval {
            let waitTime = minimumRequestInterval - timeSinceLastRequest
            print("⏱️ Rate limiting: waiting \(Int(waitTime * 1000))ms")
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
        lastRequestTime = Date()
    }
    
    private func handleRateLimitResponse(data: Data, response: URLResponse) async -> Bool {
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 429 {
            print("🚫 Rate limited (429), waiting before retry...")
            // Check for Retry-After header
            let retryAfter = httpResponse.allHeaderFields["Retry-After"] as? String
            let waitTime = TimeInterval(retryAfter ?? "1") ?? 1.0
            print("⏳ Waiting \(waitTime) seconds before retry")
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            return true
        }
        return false
    }
    
    // MARK: - Artist Search
    func searchArtists(query: String, limit: Int = 20) async -> [SpotifyArtist] {
        guard !query.isEmpty else { return [] }
        
        // Ensure we're authenticated
        if !isAuthenticated {
            await authenticate()
        }
        
        guard let token = accessToken else { return [] }
        
        await waitForRateLimit()
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(baseURL)/search?q=\(encodedQuery)&type=artist&limit=\(limit)"
        
        guard let url = URL(string: urlString) else { return [] }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        var retryCount = 0
        while retryCount < 3 {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if await handleRateLimitResponse(data: data, response: response) {
                    retryCount += 1
                    continue
                }
                
                let searchResponse = try JSONDecoder().decode(SpotifySearchResponse.self, from: data)
                return searchResponse.artists.items
            } catch {
                print("❌ Spotify search error (attempt \(retryCount + 1)): \(error)")
                retryCount += 1
                if retryCount < 3 {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
                }
            }
        }
        return []
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
        
        await waitForRateLimit()
        
        guard let url = URL(string: "\(baseURL)/artists/\(id)") else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        var retryCount = 0
        while retryCount < 3 {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if await handleRateLimitResponse(data: data, response: response) {
                    retryCount += 1
                    continue
                }
                
                let artistDetails = try JSONDecoder().decode(SpotifyArtistDetails.self, from: data)
                return artistDetails
            } catch {
                print("❌ Error fetching artist details (attempt \(retryCount + 1)): \(error)")
                retryCount += 1
                if retryCount < 3 {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }
        }
        return nil
    }
    
    // MARK: - Get Artist Top Tracks (for audio preview)
    func getArtistTopTracks(artistId: String, market: String = "US") async -> [SpotifyTrack] {
        print("🎵 Fetching top tracks for artist ID: \(artistId)")
        guard let token = accessToken else { 
            print("❌ No access token available")
            return [] 
        }
        
        // Reduced markets to prevent rate limiting - try only essential ones
        let markets = [market == "US" ? "US" : market, "US", "GB"]
        var allTracks: [SpotifyTrack] = []
        
        for marketCode in markets {
            // Rate limiting: wait between requests
            await waitForRateLimit()
            
            guard let url = URL(string: "\(baseURL)/artists/\(artistId)/top-tracks?market=\(marketCode)") else { 
                continue
            }
            
            print("🌐 Requesting for market \(marketCode): \(url.absoluteString)")
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            var retryCount = 0
            while retryCount < 2 { // Reduced retries
                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    
                    if let httpResponse = response as? HTTPURLResponse {
                        print("📡 Response status for \(marketCode): \(httpResponse.statusCode)")
                        
                        // Handle rate limiting
                        if httpResponse.statusCode == 429 {
                            if await handleRateLimitResponse(data: data, response: response) {
                                retryCount += 1
                                continue
                            }
                        }
                    }
                    
                    let topTracksResponse = try JSONDecoder().decode(SpotifyTopTracksResponse.self, from: data)
                    let tracksWithPreviews = topTracksResponse.tracks.filter { $0.preview_url != nil }
                    
                    print("🎶 Found \(topTracksResponse.tracks.count) top tracks for \(marketCode)")
                    print("🎧 Tracks with preview in \(marketCode): \(tracksWithPreviews.count)")
                    
                    // Add tracks that have preview URLs
                    for track in tracksWithPreviews {
                        if !allTracks.contains(where: { $0.id == track.id }) {
                            allTracks.append(track)
                            print("   ✅ Added preview: \(track.name) from \(marketCode)")
                        }
                    }
                    
                    // If we found previews in this market, prioritize them
                    if !tracksWithPreviews.isEmpty {
                        let finalTracks = tracksWithPreviews + topTracksResponse.tracks.filter { $0.preview_url == nil }
                        print("✅ Using tracks from \(marketCode) market with \(tracksWithPreviews.count) preview(s)")
                        return finalTracks
                    }
                    
                    break // Success, try next market
                    
                } catch {
                    print("❌ Error fetching top tracks for \(marketCode) (attempt \(retryCount + 1)): \(error)")
                    retryCount += 1
                    if retryCount < 2 {
                        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second between retries
                    }
                }
            }
        }
        
        print("🎵 Collected \(allTracks.count) total tracks with previews across \(markets.count) markets")
        return allTracks
    }
    
    // MARK: - Enhanced Top Tracks with Preview Priority  
    func getTopTracksWithPreviewPriority(artistId: String) async -> [SpotifyTrack] {
        print("🎯 Getting tracks with preview priority for artist: \(artistId)")
        
        let tracks = await getArtistTopTracks(artistId: artistId)
        
        // Separate tracks with and without previews
        let tracksWithPreviews = tracks.filter { $0.preview_url != nil }
        let tracksWithoutPreviews = tracks.filter { $0.preview_url == nil }
        
        print("📊 Total tracks: \(tracks.count)")
        print("🎧 With previews: \(tracksWithPreviews.count)")
        print("🚫 Without previews: \(tracksWithoutPreviews.count)")
        
        // Return preview tracks first, then others
        return tracksWithPreviews + tracksWithoutPreviews
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
        
        // Get top tracks with preview priority
        let topTracks = await getTopTracksWithPreviewPriority(artistId: artist.id)
        
        // Find the first track with a preview, prioritizing more popular ones
        let tracksWithPreviews = topTracks.filter { $0.preview_url != nil }
        let previewURL = tracksWithPreviews.first?.preview_url
        
        print("🎵 searchArtistWithDetails for \(name): Found \(tracksWithPreviews.count) tracks with previews")
        
        return (artist: artist, imageURL: imageURL, previewURL: previewURL)
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
            gender: estimateGender(name: self.name), // Basic gender estimation
            country: "Unknown", // Spotify doesn't provide country in basic search
            debutYear: estimateDebutYear(popularity: self.popularity), // Estimate based on popularity
            genre: self.primaryGenre,
            isSolo: isSolo,
            spotifyPopularity: self.popularity,
            imageURL: self.imageURL,
            previewURL: nil, // Will be populated when needed
            spotifyId: self.id // Store the original Spotify ID
        )
    }
    
    private func estimateGender(name: String) -> String {
        // Basic heuristic based on common patterns
        let lowercaseName = name.lowercased()
        
        // Group indicators
        if lowercaseName.contains("band") || 
           lowercaseName.contains("boys") ||
           lowercaseName.contains("girls") ||
           lowercaseName.contains("sisters") ||
           lowercaseName.contains("brothers") ||
           lowercaseName.contains(" & ") ||
           lowercaseName.contains(" and ") {
            return "Group"
        }
        
        // Common male names
        let maleNames = ["john", "michael", "david", "james", "robert", "william", "richard", "thomas", "charles", "christopher", "daniel", "matthew", "anthony", "mark", "donald", "steven", "paul", "andrew", "joshua", "kenneth", "kevin", "brian", "george", "edward", "ronald", "timothy", "jason", "jeffrey", "ryan", "jacob", "gary", "nicholas", "eric", "jonathan", "stephen", "larry", "justin", "scott", "brandon", "benjamin", "samuel", "frank", "gregory", "raymond", "alexander", "patrick", "jack", "dennis", "jerry", "tyler", "aaron", "jose", "henry", "adam", "douglas", "nathan", "peter", "zachary", "noah", "carl", "arthur", "harold", "jordan", "lawrence", "ralph", "billy", "wayne", "roy", "eugene", "louis", "albert", "vincent", "mason", "mason", "liam", "noah", "william", "elijah", "james", "benjamin", "lucas", "henry", "alexander", "jackson", "sebastian", "aiden", "matthew", "samuel", "david", "joseph", "carter", "owen", "wyatt", "john", "jack", "luke", "jayden", "dylan", "grayson", "levi", "isaac", "gabriel", "julian", "mateo", "anthony", "jaxon", "lincoln", "joshua", "christopher", "andrew", "theodore", "caleb", "ryan", "asher", "nathan", "thomas", "leo", "isaiah", "charles", "josiah", "angel", "hunter", "eli", "easton", "evan", "aaron", "adrian", "colton", "jordan", "christian", "robert", "greyson", "jonathan", "connor", "landon", "gavin", "tyler", "jose", "joel", "miles", "ralph", "kanye", "drake", "eminem", "justin", "bruno", "ed", "shawn", "post", "travis", "tyler", "kendrick", "j.", "lil", "xxxtentacion", "juice", "mac"]
        
        // Common female names  
        let femaleNames = ["mary", "patricia", "jennifer", "linda", "elizabeth", "barbara", "susan", "jessica", "sarah", "karen", "nancy", "lisa", "betty", "helen", "sandra", "donna", "carol", "ruth", "sharon", "michelle", "laura", "sarah", "kimberly", "deborah", "dorothy", "lisa", "nancy", "karen", "betty", "helen", "sandra", "donna", "carol", "ruth", "sharon", "michelle", "laura", "sarah", "kimberly", "deborah", "dorothy", "amy", "angela", "ashley", "brenda", "emma", "olivia", "cynthia", "marie", "janet", "catherine", "frances", "christine", "samantha", "debra", "rachel", "carolyn", "janet", "virginia", "maria", "heather", "diane", "julie", "joyce", "victoria", "kelly", "christina", "joan", "evelyn", "lauren", "judith", "megan", "cheryl", "andrea", "hannah", "jacqueline", "martha", "gloria", "sara", "janice", "julia", "kathryn", "alice", "teresa", "doris", "sara", "jane", "charlotte", "rebecca", "olivia", "emma", "amelia", "ava", "sophia", "isabella", "mia", "evelyn", "harper", "camila", "gianna", "abigail", "luna", "ella", "elizabeth", "sofia", "emily", "avery", "mila", "scarlett", "eleanor", "madison", "layla", "penelope", "aria", "chloe", "grace", "ellie", "nora", "hazel", "zoey", "riley", "victoria", "lily", "aurora", "violet", "nova", "hannah", "emilia", "zoe", "stella", "everly", "taylor", "rihanna", "beyonce", "ariana", "selena", "demi", "katy", "lady", "adele", "billie", "lana", "lorde", "sia", "pink", "shakira", "madonna", "cher", "whitney", "mariah", "celine", "alicia", "nicki", "gaga", "swift"]
        
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