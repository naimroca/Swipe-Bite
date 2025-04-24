//
//  IngredientsInputView.swift
//  MoodMeal
//
//  Created by Naím Rodriguez Caballero on 21.04.25.
//

import SwiftUI

struct IngredientsInputView: View {
    @State private var newIngredient = ""
    @State private var ingredients: [String] = []
    @State private var showSuggestions = false
    @State private var suggestedIngredients: [String] = []
    @State private var showingPantryIngredients = false
    @ObservedObject var recipeManager: RecipeManager
    @ObservedObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode
    
    // Common ingredients for suggestions
    private let commonIngredients = [
        "Kartoffeln", "Zwiebeln", "Karotten", "Tomaten", "Reis", "Nudeln",
        "Hühnchen", "Rind", "Schwein", "Lamm", "Tofu", "Kichererbsen",
        "Brokkoli", "Blumenkohl", "Spinat", "Knoblauch", "Paprika", "Zucchini",
        "Aubergine", "Pilze", "Eier", "Milch", "Käse", "Joghurt", "Sahne",
        "Butter", "Olivenöl", "Salz", "Pfeffer", "Zucker", "Mehl"
    ]
    
    // Filtere nur unbenutzte Vorrats-Zutaten
    private var availablePantryIngredients: [PantryIngredient] {
        guard let pantryIngredients = authManager.user?.pantryIngredients else {
            return []
        }
        
        return pantryIngredients.filter { !$0.isUsed }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.orange.opacity(0.1).ignoresSafeArea()
                
                VStack {
                    // Header
                    Text("Zutaten eingeben")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.top, 30)
                    
                    Text("Gib die Zutaten ein, die du verwenden möchtest")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Vorratskammer-Button
                    if !availablePantryIngredients.isEmpty {
                        Button(action: {
                            showingPantryIngredients.toggle()
                        }) {
                            HStack {
                                Image(systemName: "cabinet")
                                Text("Aus Vorratskammer hinzufügen (\(availablePantryIngredients.count))")
                            }
                            .padding()
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(10)
                        }
                        .padding(.top)
                        
                        if showingPantryIngredients {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(availablePantryIngredients) { ingredient in
                                        Button(action: {
                                            addIngredient(ingredient.name)
                                            authManager.markIngredientAsUsed(ingredientId: ingredient.id, isUsed: true)
                                        }) {
                                            HStack {
                                                Text(ingredient.name)
                                                Image(systemName: "plus.circle")
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.white)
                                            .foregroundColor(.orange)
                                            .cornerRadius(15)
                                            .shadow(radius: 1)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .frame(height: 60)
                            .padding(.top, 5)
                        }
                    }
                    
                    // Input field
                    HStack {
                        TextField("Zutat hinzufügen", text: $newIngredient, onCommit: {
                            addIngredient(newIngredient)
                        })
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 1)
                        .onChange(of: newIngredient) { value in
                            if value.isEmpty {
                                showSuggestions = false
                            } else {
                                suggestedIngredients = commonIngredients.filter { $0.lowercased().contains(value.lowercased()) }
                                showSuggestions = !suggestedIngredients.isEmpty
                            }
                        }
                        
                        Button(action: {
                            addIngredient(newIngredient)
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.orange)
                                .font(.title2)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Suggestions
                    if showSuggestions {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(suggestedIngredients.prefix(5), id: \.self) { suggestion in
                                    Button(action: {
                                        addIngredient(suggestion)
                                    }) {
                                        Text(suggestion)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.orange.opacity(0.2))
                                            .foregroundColor(.orange)
                                            .cornerRadius(15)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(height: 50)
                    }
                    
                    // Selected ingredients
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Deine Zutaten")
                                .font(.headline)
                                .padding(.horizontal)
                                .padding(.top)
                            
                            if ingredients.isEmpty {
                                Text("Noch keine Zutaten hinzugefügt")
                                    .foregroundColor(.gray)
                                    .italic()
                                    .padding(.horizontal)
                            } else {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                    ForEach(ingredients, id: \.self) { ingredient in
                                        IngredientBubble(ingredient: ingredient) {
                                            ingredients.removeAll { $0 == ingredient }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.top)
                    
                    Spacer()
                    
                    // Action buttons
                    VStack {
                        // Rezepte suchen
                        Button(action: {
                            recipeManager.fetchRecipes(withIngredients: ingredients)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Rezepte suchen")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(!ingredients.isEmpty ? Color.orange : Color.gray)
                                .cornerRadius(10)
                        }
                        .disabled(ingredients.isEmpty)
                        
                        // In Vorratskammer speichern
                        Button(action: {
                            saveIngredientsToPantry()
                        }) {
                            Text("Zur Vorratskammer hinzufügen")
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .shadow(radius: 1)
                        }
                        .disabled(ingredients.isEmpty)
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitle("Zutaten", displayMode: .inline)
            .navigationBarItems(leading: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.orange)
            })
        }
    }
    
    private func addIngredient(_ ingredientName: String) {
        let ingredient = ingredientName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !ingredient.isEmpty && !ingredients.contains(ingredient) {
            ingredients.append(ingredient)
            newIngredient = ""
            showSuggestions = false
        }
    }
    
    private func saveIngredientsToPantry() {
        for ingredientName in ingredients {
            let pantryIngredient = PantryIngredient(name: ingredientName)
            authManager.addToPantry(ingredient: pantryIngredient)
        }
        
        // Bestätigungsmeldung hier hinzufügen, wenn gewünscht
        ingredients = []
    }
}

struct IngredientBubble: View {
    let ingredient: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            Text(ingredient)
                .lineLimit(1)
            
            Spacer(minLength: 4)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.orange.opacity(0.8))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.orange, lineWidth: 1)
        )
        .cornerRadius(20)
    }
} 