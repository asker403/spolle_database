//
//  LanguageSelectionView.swift
//  Spolle
//
//  Created by Kiro on 7/23/25.
//

import SwiftUI

struct LanguageSelectionView: View {
    @ObservedObject private var languageManager = LanguageManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var isDropdownExpanded = false
    @State private var selectedLanguage: Language
    
    init() {
        _selectedLanguage = State(initialValue: LanguageManager.shared.currentLanguage)
    }
    
    var filteredLanguages: [Language] {
        if searchText.isEmpty {
            return Language.allCases.filter { $0 != selectedLanguage }
        } else {
            return Language.allCases.filter { language in
                language != selectedLanguage &&
                (language.rawValue.localizedCaseInsensitiveContains(searchText) ||
                 language.code.localizedCaseInsensitiveContains(searchText))
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "globe")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                        .padding(.top, 10)
                    
                    Text(languageManager.localizedString(for: "select_language"))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 24)
                
                VStack(spacing: 20) {
                    // Current Language Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Current Language")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        
                        CurrentLanguageCard(language: selectedLanguage)
                    }
                    .padding(.horizontal, 20)
                    
                    // Search and Dropdown Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Available Languages")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        
                        // Search Field with Dropdown
                        VStack(spacing: 0) {
                            // Search Input
                            HStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 16))
                                
                                TextField("Search languages...", text: $searchText)
                                    .font(.system(size: 16))
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            isDropdownExpanded = true
                                        }
                                    }
                                
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isDropdownExpanded.toggle()
                                    }
                                }) {
                                    Image(systemName: isDropdownExpanded ? "chevron.up" : "chevron.down")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 14, weight: .medium))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(isDropdownExpanded ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1)
                                    )
                            )
                            
                            // Dropdown List
                            if isDropdownExpanded {
                                VStack(spacing: 0) {
                                    Divider()
                                        .padding(.horizontal, 16)
                                    
                                    ScrollView {
                                        LazyVStack(spacing: 0) {
                                            ForEach(filteredLanguages) { language in
                                                LanguageDropdownItem(
                                                    language: language,
                                                    searchText: searchText
                                                ) {
                                                    selectLanguage(language)
                                                }
                                                
                                                if language != filteredLanguages.last {
                                                    Divider()
                                                        .padding(.horizontal, 16)
                                                }
                                            }
                                        }
                                    }
                                    .frame(maxHeight: 300)
                                }
                                .background(Color(.systemGray6))
                                .clipShape(
                                    RoundedRectangle(cornerRadius: 12)
                                        .path(in: CGRect(x: 0, y: 0, width: 1000, height: 1000))
                                )
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
                
                // Done Button
                Button(action: {
                    dismiss()
                }) {
                    Text(languageManager.localizedString(for: "done"))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue, Color.blue.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
            .background(Color(.systemBackground))
            .navigationTitle(languageManager.localizedString(for: "language"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(languageManager.localizedString(for: "done")) {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            .onTapGesture {
                // Close dropdown when tapping outside
                withAnimation(.easeInOut(duration: 0.2)) {
                    isDropdownExpanded = false
                }
            }
        }
    }
    
    private func selectLanguage(_ language: Language) {
        selectedLanguage = language
        languageManager.currentLanguage = language
        searchText = ""
        
        withAnimation(.easeInOut(duration: 0.2)) {
            isDropdownExpanded = false
        }
    }
}

struct CurrentLanguageCard: View {
    let language: Language
    
    var body: some View {
        HStack(spacing: 16) {
            // Flag
            Text(language.flag)
                .font(.system(size: 28))
            
            // Language Info
            VStack(alignment: .leading, spacing: 4) {
                Text(language.rawValue)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(language.code.uppercased())
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Current indicator
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.green)
                
                Text("Current")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1.5)
                )
        )
    }
}

struct LanguageDropdownItem: View {
    let language: Language
    let searchText: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Flag
                Text(language.flag)
                    .font(.system(size: 24))
                
                // Language Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.rawValue)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(language.code.uppercased())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Arrow indicator
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            Rectangle()
                .fill(Color.blue.opacity(0.05))
                .opacity(0)
        )
        .onHover { isHovered in
            // Add hover effect for better UX
        }
    }
}

#Preview {
    LanguageSelectionView()
}