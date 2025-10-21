//
//  ContentView.swift
//  Pulse app
//
//  Created by Noé Cornu on 20/10/2025.
//

import SwiftUI

struct ContentView: View {
    
    //MARK: - Properties
    
    // Manage the Bluetooth Low Energy (BLE) connection and state
    @StateObject private var bleManager = BLEManager()
    
    // Processes incoming raw data (either from BLE or simulation)
    @StateObject private var dataProcessor = DataProcessor()
    
    // MARK: - Data Simulation

    // Starts a timer that simulates incoming sensor data every second
    func startDataSimulation() {
        print("--- STARTING DATA SIMULATION ---")
        
        // This schedules a new timer that fires every 1.0 second
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            
            // Generate a fake heart rate that varies slightly
            let fakeHeartRate = Double.random(in: 65.0...75.0)
            
            // Génère de fausses données d'accéléromètre (valeurs proches de 0 quand on est immobile)
            let fakeAccelX = Double.random(in: -0.1...0.1)
            let fakeAccelY = Double.random(in: -0.1...0.1)
            let fakeAccelZ = Double.random(in: -1.0...(-0.9)) // Proche de -1 pour la gravité
            
            // On appelle directement la fonction 'add' de notre processeur
            dataProcessor.add(
                heartRate: fakeHeartRate,
                accelX: fakeAccelX,
                accelY: fakeAccelY,
                accelZ: fakeAccelZ
            )
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Projet Pulse ⚡️")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Affiche une icône qui change de couleur en fonction de l'état de la connexion.
            Image(systemName: "wave.3.right.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(bleManager.isConnected ? .green : .gray)
            
            // Affiche le message de statut de notre BLEManager.
            // Ce texte se mettra à jour automatiquement !
            Text(bleManager.connectionStatus)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding()

            Spacer()
        }
        .onAppear {
            // On connecte les deux modules comme avant
            bleManager.dataProcessor = self.dataProcessor
            
            // On démarre notre simulation !
            startDataSimulation()
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
