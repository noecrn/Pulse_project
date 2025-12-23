//
//  ContentView.swift
//  Pulse app
//
//  Created by Noé Cornu on 20/10/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var bleManager = BLEManager()
    @StateObject private var dataProcessor = DataProcessor()

    var body: some View {
        TabView {
            DashboardView(bleManager: bleManager, dataProcessor: dataProcessor)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }

            ImportView(dataProcessor: dataProcessor)
                .tabItem {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
        }
        .onAppear {
            bleManager.dataProcessor = self.dataProcessor
        }
    }
}
