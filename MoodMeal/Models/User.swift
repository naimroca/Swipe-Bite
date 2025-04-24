//
//  User.swift
//  MoodMeal
//
//  Created by Naím Rodriguez Caballero on 21.04.25.
//

import Foundation
import FirebaseAuth

struct User: Identifiable, Codable {
    var id: String
    var email: String
    var username: String
    var favorites: [String] = []
    var currentMood: Mood?
    var pantryIngredients: [PantryIngredient] = []
    var cookedRecipes: [CookedRecipe] = []
    
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "email": email,
            "username": username,
            "favorites": favorites,
            "currentMood": currentMood?.rawValue ?? ""
        ]
        
        if !pantryIngredients.isEmpty {
            let pantryData = pantryIngredients.map { $0.dictionary }
            dict["pantryIngredients"] = pantryData
        }
        
        if !cookedRecipes.isEmpty {
            let cookedData = cookedRecipes.map { $0.dictionary }
            dict["cookedRecipes"] = cookedData
        }
        
        return dict
    }
}

struct PantryIngredient: Identifiable, Codable, Hashable {
    var id = UUID().uuidString
    var name: String
    var quantity: Double?
    var unit: String?
    var expiryDate: Date?
    var isUsed: Bool = false
    
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "name": name,
            "isUsed": isUsed
        ]
        
        if let quantity = quantity {
            dict["quantity"] = quantity
        }
        
        if let unit = unit {
            dict["unit"] = unit
        }
        
        if let expiryDate = expiryDate {
            dict["expiryDate"] = expiryDate.timeIntervalSince1970
        }
        
        return dict
    }
}

enum Mood: String, CaseIterable, Identifiable, Codable {
    case happy = "Happy"
    case sad = "Sad"
    case energetic = "Energetic"
    case tired = "Tired"
    case stressed = "Stressed"
    case calm = "Calm"
    
    var id: String { self.rawValue }
    
    var recommendedFoodTypes: [String] {
        switch self {
        case .happy:
            return ["Festive", "Colorful", "Diverse"]
        case .sad:
            return ["Comforting", "Warm", "Sweet"]
        case .energetic:
            return ["Light", "Fresh", "Protein-rich"]
        case .tired:
            return ["Energizing", "Nutrient-dense", "Carb-rich"]
        case .stressed:
            return ["Calming", "Magnesium-rich", "Soothing"]
        case .calm:
            return ["Balanced", "Light", "Healthy"]
        }
    }
    
    var icon: String {
        switch self {
        case .happy: return "face.smiling"
        case .sad: return "cloud.rain"
        case .energetic: return "bolt"
        case .tired: return "zzz"
        case .stressed: return "exclamationmark.triangle"
        case .calm: return "leaf"
        }
    }
}

struct CookedRecipe: Identifiable, Codable, Hashable {
    var id = UUID().uuidString
    var recipeId: String
    var recipeName: String
    var cookingDate: Date
    var imageURL: String?
    
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "recipeId": recipeId,
            "recipeName": recipeName,
            "cookingDate": cookingDate.timeIntervalSince1970
        ]
        
        if let imageURL = imageURL {
            dict["imageURL"] = imageURL
        }
        
        return dict
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: cookingDate)
    }
    
    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: cookingDate)
    }
} 