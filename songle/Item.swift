//
//  Item.swift
//  songle
//
//  Created by Ümit BAĞ on 7/2/25.
//

import Foundation
import SwiftData

// MARK: - Artist Model
@Model
final class Artist {
    var id: String
    var name: String
    var gender: String // "Male", "Female", "Non-binary", "Group"
    var country: String
    var debutYear: Int
    var genre: String
    var isSolo: Bool // true for solo artist, false for group
    var spotifyPopularity: Int // 0-100
    var imageURL: String?
    var previewURL: String?
    var spotifyId: String? // Spotify artist ID for more reliable data fetching
    
    init(id: String, name: String, gender: String, country: String, debutYear: Int, genre: String, isSolo: Bool, spotifyPopularity: Int, imageURL: String? = nil, previewURL: String? = nil, spotifyId: String? = nil) {
        self.id = id
        self.name = name
        self.gender = gender
        self.country = country
        self.debutYear = debutYear
        self.genre = genre
        self.isSolo = isSolo
        self.spotifyPopularity = spotifyPopularity
        self.imageURL = imageURL
        self.previewURL = previewURL
        self.spotifyId = spotifyId
    }
}

// MARK: - Guess Model
@Model
final class Guess {
    var id: String = UUID().uuidString // Default value for migration
    var artistName: String
    var isCorrect: Bool
    var hints: [String: String] // Key-value pairs for hint results
    var timestamp: Date
    var artistImageURL: String? = nil // Optional with default
    
    init(artistName: String, isCorrect: Bool = false, hints: [String: String] = [:], artistImageURL: String? = nil) {
        self.id = UUID().uuidString
        self.artistName = artistName
        self.isCorrect = isCorrect
        self.hints = hints
        self.timestamp = Date()
        self.artistImageURL = artistImageURL
    }
}

// MARK: - Game State Model
@Model
final class GameState {
    var id: String
    var dateString: String // Format: "YYYY-MM-DD"
    var targetArtistId: String
    var currentGuesses: [Guess]
    var isCompleted: Bool
    var isWon: Bool
    var attemptsRemaining: Int
    
    init(dateString: String, targetArtistId: String) {
        self.id = UUID().uuidString
        self.dateString = dateString
        self.targetArtistId = targetArtistId
        self.currentGuesses = []
        self.isCompleted = false
        self.isWon = false
        self.attemptsRemaining = 10
    }
}
