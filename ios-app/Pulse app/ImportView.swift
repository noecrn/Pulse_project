//
//  ImportView.swift
//  Pulse app
//
//  Created by Noé Cornu on 23/12/2025.
//

import SwiftUI
import UniformTypeIdentifiers

/// A view responsible for selecting and importing external CSV simulation files.
///
/// This view provides a UI to browse the device's file system, validates the file type,
/// and securely passes the file content to the `DataProcessor` for batch analysis.
struct ImportView: View {
    
    // MARK: - Dependencies
    
    /// The central processor that handles data ingestion and analysis.
    @ObservedObject var dataProcessor: DataProcessor
    
    // MARK: - Private State
    
    /// Controls the presentation of the system file picker.
    @State private var isImporting: Bool = false

    // MARK: - View Body
    
    var body: some View {
        VStack(spacing: 30) {
            // Hero Icon
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            // Primary Action Button
            Button("Select Simulation File (CSV)") {
                isImporting = true
            }
            .buttonStyle(.borderedProminent)
        }
        // MARK: - File Import Logic
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result: result)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Handles the result of the file selection process.
    ///
    /// - Parameter result: A Result containing either the selected file URLs or an error.
    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // SECURITY CRITICAL:
            // iOS apps run in a sandbox. To read a file chosen by the user from outside
            // the sandbox (like iCloud Drive), we must explicitly request security access.
            if url.startAccessingSecurityScopedResource() {
                
                // Ensure we release access to the resource when we finish,
                // regardless of whether the read succeeds or fails.
                defer { url.stopAccessingSecurityScopedResource() }
                
                // Read and Process
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    print("Successfully loaded CSV: \(url.lastPathComponent)")
                    dataProcessor.analyzeFullSession(csvContent: content)
                } else {
                    print("Error: Unable to read file content.")
                }
            }
            
        case .failure(let error):
            print("Import failed: \(error.localizedDescription)")
        }
    }
}
