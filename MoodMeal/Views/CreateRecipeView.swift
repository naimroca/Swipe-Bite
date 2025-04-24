//
//  CreateRecipeView.swift
//  MoodMeal
//
//  Created by Naím Rodriguez Caballero on 21.04.25.
//

import SwiftUI

struct CreateRecipeView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var recipeManager: RecipeManager
    @ObservedObject var authManager: AuthManager
    
    @State private var name = ""
    @State private var description = ""
    @State private var preparationTime = ""
    @State private var difficulty = Recipe.Difficulty.medium
    @State private var newIngredient = ""
    @State private var ingredients: [String] = []
    @State private var newInstruction = ""
    @State private var instructions: [String] = []
    @State private var newTag = ""
    @State private var tags: [String] = []
    @State private var moods: [Mood] = []
    @State private var imageURL = ""
    
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.orange.opacity(0.1).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Group {
                            Text("Grundinformationen")
                                .font(.headline)
                            
                            TextField("Rezeptname", text: $name)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            TextField("Beschreibung", text: $description)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(height: 100)
                            
                            TextField("Zubereitungszeit (Minuten)", text: $preparationTime)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                            
                            VStack(alignment: .leading) {
                                Text("Schwierigkeitsgrad")
                                    .font(.subheadline)
                                
                                Picker("Schwierigkeit", selection: $difficulty) {
                                    ForEach(Recipe.Difficulty.allCases, id: \.self) { difficulty in
                                        Text(difficulty.rawValue).tag(difficulty)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                            }
                            
                            TextField("Bild-URL (optional)", text: $imageURL)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        Divider()
                        
                        Group {
                            Text("Zutaten")
                                .font(.headline)
                            
                            HStack {
                                TextField("Neue Zutat", text: $newIngredient)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                Button(action: addIngredient) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            ForEach(ingredients, id: \.self) { ingredient in
                                HStack {
                                    Text(ingredient)
                                    Spacer()
                                    Button(action: {
                                        ingredients.removeAll { $0 == ingredient }
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                        
                        Divider()
                        
                        Group {
                            Text("Zubereitungsschritte")
                                .font(.headline)
                            
                            HStack {
                                TextField("Neuer Schritt", text: $newInstruction)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                Button(action: addInstruction) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            ForEach(Array(instructions.enumerated()), id: \.element) { index, instruction in
                                HStack {
                                    Text("\(index + 1). \(instruction)")
                                    Spacer()
                                    Button(action: {
                                        instructions.removeAll { $0 == instruction }
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                        
                        Divider()
                        
                        Group {
                            Text("Tags & Stimmungen")
                                .font(.headline)
                            
                            HStack {
                                TextField("Neuer Tag", text: $newTag)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                Button(action: addTag) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            if !tags.isEmpty {
                                HStack {
                                    ForEach(tags, id: \.self) { tag in
                                        HStack {
                                            Text(tag)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.orange.opacity(0.2))
                                                .cornerRadius(10)
                                            
                                            Button(action: {
                                                tags.removeAll { $0 == tag }
                                            }) {
                                                Image(systemName: "xmark")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                    }
                                }
                            }
                            
                            Text("Passend für Stimmungen:")
                                .font(.subheadline)
                                .padding(.top, 5)
                            
                            ForEach(Mood.allCases) { mood in
                                HStack {
                                    Image(systemName: mood.icon)
                                        .foregroundColor(.orange)
                                    
                                    Text(mood.rawValue)
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: Binding(
                                        get: { moods.contains(mood) },
                                        set: { isOn in
                                            if isOn {
                                                moods.append(mood)
                                            } else {
                                                moods.removeAll { $0 == mood }
                                            }
                                        }
                                    ))
                                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        
                        Button(action: saveRecipe) {
                            Text("Rezept speichern")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .cornerRadius(10)
                        }
                        .padding(.top)
                    }
                    .padding()
                }
            }
            .navigationTitle("Neues Rezept")
            .navigationBarItems(trailing: Button("Abbrechen") {
                presentationMode.wrappedValue.dismiss()
            })
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func addIngredient() {
        guard !newIngredient.isEmpty else { return }
        ingredients.append(newIngredient)
        newIngredient = ""
    }
    
    private func addInstruction() {
        guard !newInstruction.isEmpty else { return }
        instructions.append(newInstruction)
        newInstruction = ""
    }
    
    private func addTag() {
        guard !newTag.isEmpty else { return }
        tags.append(newTag)
        newTag = ""
    }
    
    private func saveRecipe() {
        // Validierung
        guard !name.isEmpty else {
            showAlert(title: "Fehler", message: "Bitte gib einen Namen für das Rezept ein.")
            return
        }
        
        guard !description.isEmpty else {
            showAlert(title: "Fehler", message: "Bitte gib eine Beschreibung ein.")
            return
        }
        
        guard !ingredients.isEmpty else {
            showAlert(title: "Fehler", message: "Bitte füge mindestens eine Zutat hinzu.")
            return
        }
        
        guard !instructions.isEmpty else {
            showAlert(title: "Fehler", message: "Bitte füge mindestens einen Zubereitungsschritt hinzu.")
            return
        }
        
        let prepTime = Int(preparationTime) ?? 30
        let moodStrings = moods.map { $0.rawValue }
        
        // Neues Rezept erstellen
        let newRecipeId = UUID().uuidString
        let newRecipe = Recipe(
            id: newRecipeId,
            name: name,
            description: description,
            ingredients: ingredients,
            instructions: instructions,
            preparationTime: prepTime,
            difficulty: difficulty,
            imageURL: imageURL.isEmpty ? nil : imageURL,
            suitableForMoods: moodStrings,
            tags: tags
        )
        
        // Rezept in Firestore speichern
        recipeManager.saveRecipe(recipe: newRecipe) { success in
            if success {
                showAlert(title: "Erfolg", message: "Dein Rezept wurde erfolgreich gespeichert!")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    presentationMode.wrappedValue.dismiss()
                }
            } else {
                showAlert(title: "Fehler", message: "Das Rezept konnte nicht gespeichert werden. Bitte versuche es erneut.")
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}

struct CreateRecipeView_Previews: PreviewProvider {
    static var previews: some View {
        CreateRecipeView(
            recipeManager: RecipeManager(),
            authManager: AuthManager()
        )
    }
} 