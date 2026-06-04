//
//  RatingPromptView.swift
//  Spolle
//
//  Created by Kiro on 7/23/25.
//

import SwiftUI

struct RatingPromptView: View {
    @ObservedObject private var languageManager = LanguageManager.shared
    @ObservedObject private var ratingManager = AppRatingManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            // Rating prompt card
            VStack(spacing: 24) {
                // Icon and title
                VStack(spacing: 16) {
                    // App icon or star icon
                    Image(systemName: "star.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.yellow)
                        .shadow(color: .yellow.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    VStack(spacing: 8) {
                        Text(languageManager.localizedString(for: "enjoying_spolle"))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        Text(languageManager.localizedString(for: "rate_us_description"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                }
                
                // Action buttons
                VStack(spacing: 12) {
                    // Rate button
                    Button(action: {
                        ratingManager.requestAppStoreRating()
                        dismiss()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 16))
                            Text(languageManager.localizedString(for: "rate_spolle"))
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue, Color.blue.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    
                    // Maybe later button
                    Button(action: {
                        ratingManager.userDeclinedRating()
                        dismiss()
                    }) {
                        Text(languageManager.localizedString(for: "maybe_later"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 40)
            .scaleEffect(1.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: true)
        }
    }
}

#Preview {
    RatingPromptView()
}