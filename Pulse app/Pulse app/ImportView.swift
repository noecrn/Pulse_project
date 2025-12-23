//
//  ImportView.swift
//  Pulse app
//
//  Created by Noé Cornu on 23/12/2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @StateObject private var csvManager = CSVManager()
    @ObservedObject var dataProcessor: DataProcessor
    @State private var isImporting: Bool = false

    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Button("Select Simulation File (CSV)") {
                isImporting = true
            }
            .buttonStyle(.borderedProminent)
            
            // Link the manager to the processor
            .onAppear { csvManager.dataProcessor = dataProcessor }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                // result provides an array [URL], so we take the first one
                if let url = urls.first {
                    if url.startAccessingSecurityScopedResource() {
                        defer { url.stopAccessingSecurityScopedResource() }
                        
                        if let content = try? String(contentsOf: url, encoding: .utf8) {
                            dataProcessor.analyzeFullSession(csvContent: content)
                        }
                    }
                }
            case .failure(let error):
                print("Import failed: \(error.localizedDescription)")
            }
        }
    }
}
