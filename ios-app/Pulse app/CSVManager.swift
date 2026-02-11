//
//  CSVManager.swift
//  Pulse app
//
//  Created by Noé Cornu on 23/12/2025.
//

import Foundation
import Combine

/// Represents a single row of parsed data from the CSV simulation file.
struct CSVRow {
    let heartRate: Double
    let accelX: Double
    let accelY: Double
    let accelZ: Double
}

/// Manages the playback of historical sensor data for testing purposes.
///
/// This class acts as a "virtual device," parsing a CSV file and feeding data points
/// sequentially into the `DataProcessor` to simulate a live Bluetooth connection.
/// This is useful for debugging and demonstrating the app without physical hardware.
class CSVManager: ObservableObject {
    
    // MARK: - Private Properties
    
    /// The timer that triggers the data feed at regular intervals (1Hz).
    private var timer: Timer?
    
    /// A queue of parsed data rows waiting to be processed.
    private var dataQueue: [CSVRow] = []
    
    // MARK: - Dependencies
    
    /// Reference to the central data processor where simulated data will be injected.
    var dataProcessor: DataProcessor?

    // MARK: - Simulation Control
    
    /// Parses the provided CSV string and begins the real-time simulation.
    ///
    /// This method resets any existing simulation, parses the new data, and starts
    /// a timer that feeds one data point per second to the `DataProcessor`.
    ///
    /// - Parameter csvString: The full content of the CSV file.
    func startSimulation(from csvString: String) {
        stopSimulation()
        
        // Split content into lines
        let lines = csvString.components(separatedBy: .newlines)
        
        // Iterate through lines (skipping the header)
        for line in lines.dropFirst() {
            let columns = line.components(separatedBy: ",")
            
            // Ensure the row has enough columns and valid Double values
            // Indices based on standard export structure: [Timestamp, HR, X, Y, Z]
            if columns.count >= 5,
               let hr = Double(columns[1]),
               let ax = Double(columns[2]),
               let ay = Double(columns[3]),
               let az = Double(columns[4]) {
                
                dataQueue.append(CSVRow(heartRate: hr, accelX: ax, accelY: ay, accelZ: az))
            }
        }
        
        // Start the 1Hz timer (1 data point per second)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.step()
        }
    }

    /// Stops the current simulation and clears the data queue.
    func stopSimulation() {
        timer?.invalidate()
        timer = nil
        dataQueue.removeAll()
    }
    
    // MARK: - Internal Logic

    /// Processes the next row in the queue and sends it to the DataProcessor.
    /// Called automatically by the timer.
    private func step() {
        // Validation: Ensure we have data and a valid processor
        guard !dataQueue.isEmpty, let processor = dataProcessor else {
            stopSimulation()
            return
        }
        
        // Dequeue the next data point
        let nextRow = dataQueue.removeFirst()
        
        // Inject data into the processor as if it came from BLE
        processor.add(
            heartRate: nextRow.heartRate,
            accelX: nextRow.accelX,
            accelY: nextRow.accelY,
            accelZ: nextRow.accelZ
        )
    }
}
