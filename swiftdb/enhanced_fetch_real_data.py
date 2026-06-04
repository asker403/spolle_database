#!/usr/bin/env python3
"""
Enhanced Real Artist Data Fetcher with Spotify API Priority
Fetches comprehensive real artist data including:
- Top 500 artists from Kworb.net Spotify rankings
- PRIMARY: Spotify API data (genres, images, audio previews, popularity)
- FALLBACK: Other sources for missing data (country, debut year)
"""

import requests
import json
import time
import re
import base64
from bs4 import BeautifulSoup
from urllib.parse import quote, unquote
import random
from difflib import SequenceMatcher

class SpotifyPriorityArtistDataFetcher:
    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        })
        self.artists_data = []
        
        # Spotify API credentials
        self.spotify_client_id = "015767dd9089403cabdd92c686530339"
        self.spotify_client_secret = "67a2c62c212042168ffd831d13da1f80"
        self.spotify_token = None
        self.spotify_token_expires = 0
        
        # Cache for API responses to avoid repeated calls
        self.musicbrainz_cache = {}
        self.spotify_cache = {}
        
    def similarity(self, a, b):
        """Calculate similarity between two strings"""
        return SequenceMatcher(None, a.lower(), b.lower()).ratio()
    
    def get_spotify_access_token(self):
        """Get Spotify access token using client credentials"""
        current_time = time.time()
        
        # Check if we have a valid token
        if self.spotify_token and current_time < self.spotify_token_expires:
            return self.spotify_token
        
        print("🔑 Getting Spotify access token...")
        
        # Encode client credentials
        client_credentials = f"{self.spotify_client_id}:{self.spotify_client_secret}"
        client_credentials_b64 = base64.b64encode(client_credentials.encode()).decode()
        
        # Token request
        token_url = "https://accounts.spotify.com/api/token"
        headers = {
            'Authorization': f'Basic {client_credentials_b64}',
            'Content-Type': 'application/x-www-form-urlencoded'
        }
        data = {'grant_type': 'client_credentials'}
        
        try:
            response = self.session.post(token_url, headers=headers, data=data, timeout=10)
            response.raise_for_status()
            
            token_data = response.json()
            self.spotify_token = token_data['access_token']
            self.spotify_token_expires = current_time + token_data['expires_in'] - 60  # 60 second buffer
            
            print("✅ Spotify access token obtained successfully")
            return self.spotify_token
            
        except Exception as e:
            print(f"❌ Failed to get Spotify access token: {e}")
            return None
    
    def search_spotify_artist(self, artist_name):
        """Search for artist on Spotify API"""
        if artist_name in self.spotify_cache:
            return self.spotify_cache[artist_name]
        
        token = self.get_spotify_access_token()
        if not token:
            return None
        
        try:
            print(f"  🎵 Spotify API search: {artist_name}")
            
            # Clean artist name for better search results
            clean_name = artist_name.replace('&', 'and').replace('$', 's').replace('@', 'a')
            clean_name = re.sub(r'[^\w\s]', ' ', clean_name).strip()
            clean_name = re.sub(r'\s+', ' ', clean_name)
            
            search_url = "https://api.spotify.com/v1/search"
            headers = {'Authorization': f'Bearer {token}'}
            params = {
                'q': f'"{clean_name}"',  # Use quotes for exact phrase matching
                'type': 'artist',
                'limit': 20  # Get more results for better matching
            }
            
            response = self.session.get(search_url, headers=headers, params=params, timeout=15)
            response.raise_for_status()
            
            data = response.json()
            artists = data.get('artists', {}).get('items', [])
            
            # Find best match
            best_match = None
            best_score = 0
            
            for artist in artists:
                score = self.similarity(artist['name'], artist_name)
                print(f"    📊 Match: '{artist['name']}' vs '{artist_name}' = {score:.3f} (followers: {artist.get('followers', {}).get('total', 0):,})")
                if score > best_score and score > 0.85:  # Higher similarity threshold for accuracy
                    best_score = score
                    best_match = artist
            
            if best_match:
                print(f"    ✅ Best match: '{best_match['name']}' (score: {best_score:.3f}, followers: {best_match.get('followers', {}).get('total', 0):,})")
                # Cache the result
                self.spotify_cache[artist_name] = best_match
                return best_match
            else:
                print(f"    ⚠️  No good match found on Spotify (best score: {best_score:.3f})")
                # Show all candidates for debugging
                if artists:
                    print(f"    📋 Available artists:")
                    for artist in artists[:3]:
                        print(f"      - '{artist['name']}' (followers: {artist.get('followers', {}).get('total', 0):,})")
                self.spotify_cache[artist_name] = None
                return None
                
        except Exception as e:
            print(f"    ⚠️  Spotify search failed: {e}")
            self.spotify_cache[artist_name] = None
            return None
    
    def get_spotify_artist_top_tracks(self, artist_id):
        """Get artist's top tracks from Spotify with comprehensive preview search"""
        token = self.get_spotify_access_token()
        if not token:
            return None
        
        try:
            tracks_url = f"https://api.spotify.com/v1/artists/{artist_id}/top-tracks"
            headers = {'Authorization': f'Bearer {token}'}
            
            # Try multiple markets to find previews
            markets = ['US', 'GB', 'CA', 'AU', 'DE', 'FR', 'ES', 'IT', 'NL']
            
            for market in markets:
                params = {'market': market}
                response = self.session.get(tracks_url, headers=headers, params=params, timeout=10)
                
                if response.status_code == 200:
                    data = response.json()
                    tracks = data.get('tracks', [])
                    
                    # Look for tracks with preview URLs
                    for track in tracks:
                        if track.get('preview_url'):
                            print(f"    🎵 Found preview in {market}")
                            return {
                                'preview_url': track['preview_url'],
                                'track_name': track.get('name', ''),
                                'album_name': track.get('album', {}).get('name', ''),
                                'popularity': track.get('popularity', 0),
                                'source': 'Spotify'
                            }
            
            # If no previews in top tracks, search through albums more extensively
            return self.search_spotify_tracks_with_preview(artist_id)
            
        except Exception as e:
            print(f"    ⚠️  Spotify top tracks failed: {e}")
            return None
    
    def search_spotify_tracks_with_preview(self, artist_id):
        """Search extensively for any tracks by this artist that have preview URLs"""
        token = self.get_spotify_access_token()
        if not token:
            return None
        
        try:
            headers = {'Authorization': f'Bearer {token}'}
            
            # Method 1: Search through all albums/singles
            albums_url = f"https://api.spotify.com/v1/artists/{artist_id}/albums"
            params = {
                'include_groups': 'album,single,compilation',
                'market': 'US',
                'limit': 50  # Get more albums
            }
            
            response = self.session.get(albums_url, headers=headers, params=params, timeout=10)
            response.raise_for_status()
            
            albums_data = response.json()
            albums = albums_data.get('items', [])
            
            # Check tracks in albums for previews (prioritize newer albums)
            for album in albums[:10]:  # Check first 10 albums
                album_id = album.get('id')
                if album_id:
                    tracks_url = f"https://api.spotify.com/v1/albums/{album_id}/tracks"
                    tracks_response = self.session.get(tracks_url, headers=headers, timeout=10)
                    
                    if tracks_response.status_code == 200:
                        tracks_data = tracks_response.json()
                        tracks = tracks_data.get('items', [])
                        
                        for track in tracks:
                            if track.get('preview_url'):
                                return {
                                    'preview_url': track['preview_url'],
                                    'track_name': track.get('name', ''),
                                    'album_name': album.get('name', ''),
                                    'popularity': 0,
                                    'source': 'Spotify'
                                }
            
            # Method 2: Use search API to find tracks with previews
            return self.search_spotify_tracks_by_name(artist_id)
            
        except Exception as e:
            print(f"    ⚠️  Spotify album search failed: {e}")
            return None
    
    def search_spotify_tracks_by_name(self, artist_id):
        """Search for tracks by artist name using search API"""
        token = self.get_spotify_access_token()
        if not token:
            return None
        
        try:
            # Get artist name first
            artist_url = f"https://api.spotify.com/v1/artists/{artist_id}"
            headers = {'Authorization': f'Bearer {token}'}
            
            response = self.session.get(artist_url, headers=headers, timeout=10)
            if response.status_code != 200:
                return None
            
            artist_data = response.json()
            artist_name = artist_data.get('name', '')
            
            if not artist_name:
                return None
            
            # Search for tracks by this artist
            search_url = "https://api.spotify.com/v1/search"
            params = {
                'q': f'artist:"{artist_name}"',
                'type': 'track',
                'market': 'US',
                'limit': 50
            }
            
            response = self.session.get(search_url, headers=headers, params=params, timeout=10)
            response.raise_for_status()
            
            search_data = response.json()
            tracks = search_data.get('tracks', {}).get('items', [])
            
            # Look for tracks with previews
            for track in tracks:
                # Verify this is actually by the same artist
                track_artists = track.get('artists', [])
                for track_artist in track_artists:
                    if track_artist.get('id') == artist_id and track.get('preview_url'):
                        return {
                            'preview_url': track['preview_url'],
                            'track_name': track.get('name', ''),
                            'album_name': track.get('album', {}).get('name', ''),
                            'popularity': track.get('popularity', 0),
                            'source': 'Spotify'
                        }
            
            return None
            
        except Exception as e:
            print(f"    ⚠️  Spotify search failed: {e}")
            return None
    
    def get_spotify_artist_albums(self, artist_id):
        """Get artist's albums from Spotify to find debut year"""
        token = self.get_spotify_access_token()
        if not token:
            return None
        
        try:
            albums_url = f"https://api.spotify.com/v1/artists/{artist_id}/albums"
            headers = {'Authorization': f'Bearer {token}'}
            params = {
                'include_groups': 'album,single',
                'market': 'US',
                'limit': 50
            }
            
            response = self.session.get(albums_url, headers=headers, params=params, timeout=10)
            response.raise_for_status()
            
            data = response.json()
            albums = data.get('items', [])
            
            # Find earliest release year
            earliest_year = None
            for album in albums:
                release_date = album.get('release_date', '')
                if release_date:
                    try:
                        year = int(release_date[:4])
                        if year >= 1950:  # Sanity check
                            if earliest_year is None or year < earliest_year:
                                earliest_year = year
                    except:
                        continue
            
            return earliest_year
            
        except Exception as e:
            print(f"    ⚠️  Spotify albums lookup failed: {e}")
            return None
    
    def extract_spotify_artist_data(self, artist_name):
        """Extract comprehensive artist data from Spotify API"""
        spotify_artist = self.search_spotify_artist(artist_name)
        if not spotify_artist:
            return None
        
        # Extract basic artist info
        artist_data = {
            'spotify_id': spotify_artist['id'],
            'name': spotify_artist['name'],
            'popularity': spotify_artist.get('popularity', 0),
            'followers': spotify_artist.get('followers', {}).get('total', 0),
            'genres': spotify_artist.get('genres', []),
            'images': spotify_artist.get('images', []),
            'external_urls': spotify_artist.get('external_urls', {})
        }
        
        # Get best quality image
        if artist_data['images']:
            # Sort by size (largest first)
            sorted_images = sorted(artist_data['images'], key=lambda x: x.get('width', 0), reverse=True)
            artist_data['best_image'] = sorted_images[0]['url']
        else:
            artist_data['best_image'] = None
        
        # Get primary genre
        if artist_data['genres']:
            artist_data['primary_genre'] = artist_data['genres'][0].title()
        else:
            artist_data['primary_genre'] = 'Pop'
        
        # Get audio preview from top tracks
        audio_preview = self.get_spotify_artist_top_tracks(spotify_artist['id'])
        if audio_preview:
            artist_data['audio_preview'] = audio_preview
        
        # Get debut year from albums
        debut_year = self.get_spotify_artist_albums(spotify_artist['id'])
        if debut_year:
            artist_data['debut_year'] = debut_year
        
        return artist_data
    
    def determine_artist_type_from_spotify(self, artist_name, spotify_data):
        """Determine artist type using Spotify data and enhanced logic"""
        name_lower = artist_name.lower()
        
        # 1. Check well-known groups first (most reliable)
        known_groups = {
            'coldplay', 'radiohead', 'u2', 'queen', 'beatles', 'metallica',
            'linkin park', 'green day', 'red hot chili peppers', 'foo fighters',
            'arctic monkeys', 'muse', 'oasis', 'nirvana', 'pearl jam',
            'maroon 5', 'onerepublic', 'imagine dragons', 'twenty one pilots',
            'blackpink', 'red velvet', 'girls generation', 'little mix',
            'pentatonix', 'backstreet boys', 'nsync', 'spice girls',
            'bts', 'twice', 'itzy', 'stray kids', 'seventeen', 'got7',
            'the weeknd'  # Note: The Weeknd is actually solo, remove this
        }
        
        # Remove The Weeknd as it's a solo artist
        known_groups.discard('the weeknd')
        
        # Well-known solo artists that might be confused as groups
        known_solo = {
            'the weeknd', 'future', 'drake', 'eminem', 'kanye west',
            'taylor swift', 'ariana grande', 'billie eilish', 'rihanna',
            'beyoncé', 'lady gaga', 'dua lipa', 'bad bunny', 'j balvin'
        }
        
        if name_lower in known_groups:
            return 'Grup'
        elif name_lower in known_solo:
            return 'Solo'
        
        # 2. Check Spotify genres for group indicators
        genres = spotify_data.get('genres', [])
        genre_text = ' '.join(genres).lower()
        
        # Group genre indicators (bands typically have these genres)
        group_genre_indicators = [
            'rock', 'metal', 'punk', 'indie rock', 'alternative rock',
            'boy band', 'girl group', 'k-pop boy band', 'k-pop girl group'
        ]
        
        # Solo genre indicators
        solo_genre_indicators = [
            'rap', 'hip hop', 'pop', 'r&b', 'soul', 'singer-songwriter',
            'alternative pop', 'dance pop', 'trap'
        ]
        
        # Check genres
        group_genre_match = any(indicator in genre_text for indicator in group_genre_indicators)
        solo_genre_match = any(indicator in genre_text for indicator in solo_genre_indicators)
        
        # 3. Check name patterns for group indicators
        group_name_indicators = [
            # Explicit group words
            'band', 'boys', 'girls', 'brothers', 'sisters', 'family', 'crew', 'squad',
            'collective', 'society', 'union', 'gang', 'posse', 'mob', 'clan',
            'orchestra', 'ensemble', 'choir', 'quartet', 'quintet', 'sextet',
            'duo', 'trio', 'group', 'boyz', 'girlz',
            # Connectors (often indicate groups)
            ' & ', ' and ', ' + ', ' x ', ' vs ', ' feat. ', ' ft. '
        ]
        
        # Solo name indicators
        solo_name_indicators = [
            'lil ', 'young ', 'big ', 'mc ', 'dj ', 'mr. ', 'ms. ', 'sir ',
            'lady ', 'miss '
        ]
        
        name_group_match = any(indicator in name_lower for indicator in group_name_indicators)
        name_solo_match = any(indicator in name_lower for indicator in solo_name_indicators)
        
        # 4. Scoring system to determine type
        group_score = 0
        solo_score = 0
        
        # Name-based scoring (strongest indicator)
        if name_group_match:
            group_score += 3
        if name_solo_match:
            solo_score += 3
        
        # Genre-based scoring
        if group_genre_match:
            group_score += 2
        if solo_genre_match:
            solo_score += 2
        
        # Special cases based on name structure
        words = artist_name.split()
        if len(words) == 1:
            # Single word names are usually solo (Drake, Eminem, etc.)
            solo_score += 1
        elif len(words) >= 3 and not any(word.lower() in ['the', 'a', 'an', 'of', 'and', 'or', 'but'] for word in words):
            # Multiple meaningful words often indicate groups
            group_score += 1
        
        # Names starting with "The" are often groups
        if name_lower.startswith('the '):
            group_score += 2
        
        # K-pop naming patterns
        if any(indicator in name_lower for indicator in ['bts', 'blackpink', 'twice', 'itzy', 'stray kids']):
            group_score += 3
        
        # Make decision based on scores
        if group_score > solo_score:
            return 'Grup'
        elif solo_score > group_score:
            return 'Solo'
        else:
            # If tied, default to Solo (most artists are solo)
            return 'Solo'
    
    def scrape_kworb_rankings(self):
        """Scrape real artist rankings from Kworb.net monthly listeners page"""
        print("🔍 Scraping Kworb.net monthly listeners for real Spotify popularity rankings...")
        
        # Use the monthly listeners page for better popularity rankings
        url = "https://kworb.net/spotify/listeners.html"
        
        try:
            response = self.session.get(url, timeout=30)
            response.raise_for_status()
            
            soup = BeautifulSoup(response.content, 'html.parser')
            
            # Find the table with artist data
            table = soup.find('table')
            if not table:
                print("❌ Could not find artist table on Kworb.net")
                return []
            
            artists = []
            rows = getattr(table, 'find_all', lambda x: [])('tr')[1:]  # Skip header row
            
            for row in rows[:500]:  # Get top 500
                try:
                    cells = getattr(row, 'find_all', lambda x: [])('td')
                    if len(cells) >= 3:  # Ensure we have rank, artist, and listeners columns
                        # Extract rank from first column (usually #1, #2, etc.)
                        rank_text = getattr(cells[0], 'text', '').strip()
                        rank = int(re.sub(r'[^0-9]', '', rank_text)) if rank_text else None
                        
                        # Extract artist name from second column
                        artist_cell = cells[1]
                        artist_link = getattr(artist_cell, 'find', lambda x: None)('a')
                        
                        if artist_link and hasattr(artist_link, 'text'):
                            artist_name = artist_link.text.strip()
                        else:
                            artist_name = getattr(artist_cell, 'text', '').strip()
                        
                        # Extract monthly listeners from third column
                        listeners_text = getattr(cells[2], 'text', '').strip()
                        # Remove commas and extract numeric value
                        listeners = re.sub(r'[^0-9]', '', listeners_text)
                        
                        # Clean up artist name
                        artist_name = re.sub(r'\s+', ' ', artist_name)
                        artist_name = artist_name.replace('[', '').replace(']', '')
                        artist_name = artist_name.strip()
                        
                        if artist_name and len(artist_name) > 1 and rank:
                            artists.append({
                                'rank': rank,
                                'name': artist_name,
                                'monthly_listeners': listeners,
                                'monthly_listeners_formatted': listeners_text
                            })
                            
                            if rank <= 20:  # Show top 20 for verification
                                print(f"#{rank}: {artist_name} ({listeners_text} monthly listeners)")
                                
                except (ValueError, IndexError, AttributeError):
                    # Skip malformed rows
                    continue
                
                # Rate limiting
                if len(artists) % 50 == 0 and len(artists) > 0:
                    print(f"📊 Processed {len(artists)} artists...")
                    time.sleep(1)
            
            # Sort by rank to ensure proper order
            artists.sort(key=lambda x: x['rank'])
            
            print(f"✅ Successfully scraped {len(artists)} artists from Kworb.net monthly listeners")
            print(f"📈 Top artist: #{artists[0]['rank']} {artists[0]['name']} ({artists[0]['monthly_listeners_formatted']})")
            
            return artists
            
        except Exception as e:
            print(f"❌ Error scraping Kworb.net: {e}")
            return []
    
    def get_artist_image_multiple_sources(self, artist_name):
        """Get artist image from multiple sources"""
        print(f"  🖼️  Searching for image: {artist_name}")
        
        # Method 1: Try Spotify web search (no API key needed)
        image_url = self.get_spotify_web_image(artist_name)
        if image_url:
            return {'image_url': image_url, 'source': 'Spotify Web'}
        
        # Method 2: Try Last.fm API (free, no key needed for basic search)
        image_url = self.get_lastfm_image(artist_name)
        if image_url:
            return {'image_url': image_url, 'source': 'Last.fm'}
        
        # Method 3: Try Deezer (has artist images)
        image_url = self.get_deezer_image(artist_name)
        if image_url:
            return {'image_url': image_url, 'source': 'Deezer'}
        
        return None
    
    def get_spotify_web_image(self, artist_name):
        """Get Spotify image by scraping Spotify web player"""
        try:
            # Search on Spotify web
            search_url = f"https://open.spotify.com/search/{quote(artist_name)}/artists"
            
            response = self.session.get(search_url, timeout=10)
            if response.status_code == 200:
                # Look for image URLs in the HTML
                soup = BeautifulSoup(response.content, 'html.parser')
                
                # Find script tags with artist data
                scripts = soup.find_all('script', type='application/json')
                for script in scripts:
                    if artist_name.lower() in script.text.lower():
                        # Extract image URLs from the script content
                        content = script.text
                        # Look for Spotify CDN image URLs
                        image_matches = re.findall(r'https://i\.scdn\.co/image/[^"]+', content)
                        if image_matches:
                            # Return the first high-quality image
                            for url in image_matches:
                                if '640x640' in url or '300x300' in url:
                                    return url
                            return image_matches[0]
                            
        except Exception as e:
            print(f"    ⚠️  Spotify web search failed: {e}")
        
        return None
    
    def get_lastfm_image(self, artist_name):
        """Get artist image from Last.fm API (free)"""
        try:
            # Last.fm API (free tier)
            api_key = "0c61ef5fe31c43dc6d4b2adac79a5e06"  # Public API key for basic search
            url = "http://ws.audioscrobbler.com/2.0/"
            
            params = {
                'method': 'artist.getinfo',
                'artist': artist_name,
                'api_key': api_key,
                'format': 'json'
            }
            
            response = self.session.get(url, params=params, timeout=10)
            if response.status_code == 200:
                data = response.json()
                if 'artist' in data and 'image' in data['artist']:
                    images = data['artist']['image']
                    # Get the largest image
                    for img in reversed(images):
                        if img.get('#text') and img['#text'].strip():
                            return img['#text']
                            
        except Exception as e:
            print(f"    ⚠️  Last.fm search failed: {e}")
        
        return None
    
    def get_deezer_image(self, artist_name):
        """Get artist image from Deezer API"""
        try:
            search_url = "https://api.deezer.com/search/artist"
            params = {'q': artist_name, 'limit': 1}
            
            response = self.session.get(search_url, params=params, timeout=10)
            if response.status_code == 200:
                data = response.json()
                if data.get('data') and len(data['data']) > 0:
                    artist = data['data'][0]
                    # Check if names are similar enough
                    if self.similarity(artist['name'], artist_name) > 0.8:
                        return artist.get('picture_big') or artist.get('picture_medium')
                        
        except Exception as e:
            print(f"    ⚠️  Deezer search failed: {e}")
        
        return None
    
    def get_musicbrainz_metadata(self, artist_name):
        """Get comprehensive artist metadata from MusicBrainz"""
        if artist_name in self.musicbrainz_cache:
            return self.musicbrainz_cache[artist_name]
        
        try:
            print(f"  🎵 MusicBrainz lookup: {artist_name}")
            
            # Search for artist
            search_url = "https://musicbrainz.org/ws/2/artist"
            params = {
                'query': f'artist:"{artist_name}"',
                'fmt': 'json',
                'limit': 5  # Get more results to find better match
            }
            
            response = self.session.get(search_url, params=params, timeout=15)
            if response.status_code == 200:
                data = response.json()
                if data.get('artists'):
                    # Find best match by similarity
                    best_match = None
                    best_score = 0
                    
                    for artist in data['artists']:
                        score = self.similarity(artist['name'], artist_name)
                        if score > best_score and score > 0.75:  # Higher threshold for accuracy
                            best_score = score
                            best_match = artist
                    
                    if best_match:
                        metadata = {
                            'country': best_match.get('country', 'Unknown'),
                            'type': best_match.get('type', 'Unknown'),
                            'gender': self.normalize_gender(best_match.get('gender', 'Unknown')),
                            'begin_year': None,
                            'area': None
                        }
                        
                        # Extract begin year
                        if best_match.get('life-span', {}).get('begin'):
                            try:
                                metadata['begin_year'] = int(best_match['life-span']['begin'][:4])
                            except:
                                pass
                        
                        # Get area information
                        if best_match.get('area', {}).get('name'):
                            metadata['area'] = best_match['area']['name']
                        
                        self.musicbrainz_cache[artist_name] = metadata
                        return metadata
            
            # If no results, cache empty result
            self.musicbrainz_cache[artist_name] = None
            
        except Exception as e:
            print(f"    ⚠️  MusicBrainz failed: {e}")
            self.musicbrainz_cache[artist_name] = None
        
        # Rate limiting for MusicBrainz
        time.sleep(1)
        return None
    
    def normalize_gender(self, gender):
        """Normalize gender from various sources to Turkish"""
        if not gender or gender == 'Unknown':
            return 'Unknown'
        
        gender_lower = gender.lower()
        
        # Male indicators
        if any(indicator in gender_lower for indicator in ['male', 'man', 'boy', 'he', 'him', 'erkek']):
            return 'Erkek'
        
        # Female indicators  
        if any(indicator in gender_lower for indicator in ['female', 'woman', 'girl', 'she', 'her', 'kadın']):
            return 'Kadın'
        
        # Group indicators
        if any(indicator in gender_lower for indicator in ['group', 'band', 'duo', 'trio', 'grup']):
            return 'Grup'
        
        return 'Unknown'
    
    def get_gender_from_name_patterns(self, artist_name):
        """Get gender based on name patterns and known artists"""
        name_lower = artist_name.lower()
        
        # Known male artists
        known_males = {
            'drake', 'eminem', 'kanye west', 'travis scott', 'justin bieber', 
            'ed sheeran', 'the weeknd', 'bad bunny', 'post malone', 'kendrick lamar',
            'j cole', 'lil wayne', 'future', 'gunna', 'lil baby', 'bruno mars',
            'shawn mendes', 'sam smith', 'harry styles', 'maluma', 'ozuna'
        }
        
        # Known female artists
        known_females = {
            'taylor swift', 'ariana grande', 'billie eilish', 'rihanna', 'beyoncé',
            'lady gaga', 'dua lipa', 'lana del rey', 'nicki minaj', 'sza',
            'doja cat', 'halsey', 'katy perry', 'selena gomez', 'sia',
            'adele', 'shakira', 'karol g'
        }
        
        if name_lower in known_males:
            return 'Erkek'
        elif name_lower in known_females:
            return 'Kadın'
        
        # Name pattern indicators
        male_indicators = ['lil ', 'young ', 'big ', 'mc ', 'mr. ', 'sir ']
        female_indicators = ['ms. ', 'miss ', 'lady ']
        
        for indicator in male_indicators:
            if indicator in name_lower:
                return 'Erkek'
                
        for indicator in female_indicators:
            if indicator in name_lower:
                return 'Kadın'
        
        return 'Unknown'

    def get_wikipedia_metadata(self, artist_name):
        """Get additional metadata from Wikipedia with improved gender detection"""
        try:
            # Search Wikipedia
            search_url = "https://en.wikipedia.org/api/rest_v1/page/summary/"
            # Clean artist name for URL
            clean_name = artist_name.replace(' ', '_')
            url = search_url + quote(clean_name)
            
            response = self.session.get(url, timeout=10)
            if response.status_code == 200:
                data = response.json()
                extract = data.get('extract', '').lower()
                
                # Improved gender detection from description
                gender = 'Unknown'
                
                # Strong male indicators
                if any(phrase in extract for phrase in [
                    'he is a', 'he was a', 'he is an', 'he was an',
                    'american rapper', 'canadian rapper', 'male singer',
                    'his debut', 'his career', 'his music'
                ]):
                    gender = 'Erkek'
                
                # Strong female indicators
                elif any(phrase in extract for phrase in [
                    'she is a', 'she was a', 'she is an', 'she was an',
                    'female singer', 'american singer-songwriter',
                    'her debut', 'her career', 'her music'
                ]):
                    gender = 'Kadın'
                
                # Group indicators
                elif any(phrase in extract for phrase in [
                    'is a band', 'are a band', 'is a group', 'are a group',
                    'is a duo', 'is a trio', 'boy band', 'girl group'
                ]):
                    gender = 'Grup'
                
                # Country detection
                country = 'Unknown'
                country_patterns = {
                    'american': 'ABD',
                    'british': 'İngiltere', 
                    'canadian': 'Kanada',
                    'australian': 'Avustralya',
                    'german': 'Almanya',
                    'french': 'Fransa',
                    'italian': 'İtalya',
                    'spanish': 'İspanya',
                    'korean': 'Güney Kore',
                    'japanese': 'Japonya',
                    'swedish': 'İsveç',
                    'irish': 'İrlanda',
                    'dutch': 'Hollanda',
                    'puerto rican': 'Porto Riko',
                    'colombian': 'Kolombiya',
                    'mexican': 'Meksika',
                    'barbadian': 'Barbados'
                }
                
                for pattern, country_name in country_patterns.items():
                    if pattern in extract:
                        country = country_name
                        break
                
                return {'gender': gender, 'country': country, 'extract': extract}
                
        except Exception as e:
            print(f"    ⚠️  Wikipedia lookup failed: {e}")
        
        return {'gender': 'Unknown', 'country': 'Unknown', 'extract': ''}
    
    def get_itunes_preview(self, artist_name):
        """Get real audio preview from iTunes API"""
        try:
            search_url = "https://itunes.apple.com/search"
            params = {
                'term': artist_name,
                'media': 'music',
                'entity': 'song',
                'limit': 10  # Get more results to find best match
            }
            
            response = self.session.get(search_url, params=params, timeout=10)
            if response.status_code == 200:
                data = response.json()
                if data['results']:
                    # Find best matching artist
                    for track in data['results']:
                        artist_match = self.similarity(track.get('artistName', ''), artist_name)
                        if artist_match > 0.7 and track.get('previewUrl'):
                            return {
                                'preview_url': track['previewUrl'],
                                'track_name': track.get('trackName', ''),
                                'album_name': track.get('collectionName', ''),
                                'source': 'iTunes'
                            }
                            
        except Exception as e:
            print(f"    ⚠️  iTunes search failed: {e}")
        
        return None
    
    def get_deezer_preview(self, artist_name):
        """Get real audio preview from Deezer API"""
        try:
            search_url = "https://api.deezer.com/search"
            params = {
                'q': f'artist:"{artist_name}"',
                'limit': 10
            }
            
            response = self.session.get(search_url, params=params, timeout=10)
            if response.status_code == 200:
                data = response.json()
                if data.get('data'):
                    for track in data['data']:
                        artist_match = self.similarity(track.get('artist', {}).get('name', ''), artist_name)
                        if artist_match > 0.7 and track.get('preview'):
                            return {
                                'preview_url': track['preview'],
                                'track_name': track.get('title', ''),
                                'album_name': track.get('album', {}).get('title', ''),
                                'source': 'Deezer'
                            }
                            
        except Exception as e:
            print(f"    ⚠️  Deezer search failed: {e}")
        
        return None

    def get_artist_genre_from_lastfm(self, artist_name):
        """Get artist genre from Last.fm API (no API key needed)"""
        try:
            # Use Last.fm web scraping approach
            search_url = f"https://www.last.fm/music/{quote(artist_name.replace(' ', '+'))}"
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
            }
            
            response = self.session.get(search_url, headers=headers, timeout=10)
            if response.status_code == 200:
                from bs4 import BeautifulSoup
                soup = BeautifulSoup(response.content, 'html.parser')
                
                # Look for genre tags
                genre_tags = soup.find_all('a', {'class': 'tag'})
                if genre_tags:
                    # Get the most popular genre (first one)
                    genre = genre_tags[0].get_text().strip()
                    # Clean and capitalize properly
                    genre = genre.title()
                    print(f"  🎭 Found genre from Last.fm: {genre}")
                    return genre
                    
        except Exception as e:
            print(f"    ⚠️  Last.fm genre lookup failed: {e}")
        
        return None

    def get_genre_from_musicbrainz(self, artist_name):
        """Get artist genre from MusicBrainz tags"""
        try:
            # Search for artist with tags
            search_url = "https://musicbrainz.org/ws/2/artist"
            params = {
                'query': f'artist:"{artist_name}"',
                'fmt': 'json',
                'inc': 'tags',
                'limit': 1
            }
            
            response = self.session.get(search_url, params=params, timeout=15)
            if response.status_code == 200:
                data = response.json()
                if data.get('artists'):
                    artist = data['artists'][0]
                    if self.similarity(artist['name'], artist_name) > 0.8:
                        tags = artist.get('tags', [])
                        if tags:
                            # Get the most voted tag as genre
                            genre_tag = max(tags, key=lambda x: x.get('count', 0))
                            genre = genre_tag['name'].title()
                            print(f"  🎭 Found genre from MusicBrainz: {genre}")
                            return genre
                            
        except Exception as e:
            print(f"    ⚠️  MusicBrainz genre lookup failed: {e}")
        
        time.sleep(1)  # Rate limiting
        return None

    def get_comprehensive_artist_genre(self, artist_name):
        """Get artist genre from multiple sources"""
        # Try MusicBrainz first (most reliable)
        genre = self.get_genre_from_musicbrainz(artist_name)
        if genre:
            return genre
            
        # Try Last.fm as backup
        genre = self.get_artist_genre_from_lastfm(artist_name)
        if genre:
            return genre
            
        # Default genre based on common patterns in artist names
        name_lower = artist_name.lower()
        if any(word in name_lower for word in ['dj', 'electronic', 'techno']):
            return 'Electronic'
        elif any(word in name_lower for word in ['rapper', 'mc', 'lil']):
            return 'Hip Hop'
        elif 'classical' in name_lower or 'orchestra' in name_lower:
            return 'Classical'
        else:
            return 'Pop'  # Final fallback

    def get_artist_debut_year(self, artist_name, mb_metadata=None):
        """Get artist debut/career start year from multiple sources"""
        # First try MusicBrainz begin year (for individual artists)
        if mb_metadata and mb_metadata.get('begin_year'):
            begin_year = mb_metadata['begin_year']
            # For individual artists, assume career started around age 15-25
            if mb_metadata.get('type') != 'Group':
                # Estimate career start (assume they started between ages 15-25)
                estimated_start = begin_year + 18  # Conservative estimate
                if estimated_start <= 2024:  # Reasonable check
                    return estimated_start
            else:
                # For groups, begin_year is likely formation year
                return begin_year
        
        # Try to get formation/career start from Wikipedia
        try:
            search_url = "https://en.wikipedia.org/api/rest_v1/page/summary/"
            clean_name = artist_name.replace(' ', '_')
            url = search_url + quote(clean_name)
            
            response = self.session.get(url, timeout=10)
            if response.status_code == 200:
                data = response.json()
                extract = data.get('extract', '')
                
                # Look for debut year patterns
                import re
                debut_patterns = [
                    r'debut(?:ed)?\s+in\s+(\d{4})',
                    r'started\s+(?:his|her|their)\s+career\s+in\s+(\d{4})',
                    r'formed\s+in\s+(\d{4})',
                    r'began\s+(?:his|her|their)\s+career\s+in\s+(\d{4})',
                    r'first\s+album\s+in\s+(\d{4})',
                    r'career\s+began\s+in\s+(\d{4})',
                    r'active\s+since\s+(\d{4})',
                    r'(\d{4})[-–]\s*present'
                ]
                
                for pattern in debut_patterns:
                    match = re.search(pattern, extract, re.IGNORECASE)
                    if match:
                        year = int(match.group(1))
                        if 1950 <= year <= 2024:  # Reasonable year range
                            print(f"  📅 Found debut year from Wikipedia: {year}")
                            return year
                            
        except Exception as e:
            print(f"    ⚠️  Wikipedia debut year lookup failed: {e}")
        
        # Fallback based on artist popularity era (very rough estimates)
        # This is based on when certain artists typically became popular
        name_lower = artist_name.lower()
        if any(word in name_lower for word in ['lil', 'young', 'big', 'lil\'', '21', '6ix9ine']):
            return 2010  # Modern rap artists
        elif any(word in name_lower for word in ['oldschool', 'classic', 'vintage']):
            return 1980
        else:
            return 2000  # Conservative default

    def get_improved_artist_type(self, artist_name, mb_metadata=None, wiki_metadata=None):
        """Improved artist type detection using multiple sources"""
        name_lower = artist_name.lower()
        
        # First check MusicBrainz (most reliable)
        if mb_metadata and mb_metadata.get('type'):
            mb_type = mb_metadata['type']
            if mb_type == 'Group':
                return 'Grup'
            elif mb_type == 'Person':
                return 'Solo'
        
        # Check Wikipedia text for clearer indicators
        if wiki_metadata and 'extract' in wiki_metadata:
            extract = wiki_metadata['extract'].lower()
            if any(phrase in extract for phrase in ['is a band', 'are a band', 'is a group', 'are a group', 'is a duo', 'is a trio']):
                return 'Grup'
            elif any(phrase in extract for phrase in ['is a singer', 'is a rapper', 'is an artist', 'is a musician']) and 'band' not in extract:
                return 'Solo'
        
        # Enhanced group detection based on name patterns
        group_indicators = [
            # Clear group words
            'band', 'boys', 'girls', 'brothers', 'sisters', 'family', 'crew', 'squad',
            'collective', 'society', 'union', 'gang', 'posse', 'mob', 'clan',
            
            # Musical group types
            'orchestra', 'ensemble', 'choir', 'quartet', 'quintet', 'sextet',
            'duo', 'trio', 'group',
            
            # Modern group indicators
            'boyz', 'girlz', 'bts', 'nct', 'exo', 'got7', 'twice', 'itzy',
            
            # And (&) indicators - often groups
            ' & ', ' and ', '+', 'feat.', 'ft.'
        ]
        
        # Check for group indicators in name
        for indicator in group_indicators:
            if indicator in name_lower:
                return 'Grup'
        
        # Special cases for well-known groups that might not have obvious indicators
        known_groups = {
            'coldplay', 'radiohead', 'u2', 'queen', 'beatles', 'metallica', 
            'linkin park', 'green day', 'red hot chili peppers', 'foo fighters',
            'arctic monkeys', 'muse', 'oasis', 'nirvana', 'pearl jam',
            'maroon 5', 'onerepublic', 'imagine dragons', 'twenty one pilots',
            'blackpink', 'red velvet', 'girls generation', 'little mix',
            'pentatonix', 'backstreet boys', 'nsync', 'spice girls'
        }
        
        if name_lower in known_groups:
            return 'Grup'
        
        # Check for multiple capitalized words (often indicates groups)
        words = artist_name.split()
        if len(words) >= 2:
            capitalized_words = [w for w in words if w[0].isupper() if w]
            if len(capitalized_words) >= 2 and not any(word.lower() in ['the', 'a', 'an', 'of', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'by', 'with'] for word in words):
                # Could be a group, but be more conservative
                if len(words) >= 3:
                    return 'Grup'
        
        # Default to Solo for single names or unclear cases
        return 'Solo'

    def classify_artist_type(self, artist_name, metadata=None):
        """Determine if artist is Solo or Group"""
        name_lower = artist_name.lower()
        
        # Group indicators
        group_keywords = [
            'band', 'boys', 'girls', 'collective', 'crew', 'squad', 'family',
            'gang', 'society', 'union', 'brothers', 'sisters', 'group',
            'orchestra', 'ensemble', 'choir', 'duo', 'trio', 'quartet'
        ]
        
        # Check if any group keyword is in the name
        if any(keyword in name_lower for keyword in group_keywords):
            return 'Grup'
        
        # Check MusicBrainz data
        if metadata and metadata.get('type') == 'Group':
            return 'Grup'
        
        # Multi-word names might be groups (with some exceptions)
        words = artist_name.split()
        if len(words) > 2 and not any(word.lower() in ['the', 'a', 'an', 'of', 'and', '&'] for word in words):
            return 'Grup'
        
        return 'Solo'
    
    def process_all_artists(self, limit=None):
        """Main method to process all artists with Spotify API priority"""
        print("🚀 Starting Spotify-priority artist data collection...")
        
        # Step 1: Get real rankings from Kworb.net
        kworb_artists = self.scrape_kworb_rankings()
        if not kworb_artists:
            print("❌ Failed to get artist rankings. Exiting.")
            return []

        if limit:
            kworb_artists = kworb_artists[:limit]
            print(f"🔢 Limited to {limit} artists for testing")
        
        print(f"\n📊 Processing {len(kworb_artists)} artists...")
        processed_artists = []
        
        for i, kworb_artist in enumerate(kworb_artists, 1):
            artist_name = kworb_artist['name']
            print(f"\n🎵 Processing #{i}: {artist_name}")
            
            # Initialize artist data
            artist_data = {
                'isim': artist_name,
                'populerlik': kworb_artist['rank'],  # Real popularity ranking from Kworb monthly listeners (1 = most popular)
                'monthly_listeners': kworb_artist['monthly_listeners'],
                'monthly_listeners_formatted': kworb_artist['monthly_listeners_formatted']
            }
            
            # PRIORITY: Get comprehensive data from Spotify API
            spotify_data = self.extract_spotify_artist_data(artist_name)
            
            if spotify_data:
                print(f"  ✅ Found on Spotify: {spotify_data['name']}")
                
                # Use Spotify data as primary source
                artist_data['spotify_id'] = spotify_data['spotify_id']
                artist_data['spotify_followers'] = spotify_data['followers']
                # Note: Using Kworb ranking as populerlik, not Spotify's internal popularity score
                
                # Genre from Spotify (primary)
                artist_data['genre'] = spotify_data['primary_genre']
                artist_data['spotify_genres'] = spotify_data['genres']
                print(f"  🎭 Genre from Spotify: {artist_data['genre']}")
                
                # Image from Spotify (primary)
                if spotify_data['best_image']:
                    artist_data['resim_url'] = spotify_data['best_image']
                    artist_data['image_source'] = 'Spotify'
                    print(f"  🖼️  Image from Spotify")
                
                # Audio preview from Spotify (primary)
                if spotify_data.get('audio_preview'):
                    preview = spotify_data['audio_preview']
                    artist_data['audio_preview_url'] = preview['preview_url']
                    artist_data['preview_track'] = preview['track_name']
                    artist_data['preview_album'] = preview['album_name']
                    artist_data['preview_source'] = 'Spotify'
                    artist_data['track_popularity'] = preview['popularity']
                    print(f"  ✅ Audio preview from Spotify: {preview['track_name']}")
                
                # Debut year from Spotify (if available)
                if spotify_data.get('debut_year'):
                    artist_data['cikis_yili'] = spotify_data['debut_year']
                    print(f"  📅 Debut year from Spotify: {artist_data['cikis_yili']}")
                
                # Determine artist type from Spotify genres and name
                artist_data['tip'] = self.determine_artist_type_from_spotify(artist_name, spotify_data)
                print(f"  👤 Artist type: {artist_data['tip']}")
                
            else:
                print(f"  ⚠️  Not found on Spotify, using fallback methods")
                
                # Fallback to old methods
                artist_data['genre'] = self.get_comprehensive_artist_genre(artist_name)
                artist_data['tip'] = 'Solo'  # Default fallback
                
                # Get image from alternative sources
                image_data = self.get_artist_image_multiple_sources(artist_name)
                if image_data:
                    artist_data['resim_url'] = image_data['image_url']
                    artist_data['image_source'] = image_data['source']
                    print(f"  ✅ Got image from {image_data['source']}")
                
                # Get audio preview from alternative sources
                audio_data = self.get_itunes_preview(artist_name)
                if not audio_data:
                    audio_data = self.get_deezer_preview(artist_name)
                
                if audio_data:
                    artist_data['audio_preview_url'] = audio_data['preview_url']
                    artist_data['preview_track'] = audio_data['track_name']
                    artist_data['preview_album'] = audio_data['album_name']
                    artist_data['preview_source'] = audio_data['source']
                    print(f"  ✅ Got {audio_data['source']} preview: {audio_data['track_name']}")
            
            # FALLBACK: Get data that Spotify doesn't provide (country, gender)
            mb_metadata = self.get_musicbrainz_metadata(artist_name)
            wiki_metadata = self.get_wikipedia_metadata(artist_name)
            
            # Gender detection with multiple fallbacks and validation
            gender = 'Unknown'
            
            # 1. Try name-based patterns first (most reliable for known artists)
            gender = self.get_gender_from_name_patterns(artist_name)
            
            # 2. If unknown, try MusicBrainz
            if gender == 'Unknown' and mb_metadata and mb_metadata.get('gender') != 'Unknown':
                gender = mb_metadata['gender']
            
            # 3. If still unknown, try Wikipedia
            if gender == 'Unknown' and wiki_metadata.get('gender') != 'Unknown':
                gender = wiki_metadata['gender']
            
            # 4. Final validation - check if result makes sense
            if gender == 'Grup' and artist_data.get('tip') == 'Solo':
                gender = 'Unknown'  # Inconsistent, reset to unknown
            elif gender in ['Erkek', 'Kadın'] and artist_data.get('tip') == 'Grup':
                # If we have individual gender but marked as group, trust the gender more
                print(f"  ⚠️  Inconsistency detected: Individual gender ({gender}) but marked as Grup")
                # Keep the gender, but reconsider the artist type
                if artist_name.lower() not in ['bts', 'blackpink', 'twice', 'itzy']:  # Keep obvious groups as groups
                    artist_data['tip'] = 'Solo'
                    print(f"  🔄 Updated artist type to Solo based on individual gender")
            
            artist_data['cinsiyet'] = gender
            print(f"  👥 Gender: {gender}")
            
            # Country detection (prioritize MusicBrainz, then Wikipedia)
            country = 'Unknown'
            if mb_metadata:
                country = mb_metadata.get('country') or mb_metadata.get('area', 'Unknown')
            
            if country == 'Unknown' and wiki_metadata.get('country') != 'Unknown':
                country = wiki_metadata['country']
            
            artist_data['ulke'] = country
            print(f"  🌍 Country: {country}")
            
            # If we don't have debut year from Spotify, use fallback
            if 'cikis_yili' not in artist_data:
                artist_data['cikis_yili'] = self.get_artist_debut_year(artist_name, mb_metadata)
                print(f"  📅 Debut year (fallback): {artist_data['cikis_yili']}")
            
            # Fallback for missing data
            if 'resim_url' not in artist_data or not artist_data['resim_url']:
                image_data = self.get_artist_image_multiple_sources(artist_name)
                if image_data:
                    artist_data['resim_url'] = image_data['image_url']
                    artist_data['image_source'] = image_data['source']
                    print(f"  ✅ Got fallback image from {image_data['source']}")
                else:
                    artist_data['resim_url'] = None
                    print(f"  ⚠️  No image found")
            
            if 'audio_preview_url' not in artist_data or not artist_data['audio_preview_url']:
                audio_data = self.get_itunes_preview(artist_name)
                if not audio_data:
                    audio_data = self.get_deezer_preview(artist_name)
                
                if audio_data:
                    artist_data['audio_preview_url'] = audio_data['preview_url']
                    artist_data['preview_track'] = audio_data['track_name']
                    artist_data['preview_album'] = audio_data['album_name']
                    artist_data['preview_source'] = audio_data['source']
                    print(f"  ✅ Got fallback {audio_data['source']} preview: {audio_data['track_name']}")
                else:
                    artist_data['audio_preview_url'] = None
                    print(f"  ⚠️  No audio preview found")
            
            processed_artists.append(artist_data)
            
            # Progress and rate limiting
            if i % 5 == 0:
                print(f"\n📈 Progress: {i}/{len(kworb_artists)} artists processed")
                time.sleep(2)  # Shorter delay with Spotify API
            else:
                time.sleep(1)  # Respectful delay between requests
        
        print(f"\n✅ Successfully processed {len(processed_artists)} artists!")
        return processed_artists
    
    def save_to_json(self, artists_data, filename='spotify_priority_artists_data.json'):
        """Save the Spotify-priority artist data to JSON file"""
        try:
            with open(filename, 'w', encoding='utf-8') as f:
                json.dump(artists_data, f, ensure_ascii=False, indent=2)
            print(f"💾 Spotify-priority data saved to {filename}")
            
            # Print detailed statistics
            total_artists = len(artists_data)
            with_images = len([a for a in artists_data if a.get('resim_url')])
            with_audio = len([a for a in artists_data if a.get('audio_preview_url')])
            with_gender = len([a for a in artists_data if a.get('cinsiyet') != 'Unknown'])
            with_country = len([a for a in artists_data if a.get('ulke') != 'Unknown'])
            with_real_genre = len([a for a in artists_data if a.get('genre') != 'Pop'])
            with_real_debut = len([a for a in artists_data if a.get('cikis_yili') != 2000])
            
            # Spotify-specific statistics
            spotify_found = len([a for a in artists_data if a.get('spotify_id')])
            spotify_images = len([a for a in artists_data if a.get('image_source') == 'Spotify'])
            spotify_audio = len([a for a in artists_data if a.get('preview_source') == 'Spotify'])
            spotify_genres = len([a for a in artists_data if a.get('spotify_genres')])
            
            # Monthly listeners statistics
            with_monthly_listeners = len([a for a in artists_data if a.get('monthly_listeners')])
            top_5_artists = artists_data[:5] if len(artists_data) >= 5 else artists_data
            
            print(f"\n📊 Spotify-Priority Statistics:")
            print(f"   Total artists: {total_artists}")
            print(f"   📈 Kworb monthly listeners rankings: {with_monthly_listeners} ({with_monthly_listeners/total_artists*100:.1f}%)")
            print(f"   Found on Spotify: {spotify_found} ({spotify_found/total_artists*100:.1f}%)")
            print(f"   Images from Spotify: {spotify_images} ({spotify_images/total_artists*100:.1f}%)")
            print(f"   Audio previews from Spotify: {spotify_audio} ({spotify_audio/total_artists*100:.1f}%)")
            print(f"   Genres from Spotify: {spotify_genres} ({spotify_genres/total_artists*100:.1f}%)")
            print(f"   Total with images: {with_images} ({with_images/total_artists*100:.1f}%)")
            print(f"   Total with audio previews: {with_audio} ({with_audio/total_artists*100:.1f}%)")
            print(f"   With gender info: {with_gender} ({with_gender/total_artists*100:.1f}%)")
            print(f"   With country info: {with_country} ({with_country/total_artists*100:.1f}%)")
            print(f"   With accurate debut years: {with_real_debut} ({with_real_debut/total_artists*100:.1f}%)")
            
            print(f"\n🏆 Top 5 Artists by Monthly Listeners:")
            for artist in top_5_artists:
                listeners = artist.get('monthly_listeners_formatted', 'N/A')
                ranking = artist.get('populerlik', 'N/A')
                print(f"   #{ranking}: {artist['isim']} ({listeners} monthly listeners)")
            
        except Exception as e:
            print(f"❌ Error saving to JSON: {e}")

def main():
    """Main function to run the Spotify-priority data fetcher"""
    print("🎵 Spotify-Priority Artist Data Fetcher")
    print("=" * 60)
    print("This version prioritizes Spotify API data including:")
    print("✅ PRIMARY: Spotify genres, images, audio previews, popularity")
    print("✅ FALLBACK: MusicBrainz/Wikipedia for missing data")
    print("✅ Real gender and country information")
    print("✅ Accurate popularity rankings from Kworb.net monthly listeners")
    print()
    
    fetcher = SpotifyPriorityArtistDataFetcher()
    
    # Ask user if they want to test with limited artists first
    print("🧪 Would you like to test with a small number of artists first?")
    test_response = input("Test with 10 artists? (y/N): ").strip().lower()
    
    if test_response in ['y', 'yes']:
        print("\n🧪 Testing with first 10 artists...")
        artists_data = fetcher.process_all_artists(limit=10)
        if artists_data:
            fetcher.save_to_json(artists_data, 'test_spotify_artists.json')
            print(f"\n✅ Test completed! Check 'test_spotify_artists.json'")
            
            # Ask if user wants to continue with full dataset
            full_response = input("\nContinue with all ~500 artists? (y/N): ").strip().lower()
            if full_response in ['y', 'yes']:
                print("\n🚀 Processing all artists...")
                artists_data = fetcher.process_all_artists()
                if artists_data:
                    fetcher.save_to_json(artists_data)
    else:
        print("\n🚀 Processing all artists...")
        artists_data = fetcher.process_all_artists()
        if artists_data:
            fetcher.save_to_json(artists_data)
    
    print("\n🎉 Spotify-priority data collection completed!")

if __name__ == "__main__":
    main() 