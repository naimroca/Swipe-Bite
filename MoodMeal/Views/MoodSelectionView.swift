//
//  MoodSelectionView.swift
//  MoodMeal
//
//  Created by Naím Rodriguez Caballero on 21.04.25.
//

import SwiftUI

struct MoodSelectionView: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedMood: Mood?
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.orange.opacity(0.1).ignoresSafeArea()
                
                VStack {
                    Text("Wie fühlst du dich heute?")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.top, 30)
                    
                    Text("Wähle deine aktuelle Stimmung, um passende Gerichte zu erhalten")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    
                    LazyVGrid(columns: columns, spacing: 30) {
                        ForEach(Mood.allCases) { mood in
                            MoodCard(mood: mood, isSelected: selectedMood == mood)
                                .onTapGesture {
                                    selectedMood = mood
                                }
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    Button(action: {
                        if let mood = selectedMood {
                            authManager.updateMood(mood: mood)
                            presentationMode.wrappedValue.dismiss()
                        }
                    }) {
                        Text("Bestätigen")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedMood != nil ? Color.orange : Color.gray)
                            .cornerRadius(10)
                    }
                    .disabled(selectedMood == nil)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitle("Stimmungsauswahl", displayMode: .inline)
            .navigationBarItems(leading: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.orange)
            })
            .onAppear {
                selectedMood = authManager.user?.currentMood
            }
        }
    }
}

struct MoodCard: View {
    let mood: Mood
    let isSelected: Bool
    
    var body: some View {
        VStack {
            Image(systemName: mood.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .foregroundColor(isSelected ? .white : .orange)
                .padding(20)
                .background(isSelected ? Color.orange : Color.white)
                .clipShape(Circle())
                .shadow(radius: 3)
            
            Text(mood.rawValue)
                .font(.headline)
                .foregroundColor(isSelected ? .orange : .primary)
                .padding(.top, 8)
            
            Text(mood.recommendedFoodTypes.joined(separator: ", "))
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .frame(height: 40)
                .padding(.horizontal, 5)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white)
                .shadow(color: isSelected ? Color.orange.opacity(0.3) : Color.gray.opacity(0.2), radius: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
        )
    }
} 