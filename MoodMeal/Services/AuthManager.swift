//
//  AuthManager.swift
//  MoodMeal
//
//  Created by Naím Rodriguez Caballero on 21.04.25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

class AuthManager: ObservableObject {
    @Published var user: User?
    @Published var isAuthenticated = false
    @Published var errorMessage = ""
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    init() {
        auth.addStateDidChangeListener { [weak self] _, firebaseUser in
            if let firebaseUser = firebaseUser {
                self?.fetchUserData(userId: firebaseUser.uid)
            } else {
                self?.isAuthenticated = false
                self?.user = nil
            }
        }
    }
    
    func signIn(email: String, password: String) {
        auth.signIn(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
                return
            }
            
            if let userId = result?.user.uid {
                self?.fetchUserData(userId: userId)
            }
        }
    }
    
    func signUp(email: String, password: String, username: String) {
        auth.createUser(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
                return
            }
            
            if let userId = result?.user.uid {
                let newUser = User(id: userId, email: email, username: username)
                self?.saveUserData(user: newUser)
            }
        }
    }
    
    func signOut() {
        do {
            try auth.signOut()
            isAuthenticated = false
            user = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func updateMood(mood: Mood) {
        guard let userId = user?.id else { return }
        
        var updatedUser = user
        updatedUser?.currentMood = mood
        
        if let updatedUser = updatedUser {
            saveUserData(user: updatedUser)
        }
    }
    
    // MARK: - Pantry Management
    
    func addToPantry(ingredient: PantryIngredient) {
        guard var currentUser = user else { 
            print("Fehler: Kein Benutzer angemeldet")
            return 
        }
        
        print("Füge Zutat zur Vorratskammer hinzu: \(ingredient.name)")
        
        // Prüfen, ob Zutat bereits im Vorrat existiert
        if let index = currentUser.pantryIngredients.firstIndex(where: { $0.name.lowercased() == ingredient.name.lowercased() }) {
            // Aktualisieren der vorhandenen Zutat
            print("Aktualisiere bestehende Zutat")
            currentUser.pantryIngredients[index] = ingredient
        } else {
            // Neue Zutat hinzufügen
            print("Füge neue Zutat hinzu")
            currentUser.pantryIngredients.append(ingredient)
        }
        
        user = currentUser
        print("Speichere aktualisierte Benutzerdaten mit \(currentUser.pantryIngredients.count) Zutaten")
        saveUserData(user: currentUser)
    }
    
    func removeFromPantry(ingredientId: String) {
        guard var currentUser = user else { return }
        
        currentUser.pantryIngredients.removeAll { $0.id == ingredientId }
        
        user = currentUser
        saveUserData(user: currentUser)
    }
    
    func markIngredientAsUsed(ingredientId: String, isUsed: Bool) {
        guard var currentUser = user else { return }
        
        if let index = currentUser.pantryIngredients.firstIndex(where: { $0.id == ingredientId }) {
            currentUser.pantryIngredients[index].isUsed = isUsed
            
            user = currentUser
            saveUserData(user: currentUser)
        }
    }
    
    // MARK: - Rezept-Kochplanung
    
    func addCookedRecipe(recipe: Recipe) {
        guard var currentUser = user else { return }
        
        let cookedRecipe = CookedRecipe(
            recipeId: recipe.id,
            recipeName: recipe.name,
            cookingDate: Date(),
            imageURL: recipe.imageURL
        )
        
        // Bestehende gekochte Rezepte beibehalten und neues hinzufügen
        currentUser.cookedRecipes.append(cookedRecipe)
        
        // Nach Datum sortieren (neueste zuerst)
        currentUser.cookedRecipes.sort { $0.cookingDate > $1.cookingDate }
        
        user = currentUser
        saveUserData(user: currentUser)
    }
    
    // Neue Methode zur Verwendung in der RecipeSwipeView
    func markRecipeAsCooked(recipeId: String, recipeName: String, imageURL: String?) {
        guard var currentUser = user else { return }
        
        let cookedRecipe = CookedRecipe(
            recipeId: recipeId,
            recipeName: recipeName,
            cookingDate: Date(),
            imageURL: imageURL
        )
        
        // Bestehende gekochte Rezepte beibehalten und neues hinzufügen
        currentUser.cookedRecipes.append(cookedRecipe)
        
        // Nach Datum sortieren (neueste zuerst)
        currentUser.cookedRecipes.sort { $0.cookingDate > $1.cookingDate }
        
        user = currentUser
        saveUserData(user: currentUser)
    }
    
    func getWeeklyMealPlan() -> [String: [CookedRecipe]] {
        guard let currentUser = user else { return [:] }
        
        // Nur Rezepte der letzten 7 Tage berücksichtigen
        let calendar = Calendar.current
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        let recentlyCooked = currentUser.cookedRecipes.filter { $0.cookingDate >= oneWeekAgo }
        
        // Nach Wochentagen gruppieren
        var mealPlan: [String: [CookedRecipe]] = [:]
        
        for recipe in recentlyCooked {
            let dayOfWeek = recipe.dayOfWeek
            if mealPlan[dayOfWeek] == nil {
                mealPlan[dayOfWeek] = []
            }
            mealPlan[dayOfWeek]?.append(recipe)
        }
        
        return mealPlan
    }
    
    private func saveUserData(user: User) {
        print("Versuche, Benutzerdaten zu speichern: \(user.id)")
        print("Anzahl der Vorratszutaten: \(user.pantryIngredients.count)")
        
        // Log dictionary für Debugging
        let userDict = user.dictionary
        print("User dictionary: \(userDict)")
        
        db.collection("users").document(user.id).setData(userDict) { [weak self] error in
            if let error = error {
                print("Fehler beim Speichern der Benutzerdaten: \(error.localizedDescription)")
                self?.errorMessage = error.localizedDescription
                return
            }
            
            print("Benutzerdaten erfolgreich gespeichert!")
            self?.user = user
            self?.isAuthenticated = true
        }
    }
    
    private func fetchUserData(userId: String) {
        db.collection("users").document(userId).getDocument { [weak self] snapshot, error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
                return
            }
            
            if let data = snapshot?.data(),
               let email = data["email"] as? String,
               let username = data["username"] as? String {
                
                var favorites: [String] = []
                if let favs = data["favorites"] as? [String] {
                    favorites = favs
                }
                
                var currentMood: Mood?
                if let moodString = data["currentMood"] as? String, !moodString.isEmpty {
                    currentMood = Mood(rawValue: moodString)
                }
                
                var pantryIngredients: [PantryIngredient] = []
                if let pantryData = data["pantryIngredients"] as? [[String: Any]] {
                    for ingredientData in pantryData {
                        guard let id = ingredientData["id"] as? String,
                              let name = ingredientData["name"] as? String else {
                            continue
                        }
                        
                        var ingredient = PantryIngredient(id: id, name: name)
                        
                        if let quantity = ingredientData["quantity"] as? Double {
                            ingredient.quantity = quantity
                        }
                        
                        if let unit = ingredientData["unit"] as? String {
                            ingredient.unit = unit
                        }
                        
                        if let expiryTimestamp = ingredientData["expiryDate"] as? TimeInterval {
                            ingredient.expiryDate = Date(timeIntervalSince1970: expiryTimestamp)
                        }
                        
                        if let isUsed = ingredientData["isUsed"] as? Bool {
                            ingredient.isUsed = isUsed
                        }
                        
                        pantryIngredients.append(ingredient)
                    }
                }
                
                // Geladene gekochte Rezepte
                var cookedRecipes: [CookedRecipe] = []
                if let cookedData = data["cookedRecipes"] as? [[String: Any]] {
                    for cookedRecipeData in cookedData {
                        guard let id = cookedRecipeData["id"] as? String,
                              let recipeId = cookedRecipeData["recipeId"] as? String,
                              let recipeName = cookedRecipeData["recipeName"] as? String,
                              let cookingTimestamp = cookedRecipeData["cookingDate"] as? TimeInterval else {
                            continue
                        }
                        
                        var cookedRecipe = CookedRecipe(
                            id: id,
                            recipeId: recipeId,
                            recipeName: recipeName,
                            cookingDate: Date(timeIntervalSince1970: cookingTimestamp)
                        )
                        
                        if let imageURL = cookedRecipeData["imageURL"] as? String {
                            cookedRecipe.imageURL = imageURL
                        }
                        
                        cookedRecipes.append(cookedRecipe)
                    }
                    
                    // Nach Datum sortieren (neueste zuerst)
                    cookedRecipes.sort { $0.cookingDate > $1.cookingDate }
                }
                
                let user = User(
                    id: userId,
                    email: email,
                    username: username,
                    favorites: favorites,
                    currentMood: currentMood,
                    pantryIngredients: pantryIngredients,
                    cookedRecipes: cookedRecipes
                )
                
                self?.user = user
                self?.isAuthenticated = true
                
                print("Benutzerdaten geladen: \(username)")
                print("Stimmung: \(currentMood?.rawValue ?? "keine")")
                print("Anzahl Zutaten in Vorratskammer: \(pantryIngredients.count)")
                print("Anzahl Favoriten: \(favorites.count)")
                print("Anzahl gekochter Rezepte: \(cookedRecipes.count)")
            }
        }
    }
} 