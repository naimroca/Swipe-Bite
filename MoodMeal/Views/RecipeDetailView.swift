//
//  RecipeDetailView.swift
//  MoodMeal
//
//  Created by Naím Rodriguez Caballero on 21.04.25.
//

import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe
    @State private var isFavorite: Bool
    let onFavoriteToggle: (Bool) -> Void
    @ObservedObject var authManager: AuthManager
    @State private var showingCookConfirmation = false
    @Environment(\.presentationMode) var presentationMode
    
    init(recipe: Recipe, isFavorite: Bool, authManager: AuthManager, onFavoriteToggle: @escaping (Bool) -> Void) {
        self.recipe = recipe
        self._isFavorite = State(initialValue: isFavorite)
        self.authManager = authManager
        self.onFavoriteToggle = onFavoriteToggle
    }
    
    // Berechne, welche Zutaten fehlen
    private var missingIngredients: [String] {
        guard let pantry = authManager.user?.pantryIngredients else { return recipe.ingredients }
        
        let pantryNames = pantry
            .filter { !$0.isUsed }
            .map { $0.name.lowercased() }
        
        return recipe.ingredients.filter { ingredient in
            !pantryNames.contains { pantryItem in
                ingredient.lowercased().contains(pantryItem) || 
                pantryItem.contains(ingredient.lowercased())
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Recipe image or placeholder
                if let imageURL = recipe.imageURL, !imageURL.isEmpty {
                    AsyncImage(url: URL(string: imageURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                    .frame(height: 250)
                    .frame(maxWidth: .infinity)
                    .clipShape(Rectangle())
                } else {
                    ZStack {
                        Rectangle()
                            .fill(Color.orange.opacity(0.8))
                            .frame(height: 250)
                        
                        Image(systemName: "fork.knife")
                            .font(.system(size: 80))
                            .foregroundColor(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: 15) {
                    // Title and favorite button
                    HStack {
                        Text(recipe.name)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button(action: {
                            isFavorite.toggle()
                            onFavoriteToggle(isFavorite)
                        }) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .font(.title2)
                                .foregroundColor(isFavorite ? .red : .gray)
                        }
                    }
                    
                    // Recipe info
                    HStack(spacing: 15) {
                        Label("\(recipe.preparationTime) Min", systemImage: "clock")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Label(recipe.difficulty.rawValue, systemImage: "speedometer")
                            .font(.subheadline)
                    }
                    .foregroundColor(.gray)
                    .padding(.bottom, 10)
                    
                    // "Heute kochen" Button
                    Button(action: {
                        showingCookConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "flame.fill")
                            Text("Heute kochen")
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.orange)
                        .cornerRadius(10)
                    }
                    .alert(isPresented: $showingCookConfirmation) {
                        Alert(
                            title: Text("Rezept kochen"),
                            message: Text("Möchtest du dieses Rezept zum Wochenplan hinzufügen? Dies wird als 'heute gekocht' markiert."),
                            primaryButton: .default(Text("Ja, kochen")) {
                                authManager.addCookedRecipe(recipe: recipe)
                                // Automatisch verbrauchte Zutaten markieren
                                markUsedIngredients()
                            },
                            secondaryButton: .cancel(Text("Abbrechen"))
                        )
                    }
                    
                    // Description
                    Text("Beschreibung")
                        .font(.headline)
                    
                    Text(recipe.description)
                        .foregroundColor(.secondary)
                    
                    // Ingredients
                    Text("Zutaten")
                        .font(.headline)
                        .padding(.top, 10)
                    
                    if !missingIngredients.isEmpty {
                        Text("Fehlende Zutaten in deiner Vorratskammer:")
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .padding(.bottom, 5)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(recipe.ingredients, id: \.self) { ingredient in
                            let isMissing = missingIngredients.contains(ingredient)
                            
                            HStack(alignment: .top) {
                                Image(systemName: isMissing ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                                    .foregroundColor(isMissing ? .red : .green)
                                    .font(.system(size: 12))
                                    .padding(.top, 4)
                                
                                Text(ingredient)
                                    .foregroundColor(isMissing ? .red : .secondary)
                                    .fontWeight(isMissing ? .bold : .regular)
                            }
                        }
                    }
                    
                    // Instructions
                    Text("Zubereitung")
                        .font(.headline)
                        .padding(.top, 10)
                    
                    VStack(alignment: .leading, spacing: 15) {
                        ForEach(Array(recipe.instructions.enumerated()), id: \.element) { index, instruction in
                            HStack(alignment: .top) {
                                Text("\(index + 1).")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                                    .frame(width: 25, alignment: .leading)
                                
                                Text(instruction)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Moods and tags
                    if !recipe.suitableForMoods.isEmpty {
                        Text("Passend für Stimmungen")
                            .font(.headline)
                            .padding(.top, 10)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(recipe.suitableForMoods, id: \.self) { mood in
                                Text(mood)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 5)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    
                    if !recipe.tags.isEmpty {
                        Text("Tags")
                            .font(.headline)
                            .padding(.top, 10)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(recipe.tags, id: \.self) { tag in
                                Text(tag)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 5)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(20)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationBarTitle("Rezeptdetails", displayMode: .inline)
        .navigationBarItems(leading: Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            Image(systemName: "xmark")
                .foregroundColor(.orange)
        })
        .edgesIgnoringSafeArea(.top)
    }
    
    // Markiere die Zutaten des Rezepts, die wir in der Vorratskammer haben, als verwendet
    private func markUsedIngredients() {
        guard let pantry = authManager.user?.pantryIngredients else { return }
        
        for ingredient in recipe.ingredients {
            for pantryItem in pantry {
                if !pantryItem.isUsed && 
                   (ingredient.lowercased().contains(pantryItem.name.lowercased()) || 
                    pantryItem.name.lowercased().contains(ingredient.lowercased())) {
                    authManager.markIngredientAsUsed(ingredientId: pantryItem.id, isUsed: true)
                }
            }
        }
    }
}

// Helper view to create a flowing layout for tags/moods
struct FlowLayout: Layout {
    var spacing: CGFloat = 10
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        
        var height: CGFloat = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxHeight: CGFloat = 0
        
        for view in subviews {
            let viewSize = view.sizeThatFits(.unspecified)
            
            if x + viewSize.width > width {
                // Move to next row
                y += maxHeight + spacing
                x = 0
                maxHeight = 0
            }
            
            maxHeight = max(maxHeight, viewSize.height)
            x += viewSize.width + spacing
            
            height = max(height, y + maxHeight)
        }
        
        return CGSize(width: width, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = bounds.width
        
        var x = bounds.minX
        var y = bounds.minY
        var maxHeight: CGFloat = 0
        
        for view in subviews {
            let viewSize = view.sizeThatFits(.unspecified)
            
            if x + viewSize.width > bounds.maxX {
                // Move to next row
                y += maxHeight + spacing
                x = bounds.minX
                maxHeight = 0
            }
            
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: viewSize.width, height: viewSize.height))
            
            maxHeight = max(maxHeight, viewSize.height)
            x += viewSize.width + spacing
        }
    }
} 