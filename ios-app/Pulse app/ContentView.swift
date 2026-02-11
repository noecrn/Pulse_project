//
//  ContentView.swift
//  Pulse app
//
//  Created by Noé Cornu on 20/10/2025.
//

import SwiftUI

/// The root view of the application, acting as the main container and navigation controller.
///
/// This view is responsible for:
/// 1. Initializing the shared state objects (`BLEManager` and `DataProcessor`).
/// 2. Setting up the main tab-based navigation structure.
/// 3. Performing dependency injection to link the BLE manager with the data processor.
struct ContentView: View {
    
    // MARK: - App State (Single Source of Truth)
    
    /// Manages Bluetooth connections and hardware communication.
    /// Owned here to ensure it persists throughout the app's lifecycle.
    @StateObject private var bleManager = BLEManager()
    
    /// Central hub for processing raw sensor data and running logic.
    /// Owned here to ensure data persists across tab switches.
    @StateObject private var dataProcessor = DataProcessor()

    // MARK: - View Body
    
    var body: some View {
        TabView {
            // Tab 1: Live Dashboard & Analytics
            DashboardView(bleManager: bleManager, dataProcessor: dataProcessor)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }

            // Tab 2: Offline File Import
            ImportView(dataProcessor: dataProcessor)
                .tabItem {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
        }
        // MARK: - Dependency Injection
        .onAppear {
            // Link the BLE Manager to the Data Processor so incoming Bluetooth
            // data is automatically sent for processing.
            bleManager.dataProcessor = self.dataProcessor
        }
    }
}
