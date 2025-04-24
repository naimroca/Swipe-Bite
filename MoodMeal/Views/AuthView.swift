//
//  AuthView.swift
//  MoodMeal
//
//  Created by Naím Rodriguez Caballero on 21.04.25.
//

import SwiftUI

struct AuthView: View {
    @ObservedObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var isSignUp = false
    @State private var showPassword = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.orange.opacity(0.1).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Logo and Title
                    VStack {
                        Image(systemName: "fork.knife.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .foregroundColor(.orange)
                        
                        Text("MoodMeal")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 50)
                    .padding(.bottom, 30)
                    
                    // Form
                    VStack(spacing: 20) {
                        if isSignUp {
                            // Username field (only for sign up)
                            TextField("Benutzername", text: $username)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .shadow(radius: 1)
                        }
                        
                        // Email field
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(radius: 1)
                        
                        // Password field
                        HStack {
                            if showPassword {
                                TextField("Passwort", text: $password)
                            } else {
                                SecureField("Passwort", text: $password)
                            }
                            
                            Button(action: {
                                showPassword.toggle()
                            }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 1)
                        
                        // Error message
                        if !authManager.errorMessage.isEmpty {
                            Text(authManager.errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        
                        // Action button (Sign in / Sign up)
                        Button(action: {
                            if isSignUp {
                                authManager.signUp(email: email, password: password, username: username)
                            } else {
                                authManager.signIn(email: email, password: password)
                            }
                        }) {
                            Text(isSignUp ? "Registrieren" : "Anmelden")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .cornerRadius(10)
                        }
                        .disabled(isSignUp ? (email.isEmpty || password.isEmpty || username.isEmpty) : (email.isEmpty || password.isEmpty))
                    }
                    .padding(.horizontal, 30)
                    
                    // Toggle between sign in and sign up
                    Button(action: {
                        isSignUp.toggle()
                        authManager.errorMessage = ""
                    }) {
                        Text(isSignUp ? "Bereits registriert? Anmelden" : "Neu hier? Registrieren")
                            .foregroundColor(.orange)
                            .underline()
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
    }
} 