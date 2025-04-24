//
//  RecipeAPI.swift
//  MoodMeal
//
//  Created by Naím Rodriguez Caballero on 21.04.25.
//

import Foundation
import FirebaseFirestore

// Gustar.io API-Strukturen
struct GustarResponse: Codable {
    let recipes: [GustarRecipe]
}

struct GustarRecipe: Codable {
    let id: String
    let title: String
    let description: String?
    let ingredients: [String]
    let instructions: [String]
    let prepTime: Int?
    let imageUrl: String?
    let categories: [String]?
    let tags: [String]?
}

class RecipeAPI {
    static let shared = RecipeAPI()
    private let db = Firestore.firestore()
    
    // Gustar.io API von RapidAPI - ersetze dies mit deinen eigenen Zugangsdaten
    private let rapidAPIKey = "55518260f9msh43a385ecf6a005ep139704jsn79b97a7f6d7f" // ⚠️ Deinen eigenen Key hier eintragen
    private let rapidAPIHost = "gustar-io-deutsche-rezepte.p.rapidapi.com"
    private let baseURL = "https://gustar-io-deutsche-rezepte.p.rapidapi.com"
    
    func fetchAndStoreRecipes(query: String = "", completion: @escaping (Result<[Recipe], Error>) -> Void) {
        print("\n=== STARTE REZEPTSUCHE ===")
        print("Versuche, Rezepte zu laden für Suchanfrage: '\(query)'")
        
        // Für Testzwecke können wir die lokalen Fallback-Rezepte direkt verwenden
        // Comment this out when API should be used
        if let fallbackRecipes = createFallbackRecipes() {
            print("⚠️ HINWEIS: Verwende SOFORT lokale Fallback-Rezepte für schnelle Tests")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Kommentiere diese Zeile aus, um zu verhindern, dass die Rezepte bei jedem API-Aufruf gespeichert werden
                // self.storeRecipesInFirestore(recipes: fallbackRecipes)
                completion(.success(fallbackRecipes))
            }
            return
        }
        
        // Standard API-Aufruf (auskommentieren, um immer lokale Rezepte zu verwenden)
        /*
        // Verwende zuerst die primäre API-Methode
        fetchFromGustarIO(query: query) { [weak self] result in
            switch result {
            case .success(let recipes):
                // Erfolgreicher API-Aufruf
                // Kommentiere diese Zeile aus, um zu verhindern, dass die Rezepte bei jedem API-Aufruf gespeichert werden
                // self?.storeRecipesInFirestore(recipes: recipes)
                completion(.success(recipes))
                
            case .failure(let error):
                print("Primäre API-Anfrage fehlgeschlagen: \(error). Versuche Fallback-Methode...")
                
                // Wenn der primäre API-Endpunkt fehlschlägt, versuchen wir einen alternativen
                self?.fetchFromAlternativeAPI(query: query) { altResult in
                    switch altResult {
                    case .success(let recipes):
                        // Kommentiere diese Zeile aus, um zu verhindern, dass die Rezepte bei jedem API-Aufruf gespeichert werden
                        // self?.storeRecipesInFirestore(recipes: recipes)
                        completion(.success(recipes))
                        
                    case .failure(let altError):
                        print("Auch alternative API-Anfrage fehlgeschlagen: \(altError)")
                        
                        // Als letzter Ausweg verwenden wir lokale Beispielrezepte
                        if let fallbackRecipes = self?.createFallbackRecipes() {
                            print("Verwende lokale Fallback-Rezepte")
                            // Kommentiere diese Zeile aus, um zu verhindern, dass die Rezepte bei jedem API-Aufruf gespeichert werden
                            // self?.storeRecipesInFirestore(recipes: fallbackRecipes)
                            completion(.success(fallbackRecipes))
                        } else {
                            completion(.failure(altError))
                        }
                    }
                }
            }
        }
        */
    }
    
    /// Primäre Methode: Rezepte von Gustar.io API abrufen
    private func fetchFromGustarIO(query: String, completion: @escaping (Result<[Recipe], Error>) -> Void) {
        // Verwende die Suchendpunkte aus der Gustar.io API
        // Wenn die ursprüngliche URL nicht funktioniert, probieren wir einen anderen Endpunkt aus
        let endpoint = query.isEmpty ? "/recipes/random" : "/recipes/search"
        var urlString = "\(baseURL)\(endpoint)"
        
        // Füge Parameter hinzu
        if !query.isEmpty {
            urlString += "?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        } else {
            // Für zufällige Rezepte könnten Anzahl Parameter benötigt werden
            urlString += "?number=10" // Beispiel: 10 zufällige Rezepte anfordern
        }
        
        print("Starte primäre API-Anfrage an Gustar.io: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("Fehler: Ungültige URL")
            completion(.failure(NSError(domain: "RecipeAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Ungültige URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(rapidAPIKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.addValue(rapidAPIHost, forHTTPHeaderField: "X-RapidAPI-Host")
        
        // Timeout für den Fall, dass die API nicht antwortet
        request.timeoutInterval = 10
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("Primäre API Netzwerkfehler: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Primäre API-Antwort Status: \(httpResponse.statusCode)")
                
                // Headers für Debugging ausgeben
                print("Primäre API-Antwort-Header:")
                for (key, value) in httpResponse.allHeaderFields {
                    print("  \(key): \(value)")
                }
                
                if httpResponse.statusCode != 200 {
                    print("Primäre API-Fehler: Statuscode \(httpResponse.statusCode)")
                    completion(.failure(NSError(domain: "RecipeAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API error: \(httpResponse.statusCode)"])))
                    return
                }
            }
            
            guard let data = data else {
                print("Fehler: Keine Daten erhalten")
                completion(.failure(NSError(domain: "RecipeAPI", code: 2, userInfo: [NSLocalizedDescriptionKey: "Keine Daten erhalten"])))
                return
            }
            
            // Debug: Antwort anzeigen
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Primäre API-Antwort (vollständig):")
                print(jsonString)
                
                if jsonString.contains("error") || jsonString.contains("message") {
                    print("⚠️ Die Primäre API-Antwort enthält möglicherweise einen Fehler")
                }
            }
            
            do {
                // Gustar.io API-Struktur anpassen
                let recipes = try self?.parseGustarRecipes(from: data) ?? []
                
                if recipes.isEmpty {
                    print("⚠️ Keine Rezepte von der primären API erhalten oder Parsing-Fehler")
                    completion(.failure(NSError(domain: "RecipeAPI", code: 3, userInfo: [NSLocalizedDescriptionKey: "Keine Rezepte gefunden"])))
                    return
                }
                
                print("Erfolgreich \(recipes.count) Rezepte von der primären API erhalten")
                
                // Speichern der Rezepte in Firestore
                print("Speichere \(recipes.count) Rezepte in Firestore")
                // Kommentiere diese Zeile aus, um zu verhindern, dass die Rezepte bei jedem API-Aufruf gespeichert werden
                // self?.storeRecipesInFirestore(recipes: recipes)
                
                completion(.success(recipes))
            } catch {
                print("Fehler beim Parsen der primären API-Daten: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    /// Alternative Methode: Verwende eine andere RapidAPI als Fallback
    private func fetchFromAlternativeAPI(query: String, completion: @escaping (Result<[Recipe], Error>) -> Void) {
        // Diese Funktion würde eine alternative API als Fallback verwenden
        // Hier verwenden wir für das Beispiel die RecipesAPI von RapidAPI
        
        // Alternative API-Konfiguration
        let altHost = "recipesapi2.p.rapidapi.com"
        let altBaseURL = "https://recipesapi2.p.rapidapi.com"
        let endpoint = "/recipes"
        
        var urlComponents = URLComponents(string: "\(altBaseURL)\(endpoint)")
        urlComponents?.queryItems = [
            URLQueryItem(name: "q", value: query)
        ]
        
        guard let url = urlComponents?.url else {
            print("Fehler: Ungültige alternative API-URL")
            completion(.failure(NSError(domain: "RecipeAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Ungültige URL"])))
            return
        }
        
        print("Starte alternative API-Anfrage: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(rapidAPIKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.addValue(altHost, forHTTPHeaderField: "X-RapidAPI-Host")
        
        // Kurzes Timeout für schnelles Fehlschlagen
        request.timeoutInterval = 5
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            print("Alternative API-Antwort erhalten")
            
            if let error = error {
                print("Alternative API Netzwerkfehler: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Alternative API-Antwort Status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    print("Alternative API-Fehler: Statuscode \(httpResponse.statusCode)")
                    completion(.failure(NSError(domain: "RecipeAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API error: \(httpResponse.statusCode)"])))
                    return
                }
            }
            
            guard let data = data else {
                print("Fehler: Keine Daten von der alternativen API erhalten")
                completion(.failure(NSError(domain: "RecipeAPI", code: 2, userInfo: [NSLocalizedDescriptionKey: "Keine Daten erhalten"])))
                return
            }
            
            // Debug-Ausgabe der alternativen API-Antwort
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Alternative API-Antwort:")
                print(jsonString)
            }
            
            // Da diese API wahrscheinlich ein anderes Format hat, müssen wir sie anders parsen
            // Für dieses Beispiel verwenden wir direkt Fallback-Rezepte
            print("Verwende direkt Fallback-Rezepte, da die alternative API ein anderes Format hat")
            if let fallbackRecipes = self?.createFallbackRecipes() {
                // Kommentiere diese Zeile aus, um zu verhindern, dass die Rezepte bei jedem API-Aufruf gespeichert werden
                // self?.storeRecipesInFirestore(recipes: fallbackRecipes)
                completion(.success(fallbackRecipes))
            } else {
                completion(.failure(NSError(domain: "RecipeAPI", code: 4, userInfo: [NSLocalizedDescriptionKey: "Konnte keine Fallback-Rezepte erstellen"])))
            }
        }.resume()
    }
    
    private func parseGustarRecipes(from data: Data) throws -> [Recipe] {
        let decoder = JSONDecoder()
        
        // Wir versuchen zuerst, die Daten als Array von Rezepten zu parsen
        do {
            let gustarRecipes = try decoder.decode([GustarRecipe].self, from: data)
            return convertGustarRecipes(gustarRecipes)
        } catch let error1 {
            // Wenn das fehlschlägt, versuchen wir, es als einzelnes Objekt mit einem recipes-Array zu parsen
            do {
                let response = try decoder.decode(GustarResponse.self, from: data)
                return convertGustarRecipes(response.recipes)
            } catch let error2 {
                print("Konnte die API-Antwort nicht parsen. Fehler 1: \(error1)")
                print("Fehler 2: \(error2)")
                print("Rohformat: \(String(data: data, encoding: .utf8) ?? "nicht lesbar")")
                
                // Wenn beide Parsing-Versuche fehlschlagen, erstellen wir Beispielrezepte als Fallback
                if let fallbackRecipes = createFallbackRecipes() {
                    print("⚠️ Verwende Fallback-Rezepte, da das API-Parsen fehlgeschlagen ist")
                    return fallbackRecipes
                }
                
                throw error2
            }
        }
    }
    
    private func convertGustarRecipes(_ gustarRecipes: [GustarRecipe]) -> [Recipe] {
        return gustarRecipes.map { gustarRecipe in
            // Passende Stimmungen basierend auf Kategorien/Tags bestimmen
            let moodTags = getMoodsForGustarRecipe(recipe: gustarRecipe)
            
            // Schwierigkeitsgrad aus Zubereitungszeit ableiten
            let prepTime = gustarRecipe.prepTime ?? 30
            let difficulty = getDifficultyFromTime(minutes: prepTime)
            
            // Recipe-Objekt erstellen
            return Recipe(
                id: gustarRecipe.id,
                name: gustarRecipe.title,
                description: gustarRecipe.description ?? "Ein leckeres deutsches Rezept",
                ingredients: gustarRecipe.ingredients,
                instructions: gustarRecipe.instructions,
                preparationTime: prepTime,
                difficulty: difficulty,
                imageURL: gustarRecipe.imageUrl,
                suitableForMoods: moodTags,
                tags: gustarRecipe.tags ?? gustarRecipe.categories ?? []
            )
        }
    }
    
    private func getMoodsForGustarRecipe(recipe: GustarRecipe) -> [String] {
        var moods: [String] = []
        let categories = recipe.categories ?? []
        let tags = recipe.tags ?? []
        let allTags = categories + tags
        
        // Deutsche Kategorien zu Stimmungen zuordnen
        if allTags.contains(where: { $0.lowercased().contains("leicht") || $0.lowercased().contains("frisch") }) {
            moods.append(Mood.energetic.rawValue)
            moods.append(Mood.calm.rawValue)
        }
        
        if allTags.contains(where: { $0.lowercased().contains("fest") || $0.lowercased().contains("party") }) {
            moods.append(Mood.happy.rawValue)
        }
        
        if allTags.contains(where: { $0.lowercased().contains("suppe") || $0.lowercased().contains("eintopf") || $0.lowercased().contains("comfort") }) {
            moods.append(Mood.sad.rawValue)
        }
        
        if allTags.contains(where: { $0.lowercased().contains("frühstück") || $0.lowercased().contains("snack") || $0.lowercased().contains("energie") }) {
            moods.append(Mood.tired.rawValue)
        }
        
        if allTags.contains(where: { $0.lowercased().contains("salat") || $0.lowercased().contains("gesund") || $0.lowercased().contains("beruhigend") }) {
            moods.append(Mood.stressed.rawValue)
        }
        
        // Zufällige Stimmung als Fallback
        if moods.isEmpty {
            moods.append(Mood.allCases.randomElement()!.rawValue)
        }
        
        return moods
    }
    
    private func storeRecipesInFirestore(recipes: [Recipe]) {
        print("Beginne das Speichern von \(recipes.count) Rezepten in Firestore")
        let batch = db.batch()
        
        for (index, recipe) in recipes.enumerated() {
            let recipeRef = db.collection("recipes").document(recipe.id)
            
            // Zeige mehr Details für die ersten Rezepte
            if index < 3 {
                print("Speichere Rezept #\(index): \(recipe.name) (ID: \(recipe.id))")
                print("  - Geeignet für Stimmungen: \(recipe.suitableForMoods.joined(separator: ", "))")
                print("  - Tags: \(recipe.tags.joined(separator: ", "))")
                print("  - Anzahl Zutaten: \(recipe.ingredients.count)")
            }
            
            batch.setData(recipe.dictionary, forDocument: recipeRef, merge: true)
        }
        
        print("RecipeAPI: Commit Batch-Operation mit \(recipes.count) Rezepten...")
        batch.commit { error in
            if let error = error {
                print("Fehler beim Speichern der Rezepte in Firestore: \(error)")
            } else {
                print("Alle \(recipes.count) Rezepte erfolgreich in Firestore gespeichert")
                print("RecipeAPI: Sie sollten jetzt über RecipeManager.fetchRecipes() abrufbar sein")
            }
        }
    }
    
    private func getDifficultyFromTime(minutes: Int) -> Recipe.Difficulty {
        switch minutes {
        case 0..<30:
            return .easy
        case 30..<60:
            return .medium
        default:
            return .hard
        }
    }
    
    /// Erstellt einige Fallback-Rezepte, falls die API nicht funktioniert
    private func createFallbackRecipes() -> [Recipe]? {
        print("Erstelle lokale Fallback-Rezepte...")
        // Einfache deutsche Rezepte, die immer funktionieren, falls die API nicht antwortet
        let fallbackRecipes: [Recipe] = [
            Recipe(
                id: UUID().uuidString,
                name: "Spaghetti Bolognese",
                description: "Ein klassisches italienisches Gericht mit Hackfleischsoße und Pasta.",
                ingredients: [
                    "500g Spaghetti",
                    "400g Rinderhackfleisch",
                    "2 Zwiebeln, gewürfelt",
                    "2 Knoblauchzehen, gehackt",
                    "2 Karotten, gewürfelt",
                    "2 Stangen Sellerie, gewürfelt",
                    "400g Dosentomaten, gestückelt",
                    "2 EL Tomatenmark",
                    "200ml Rinderbrühe",
                    "2 EL Olivenöl",
                    "1 TL Oregano",
                    "1 TL Basilikum",
                    "Salz und Pfeffer nach Geschmack",
                    "Parmesan zum Servieren"
                ],
                instructions: [
                    "Erhitze das Olivenöl in einer großen Pfanne und brate die Zwiebeln und den Knoblauch glasig an.",
                    "Füge das Hackfleisch hinzu und brate es krümelig an.",
                    "Gib die gewürfelten Karotten und den Sellerie hinzu und brate alles weitere 5 Minuten.",
                    "Rühre das Tomatenmark ein und lasse es kurz anrösten.",
                    "Füge die gestückelten Tomaten und die Brühe hinzu.",
                    "Würze mit Oregano, Basilikum, Salz und Pfeffer.",
                    "Lasse die Soße bei niedriger Hitze etwa 30 Minuten köcheln.",
                    "Koche in der Zwischenzeit die Spaghetti nach Packungsanweisung al dente.",
                    "Serviere die Spaghetti mit der Bolognese und frisch geriebenem Parmesan."
                ],
                preparationTime: 45,
                difficulty: .medium,
                imageURL: "https://images.unsplash.com/photo-1598866594230-a7c12756260f?q=80&w=1000",
                suitableForMoods: [Mood.happy.rawValue, Mood.sad.rawValue],
                tags: ["Italienisch", "Pasta", "Hauptgericht", "Nudeln"]
            ),
            Recipe(
                id: UUID().uuidString,
                name: "Kartoffelsalat",
                description: "Ein traditioneller deutscher Kartoffelsalat mit Gurken und Zwiebeln.",
                ingredients: [
                    "1kg festkochende Kartoffeln",
                    "1 Zwiebel, fein gewürfelt",
                    "1 Salatgurke, gewürfelt",
                    "3 Gewürzgurken, gewürfelt",
                    "4 EL Mayonnaise",
                    "2 EL Naturjoghurt",
                    "2 EL Gurkenwasser",
                    "1 TL Senf",
                    "2 EL frischer Dill, gehackt",
                    "Salz und Pfeffer nach Geschmack"
                ],
                instructions: [
                    "Kartoffeln in Salzwasser kochen, bis sie gar, aber noch fest sind.",
                    "Kartoffeln abkühlen lassen, schälen und in Scheiben schneiden.",
                    "Zwiebeln, Gurken und Gewürzgurken in einer großen Schüssel mit den Kartoffeln vermischen.",
                    "Mayonnaise, Joghurt, Gurkenwasser und Senf zu einer Soße verrühren.",
                    "Die Soße über den Kartoffelsalat gießen und vorsichtig unterheben.",
                    "Mit Dill, Salz und Pfeffer abschmecken.",
                    "Vor dem Servieren mindestens 1 Stunde im Kühlschrank ziehen lassen."
                ],
                preparationTime: 40,
                difficulty: .easy,
                imageURL: "https://images.unsplash.com/photo-1576007471877-1466ba3df5ea?q=80&w=1000",
                suitableForMoods: [Mood.happy.rawValue, Mood.energetic.rawValue],
                tags: ["Deutsch", "Beilage", "Vegetarisch", "Kalt", "Kartoffeln"]
            ),
            Recipe(
                id: UUID().uuidString,
                name: "Apfelstrudel",
                description: "Ein klassisches österreichisches Dessert mit Äpfeln und Zimt.",
                ingredients: [
                    "300g Blätterteig",
                    "6 Äpfel, geschält und in dünne Scheiben geschnitten",
                    "100g Zucker",
                    "1 TL Zimt",
                    "50g Rosinen (optional)",
                    "50g gehackte Walnüsse",
                    "2 EL Zitronensaft",
                    "50g Butter, geschmolzen",
                    "Puderzucker zum Bestäuben"
                ],
                instructions: [
                    "Heize den Backofen auf 180°C vor.",
                    "Vermische die Apfelscheiben mit Zucker, Zimt, Rosinen, Walnüssen und Zitronensaft.",
                    "Rolle den Blätterteig dünn aus und bestreiche ihn mit etwas geschmolzener Butter.",
                    "Verteile die Apfelmischung auf dem Teig, lasse an den Rändern etwas Platz.",
                    "Rolle den Teig vorsichtig auf und verschließe die Enden.",
                    "Lege den Strudel auf ein mit Backpapier ausgelegtes Backblech.",
                    "Bestreiche den Strudel mit der restlichen geschmolzenen Butter.",
                    "Backe ihn für etwa 30-35 Minuten, bis er goldbraun ist.",
                    "Lass den Strudel etwas abkühlen und bestäube ihn mit Puderzucker vor dem Servieren."
                ],
                preparationTime: 60,
                difficulty: .medium,
                imageURL: "https://images.unsplash.com/photo-1566653166796-d6c33b496650?q=80&w=1000",
                suitableForMoods: [Mood.happy.rawValue, Mood.calm.rawValue],
                tags: ["Österreichisch", "Dessert", "Süß", "Gebäck", "Äpfel"]
            ),
            Recipe(
                id: UUID().uuidString,
                name: "Pfannkuchen",
                description: "Fluffige deutsche Pfannkuchen, die süß oder herzhaft serviert werden können.",
                ingredients: [
                    "250g Mehl",
                    "500ml Milch",
                    "3 Eier",
                    "1 Prise Salz",
                    "1 EL Zucker",
                    "2 EL Butter zum Braten",
                    "Marmelade, Nutella oder Zimt-Zucker zum Servieren"
                ],
                instructions: [
                    "Mehl, Milch, Eier, Salz und Zucker zu einem glatten Teig verrühren.",
                    "Den Teig etwa 15 Minuten ruhen lassen.",
                    "Butter in einer Pfanne erhitzen.",
                    "Eine kleine Kelle Teig in die heiße Pfanne geben und schwenken, um ihn gleichmäßig zu verteilen.",
                    "Bei mittlerer Hitze backen, bis die Unterseite goldbraun ist.",
                    "Den Pfannkuchen wenden und die andere Seite goldbraun backen.",
                    "Mit süßen oder herzhaften Füllungen servieren."
                ],
                preparationTime: 30,
                difficulty: .easy,
                imageURL: "https://images.unsplash.com/photo-1565299543923-37dd37887442?q=80&w=1000",
                suitableForMoods: [Mood.happy.rawValue, Mood.calm.rawValue, Mood.tired.rawValue],
                tags: ["Deutsch", "Frühstück", "Süß", "Dessert", "Eier"]
            ),
            Recipe(
                id: UUID().uuidString,
                name: "Gulaschsuppe",
                description: "Eine herzhafte ungarisch inspirierte Suppe mit zartem Rindfleisch und Paprika.",
                ingredients: [
                    "500g Rindergulasch, in Würfel geschnitten",
                    "2 Zwiebeln, gewürfelt",
                    "2 Knoblauchzehen, gehackt",
                    "2 Paprikaschoten, gewürfelt",
                    "2 Karotten, in Scheiben geschnitten",
                    "2 Kartoffeln, gewürfelt",
                    "2 EL Tomatenmark",
                    "2 EL Paprikapulver",
                    "1 TL Kreuzkümmel",
                    "1 L Rinderbrühe",
                    "2 EL Öl",
                    "Salz und Pfeffer nach Geschmack",
                    "Saure Sahne zum Servieren"
                ],
                instructions: [
                    "Öl in einem großen Topf erhitzen und das Fleisch darin anbraten.",
                    "Zwiebeln und Knoblauch hinzufügen und glasig dünsten.",
                    "Tomatenmark und Paprikapulver unterrühren und kurz anrösten.",
                    "Paprika, Karotten und Kartoffeln hinzufügen und kurz mitbraten.",
                    "Mit Rinderbrühe ablöschen und zum Kochen bringen.",
                    "Mit Kreuzkümmel, Salz und Pfeffer würzen.",
                    "Bei niedriger Hitze etwa 1,5 Stunden köcheln lassen, bis das Fleisch zart ist.",
                    "Mit einem Klecks saurer Sahne und frischem Brot servieren."
                ],
                preparationTime: 120,
                difficulty: .medium,
                imageURL: "https://images.unsplash.com/photo-1547592166-23ac45744acd?q=80&w=1000",
                suitableForMoods: [Mood.sad.rawValue, Mood.stressed.rawValue],
                tags: ["Ungarisch", "Suppe", "Eintopf", "Rindfleisch", "Herzhaft"]
            ),
            Recipe(
                id: UUID().uuidString,
                name: "Käsespätzle",
                description: "Ein beliebtes schwäbisches Gericht mit selbstgemachten Spätzle und würzigem Käse.",
                ingredients: [
                    "400g Mehl",
                    "4 Eier",
                    "200ml Wasser",
                    "1 TL Salz",
                    "200g geriebener Bergkäse",
                    "100g geriebener Emmentaler",
                    "2 Zwiebeln, in Ringe geschnitten",
                    "2 EL Butter",
                    "Frisch gehackte Petersilie zum Garnieren"
                ],
                instructions: [
                    "Mehl, Eier, Wasser und Salz zu einem zähen Teig verarbeiten.",
                    "Einen großen Topf mit Salzwasser zum Kochen bringen.",
                    "Den Teig durch ein Spätzlesieb in das kochende Wasser drücken.",
                    "Die Spätzle sind fertig, wenn sie an die Oberfläche steigen (ca. 2-3 Minuten).",
                    "Spätzle abgießen und kurz kalt abschrecken.",
                    "Die Zwiebeln in Butter goldbraun anbraten.",
                    "Spätzle in eine Auflaufform geben, mit Käse schichten und mit Röstzwiebeln bestreuen.",
                    "Im vorgeheizten Ofen bei 180°C für 15 Minuten überbacken, bis der Käse geschmolzen ist.",
                    "Mit frischer Petersilie garnieren und sofort servieren."
                ],
                preparationTime: 45,
                difficulty: .medium,
                imageURL: "https://images.unsplash.com/photo-1632778149955-e80f8ceca2e8?q=80&w=1000",
                suitableForMoods: [Mood.happy.rawValue, Mood.sad.rawValue, Mood.stressed.rawValue],
                tags: ["Deutsch", "Schwäbisch", "Hauptgericht", "Käse", "Vegetarisch"]
            ),
            Recipe(
                id: UUID().uuidString,
                name: "Grüner Smoothie",
                description: "Ein energiegeladener Smoothie mit Spinat, Banane und Apfel.",
                ingredients: [
                    "1 Handvoll frischer Spinat",
                    "1 reife Banane",
                    "1 grüner Apfel, gewürfelt",
                    "1 EL Chiasamen",
                    "1 EL Honig oder Agavendicksaft",
                    "200ml Wasser oder Mandelmilch",
                    "Saft einer halben Zitrone",
                    "Eiswürfel nach Belieben"
                ],
                instructions: [
                    "Alle Zutaten in einen Mixer geben.",
                    "Alles zu einer glatten Masse pürieren, bis keine Klumpen mehr vorhanden sind.",
                    "Bei Bedarf mehr Flüssigkeit hinzufügen, um die gewünschte Konsistenz zu erreichen.",
                    "In ein Glas füllen und sofort genießen."
                ],
                preparationTime: 10,
                difficulty: .easy,
                imageURL: "https://images.unsplash.com/photo-1577805947697-89e18249d767?q=80&w=1000",
                suitableForMoods: [Mood.energetic.rawValue, Mood.tired.rawValue, Mood.stressed.rawValue],
                tags: ["Getränk", "Frühstück", "Gesund", "Vegan", "Schnell"]
            ),
            Recipe(
                id: UUID().uuidString,
                name: "Rote Linsensuppe",
                description: "Eine wärmende, proteinreiche Suppe, perfekt für kühle Tage.",
                ingredients: [
                    "250g rote Linsen",
                    "1 Zwiebel, gewürfelt",
                    "2 Karotten, gewürfelt",
                    "1 Kartoffel, gewürfelt",
                    "2 EL Olivenöl",
                    "1 TL Kreuzkümmel",
                    "1 TL Kurkuma",
                    "1 TL Paprikapulver",
                    "1L Gemüsebrühe",
                    "Saft einer halben Zitrone",
                    "Frische Petersilie zum Garnieren",
                    "Salz und Pfeffer nach Geschmack"
                ],
                instructions: [
                    "Linsen gründlich waschen und abtropfen lassen.",
                    "Olivenöl in einem Topf erhitzen und Zwiebeln darin glasig dünsten.",
                    "Karotten und Kartoffel hinzufügen und 3-4 Minuten anbraten.",
                    "Gewürze hinzufügen und kurz anrösten, bis sie duften.",
                    "Linsen und Gemüsebrühe hinzugeben und zum Kochen bringen.",
                    "Bei mittlerer Hitze etwa 20-25 Minuten köcheln lassen, bis alle Zutaten weich sind.",
                    "Mit einem Stabmixer die Suppe pürieren, bis sie cremig ist.",
                    "Mit Zitronensaft, Salz und Pfeffer abschmecken.",
                    "Mit frischer Petersilie garniert servieren."
                ],
                preparationTime: 35,
                difficulty: .easy,
                imageURL: "https://images.unsplash.com/photo-1547592180-85f173990554?q=80&w=1000",
                suitableForMoods: [Mood.sad.rawValue, Mood.calm.rawValue, Mood.stressed.rawValue],
                tags: ["Suppe", "Vegetarisch", "Gesund", "Protein", "Warm"]
            ),
            Recipe(
                id: UUID().uuidString,
                name: "Schwarzwälder Kirschtorte",
                description: "Die klassische deutsche Torte mit Schokolade, Sahne und Kirschen.",
                ingredients: [
                    "6 Eier",
                    "175g Zucker",
                    "150g Mehl",
                    "50g Kakaopulver",
                    "1 TL Backpulver",
                    "1 Glas Sauerkirschen (ca. 350g)",
                    "2 EL Kirschwasser",
                    "500ml Schlagsahne",
                    "50g Zucker für die Sahne",
                    "200g Zartbitterschokolade für die Dekoration"
                ],
                instructions: [
                    "Den Backofen auf 180°C vorheizen und eine Springform (26cm) fetten.",
                    "Eier und Zucker schaumig schlagen, bis die Masse hell und cremig ist.",
                    "Mehl, Kakao und Backpulver mischen und vorsichtig unter die Eimasse heben.",
                    "Den Teig in die Form füllen und etwa 30-35 Minuten backen.",
                    "Den Kuchen abkühlen lassen und zweimal horizontal durchschneiden.",
                    "Die Kirschen abtropfen lassen und den Saft auffangen. Einige Kirschen für die Dekoration beiseite legen.",
                    "Die Sahne mit Zucker steif schlagen.",
                    "Die untere Schicht mit Kirschsaft und Kirschwasser beträufeln, mit Sahne bestreichen und Kirschen darauf verteilen.",
                    "Die mittlere Schicht auflegen, auch tränken und mit Sahne und Kirschen belegen.",
                    "Die oberste Schicht auflegen, die gesamte Torte mit Sahne einstreichen.",
                    "Die Schokolade raspeln und die Seiten der Torte damit dekorieren.",
                    "Mit den beiseite gelegten Kirschen und Sahnetupfen die Oberseite dekorieren."
                ],
                preparationTime: 90,
                difficulty: .hard,
                imageURL: "https://images.unsplash.com/photo-1568644396922-5c3bfae7521e?q=80&w=1000",
                suitableForMoods: [Mood.happy.rawValue, Mood.calm.rawValue],
                tags: ["Deutsch", "Kuchen", "Dessert", "Schokolade", "Kirschen", "Feier"]
            ),
            Recipe(
                id: UUID().uuidString,
                name: "Kürbissuppe",
                description: "Cremige Kürbissuppe mit Ingwer und Kokosmilch - perfekt für Herbsttage.",
                ingredients: [
                    "1 mittelgroßer Hokkaido-Kürbis (ca. 1kg)",
                    "1 Zwiebel, gewürfelt",
                    "2 Knoblauchzehen, gehackt",
                    "1 Stück frischer Ingwer (ca. 3cm), gerieben",
                    "1 EL Olivenöl",
                    "400ml Gemüsebrühe",
                    "200ml Kokosmilch",
                    "1 TL Currypulver",
                    "Salz und Pfeffer nach Geschmack",
                    "Frische Petersilie oder Kürbiskerne zum Garnieren"
                ],
                instructions: [
                    "Den Kürbis waschen, halbieren, entkernen und in Würfel schneiden.",
                    "Olivenöl in einem großen Topf erhitzen und Zwiebeln, Knoblauch und Ingwer darin glasig dünsten.",
                    "Kürbiswürfel hinzufügen und kurz anbraten.",
                    "Mit Gemüsebrühe ablöschen und zum Kochen bringen.",
                    "Bei mittlerer Hitze etwa 15-20 Minuten köcheln lassen, bis der Kürbis weich ist.",
                    "Mit einem Stabmixer die Suppe pürieren, bis sie cremig ist.",
                    "Kokosmilch und Currypulver hinzufügen und gut verrühren.",
                    "Noch einmal aufkochen lassen und mit Salz und Pfeffer abschmecken.",
                    "In Schalen anrichten und mit Petersilie oder gerösteten Kürbiskernen garnieren."
                ],
                preparationTime: 40,
                difficulty: .easy,
                imageURL: "https://images.unsplash.com/photo-1543198067-1a4573b93eff?q=80&w=1000",
                suitableForMoods: [Mood.calm.rawValue, Mood.sad.rawValue, Mood.stressed.rawValue],
                tags: ["Suppe", "Vegetarisch", "Herbst", "Kürbis", "Cremig"]
            ),
            Recipe(
                id: UUID().uuidString,
                name: "Fitness-Frühstücksbowl",
                description: "Proteinreiche Frühstücksbowl mit Joghurt, Obst und Nüssen für einen energiegeladenen Start in den Tag.",
                ingredients: [
                    "200g griechischer Joghurt",
                    "1 EL Honig oder Ahornsirup",
                    "1 Banane, in Scheiben geschnitten",
                    "100g gemischte Beeren (frisch oder tiefgefroren)",
                    "2 EL Granola oder Müsli",
                    "1 EL Chiasamen",
                    "1 EL gehackte Nüsse (Mandeln, Walnüsse)",
                    "1/2 TL Zimt"
                ],
                instructions: [
                    "Joghurt in eine Schüssel geben und mit Honig verrühren.",
                    "Bananenscheiben und Beeren darauf verteilen.",
                    "Mit Granola oder Müsli bestreuen.",
                    "Chiasamen, Nüsse und Zimt darüber streuen.",
                    "Vor dem Servieren kurz ziehen lassen, damit die Chiasamen etwas quellen können."
                ],
                preparationTime: 10,
                difficulty: .easy,
                imageURL: "https://images.unsplash.com/photo-1511690656952-34342bb7c2f2?q=80&w=1000",
                suitableForMoods: [Mood.energetic.rawValue, Mood.tired.rawValue, Mood.happy.rawValue],
                tags: ["Frühstück", "Gesund", "Protein", "Joghurt", "Schnell", "Beeren"]
            ),
            Recipe(
                id: UUID().uuidString,
                name: "Gemüsepfanne mit Halloumi",
                description: "Bunte Gemüsepfanne mit gebratenem Halloumi-Käse - schnell, einfach und gesund.",
                ingredients: [
                    "1 Zucchini, in Scheiben geschnitten",
                    "1 Paprika (rot oder gelb), in Streifen geschnitten",
                    "1 kleine Aubergine, gewürfelt",
                    "1 rote Zwiebel, in Ringe geschnitten",
                    "200g Halloumi-Käse, in Scheiben geschnitten",
                    "2 EL Olivenöl",
                    "1 TL getrockneter Oregano",
                    "1 TL Paprikapulver",
                    "Frischer Thymian oder Basilikum",
                    "Salz und Pfeffer nach Geschmack",
                    "Zitronensaft zum Beträufeln"
                ],
                instructions: [
                    "Olivenöl in einer großen Pfanne erhitzen.",
                    "Zwiebeln darin glasig dünsten.",
                    "Aubergine, Zucchini und Paprika hinzufügen und bei mittlerer Hitze etwa 10 Minuten braten.",
                    "Das Gemüse mit Oregano, Paprikapulver, Salz und Pfeffer würzen.",
                    "In einer separaten Pfanne die Halloumi-Scheiben von beiden Seiten goldbraun braten.",
                    "Das fertige Gemüse auf Teller verteilen und die Halloumi-Scheiben darauf anrichten.",
                    "Mit frischen Kräutern garnieren und vor dem Servieren mit etwas Zitronensaft beträufeln."
                ],
                preparationTime: 25,
                difficulty: .easy,
                imageURL: "https://images.unsplash.com/photo-1511690743698-d9d85f2fbf38?q=80&w=1000",
                suitableForMoods: [Mood.energetic.rawValue, Mood.happy.rawValue, Mood.stressed.rawValue],
                tags: ["Vegetarisch", "Gemüse", "Käse", "Schnell", "Gesund", "Proteinreich"]
            ),
            Recipe(
                id: UUID().uuidString,
                name: "Warmer Schokoladenkuchen mit flüssigem Kern",
                description: "Unwiderstehlicher Schokoladenkuchen mit warmem, fließendem Kern - ein Tröster für die Seele.",
                ingredients: [
                    "200g Zartbitterschokolade",
                    "200g Butter",
                    "200g Zucker",
                    "4 Eier",
                    "100g Mehl",
                    "1 Prise Salz",
                    "Puderzucker zum Bestäuben",
                    "Vanilleeis zum Servieren (optional)"
                ],
                instructions: [
                    "Den Backofen auf 200°C vorheizen und 4 kleine Förmchen oder Tassen mit Butter einfetten.",
                    "Schokolade und Butter im Wasserbad schmelzen lassen und gut verrühren.",
                    "In einer separaten Schüssel Eier und Zucker schaumig schlagen.",
                    "Die geschmolzene Schokoladenmischung unter die Eimasse rühren.",
                    "Mehl und Salz unterrühren, bis ein glatter Teig entsteht.",
                    "Den Teig in die vorbereiteten Förmchen füllen.",
                    "Im vorgeheizten Ofen etwa 10-12 Minuten backen. Die Oberfläche sollte fest sein, der Kern aber noch flüssig.",
                    "Kuchen kurz ruhen lassen, dann auf Teller stürzen.",
                    "Mit Puderzucker bestäuben und sofort servieren, evtl. mit einer Kugel Vanilleeis."
                ],
                preparationTime: 25,
                difficulty: .medium,
                imageURL: "https://images.unsplash.com/photo-1552844926-e21c863e0c16?q=80&w=1000",
                suitableForMoods: [Mood.sad.rawValue, Mood.stressed.rawValue, Mood.calm.rawValue],
                tags: ["Dessert", "Schokolade", "Kuchen", "Süß", "Trost", "Warm"]
            )
        ]
        
        print("✅ \(fallbackRecipes.count) lokale Rezepte erstellt")
        return fallbackRecipes
    }
}

// Entferne die alten Spoonacular-spezifischen Strukturen
// Stattdessen müssen wir die Gustar.io-spezifischen Strukturen definieren, 
// die wir im parseGustarRecipes bereits verwenden 
 