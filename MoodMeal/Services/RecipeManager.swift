//
//  RecipeManager.swift
//  MoodMeal
//
//  Created by Naím Rodriguez Caballero on 21.04.25.
//

import Foundation
import FirebaseFirestore

class RecipeManager: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var errorMessage = ""
    
    private let db = Firestore.firestore()
    
    init() {
        // Firebase/Firestore Verbindung prüfen
        checkFirestoreConnection()
    }
    
    /// Überprüft die Verbindung zur Firestore-Datenbank und die Verfügbarkeit der Sammlung "recipes"
    private func checkFirestoreConnection() {
        print("\n=== FIRESTORE VERBINDUNGSTEST ===")
        print("Prüfe Firestore-Verbindung...")
        
        // Einfachen Zugriff auf Firestore testen
        db.collection("recipes").limit(to: 1).getDocuments { snapshot, error in
            if let error = error {
                print("❌ Firestore-Verbindungsfehler: \(error.localizedDescription)")
                self.errorMessage = "Firestore-Verbindungsfehler: \(error.localizedDescription)"
                return
            }
            
            guard let snapshot = snapshot else {
                print("❌ Firestore-Snapshot ist nil")
                return
            }
            
            print("✅ Firestore-Verbindung erfolgreich")
            print("Gefundene Dokumente in 'recipes': \(snapshot.documents.count)")
            
            if snapshot.documents.isEmpty {
                print("⚠️ Keine Rezepte in der Datenbank gefunden.")
                print("API-Aufruf wird benötigt, um Rezepte zu laden.")
            } else {
                print("📋 Erste Rezept-ID: \(snapshot.documents[0].documentID)")
                
                // Beispieldaten ausgeben
                let data = snapshot.documents[0].data()
                let keys = data.keys.joined(separator: ", ")
                print("Vorhandene Felder: \(keys)")
            }
            
            print("==============================\n")
        }
    }
    
    func fetchRecipes(forMood mood: Mood? = nil, withIngredients ingredients: [String]? = nil, checkPantry: Bool = false, user: User? = nil) {
        print("Starte Rezeptsuche - Mood: \(mood?.rawValue ?? "keine"), Zutaten: \(ingredients?.joined(separator: ", ") ?? "keine"), Pantry: \(checkPantry)")
        
        var query: Query = db.collection("recipes")
        
        if let mood = mood {
            print("Suche nach Rezepten für Stimmung: \(mood.rawValue)")
            query = query.whereField("suitableForMoods", arrayContains: mood.rawValue)
        }
        
        print("RecipeManager: Führe Firestore-Abfrage aus...")
        query.getDocuments { [weak self] snapshot, error in
            if let error = error {
                print("Firestore-Fehler beim Laden der Rezepte: \(error.localizedDescription)")
                self?.errorMessage = error.localizedDescription
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("Keine Rezepte in Firestore gefunden")
                self?.recipes = []
                return
            }
            
            print("Firestore hat \(documents.count) Rezeptdokumente gefunden")
            if documents.count == 0 {
                print("RecipeManager: WARNUNG - Keine Rezepte in Firestore gefunden!")
                self?.recipes = []
                return
            }
            
            var fetchedRecipes = documents.compactMap { document -> Recipe? in
                let data = document.data()
                
                // Debuggen, falls bestimmte Felder fehlen
                if data["name"] == nil { print("Rezept \(document.documentID) hat kein 'name' Feld") }
                if data["description"] == nil { print("Rezept \(document.documentID) hat kein 'description' Feld") }
                if data["ingredients"] == nil { print("Rezept \(document.documentID) hat kein 'ingredients' Feld") }
                
                guard 
                    let name = data["name"] as? String,
                    let description = data["description"] as? String,
                    let ingredients = data["ingredients"] as? [String],
                    let instructions = data["instructions"] as? [String],
                    let preparationTime = data["preparationTime"] as? Int,
                    let difficultyString = data["difficulty"] as? String,
                    let difficulty = Recipe.Difficulty(rawValue: difficultyString),
                    let suitableForMoods = data["suitableForMoods"] as? [String],
                    let tags = data["tags"] as? [String]
                else {
                    print("Rezept \(document.documentID) fehlen notwendige Felder")
                    return nil
                }
                
                let imageURL = data["imageURL"] as? String
                let rating = data["rating"] as? Double
                
                return Recipe(
                    id: document.documentID,
                    name: name,
                    description: description,
                    ingredients: ingredients,
                    instructions: instructions,
                    preparationTime: preparationTime,
                    difficulty: difficulty,
                    imageURL: imageURL,
                    suitableForMoods: suitableForMoods,
                    tags: tags,
                    rating: rating
                )
            }
            
            print("Erfolgreich \(fetchedRecipes.count) von \(documents.count) Rezepten verarbeitet")
            if fetchedRecipes.count == 0 && documents.count > 0 {
                print("RecipeManager: WARNUNG - Alle Rezeptdokumente fehlerhaft oder unvollständig!")
            }
            
            // Filter by ingredients if provided
            if let ingredients = ingredients, !ingredients.isEmpty {
                print("Filtere nach Zutaten: \(ingredients.joined(separator: ", "))")
                let originalCount = fetchedRecipes.count
                
                // Debug-Informationen für jeden Zutatennamen
                for ingredient in ingredients {
                    let normalizedSearchTerm = ingredient.lowercased()
                        .replacingOccurrences(of: "-", with: " ")
                        .replacingOccurrences(of: ",", with: " ")
                    
                    let englishTerms = self?.getEnglishTerms(forGermanIngredient: normalizedSearchTerm) ?? []
                    let germanTerms = self?.getGermanTerms(forEnglishIngredient: normalizedSearchTerm) ?? []
                    
                    print("DEBUG Zutat: '\(ingredient)'")
                    print("  - Normalisiert: '\(normalizedSearchTerm)'")
                    print("  - Englische Begriffe: \(englishTerms.joined(separator: ", "))")
                    print("  - Deutsche Begriffe: \(germanTerms.joined(separator: ", "))")
                }
                
                // Debug: Zeige die ersten 5 Rezepte und ihre Zutaten
                print("Erste 5 Rezepte und ihre Zutaten:")
                for (index, recipe) in fetchedRecipes.prefix(5).enumerated() {
                    print("Rezept #\(index+1): \(recipe.name)")
                    print("  Zutaten: \(recipe.ingredients.joined(separator: ", "))")
                }
                
                fetchedRecipes = fetchedRecipes.filter { recipe in
                    // Wandle Rezeptzutaten in Kleinbuchstaben um und normalisiere
                    let recipeIngredients = recipe.ingredients.map { 
                        $0.lowercased()
                         .replacingOccurrences(of: "-", with: " ")
                         .replacingOccurrences(of: ",", with: " ")
                    }
                    
                    // Für jede gesuchte Zutat prüfen, ob sie in einem Rezept vorkommt
                    return ingredients.first(where: { searchIngredient in
                        let normalizedSearchTerm = searchIngredient.lowercased()
                            .replacingOccurrences(of: "-", with: " ")
                            .replacingOccurrences(of: ",", with: " ")
                        
                        // Prüfe sowohl englische als auch deutsche Namen
                        let englishTerms = self?.getEnglishTerms(forGermanIngredient: normalizedSearchTerm) ?? []
                        let germanTerms = self?.getGermanTerms(forEnglishIngredient: normalizedSearchTerm) ?? []
                        
                        // Kombiniere alle möglichen Suchbegriffe
                        let allSearchTerms = [normalizedSearchTerm] + englishTerms + germanTerms
                        
                        // Prüfe, ob einer der Suchbegriffe in Rezeptzutaten enthalten ist
                        return recipeIngredients.contains { ingredient in
                            return allSearchTerms.contains { searchTerm in
                                ingredient.contains(searchTerm)
                            }
                        }
                    }) != nil
                }
                
                print("Gefiltert: \(fetchedRecipes.count) von \(originalCount) Rezepten enthalten die gesuchten Zutaten")
                
                // Sortieren nach Anzahl der übereinstimmenden Zutaten
                fetchedRecipes.sort { (recipe1, recipe2) -> Bool in
                    let recipeIngredients1 = recipe1.ingredients.map { $0.lowercased() }
                    let recipeIngredients2 = recipe2.ingredients.map { $0.lowercased() }
                    
                    let normalizedIngredients = ingredients.map { $0.lowercased() }
                    
                    let matches1 = normalizedIngredients.filter { ingredient in 
                        recipeIngredients1.contains { recipeIngredient in
                            recipeIngredient.contains(ingredient) || 
                            (self?.getEnglishTerms(forGermanIngredient: ingredient) ?? []).contains { term in
                                recipeIngredient.contains(term)
                            } ||
                            (self?.getGermanTerms(forEnglishIngredient: ingredient) ?? []).contains { term in
                                recipeIngredient.contains(term)
                            }
                        }
                    }.count
                    
                    let matches2 = normalizedIngredients.filter { ingredient in 
                        recipeIngredients2.contains { recipeIngredient in
                            recipeIngredient.contains(ingredient) || 
                            (self?.getEnglishTerms(forGermanIngredient: ingredient) ?? []).contains { term in
                                recipeIngredient.contains(term)
                            } ||
                            (self?.getGermanTerms(forEnglishIngredient: ingredient) ?? []).contains { term in
                                recipeIngredient.contains(term)
                            }
                        }
                    }.count
                    
                    return matches1 > matches2
                }
            }
            
            // Filter zusätzlich nach Vorratskammer-Zutaten, wenn aktiviert
            if checkPantry, let pantryIngredients = user?.pantryIngredients, !pantryIngredients.isEmpty {
                print("Berücksichtige Vorratskammer mit \(pantryIngredients.count) Zutaten")
                let pantryNames = pantryIngredients.filter { !$0.isUsed }.map { $0.name.lowercased() }
                print("Verfügbare Zutaten: \(pantryNames.joined(separator: ", "))")
                
                // Rezepte, für die man Zutaten im Vorratsschrank hat, priorisieren
                fetchedRecipes.sort { (recipe1, recipe2) -> Bool in
                    let recipeIngredients1 = recipe1.ingredients.map { $0.lowercased() }
                    let recipeIngredients2 = recipe2.ingredients.map { $0.lowercased() }
                    
                    let pantryMatches1 = recipeIngredients1.filter { recipeIngredient in
                        pantryNames.contains { pantryIngredient in
                            recipeIngredient.contains(pantryIngredient) || pantryIngredient.contains(recipeIngredient)
                        }
                    }.count
                    
                    let pantryMatches2 = recipeIngredients2.filter { recipeIngredient in
                        pantryNames.contains { pantryIngredient in
                            recipeIngredient.contains(pantryIngredient) || pantryIngredient.contains(recipeIngredient)
                        }
                    }.count
                    
                    return pantryMatches1 > pantryMatches2
                }
                
                // Zeige die Top-3 Rezepte und die Übereinstimmungen
                for (index, recipe) in fetchedRecipes.prefix(3).enumerated() {
                    let recipeIngredients = recipe.ingredients.map { $0.lowercased() }
                    
                    // Sammle alle Übereinstimmungen mit detaillierten Infos
                    var matchDetails: [String: [String]] = [:]
                    
                    for pantryIngredient in pantryNames {
                        var matchedWith: [String] = []
                        
                        for recipeIngredient in recipeIngredients {
                            // Deutsche Zutat direkt enthalten
                            if recipeIngredient.contains(pantryIngredient) {
                                matchedWith.append("\(recipeIngredient) (direkt)")
                                continue
                            }
                            
                            // Deutsche Zutat -> Englisch -> Match
                            for englishTerm in self?.getEnglishTerms(forGermanIngredient: pantryIngredient) ?? [] {
                                if recipeIngredient.contains(englishTerm) {
                                    matchedWith.append("\(recipeIngredient) (über engl. \(englishTerm))")
                                    break
                                }
                            }
                            
                            // Englische Zutat -> Deutsch -> Match
                            if matchedWith.isEmpty {
                                for germanTerm in self?.getGermanTerms(forEnglishIngredient: pantryIngredient) ?? [] {
                                    if recipeIngredient.contains(germanTerm) {
                                        matchedWith.append("\(recipeIngredient) (über dt. \(germanTerm))")
                                        break
                                    }
                                }
                            }
                        }
                        
                        if !matchedWith.isEmpty {
                            matchDetails[pantryIngredient] = matchedWith
                        }
                    }
                    
                    // Berechne Gesamtzahl Übereinstimmungen
                    let totalMatches = matchDetails.values.reduce(0) { $0 + $1.count }
                    
                    print("Top-\(index+1) Rezept: \(recipe.name) - \(totalMatches) Übereinstimmungen")
                    if !matchDetails.isEmpty {
                        for (ingredient, matches) in matchDetails {
                            print("   - \(ingredient) passt zu: \(matches.joined(separator: ", "))")
                        }
                    } else {
                        print("   (Keine direkten Übereinstimmungen gefunden)")
                    }
                }
            }
            
            print("Setze \(fetchedRecipes.count) Rezepte in RecipeManager")
            DispatchQueue.main.async {
                self?.recipes = fetchedRecipes
                print("RecipeManager: recipes Property aktualisiert. Neuer Wert: \(fetchedRecipes.count) Rezepte")
                
                // Debug-Ausgabe für die ersten 3 Rezepte
                for (index, recipe) in fetchedRecipes.prefix(3).enumerated() {
                    print("Debug Rezept #\(index+1):")
                    Recipe.debugPrint(recipe: recipe)
                }
                
                // Prüfe auf mögliche UI-Update-Probleme
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("RecipeManager: Erneuter Check nach 0.5s - Anzahl Rezepte: \(self?.recipes.count ?? 0)")
                }
            }
        }
    }
    
    func toggleFavorite(recipeId: String, userId: String, isFavorite: Bool) {
        let userRef = db.collection("users").document(userId)
        
        if isFavorite {
            // Add to favorites
            userRef.updateData([
                "favorites": FieldValue.arrayUnion([recipeId])
            ]) { [weak self] error in
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                }
            }
        } else {
            // Remove from favorites
            userRef.updateData([
                "favorites": FieldValue.arrayRemove([recipeId])
            ]) { [weak self] error in
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func fetchFavoriteRecipes(favoriteIds: [String]) {
        guard !favoriteIds.isEmpty else {
            recipes = []
            return
        }
        
        // Firestore has a limit on array-contains-any queries, so we'll chunk into batches of 10
        let chunks = favoriteIds.chunked(into: 10)
        var allRecipes: [Recipe] = []
        
        let dispatchGroup = DispatchGroup()
        
        for chunk in chunks {
            dispatchGroup.enter()
            
            db.collection("recipes").whereField(FieldPath.documentID(), in: chunk).getDocuments { [weak self] snapshot, error in
                defer { dispatchGroup.leave() }
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                
                if let documents = snapshot?.documents {
                    let chunkRecipes = documents.compactMap { document -> Recipe? in
                        let data = document.data()
                        
                        guard 
                            let name = data["name"] as? String,
                            let description = data["description"] as? String,
                            let ingredients = data["ingredients"] as? [String],
                            let instructions = data["instructions"] as? [String],
                            let preparationTime = data["preparationTime"] as? Int,
                            let difficultyString = data["difficulty"] as? String,
                            let difficulty = Recipe.Difficulty(rawValue: difficultyString),
                            let suitableForMoods = data["suitableForMoods"] as? [String],
                            let tags = data["tags"] as? [String]
                        else {
                            return nil
                        }
                        
                        let imageURL = data["imageURL"] as? String
                        let rating = data["rating"] as? Double
                        
                        return Recipe(
                            id: document.documentID,
                            name: name,
                            description: description,
                            ingredients: ingredients,
                            instructions: instructions,
                            preparationTime: preparationTime,
                            difficulty: difficulty,
                            imageURL: imageURL,
                            suitableForMoods: suitableForMoods,
                            tags: tags,
                            rating: rating
                        )
                    }
                    
                    allRecipes.append(contentsOf: chunkRecipes)
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) { [weak self] in
            self?.recipes = allRecipes
        }
    }
    
    // Funktion zum Speichern eines benutzerdefinierten Rezepts
    func saveRecipe(recipe: Recipe, completion: @escaping (Bool) -> Void) {
        // Erstelle ein Dictionary aus dem Rezept
        let recipeData = recipe.dictionary
        
        // Speichere das Rezept in Firestore
        print("Speichere Rezept in Firestore: \(recipe.name)")
        
        db.collection("recipes").document(recipe.id).setData(recipeData) { error in
            if let error = error {
                print("Fehler beim Speichern des Rezepts: \(error.localizedDescription)")
                self.errorMessage = error.localizedDescription
                completion(false)
                return
            }
            
            print("Rezept erfolgreich gespeichert!")
            
            // Aktualisiere die lokale Rezeptliste
            DispatchQueue.main.async {
                // Füge das neue Rezept zur aktuellen Liste hinzu
                if !self.recipes.contains(where: { $0.id == recipe.id }) {
                    self.recipes.append(recipe)
                }
                completion(true)
            }
        }
    }
    
    // Funktion zum Laden eines einzelnen Rezepts anhand seiner ID
    func fetchRecipeById(recipeId: String, completion: @escaping (Result<Recipe, Error>) -> Void) {
        print("Lade Rezept mit ID: \(recipeId)")
        
        db.collection("recipes").document(recipeId).getDocument { snapshot, error in
            if let error = error {
                print("Fehler beim Laden des Rezepts: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let snapshot = snapshot, snapshot.exists, let data = snapshot.data() else {
                let noDataError = NSError(domain: "RecipeManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Rezept nicht gefunden"])
                print("Rezept mit ID \(recipeId) nicht gefunden")
                completion(.failure(noDataError))
                return
            }
            
            guard 
                let name = data["name"] as? String,
                let description = data["description"] as? String,
                let ingredients = data["ingredients"] as? [String],
                let instructions = data["instructions"] as? [String],
                let preparationTime = data["preparationTime"] as? Int,
                let difficultyString = data["difficulty"] as? String,
                let difficulty = Recipe.Difficulty(rawValue: difficultyString),
                let suitableForMoods = data["suitableForMoods"] as? [String],
                let tags = data["tags"] as? [String]
            else {
                let invalidDataError = NSError(domain: "RecipeManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Ungültige Rezeptdaten"])
                print("Ungültige Daten für Rezept mit ID \(recipeId)")
                completion(.failure(invalidDataError))
                return
            }
            
            let imageURL = data["imageURL"] as? String
            let rating = data["rating"] as? Double
            
            let recipe = Recipe(
                id: recipeId,
                name: name,
                description: description,
                ingredients: ingredients,
                instructions: instructions,
                preparationTime: preparationTime,
                difficulty: difficulty,
                imageURL: imageURL,
                suitableForMoods: suitableForMoods,
                tags: tags,
                rating: rating
            )
            
            print("Rezept \(name) erfolgreich geladen")
            completion(.success(recipe))
        }
    }
    
    // Hilfsfunktionen für Deutsch/Englisch-Übersetzungen
    private func getEnglishTerms(forGermanIngredient german: String) -> [String] {
        let translations: [String: [String]] = [
            "eier": ["eggs", "egg"],
            "nudeln": ["pasta", "noodles", "spaghetti", "macaroni"],
            "tomaten": ["tomato", "tomatoes"],
            "schinken": ["ham", "prosciutto"],
            "pesto": ["pesto"],
            "thunfisch": ["tuna", "tuna fish"],
            "spaghetti": ["spaghetti", "pasta"],
            "käse": ["cheese"],
            "zwiebeln": ["onion", "onions"],
            "knoblauch": ["garlic"],
            "olivenöl": ["olive oil"],
            "salz": ["salt"],
            "pfeffer": ["pepper"],
            "kartoffeln": ["potato", "potatoes"],
            "reis": ["rice"]
        ]
        
        // Suche nach Übereinstimmungen
        for (germanKey, englishValues) in translations {
            if german.contains(germanKey) {
                return englishValues
            }
        }
        
        return []
    }
    
    private func getGermanTerms(forEnglishIngredient english: String) -> [String] {
        let translations: [String: [String]] = [
            "eggs": ["eier", "ei"],
            "egg": ["eier", "ei"],
            "pasta": ["nudeln", "pasta", "spaghetti"],
            "noodles": ["nudeln"],
            "tomato": ["tomaten", "tomate"],
            "tomatoes": ["tomaten", "tomate"],
            "ham": ["schinken"],
            "tuna": ["thunfisch"],
            "spaghetti": ["spaghetti"],
            "cheese": ["käse"],
            "onion": ["zwiebel", "zwiebeln"],
            "onions": ["zwiebeln", "zwiebel"],
            "garlic": ["knoblauch"],
            "olive oil": ["olivenöl"],
            "salt": ["salz"],
            "pepper": ["pfeffer"],
            "potato": ["kartoffel", "kartoffeln"],
            "potatoes": ["kartoffeln", "kartoffel"],
            "rice": ["reis"]
        ]
        
        // Suche nach Übereinstimmungen
        for (englishKey, germanValues) in translations {
            if english.contains(englishKey) {
                return germanValues
            }
        }
        
        return []
    }
}

// Helper extension for chunking arrays
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
} 