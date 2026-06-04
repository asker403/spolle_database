const admin = require("firebase-admin");
const fs = require("fs");

// Firestore config
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// Check which file to use - prioritize Spotify-priority data
let artists;
let dataSource;

if (fs.existsSync("spotify_priority_artists_data.json")) {
  artists = JSON.parse(fs.readFileSync("spotify_priority_artists_data.json", "utf8"));
  dataSource = "spotify_priority_artists_data.json (SPOTIFY-PRIORITY DATA)";
} else if (fs.existsSync("test_spotify_artists.json")) {
  artists = JSON.parse(fs.readFileSync("test_spotify_artists.json", "utf8"));
  dataSource = "test_spotify_artists.json (TEST SPOTIFY DATA)";
} else if (fs.existsSync("enhanced_real_artists_data.json")) {
  artists = JSON.parse(fs.readFileSync("enhanced_real_artists_data.json", "utf8"));
  dataSource = "enhanced_real_artists_data.json (ENHANCED REAL DATA)";
} else if (fs.existsSync("test_enhanced_artists.json")) {
  artists = JSON.parse(fs.readFileSync("test_enhanced_artists.json", "utf8"));
  dataSource = "test_enhanced_artists.json (TEST ENHANCED DATA)";
} else if (fs.existsSync("real_artists_data.json")) {
  artists = JSON.parse(fs.readFileSync("real_artists_data.json", "utf8"));
  dataSource = "real_artists_data.json (REAL DATA)";
} else if (fs.existsSync("artists.json")) {
  artists = JSON.parse(fs.readFileSync("artists.json", "utf8"));
  dataSource = "artists.json (generated data)";
} else {
  console.error("❌ No artist data file found! Run the data fetcher first.");
  process.exit(1);
}

console.log(`📁 Using data source: ${dataSource}`);
console.log(`📊 Found ${artists.length} artists to upload`);

async function uploadArtists() {
  const batch = db.batch();
  let uploadCount = 0;

  artists.forEach((artist, index) => {
    // Clean up the data for Firestore with comprehensive field mapping
    const cleanArtist = {
      // Core required fields
      isim: artist.isim,
      populerlik: artist.populerlik,
      cinsiyet: artist.cinsiyet || "Unknown",
      resim_url: artist.resim_url,
      audio_preview_url: artist.audio_preview_url,
      genre: artist.genre || (artist.spotify_genres && artist.spotify_genres[0]) || "Pop",
      ulke: artist.ulke || "Unknown",
      cikis_yili: artist.cikis_yili || 2000,
      tip: artist.tip || "Solo",
      
      // Spotify-specific fields (from new data structure)
      ...(artist.spotify_id && { spotify_id: artist.spotify_id }),
      ...(artist.spotify_popularity && { spotify_popularity: artist.spotify_popularity }),
      ...(artist.spotify_followers && { spotify_followers: artist.spotify_followers }),
      ...(artist.spotify_genres && { spotify_genres: artist.spotify_genres }),
      
      // Kworb rankings data
      ...(artist.kworb_streams && { kworb_streams: artist.kworb_streams }),
      
      // Audio preview metadata
      ...(artist.preview_track && { preview_track: artist.preview_track }),
      ...(artist.preview_source && { preview_source: artist.preview_source }),
      ...(artist.preview_album && { preview_album: artist.preview_album }),
      ...(artist.track_popularity && { track_popularity: artist.track_popularity }),
      
      // Image metadata
      ...(artist.image_source && { image_source: artist.image_source }),
      
      // Additional metadata for debugging/analytics
      ...(artist.preview_market && { preview_market: artist.preview_market }),
    };

    const docRef = db.collection("sanatcilar").doc(); // Otomatik ID
    batch.set(docRef, cleanArtist);
    uploadCount++;
  });

  console.log(`🚀 Uploading ${uploadCount} artists to Firestore...`);
  await batch.commit();
  
  console.log("✅ Sanatçılar başarıyla yüklendi!");
  console.log(`📊 Total uploaded: ${uploadCount} artists`);
  console.log(`📁 Data source: ${dataSource}`);
  
  // Enhanced statistics reporting
  const withImages = artists.filter(a => a.resim_url).length;
  const withAudio = artists.filter(a => a.audio_preview_url).length;
  const withSpotifyData = artists.filter(a => a.spotify_id).length;
  const spotifyImages = artists.filter(a => a.image_source === 'Spotify').length;
  const spotifyAudio = artists.filter(a => a.preview_source === 'Spotify').length;
  const withGenres = artists.filter(a => a.spotify_genres && a.spotify_genres.length > 0).length;
  const withGender = artists.filter(a => a.cinsiyet !== 'Unknown').length;
  const withCountry = artists.filter(a => a.ulke !== 'Unknown').length;
  
  console.log(`\n📈 Upload Statistics:`);
  console.log(`   Total artists: ${artists.length}`);
  console.log(`   Found on Spotify: ${withSpotifyData}/${artists.length} (${(withSpotifyData/artists.length*100).toFixed(1)}%)`);
  console.log(`   Images from Spotify: ${spotifyImages}/${artists.length} (${(spotifyImages/artists.length*100).toFixed(1)}%)`);
  console.log(`   Audio previews from Spotify: ${spotifyAudio}/${artists.length} (${(spotifyAudio/artists.length*100).toFixed(1)}%)`);
  console.log(`   Total with images: ${withImages}/${artists.length} (${(withImages/artists.length*100).toFixed(1)}%)`);
  console.log(`   Total with audio: ${withAudio}/${artists.length} (${(withAudio/artists.length*100).toFixed(1)}%)`);
  console.log(`   With Spotify genres: ${withGenres}/${artists.length} (${(withGenres/artists.length*100).toFixed(1)}%)`);
  console.log(`   With gender info: ${withGender}/${artists.length} (${(withGender/artists.length*100).toFixed(1)}%)`);
  console.log(`   With country info: ${withCountry}/${artists.length} (${(withCountry/artists.length*100).toFixed(1)}%)`);
  
  // Show data quality insights
  console.log(`\n🎵 Data Quality Insights:`);
  if (withSpotifyData > 0) {
    const avgFollowers = artists
      .filter(a => a.spotify_followers)
      .reduce((sum, a) => sum + a.spotify_followers, 0) / withSpotifyData;
    const avgPopularity = artists
      .filter(a => a.spotify_popularity)
      .reduce((sum, a) => sum + a.spotify_popularity, 0) / withSpotifyData;
    
    console.log(`   Average Spotify followers: ${Math.round(avgFollowers).toLocaleString()}`);
    console.log(`   Average Spotify popularity: ${avgPopularity.toFixed(1)}/100`);
  }
  
  console.log(`\n🎉 Upload completed successfully!`);
}

uploadArtists().catch(console.error);
