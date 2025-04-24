//
//  RecipeSwipeView.swift
//  MoodMeal
//
//  Created by Naím Rodriguez Caballero on 21.04.25.
//

import SwiftUI
import FirebaseFirestore

struct RecipeSwipeView: View {
    @ObservedObject var recipeManager: RecipeManager
    @ObservedObject var authManager: AuthManager
    @State private var currentIndex = 0
    @State private var offset = CGSize.zero
    @State private var showRecipeDetail = false
    @State private var selectedRecipe: Recipe?
    @State private var swipeDirection: SwipeDirection = .none
    @State private var showCreateRecipe = false
    
    enum SwipeDirection {
        case none, left, right, up
    }
    
    // Sortierte Rezepte mit eigenen Rezepten an erster Stelle
    private var sortedRecipes: [Recipe] {
        if recipeManager.recipes.isEmpty {
            return []
        }
        
        // Prüfen, ob der User existiert und eigene Rezepte hat
        guard let userId = authManager.user?.id else {
            return recipeManager.recipes
        }
        
        // Trennen in eigene und andere Rezepte
        let ownRecipes = recipeManager.recipes.filter { recipe in
            if let creatorId = recipe.creatorId {
                return creatorId == userId
            }
            return false
        }
        
        let otherRecipes = recipeManager.recipes.filter { recipe in
            if let creatorId = recipe.creatorId {
                return creatorId != userId
            }
            return true // Wenn kein creatorId, dann ist es ein API-Rezept
        }
        
        // Eigene Rezepte zuerst, dann die anderen
        return ownRecipes + otherRecipes
    }
    
    var body: some View {
        ZStack {
            // Hintergrundfarbe
            Color.orange.opacity(0.1).ignoresSafeArea()
            
            // Haupt-Content
            VStack {
                // Header mit Titel und "+" Button
                HStack {
                    Text("Rezepte")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        showCreateRecipe = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.orange)
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Swipe-Karten
                if sortedRecipes.isEmpty {
                    VStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()
                        Text("Rezepte werden geladen...")
                            .font(.headline)
                        Spacer()
                    }
                } else {
                    ZStack {
                        // Anzeigen des nächsten Rezepts als Hintergrundhilfe
                        if currentIndex + 1 < sortedRecipes.count {
                            RecipeSwipeCard(recipe: sortedRecipes[currentIndex + 1], pantryIngredients: authManager.user?.pantryIngredients ?? [])
                                .scaleEffect(0.9)
                                .opacity(0.5)
                        }
                        
                        // Aktuelles Rezept
                        if currentIndex < sortedRecipes.count {
                            let recipe = sortedRecipes[currentIndex]
                            RecipeSwipeCard(recipe: recipe, pantryIngredients: authManager.user?.pantryIngredients ?? [])
                                .offset(x: offset.width, y: offset.height)
                                .rotationEffect(.degrees(Double(offset.width / 25)))
                                .overlay(
                                    // Eigenes Rezept-Badge
                                    recipe.creatorId == authManager.user?.id ? 
                                    VStack {
                                        HStack {
                                            Spacer()
                                            Text("Mein Rezept")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.blue)
                                                .cornerRadius(8)
                                                .padding(12)
                                        }
                                        Spacer()
                                    } : nil
                                )
                                .gesture(
                                    DragGesture()
                                        .onChanged { gesture in
                                            offset = gesture.translation
                                        }
                                        .onEnded { gesture in
                                            withAnimation(.spring()) {
                                                handleSwipe(width: offset.width, height: offset.height)
                                            }
                                        }
                                )
                                .onTapGesture {
                                    selectedRecipe = recipe
                                    showRecipeDetail = true
                                }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Swipe-Anweisungen
                    VStack(spacing: 8) {
                        HStack {
                            SwipeInstructionView(systemName: "xmark.circle.fill", text: "Ablehnen", color: .red)
                            Spacer()
                            SwipeInstructionView(systemName: "arrow.up.circle.fill", text: "Jetzt kochen", color: .green)
                            Spacer()
                            SwipeInstructionView(systemName: "heart.circle.fill", text: "Gefällt mir", color: .pink)
                        }
                        .padding(.horizontal, 40)
                        .padding(.vertical)
                    }
                }
            }
        }
        .onAppear {
            if recipeManager.recipes.isEmpty {
                recipeManager.fetchRecipes()
            }
        }
        .fullScreenCover(isPresented: $showRecipeDetail) {
            if let recipe = selectedRecipe {
                RecipeDetailView(
                    recipe: recipe,
                    isFavorite: authManager.user?.favorites.contains(recipe.id) ?? false,
                    authManager: authManager
                ) { isFavorite in
                    if let userId = authManager.user?.id {
                        recipeManager.toggleFavorite(recipeId: recipe.id, userId: userId, isFavorite: isFavorite)
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateRecipe) {
            CreateRecipeView(recipeManager: recipeManager, authManager: authManager)
        }
    }
    
    // Behandelt die Swipe-Geste und führt entsprechende Aktionen aus
    private func handleSwipe(width: CGFloat, height: CGFloat) {
        // Horizontaler Swipe hat Priorität (wenn beides, horizontal und vertikal)
        if abs(width) > 150 {
            // Swipe nach rechts - Gefällt mir
            if width > 0 {
                offset = CGSize(width: 500, height: 0)
                addToFavorites()
                swipeDirection = .right
            }
            // Swipe nach links - Ablehnen
            else {
                offset = CGSize(width: -500, height: 0)
                swipeDirection = .left
            }
            moveToNextCard()
        }
        // Vertikaler Swipe nach oben - Jetzt kochen
        else if height < -150 {
            offset = CGSize(width: 0, height: -500)
            swipeDirection = .up
            
            if currentIndex < sortedRecipes.count {
                let recipe = sortedRecipes[currentIndex]
                selectedRecipe = recipe
                
                // Markiere als gekocht und öffne das Rezept
                authManager.markRecipeAsCooked(
                    recipeId: recipe.id,
                    recipeName: recipe.name,
                    imageURL: recipe.imageURL
                )
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showRecipeDetail = true
                    moveToNextCard()
                }
            }
        }
        // Kein ausreichender Swipe - zurück zur Mitte
        else {
            offset = .zero
            swipeDirection = .none
        }
    }
    
    // Fügt das aktuelle Rezept zu den Favoriten hinzu
    private func addToFavorites() {
        if currentIndex < sortedRecipes.count {
            let recipe = sortedRecipes[currentIndex]
            if let userId = authManager.user?.id {
                print("Füge Rezept \(recipe.name) zu Favoriten hinzu")
                
                // Aktualisiere die User-Instanz direkt
                if var user = authManager.user {
                    if !user.favorites.contains(recipe.id) {
                        user.favorites.append(recipe.id)
                        authManager.user = user
                    }
                }
                
                // Und speichere es in Firestore
                recipeManager.toggleFavorite(recipeId: recipe.id, userId: userId, isFavorite: true)
            }
        }
    }
    
    // Wechselt zur nächsten Karte
    private func moveToNextCard() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if currentIndex < sortedRecipes.count - 1 {
                currentIndex += 1
            } else {
                // Optionale Logik, wenn alle Karten durchgegangen wurden
                // Zum Beispiel: Lade mehr Rezepte oder zeige eine Nachricht an
            }
            offset = .zero
            swipeDirection = .none
        }
    }
}

// Hilfsstruktur für die Swipe-Anweisungen
struct SwipeInstructionView: View {
    let systemName: String
    let text: String
    let color: Color
    
    var body: some View {
        VStack {
            Image(systemName: systemName)
                .font(.system(size: 30))
                .foregroundColor(color)
            Text(text)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

// Die eigentliche Rezept-Karte
struct RecipeSwipeCard: View {
    let recipe: Recipe
    let pantryIngredients: [PantryIngredient]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Bild
            if let imageURL = recipe.imageURL, let url = URL(string: imageURL) {
                GeometryReader { geo in
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.white)
                            )
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.orange.opacity(0.3))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                    )
            }
            
            // Informationsoverlay am unteren Rand
            VStack(alignment: .leading, spacing: 10) {
                // Titel und Basisdaten
                HStack {
                    VStack(alignment: .leading) {
                        Text(recipe.name)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(2)
                        
                        HStack {
                            // Zubereitungszeit
                            Label("\(recipe.preparationTime) Min", systemImage: "clock")
                                .foregroundColor(.white)
                                .padding(.vertical, 5)
                                .padding(.horizontal, 10)
                                .background(Color.orange.opacity(0.7))
                                .cornerRadius(20)
                            
                            // Schwierigkeitsgrad
                            Label(recipe.difficulty.displayName, systemImage: "chart.bar")
                                .foregroundColor(.white)
                                .padding(.vertical, 5)
                                .padding(.horizontal, 10)
                                .background(Color.orange.opacity(0.7))
                                .cornerRadius(20)
                            
                            // Anzeige wie viele Zutaten verfügbar sind
                            if let matchCount = ingredientMatchCount(), matchCount > 0 {
                                Label("\(matchCount) Zutaten vorhanden", systemImage: "checkmark.circle")
                                    .foregroundColor(.white)
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, 10)
                                    .background(Color.green.opacity(0.7))
                                    .cornerRadius(20)
                            }
                        }
                    }
                    
                    Spacer()
                }
                
                // Expandierbarer Bereich für weitere Informationen
                ExpandableInfoSection(title: "Zutaten") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(recipe.ingredients.prefix(5), id: \.self) { ingredient in
                            HStack {
                                Text("• \(ingredient)")
                                    .foregroundColor(.white)
                                    .font(.callout)
                                
                                if isIngredientInPantry(ingredient) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        
                        if recipe.ingredients.count > 5 {
                            Text("+ \(recipe.ingredients.count - 5) weitere...")
                                .foregroundColor(.white)
                                .font(.callout)
                                .italic()
                        }
                    }
                }
                
                ExpandableInfoSection(title: "Zubereitung") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(recipe.instructions.prefix(2), id: \.self) { step in
                            Text("• \(step)")
                                .foregroundColor(.white)
                                .font(.callout)
                                .lineLimit(1)
                        }
                        
                        if recipe.instructions.count > 2 {
                            Text("+ \(recipe.instructions.count - 2) weitere Schritte...")
                                .foregroundColor(.white)
                                .font(.callout)
                                .italic()
                        }
                    }
                }
                
                // Typisches Swipe-Foto-Indikator
                HStack {
                    Text("Zum Swipen nach links oder rechts wischen")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
            }
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.black.opacity(0.8), Color.black.opacity(0.3), Color.clear]),
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
        }
        .cornerRadius(15)
        .shadow(radius: 5)
        .frame(height: 550)
    }
    
    // Prüft, ob eine Zutat in der Vorratskammer vorhanden ist
    private func isIngredientInPantry(_ ingredientName: String) -> Bool {
        let normalizedIngredientName = ingredientName.lowercased()
        
        return pantryIngredients.contains { pantryIngredient in
            // Ignoriere benutzte Zutaten
            guard !pantryIngredient.isUsed else { return false }
            
            let normalizedPantryName = pantryIngredient.name.lowercased()
            
            // Prüfe auf exakte oder teilweise Übereinstimmung
            return normalizedPantryName.contains(normalizedIngredientName) || 
                   normalizedIngredientName.contains(normalizedPantryName)
        }
    }
    
    // Zählt, wie viele Zutaten in der Vorratskammer vorhanden sind
    private func ingredientMatchCount() -> Int? {
        let matches = recipe.ingredients.filter { isIngredientInPantry($0) }.count
        return matches > 0 ? matches : nil
    }
}

// Korrigierter expandierbarer Abschnitt für zusätzliche Informationen
struct ExpandableInfoSection<Content: View>: View {
    let title: String
    let content: () -> Content
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.white)
                }
            }
            
            if isExpanded {
                content()
                    .padding(.leading, 5)
                    .padding(.top, 5)
            }
        }
    }
}

// Erweiterung für Recipe.Difficulty, um einen benutzerfreundlichen Namen zu erhalten
extension Recipe.Difficulty {
    var displayName: String {
        switch self {
        case .easy:
            return "Leicht"
        case .medium:
            return "Mittel"
        case .hard:
            return "Schwer"
        }
    }
}

// Preview
struct RecipeSwipeView_Previews: PreviewProvider {
    static var previews: some View {
        RecipeSwipeView(
            recipeManager: RecipeManager(),
            authManager: AuthManager()
        )
    }
} 
