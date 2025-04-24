//
//  RecipeListView.swift
//  MoodMeal
//
//  Created by Naím Rodriguez Caballero on 21.04.25.
//

import SwiftUI

struct RecipeListView: View {
    @ObservedObject var recipeManager: RecipeManager
    @ObservedObject var authManager: AuthManager
    @State private var showingIngredientInput = false
    @State private var showingMoodSelection = false
    @State private var selectedRecipe: Recipe?
    @State private var searchText = ""
    @State private var usePantryIngredients = true
    
    private var filteredRecipes: [Recipe] {
        if searchText.isEmpty {
            return recipeManager.recipes
        } else {
            return recipeManager.recipes.filter { recipe in
                recipe.name.lowercased().contains(searchText.lowercased()) ||
                recipe.ingredients.contains { $0.lowercased().contains(searchText.lowercased()) } ||
                recipe.tags.contains { $0.lowercased().contains(searchText.lowercased()) }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.orange.opacity(0.1).ignoresSafeArea()
                
                VStack {
                    // Debug-Ansicht, um den Rezeptstatus zu sehen
                    VStack {
                        Text("Debug-Info:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("Rezeptanzahl: \(recipeManager.recipes.count)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 10)
                    
                    // Search
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Nach Rezepten suchen", text: $searchText)
                            .autocapitalization(.none)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Recipe filter buttons
                    HStack(spacing: 15) {
                        Button(action: {
                            showingIngredientInput = true
                        }) {
                            HStack {
                                Image(systemName: "carrot")
                                Text("Zutaten")
                            }
                            .padding(.horizontal, 15)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .foregroundColor(.orange)
                            .cornerRadius(20)
                            .shadow(radius: 1)
                        }
                        
                        Button(action: {
                            showingMoodSelection = true
                        }) {
                            HStack {
                                Image(systemName: "face.smiling")
                                Text("Stimmung")
                            }
                            .padding(.horizontal, 15)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .foregroundColor(.orange)
                            .cornerRadius(20)
                            .shadow(radius: 1)
                        }
                        
                        Button(action: {
                            loadFavorites()
                        }) {
                            HStack {
                                Image(systemName: "heart.fill")
                                Text("Favoriten")
                            }
                            .padding(.horizontal, 15)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .foregroundColor(.orange)
                            .cornerRadius(20)
                            .shadow(radius: 1)
                        }
                    }
                    .padding(.top, 5)
                    
                    // Pantry Option
                    if !(authManager.user?.pantryIngredients.isEmpty ?? true) {
                        HStack {
                            Toggle(isOn: $usePantryIngredients) {
                                HStack {
                                    Image(systemName: "cabinet")
                                    Text("Zutaten aus Vorratskammer bevorzugen")
                                        .font(.callout)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .orange))
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(10)
                        .shadow(radius: 1)
                        .padding(.horizontal)
                        .padding(.top, 5)
                        .onChange(of: usePantryIngredients) { value in
                            if value {
                                print("Aktiviere Vorratskammer-Filter mit \(authManager.user?.pantryIngredients.count ?? 0) Zutaten")
                                
                                // Hole Zutaten aus Vorratskammer
                                if let pantryItems = authManager.user?.pantryIngredients.filter({ !$0.isUsed }) {
                                    let ingredientNames = pantryItems.map { $0.name }
                                    print("Suche nach Rezepten mit: \(ingredientNames.joined(separator: ", "))")
                                    
                                    if let mood = authManager.user?.currentMood {
                                        recipeManager.fetchRecipes(forMood: mood, withIngredients: ingredientNames, checkPantry: true, user: authManager.user)
                                    } else {
                                        recipeManager.fetchRecipes(withIngredients: ingredientNames, checkPantry: true, user: authManager.user)
                                    }
                                }
                            } else {
                                print("Deaktiviere Vorratskammer-Filter")
                                if let mood = authManager.user?.currentMood {
                                    recipeManager.fetchRecipes(forMood: mood)
                                } else {
                                    recipeManager.fetchRecipes()
                                }
                            }
                        }
                    }
                    
                    if let mood = authManager.user?.currentMood {
                        HStack {
                            Image(systemName: mood.icon)
                                .foregroundColor(.orange)
                            Text("Rezepte für deine \(mood.rawValue) Stimmung")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 5)
                    }
                    
                    // Recipe list
                    if filteredRecipes.isEmpty {
                        Spacer()
                        VStack {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.6))
                            
                            Text("Keine Rezepte gefunden")
                                .font(.title2)
                                .foregroundColor(.gray)
                                .padding(.top)
                            
                            Text("Versuche andere Zutaten oder eine andere Stimmung")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 15) {
                                ForEach(filteredRecipes) { recipe in
                                    RecipeCard(recipe: recipe, isFavorite: authManager.user?.favorites.contains(recipe.id) ?? false)
                                        .onTapGesture {
                                            selectedRecipe = recipe
                                        }
                                }
                            }
                            .padding()
                        }
                    }
                }
                .navigationTitle("Rezepte")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(action: {
                                authManager.signOut()
                            }) {
                                Label("Abmelden", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                            
                            Button(action: {
                                loadRecipesManually()
                            }) {
                                Label("Rezepte neu laden", systemImage: "arrow.clockwise")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.orange)
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarLeading) {
                        if let user = authManager.user {
                            Text("Hallo, \(user.username)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingIngredientInput) {
                IngredientsInputView(recipeManager: recipeManager, authManager: authManager)
            }
            .sheet(isPresented: $showingMoodSelection) {
                MoodSelectionView(authManager: authManager)
            }
            .sheet(item: $selectedRecipe) { recipe in
                RecipeDetailView(
                    recipe: recipe, 
                    isFavorite: authManager.user?.favorites.contains(recipe.id) ?? false,
                    authManager: authManager
                ) { isFavorite in
                    toggleFavorite(recipe: recipe, isFavorite: isFavorite)
                }
            }
            .onAppear {
                print("\n=== RecipeListView erscheint ===")
                print("Vorhandene Rezepte: \(recipeManager.recipes.count)")
                print("Auth Status: \(authManager.isAuthenticated ? "Angemeldet" : "Nicht angemeldet")")
                print("User: \(authManager.user?.username ?? "Kein Benutzer")")
                print("Stimmung: \(authManager.user?.currentMood?.rawValue ?? "Keine")")
                
                // Direkt Rezepte laden, unabhängig von der Stimmung
                print("Lade ALLE Rezepte direkt aus Firestore ohne Filter...")
                recipeManager.fetchRecipes()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    print("Check nach 1s: \(recipeManager.recipes.count) Rezepte geladen")
                    
                    // Wenn Rezepte geladen wurden und Vorratskammer-Zutaten vorhanden sind, 
                    // aktiviere den Vorratskammer-Filter
                    if !recipeManager.recipes.isEmpty && !(authManager.user?.pantryIngredients.isEmpty ?? true) {
                        print("Aktiviere automatisch Vorratskammer-Filter")
                        
                        // Hole Zutaten aus Vorratskammer
                        if let pantryItems = authManager.user?.pantryIngredients.filter({ !$0.isUsed }) {
                            let ingredientNames = pantryItems.map { $0.name }
                            print("Suche nach Rezepten mit: \(ingredientNames.joined(separator: ", "))")
                            
                            if let mood = authManager.user?.currentMood {
                                recipeManager.fetchRecipes(forMood: mood, withIngredients: ingredientNames, checkPantry: true, user: authManager.user)
                            } else {
                                recipeManager.fetchRecipes(withIngredients: ingredientNames, checkPantry: true, user: authManager.user)
                            }
                        }
                    }
                    
                    // Wenn immer noch keine Rezepte, API-Aufruf starten
                    if recipeManager.recipes.isEmpty {
                        print("Keine Rezepte gefunden, starte API-Aufruf...")
                        loadRecipesManually()
                    }
                }
            }
        }
    }
    
    private func loadFavorites() {
        if let favorites = authManager.user?.favorites, !favorites.isEmpty {
            recipeManager.fetchFavoriteRecipes(favoriteIds: favorites)
        }
    }
    
    private func toggleFavorite(recipe: Recipe, isFavorite: Bool) {
        if let userId = authManager.user?.id {
            recipeManager.toggleFavorite(recipeId: recipe.id, userId: userId, isFavorite: isFavorite)
            
            // Update the local user favorites
            if isFavorite {
                authManager.user?.favorites.append(recipe.id)
            } else {
                authManager.user?.favorites.removeAll { $0 == recipe.id }
            }
        }
    }
    
    private func loadRecipesManually() {
        print("Starte manuelles Laden von Rezepten...")
        
        // Erst API-Call, dann Firestore
        RecipeAPI.shared.fetchAndStoreRecipes { result in
            switch result {
            case .success(let recipes):
                print("API hat \(recipes.count) Rezepte geladen")
                
                // Kleine Verzögerung, damit Firestore Zeit hat, zu schreiben
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    print("Lade Rezepte aus Firestore...")
                    if let mood = self.authManager.user?.currentMood {
                        self.recipeManager.fetchRecipes(forMood: mood, checkPantry: self.usePantryIngredients, user: self.authManager.user)
                    } else {
                        self.recipeManager.fetchRecipes(checkPantry: self.usePantryIngredients, user: self.authManager.user)
                    }
                }
                
            case .failure(let error):
                print("Fehler beim Laden der Rezepte via API: \(error)")
                
                // Fall-back auf Firestore
                print("Versuche, Rezepte direkt aus Firestore zu laden...")
                if let mood = self.authManager.user?.currentMood {
                    self.recipeManager.fetchRecipes(forMood: mood, checkPantry: self.usePantryIngredients, user: self.authManager.user)
                } else {
                    self.recipeManager.fetchRecipes(checkPantry: self.usePantryIngredients, user: self.authManager.user)
                }
            }
        }
    }
}

struct RecipeCard: View {
    let recipe: Recipe
    let isFavorite: Bool
    
    var body: some View {
        HStack(spacing: 15) {
            // Recipe image or placeholder
            if let imageURL = recipe.imageURL, !imageURL.isEmpty {
                AsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Image(systemName: "fork.knife")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                    .frame(width: 100, height: 100)
                    .background(Color.orange.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            // Recipe info
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(recipe.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if isFavorite {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                    }
                }
                
                Text(recipe.description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(2)
                
                HStack {
                    Label("\(recipe.preparationTime) Min", systemImage: "clock")
                    
                    Spacer()
                    
                    Text(recipe.difficulty.rawValue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            difficultyBackground(for: recipe.difficulty)
                        )
                        .foregroundColor(.white)
                        .font(.caption)
                        .cornerRadius(5)
                }
                .font(.caption)
                .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func difficultyBackground(for difficulty: Recipe.Difficulty) -> Color {
        switch difficulty {
        case .easy:
            return .green
        case .medium:
            return .orange
        case .hard:
            return .red
        }
    }
} 