//
//  PantryView.swift
//  MoodMeal
//
//  Created by Naím Rodriguez Caballero on 21.04.25.
//

import SwiftUI

struct PantryView: View {
    @ObservedObject var authManager: AuthManager
    @State private var showingAddIngredient = false
    @State private var searchText = ""
    @State private var sortOption: SortOption = .name
    
    enum SortOption: String, CaseIterable {
        case name = "Name"
        case expiry = "Ablaufdatum"
        case recent = "Kürzlich hinzugefügt"
    }
    
    var filteredAndSortedIngredients: [PantryIngredient] {
        guard let pantryIngredients = authManager.user?.pantryIngredients else {
            return []
        }
        
        // Filtern
        let filtered = searchText.isEmpty ? pantryIngredients : pantryIngredients.filter {
            $0.name.lowercased().contains(searchText.lowercased())
        }
        
        // Sortieren
        switch sortOption {
        case .name:
            return filtered.sorted { $0.name.lowercased() < $1.name.lowercased() }
        case .expiry:
            return filtered.sorted { 
                guard let date1 = $0.expiryDate else { return false }
                guard let date2 = $1.expiryDate else { return true }
                return date1 < date2
            }
        case .recent:
            return filtered.reversed() // Einfache Annahme: Die neuesten Einträge sind am Ende des Arrays
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.orange.opacity(0.1).ignoresSafeArea()
                
                VStack {
                    // Search
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Nach Zutaten suchen", text: $searchText)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // Sortieroptionen
                    HStack {
                        Text("Sortieren nach:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Picker("Sortieren", selection: $sortOption) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Text(option.rawValue)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    .padding(.horizontal)
                    
                    if filteredAndSortedIngredients.isEmpty {
                        Spacer()
                        VStack {
                            Image(systemName: "carrot")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.6))
                            
                            Text("Keine Zutaten vorhanden")
                                .font(.title2)
                                .foregroundColor(.gray)
                                .padding(.top)
                            
                            Text("Füge Zutaten hinzu, um loszulegen")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        Spacer()
                    } else {
                        List {
                            ForEach(filteredAndSortedIngredients) { ingredient in
                                PantryIngredientRow(
                                    ingredient: ingredient,
                                    onToggleUsed: { isUsed in
                                        authManager.markIngredientAsUsed(ingredientId: ingredient.id, isUsed: isUsed)
                                    }
                                )
                                .swipeActions {
                                    Button(role: .destructive) {
                                        authManager.removeFromPantry(ingredientId: ingredient.id)
                                    } label: {
                                        Label("Löschen", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(InsetGroupedListStyle())
                    }
                }
                .navigationTitle("Meine Vorratskammer")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingAddIngredient = true
                        }) {
                            Image(systemName: "plus")
                                .foregroundColor(.orange)
                        }
                    }
                }
                .sheet(isPresented: $showingAddIngredient) {
                    AddIngredientView(authManager: authManager)
                }
            }
        }
    }
}

struct PantryIngredientRow: View {
    let ingredient: PantryIngredient
    let onToggleUsed: (Bool) -> Void
    
    var body: some View {
        HStack {
            Button(action: {
                onToggleUsed(!ingredient.isUsed)
            }) {
                Image(systemName: ingredient.isUsed ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(ingredient.isUsed ? .green : .gray)
                    .font(.title2)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 3) {
                Text(ingredient.name)
                    .font(.headline)
                    .foregroundColor(ingredient.isUsed ? .gray : .primary)
                    .strikethrough(ingredient.isUsed)
                
                HStack(spacing: 8) {
                    if let quantity = ingredient.quantity, let unit = ingredient.unit {
                        Text("\(String(format: "%.1f", quantity)) \(unit)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    if let expiryDate = ingredient.expiryDate {
                        let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day ?? 0
                        
                        HStack(spacing: 2) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            
                            Text("\(daysRemaining) Tage")
                                .font(.caption)
                        }
                        .foregroundColor(daysRemaining < 3 ? .red : (daysRemaining < 7 ? .orange : .gray))
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 5)
    }
}

struct AddIngredientView: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var name = ""
    @State private var quantity = ""
    @State private var unit = "g"
    @State private var expiryDate = Date().addingTimeInterval(7 * 24 * 60 * 60) // 1 Woche
    @State private var hasExpiryDate = false
    
    let units = ["g", "kg", "ml", "l", "Stück", "TL", "EL", "Tasse", "Prise"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Zutatdetails")) {
                    TextField("Name der Zutat", text: $name)
                    
                    TextField("Menge", text: $quantity)
                        .keyboardType(.decimalPad)
                    
                    Picker("Einheit", selection: $unit) {
                        ForEach(units, id: \.self) { unit in
                            Text(unit)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section(header: Text("Haltbarkeit")) {
                    Toggle("Haltbarkeitsdatum setzen", isOn: $hasExpiryDate)
                    
                    if hasExpiryDate {
                        DatePicker("Haltbar bis", selection: $expiryDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("Zutat hinzufügen")
            .navigationBarItems(
                leading: Button("Abbrechen") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Speichern") {
                    saveIngredient()
                }
                .disabled(name.isEmpty)
            )
        }
    }
    
    private func saveIngredient() {
        var ingredient = PantryIngredient(name: name)
        
        if let quantityDouble = Double(quantity) {
            ingredient.quantity = quantityDouble
            ingredient.unit = unit
        }
        
        if hasExpiryDate {
            ingredient.expiryDate = expiryDate
        }
        
        authManager.addToPantry(ingredient: ingredient)
        presentationMode.wrappedValue.dismiss()
    }
} 