//
//  ContentView.swift
//  MoodMeal
//
//  Created by Naím Rodriguez Caballero on 21.04.25.
//


import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// Benötigte Verweise
import Foundation

struct ContentView: View {
    @StateObject private var authManager = AuthManager()
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView(authManager: authManager)
                    .onAppear {
                        print("ContentView: MainTabView erscheint")
                        print("ContentView: Benutzer ist angemeldet mit ID: \(authManager.user?.id ?? "keine ID")")
                        print("ContentView: Aktuelle Stimmung: \(authManager.user?.currentMood?.rawValue ?? "keine")")
                    }
            } else {
                AuthView(authManager: authManager)
                    .onAppear {
                        print("ContentView: AuthView erscheint - Benutzer nicht angemeldet")
        }
            }
    }
}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
    ContentView()
    }
}
