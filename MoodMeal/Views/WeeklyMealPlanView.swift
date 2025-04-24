//
//  WeeklyMealPlanView.swift
//  MoodMeal
//
//  Created by Naím Rodriguez Caballero on 21.04.25.
//

import SwiftUI

struct WeeklyMealPlanView: View {
    @ObservedObject var authManager: AuthManager
    @State private var weeklyPlan: [String: [CookedRecipe]] = [:]
    @State private var selectedRecipe: Recipe?
    
    // Wochentagsreihenfolge für die Anzeige
    private let weekdayOrder = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]
    
    // Sortierte Wochentage basierend auf der vorgegebenen Reihenfolge
    private var sortedDays: [String] {
        let days = Array(weeklyPlan.keys)
        return weekdayOrder.filter { days.contains($0) }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.orange.opacity(0.1).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Überschrift und Beschreibung
                        Text("Hier siehst du, was du in dieser Woche gekocht hast")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                        
                        // Falls keine Rezepte gekocht wurden
                        if weeklyPlan.isEmpty {
                            VStack(spacing: 15) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray.opacity(0.6))
                                
                                Text("Keine gekochten Rezepte in dieser Woche")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                
                                Text("Wähle ein Rezept und tippe auf 'Heute kochen', um es deinem Wochenplan hinzuzufügen")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        } else {
                            // Anzeige der Wochentagsabschnitte
                            ForEach(sortedDays, id: \.self) { day in
                                if let recipes = weeklyPlan[day] {
                                    Section(header: dayHeader(day)) {
                                        ForEach(recipes) { recipe in
                                            RecipePreviewCard(recipe: recipe)
                                                .onTapGesture {
                                                    // Hier könnte man das vollständige Rezept aus der Firestore laden
                                                    print("Tippe auf gekochtes Rezept: \(recipe.recipeName)")
                                                }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Wochenplan")
            .onAppear {
                loadWeeklyPlan()
            }
        }
    }
    
    private func loadWeeklyPlan() {
        weeklyPlan = authManager.getWeeklyMealPlan()
    }
    
    private func dayHeader(_ day: String) -> some View {
        HStack {
            Text(day)
                .font(.headline)
                .foregroundColor(.orange)
            
            Spacer()
            
            if let recipes = weeklyPlan[day], !recipes.isEmpty {
                Text("\(recipes.count) Rezept\(recipes.count > 1 ? "e" : "")")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.8))
    }
}

struct RecipePreviewCard: View {
    let recipe: CookedRecipe
    
    var body: some View {
        HStack(spacing: 15) {
            // Rezeptbild oder Platzhalter
            if let imageURL = recipe.imageURL, !imageURL.isEmpty {
                AsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Image(systemName: "fork.knife")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                    .frame(width: 80, height: 80)
                    .background(Color.orange.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            // Rezeptinfos
            VStack(alignment: .leading, spacing: 5) {
                Text(recipe.recipeName)
                    .font(.headline)
                    .lineLimit(1)
                
                Text("Gekocht am \(recipe.formattedDate)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}

struct WeeklyMealPlanView_Previews: PreviewProvider {
    static var previews: some View {
        WeeklyMealPlanView(authManager: AuthManager())
    }
} 