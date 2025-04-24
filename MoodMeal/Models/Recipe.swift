//
//  Recipe.swift
//  MoodMeal
//
//  Created by Naím Rodriguez Caballero on 21.04.25.
//

import Foundation

struct Recipe: Identifiable, Codable {
    var id: String
    var name: String
    var description: String
    var ingredients: [String]
    var instructions: [String]
    var preparationTime: Int // in minutes
    var difficulty: Difficulty
    var imageURL: String?
    var suitableForMoods: [String]
    var tags: [String]
    var rating: Double?
    var creatorId: String? // ID des Nutzers, der das Rezept erstellt hat
    
    enum Difficulty: String, Codable, CaseIterable {
        case easy = "Easy"
        case medium = "Medium"
        case hard = "Hard"
    }
    
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "name": name,
            "description": description,
            "ingredients": ingredients,
            "instructions": instructions,
            "preparationTime": preparationTime,
            "difficulty": difficulty.rawValue,
            "imageURL": imageURL ?? "",
            "suitableForMoods": suitableForMoods,
            "tags": tags,
            "rating": rating ?? 0.0
        ]
        
        if let creatorId = creatorId {
            dict["creatorId"] = creatorId
        }
        
        return dict
    }
}

// Hinzufügen einer Debug-Extension für bessere Fehlersuche
extension Recipe {
    static func debugPrint(recipe: Recipe) {
        print("Rezept-Debug: ID=\(recipe.id), Name=\(recipe.name)")
        print("  - Geeignet für Stimmungen: \(recipe.suitableForMoods.joined(separator: ", "))")
        print("  - Tags: \(recipe.tags.joined(separator: ", "))")
        print("  - Anzahl Zutaten: \(recipe.ingredients.count)")
        if let creatorId = recipe.creatorId {
            print("  - Erstellt von: \(creatorId)")
        }
    }
} 