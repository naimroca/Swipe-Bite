import SwiftUI

struct ProfileView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var recipeManager: RecipeManager
    @State private var showingMoodSelection = false
    @State private var showingCreateRecipe = false
    @State private var showingWeeklyPlan = false
    @State private var showMoodSelector = false
    @State private var selectedRecipe: Recipe?
    @State private var showRecipeDetail = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Debug-Info-Button hinzufügen
                VStack {
                    Button(action: {
                        print("\n=== DEBUG PROFIL-ANSICHT ===")
                        print("Benutzer: \(authManager.user?.username ?? "nicht verfügbar")")
                        print("ID: \(authManager.user?.id ?? "nicht verfügbar")")
                        print("Aktuelle Stimmung: \(authManager.user?.currentMood?.rawValue ?? "keine")")
                        print("Mood Icon: \(authManager.user?.currentMood?.icon ?? "keines")")
                        print("Vorratskammer Zutaten: \(authManager.user?.pantryIngredients.count ?? 0)")
                        print("Gekochte Rezepte: \(authManager.user?.cookedRecipes.count ?? 0)")
                        print("Authentifiziert: \(authManager.isAuthenticated)")
                        
                        // Versuche auch, eine Stimmung direkt zu setzen für Tests
                        if let randomMood = Mood.allCases.randomElement() {
                            print("Setze test-Stimmung: \(randomMood.rawValue)")
                            authManager.updateMood(mood: randomMood)
                            
                            // Überprüfe nach kurzer Verzögerung
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                print("Nach Mood-Update: \(authManager.user?.currentMood?.rawValue ?? "keine")")
                            }
                        }
                    }) {
                        Image(systemName: "ladybug")
                            .foregroundColor(.gray)
                            .padding(8)
                            .background(Color.white.opacity(0.8))
                            .clipShape(Circle())
                    }
                    .padding()
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .zIndex(1)
                
                // Hintergrund
                Color.orange.opacity(0.1).ignoresSafeArea()
                
                // Hauptinhalt
                ScrollView {
                    VStack(spacing: 25) {
                        // Profilbild
                        VStack {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 100, height: 100)
                                .foregroundColor(.orange)
                            
                            if let user = authManager.user {
                                Text(user.username)
                                    .font(.title)
                                    .fontWeight(.bold)
                                
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.top, 30)
                        
                        // Stimmung
                        VStack(spacing: 15) {
                            Text("Aktuelle Stimmung")
                                .font(.headline)
                            
                            if let mood = authManager.user?.currentMood {
                                HStack {
                                    Image(systemName: mood.icon)
                                        .font(.title)
                                        .foregroundColor(.orange)
                                    
                                    Text(mood.rawValue)
                                        .font(.title3)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.white)
                                .cornerRadius(10)
                                .shadow(radius: 1)
                            } else {
                                Text("Keine Stimmung ausgewählt")
                                    .foregroundColor(.gray)
                            }
                            
                            Button(action: {
                                showMoodSelector = true
                            }) {
                                Text("Stimmung ändern")
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.orange)
                                    .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal, 30)
                        
                        // Wochenplan-Vorschau
                        VStack(spacing: 15) {
                            HStack {
                                Text("Wochenplan")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Button(action: {
                                    showingWeeklyPlan = true
                                }) {
                                    Text("Alle anzeigen")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            if let recentRecipes = authManager.user?.cookedRecipes.prefix(3), !recentRecipes.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(Array(recentRecipes), id: \.id) { recipe in
                                        HStack {
                                            Text(recipe.dayOfWeek)
                                                .fontWeight(.medium)
                                                .foregroundColor(.gray)
                                                .frame(width: 100, alignment: .leading)
                                            
                                            Text(recipe.recipeName)
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            
                                            Spacer()
                                        }
                                        .padding(.vertical, 5)
                                    }
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .shadow(radius: 1)
                            } else {
                                Text("Noch keine Gerichte gekocht")
                                    .foregroundColor(.gray)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .shadow(radius: 1)
                            }
                        }
                        .padding(.horizontal, 30)
                        
                        // Eigenes Rezept erstellen
                        VStack(spacing: 15) {
                            Text("Eigene Rezepte")
                                .font(.headline)
                            
                            Button(action: {
                                showingCreateRecipe = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Neues Rezept erstellen")
                                }
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.orange)
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal, 30)
                        
                        // Gekochte Rezepte der letzten Woche
                        CookedRecipesSection(
                            authManager: authManager,
                            recipeManager: recipeManager,
                            onRecipeTapped: { recipe in
                                selectedRecipe = recipe
                                showRecipeDetail = true
                            }
                        )
                        
                        // Abmelden Button
                        Button(action: {
                            authManager.signOut()
                        }) {
                            Text("Abmelden")
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.white)
                                .cornerRadius(10)
                                .shadow(radius: 1)
                        }
                        .padding(.horizontal, 30)
                        .padding(.vertical, 30)
                    }
                }
                .navigationTitle("Profil")
                .navigationBarTitleDisplayMode(.inline)
            }
            .sheet(isPresented: $showingMoodSelection) {
                MoodSelectionView(authManager: authManager)
            }
            .sheet(isPresented: $showingCreateRecipe) {
                CreateRecipeView(recipeManager: recipeManager, authManager: authManager)
            }
            .sheet(isPresented: $showingWeeklyPlan) {
                WeeklyMealPlanView(authManager: authManager)
            }
            .sheet(isPresented: $showMoodSelector) {
                MoodSelectionView(authManager: authManager)
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
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView(
            authManager: AuthManager(),
            recipeManager: RecipeManager()
        )
    }
}

// Abschnitt für gekochte Rezepte der letzten Woche
struct CookedRecipesSection: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var recipeManager: RecipeManager
    var onRecipeTapped: (Recipe) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Letzte gekochte Rezepte")
                .font(.headline)
                .padding(.horizontal)
            
            if let user = authManager.user, !user.cookedRecipes.isEmpty {
                VStack(spacing: 15) {
                    // Gruppiere nach Wochentagen für die letzten 7 Tage
                    let mealPlan = authManager.getWeeklyMealPlan()
                    
                    if mealPlan.isEmpty {
                        Text("Keine kürzlich gekochten Rezepte")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        ForEach(Array(mealPlan.keys.sorted(by: sortDays)), id: \.self) { day in
                            if let recipes = mealPlan[day] {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(day)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.secondary)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 15) {
                                            ForEach(recipes) { cookedRecipe in
                                                CookedRecipeCard(cookedRecipe: cookedRecipe)
                                                    .onTapGesture {
                                                        // Vollständiges Rezept laden und anzeigen
                                                        loadAndShowRecipe(recipeId: cookedRecipe.recipeId)
                                                    }
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                                .padding(.bottom, 5)
                            }
                        }
                    }
                }
                .padding(.vertical)
            } else {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "flame.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.6))
                        
                        Text("Keine gekochten Rezepte")
                            .foregroundColor(.gray)
                        
                        Text("Swipe bei einem Rezept nach oben, um es als 'Heute gekocht' zu markieren")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                }
            }
        }
        .padding(.vertical)
        .background(Color.white.opacity(0.7))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    private func loadAndShowRecipe(recipeId: String) {
        // Zuerst im aktuellen recipeManager suchen
        if let recipe = recipeManager.recipes.first(where: { $0.id == recipeId }) {
            onRecipeTapped(recipe)
            return
        }
        
        // Falls nicht gefunden, aus Firestore laden
        recipeManager.fetchRecipeById(recipeId: recipeId) { result in
            switch result {
            case .success(let recipe):
                DispatchQueue.main.async {
                    onRecipeTapped(recipe)
                }
            case .failure(let error):
                print("Fehler beim Laden des Rezepts: \(error)")
            }
        }
    }
    
    // Hilfsfunktion zum Sortieren der Wochentage
    private func sortDays(_ day1: String, _ day2: String) -> Bool {
        let weekdaysOrder = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]
        
        // Wenn beide Tage in der Liste sind, nach der Reihenfolge sortieren
        if let index1 = weekdaysOrder.firstIndex(of: day1),
           let index2 = weekdaysOrder.firstIndex(of: day2) {
            return index1 < index2
        }
        
        // Wenn nur einer in der Liste ist, diesen an den Anfang stellen
        if weekdaysOrder.contains(day1) {
            return true
        }
        if weekdaysOrder.contains(day2) {
            return false
        }
        
        // Ansonsten alphabetisch sortieren
        return day1 < day2
    }
}

// Karte für ein gekochtes Rezept
struct CookedRecipeCard: View {
    let cookedRecipe: CookedRecipe
    
    var body: some View {
        VStack(alignment: .leading) {
            if let imageURL = cookedRecipe.imageURL, !imageURL.isEmpty {
                AsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 120, height: 100)
                .cornerRadius(8)
            } else {
                ZStack {
                    Color.orange.opacity(0.3)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }
                .frame(width: 120, height: 100)
                .cornerRadius(8)
            }
            
            Text(cookedRecipe.recipeName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
                .frame(width: 120, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            
            Text(cookedRecipe.formattedDate)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(width: 120)
        .padding(.vertical, 5)
    }
}

// Profilinformationen
struct ProfileInfoView: View {
    let user: User
    let authManager: AuthManager
    
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 70))
                .foregroundColor(.orange)
            
            Text(user.username)
                .font(.title)
                .fontWeight(.bold)
            
            Text(user.email)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Divider()
                .padding(.horizontal, 40)
                .padding(.vertical, 5)
            
            HStack(spacing: 30) {
                VStack {
                    Text("\(user.favorites.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Favoriten")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                VStack {
                    Text("\(user.cookedRecipes.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Gekocht")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                VStack {
                    Text("\(user.pantryIngredients.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Zutaten")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.7))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

// Aktuelle Stimmungsanzeige
struct CurrentMoodView: View {
    let user: User
    let onChangeMood: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Aktuelle Stimmung")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 20) {
                if let currentMood = user.currentMood {
                    HStack {
                        Image(systemName: currentMood.icon)
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading) {
                            Text(currentMood.rawValue)
                                .font(.title3)
                                .fontWeight(.bold)
                            
                            Text("Passende Rezepte für deine aktuelle Stimmung werden angezeigt.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.leading, 5)
                        
                        Spacer()
                    }
                    .padding()
                } else {
                    HStack {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text("Keine Stimmung ausgewählt")
                            .foregroundColor(.gray)
                        
                        Spacer()
                    }
                    .padding()
                }
                
                Button(action: onChangeMood) {
                    Text(user.currentMood == nil ? "Stimmung wählen" : "Stimmung ändern")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(Color.white.opacity(0.7))
            .cornerRadius(10)
            .padding(.horizontal)
        }
    }
} 
