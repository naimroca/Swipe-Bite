//
//  MainTabView.swift
//  MoodMeal
//
//  Created by Naím Rodriguez Caballero on 21.04.25.
//

import SwiftUI

struct MainTabView: View {
    @ObservedObject var authManager: AuthManager
    @StateObject private var recipeManager = RecipeManager()
    @State private var isInitialLoad = true
    @State private var showDebugInfo = false
    
    var body: some View {
        TabView {
            // Tinder-ähnliche Swipe-Ansicht als erster Tab mit umbenannter Bezeichnung
            RecipeSwipeView(recipeManager: recipeManager, authManager: authManager)
                .tabItem {
                    Image(systemName: "square.stack")
                    Text("Rezepte")
                }
            
            // Vorratskammer als zweiter Tab
            PantryView(authManager: authManager)
                .tabItem {
                    Image(systemName: "cabinet")
                    Text("Vorratskammer")
                }
            
            // Favoriten als dritter Tab
            FavoritesView(recipeManager: recipeManager, authManager: authManager)
                .tabItem {
                    Image(systemName: "heart")
                    Text("Favoriten")
                }
            
            // Profil als vierter Tab
            ProfileView(authManager: authManager, recipeManager: recipeManager)
                .tabItem {
                    Image(systemName: "person")
                    Text("Profil")
                }
        }
        .accentColor(.orange)
        .onAppear {
            if isInitialLoad {
                // Initialer API-Aufruf zum Laden von Rezepten, falls noch keine vorhanden sind
                print("MainTabView: Erster Aufruf, lade Rezepte...")
                
                // Laden mit einem Verzögerungsmechanismus
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    print("MainTabView: Starte API-Aufruf...")
                    RecipeAPI.shared.fetchAndStoreRecipes { result in
                        switch result {
                        case .success(let recipes):
                            print("MainTabView: API hat \(recipes.count) Rezepte geladen")
                            
                            // Kleine Verzögerung, damit Firestore Zeit hat zu schreiben
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                // Überprüfen, ob Rezepte schon angezeigt werden, sonst laden
                                print("MainTabView: Rezepte im RecipeManager aktuell: \(self.recipeManager.recipes.count)")
                                if self.recipeManager.recipes.isEmpty {
                                    print("MainTabView: Lade Rezepte aus Firestore")
                                    if let mood = self.authManager.user?.currentMood {
                                        print("MainTabView: Suche nach Rezepten für Stimmung: \(mood.rawValue)")
                                        self.recipeManager.fetchRecipes(forMood: mood)
                                    } else {
                                        print("MainTabView: Keine Stimmung gefunden, lade alle Rezepte")
                                        self.recipeManager.fetchRecipes()
                                    }
                                    print("MainTabView: fetchRecipes aufgerufen, warte auf Ergebnisse...")
                                }
                            }
                        case .failure(let error):
                            print("MainTabView: Fehler beim Laden der Rezepte: \(error)")
                            
                            // Trotz Fehler versuchen, aus Firestore zu laden
                            print("MainTabView: Rezepte im RecipeManager aktuell: \(self.recipeManager.recipes.count)")
                            if self.recipeManager.recipes.isEmpty {
                                print("MainTabView: Versuche direkt aus Firestore zu laden")
                                if let mood = self.authManager.user?.currentMood {
                                    print("MainTabView: Suche nach Rezepten für Stimmung: \(mood.rawValue)")
                                    self.recipeManager.fetchRecipes(forMood: mood)
                                } else {
                                    print("MainTabView: Keine Stimmung gefunden, lade alle Rezepte")
                                    self.recipeManager.fetchRecipes()
                                }
                                print("MainTabView: fetchRecipes aufgerufen, warte auf Ergebnisse...")
                            }
                        }
                    }
                }
                
                isInitialLoad = false
            }
        }
    }
}

struct FavoritesView: View {
    @ObservedObject var recipeManager: RecipeManager
    @ObservedObject var authManager: AuthManager
    @State private var selectedRecipe: Recipe?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.orange.opacity(0.1).ignoresSafeArea()
                
                if let favorites = authManager.user?.favorites, !favorites.isEmpty {
                    VStack {
                        ScrollView {
                            LazyVStack(spacing: 15) {
                                ForEach(recipeManager.recipes) { recipe in
                                    RecipeCard(recipe: recipe, isFavorite: true)
                                        .onTapGesture {
                                            selectedRecipe = recipe
                                        }
                                }
                            }
                            .padding()
                        }
                    }
                    .navigationTitle("Favoriten")
                    .onAppear {
                        recipeManager.fetchFavoriteRecipes(favoriteIds: authManager.user?.favorites ?? [])
                    }
                } else {
                    VStack {
                        Image(systemName: "heart.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.6))
                        
                        Text("Keine Favoriten")
                            .font(.title2)
                            .foregroundColor(.gray)
                            .padding(.top)
                        
                        Text("Füge Rezepte zu deinen Favoriten hinzu, indem du das Herz-Symbol auf der Rezeptdetailseite anklickst.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .navigationTitle("Favoriten")
                }
            }
            .sheet(item: $selectedRecipe) { recipe in
                RecipeDetailView(
                    recipe: recipe,
                    isFavorite: true,
                    authManager: authManager
                ) { isFavorite in
                    if !isFavorite {
                        if let userId = authManager.user?.id {
                            recipeManager.toggleFavorite(recipeId: recipe.id, userId: userId, isFavorite: false)
                            authManager.user?.favorites.removeAll { $0 == recipe.id }
                            recipeManager.fetchFavoriteRecipes(favoriteIds: authManager.user?.favorites ?? [])
                        }
                    }
                }
            }
        }
    }
}

// Neue View für gekochte Rezepte
struct CookedRecipesView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var recipeManager: RecipeManager
    @State private var selectedRecipe: Recipe?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.orange.opacity(0.1).ignoresSafeArea()
                
                if let cookedRecipes = authManager.user?.cookedRecipes, !cookedRecipes.isEmpty {
                    VStack {
                        List {
                            ForEach(cookedRecipes) { cooked in
                                HStack {
                                    if let imageURL = cooked.imageURL, !imageURL.isEmpty {
                                        AsyncImage(url: URL(string: imageURL)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Color.gray.opacity(0.3)
                                        }
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        Image(systemName: "flame.fill")
                                            .font(.system(size: 30))
                                            .foregroundColor(.white)
                                            .frame(width: 60, height: 60)
                                            .background(Color.orange)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(cooked.recipeName)
                                            .font(.headline)
                                        
                                        Text("Gekocht am \(cooked.formattedDate)")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.leading, 5)
                                    
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    // Suche das Original-Rezept
                                    loadRecipeDetails(recipeId: cooked.recipeId)
                                }
                                .padding(.vertical, 5)
                            }
                        }
                        .listStyle(InsetGroupedListStyle())
                    }
                    .navigationTitle("Gekochte Rezepte")
                } else {
                    VStack {
                        Image(systemName: "flame.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.6))
                        
                        Text("Keine gekochten Rezepte")
                            .font(.title2)
                            .foregroundColor(.gray)
                            .padding(.top)
                        
                        Text("Deine gekochten Rezepte werden hier angezeigt, wenn du über die Rezeptdetailseite das \"Heute kochen\"-Feature nutzt.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .navigationTitle("Gekochte Rezepte")
                }
            }
            .sheet(item: $selectedRecipe) { recipe in
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
    }
    
    private func loadRecipeDetails(recipeId: String) {
        // Versuche, das Rezept aus dem RecipeManager zu laden
        if let recipe = recipeManager.recipes.first(where: { $0.id == recipeId }) {
            selectedRecipe = recipe
            return
        }
        
        // Wenn nicht gefunden, aus Firestore laden
        recipeManager.fetchRecipeById(recipeId: recipeId) { result in
            switch result {
            case .success(let recipe):
                DispatchQueue.main.async {
                    self.selectedRecipe = recipe
                }
            case .failure(let error):
                print("Fehler beim Laden des Rezepts: \(error)")
            }
        }
    }
} 