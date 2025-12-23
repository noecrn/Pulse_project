//
//  CSVManager.swift
//  Pulse app
//
//  Created by Noé Cornu on 23/12/2025.
//

import Foundation
import Combine

struct CSVRow {
    let heartRate: Double
    let accelX: Double
    let accelY: Double
    let accelZ: Double
}

class CSVManager: ObservableObject {
    private var timer: Timer?
    private var dataQueue: [CSVRow] = []
    
    // Reference to your existing processor
    var dataProcessor: DataProcessor?

    /// Parses the CSV string and starts the simulation
    func startSimulation(from csvString: String) {
        stopSimulation()
        
        let lines = csvString.components(separatedBy: .newlines)
        // Skip header if your file has one
        for line in lines.dropFirst() {
            let columns = line.components(separatedBy: ",")
            // Modify these indices based on your all_users.csv structure
            if columns.count >= 5,
               let hr = Double(columns[1]),
               let ax = Double(columns[2]),
               let ay = Double(columns[3]),
               let az = Double(columns[4]) {
                dataQueue.append(CSVRow(heartRate: hr, accelX: ax, accelY: ay, accelZ: az))
            }
        }
        
        // Feed one row every second to simulate a live person
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.step()
        }
    }

    private func step() {
        guard !dataQueue.isEmpty, let processor = dataProcessor else {
            stopSimulation()
            return
        }
        
        let nextRow = dataQueue.removeFirst()
        processor.add(heartRate: nextRow.heartRate,
                      accelX: nextRow.accelX,
                      accelY: nextRow.accelY,
                      accelZ: nextRow.accelZ)
    }

    func stopSimulation() {
        timer?.invalidate()
        timer = nil
        dataQueue.removeAll()
    }
}
