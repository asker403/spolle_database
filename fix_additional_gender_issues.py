#!/usr/bin/env python3
"""
Script to fix additional gender inconsistencies in spotify_priority_artists_data.json

This script fixes women artists that are incorrectly marked as "Man"
"""

import json
import re

def fix_additional_gender_inconsistencies():
    # List of additional women artists that are incorrectly marked as "Man"
    additional_women_artists = [
        "Whitney Houston",
        "Christina Aguilera"
    ]
    
    file_path = "swiftdb/spotify_priority_artists_data.json"
    
    # Read the file
    with open(file_path, 'r', encoding='utf-8') as file:
        content = file.read()
    
    # Count fixes
    fixes_made = 0
    
    # Fix each woman artist
    for artist in additional_women_artists:
        # Create pattern to match the specific artist entry
        pattern = rf'(\s*"isim": "{re.escape(artist)}",\s*\n[^}}]*"cinsiyet": "Man")'
        replacement = r'\1'.replace('"cinsiyet": "Man"', '"cinsiyet": "Woman"')
        
        # Count how many matches we find
        matches = re.findall(pattern, content)
        if matches:
            content = re.sub(pattern, replacement, content)
            fixes_made += len(matches)
            print(f"Fixed: {artist} - changed from 'Man' to 'Woman'")
        else:
            print(f"Warning: Could not find {artist} with 'Man' gender")
    
    # Write the fixed content back to the file
    with open(file_path, 'w', encoding='utf-8') as file:
        file.write(content)
    
    print(f"\nTotal additional fixes made: {fixes_made}")
    return fixes_made

if __name__ == "__main__":
    fix_additional_gender_inconsistencies() 