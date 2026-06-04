# Firestore Database Schema for Multiplayer System

## Overview
This document describes the Firestore collections and document structure needed for the multiplayer functionality in Songle.

## Collections

### 1. `multiplayer_sessions`
**Purpose**: Store active multiplayer game sessions

**Document ID**: Auto-generated UUID (e.g., `session_123456789`)

**Document Structure**:
```json
{
  "inviteCode": "ABC123",
  "dateString": "2025-01-07",
  "targetArtistId": "artist_uuid",
  "targetArtistName": "Taylor Swift",
  "players": [
    {
      "id": "player_uuid_1",
      "name": "Player 1",
      "guesses": [
        {
          "id": "guess_uuid_1",
          "artistName": "Adele",
          "timestamp": "2025-01-07T10:30:00Z",
          "result": "incorrect",
          "hints": {
            "Gender": "Female|correct",
            "Country": "UK|incorrect",
            "Debut Year": "2008|close",
            "Genre": "Pop|correct",
            "Popularity": "#5|incorrect"
          }
        }
      ],
      "isCorrect": false,
      "joinedAt": "2025-01-07T10:25:00Z"
    },
    {
      "id": "player_uuid_2",
      "name": "Player 2",
      "guesses": [],
      "isCorrect": false,
      "joinedAt": "2025-01-07T10:26:00Z"
    }
  ],
  "currentPlayerIndex": 0,
  "createdAt": "2025-01-07T10:25:00Z",
  "isCompleted": false,
  "winnerPlayerIndex": null,
  "gameStarted": true
}
```

**Firestore Rules**:
```javascript
// Allow read/write access to multiplayer sessions
match /multiplayer_sessions/{sessionId} {
  allow read, write: if true; // For simplicity - can be restricted later
}
```

### 2. `artists` (existing collection)
**Purpose**: Store artist data for the game

**Document Structure**: (Already exists in your current setup)
```json
{
  "name": "Taylor Swift",
  "country": "USA",
  "genre": "Pop",
  "debutYear": 2006,
  "spotifyPopularity": 1,
  "gender": "Female"
}
```

## Game Flow

### 1. Creating a Game Session
1. Player 1 creates a session with a random 6-character invite code
2. Document is created in `multiplayer_sessions` collection
3. Player 1 is added to the `players` array
4. Session status: `gameStarted = false`

### 2. Joining a Game Session
1. Player 2 uses invite code to find the session
2. Player 2 is added to the `players` array
3. Session status: `gameStarted = true` (when 2 players are present)

### 3. Playing the Game
1. Players take turns making guesses
2. Each guess is added to the player's `guesses` array
3. `currentPlayerIndex` alternates between 0 and 1
4. Game checks for win conditions after each guess

### 4. Game Completion
1. Game ends when:
   - A player guesses correctly (`isCorrect = true`)
   - Both players use all 5 guesses
2. `isCompleted = true`
3. `winnerPlayerIndex` is set (or null for draw)

## Implementation Notes

### Security Considerations
- Session documents should auto-delete after 24 hours
- Only players in a session should be able to modify it
- Implement proper Firestore security rules

### Performance Optimizations
- Index on `inviteCode` for fast session lookups
- Clean up completed sessions periodically
- Limit to 2 players per session

### Real-time Updates
- Use Firestore listeners to update UI when opponent makes moves
- Handle network disconnections gracefully
- Show connection status to players

## Required Firestore Functions

### 1. Create Session
```swift
func createMultiplayerSession(_ session: MultiplayerGameSession) async throws {
    let sessionData = try Firestore.Encoder().encode(session)
    try await db.collection("multiplayer_sessions")
        .document(session.id.uuidString)
        .setData(sessionData)
}
```

### 2. Find Session by Invite Code
```swift
func findMultiplayerSession(inviteCode: String) async throws -> MultiplayerGameSession? {
    let query = db.collection("multiplayer_sessions")
        .whereField("inviteCode", isEqualTo: inviteCode)
        .whereField("isCompleted", isEqualTo: false)
        .limit(to: 1)
    
    let snapshot = try await query.getDocuments()
    guard let document = snapshot.documents.first else { return nil }
    
    return try document.data(as: MultiplayerGameSession.self)
}
```

### 3. Update Session
```swift
func updateMultiplayerSession(_ session: MultiplayerGameSession) async throws {
    let sessionData = try Firestore.Encoder().encode(session)
    try await db.collection("multiplayer_sessions")
        .document(session.id.uuidString)
        .setData(sessionData)
}
```

### 4. Listen for Session Updates
```swift
func listenToMultiplayerSession(sessionId: String, 
                               completion: @escaping (MultiplayerGameSession?) -> Void) {
    db.collection("multiplayer_sessions")
        .document(sessionId)
        .addSnapshotListener { snapshot, error in
            guard let document = snapshot,
                  let session = try? document.data(as: MultiplayerGameSession.self) else {
                completion(nil)
                return
            }
            completion(session)
        }
}
```

## Next Steps

1. **Add Firebase SDK** to your Xcode project
2. **Add GoogleService-Info.plist** from Firebase Console
3. **Implement the Firestore functions** in `FirestoreService.swift`
4. **Test with two devices/simulators** to verify multiplayer works
5. **Add real-time listeners** for live updates during games 