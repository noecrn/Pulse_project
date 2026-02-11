//
//  DataProcessor.swift
//  Pulse app
//
//  Created by Noé Cornu on 20/10/2025.
//

import Foundation
import Combine

// MARK: - Helper Structures

/// Represents a single raw data reading from the sensor.
struct SensorDataPoint {
    let timestamp: Date
    let heartRate: Double
    let vectorMagnitude: Double
}

/// A summary object containing the final results of a sleep analysis.
struct SleepReport {
    let bedTime: String
    let wakeTime: String
    let sleepDuration: String
    let efficiency: String
    
    /// The actual start date of the sleep session, used for chart filtering.
    let sessionStartDate: Date
    /// The actual end date of the sleep session, used for chart filtering.
    let sessionEndDate: Date
}

/// A single data point formatted specifically for Swift Charts.
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

// MARK: - Main Processor Class

/// The central data manager for the application.
///
/// This class is responsible for:
/// 1. Ingesting live sensor data via BLE.
/// 2. processing historical data via CSV import.
/// 3. Calculating statistical features for the ML model.
/// 4. Generating sleep reports and chart history.
class DataProcessor: ObservableObject {
    
    // MARK: - Live Data Properties
    
    /// The most recent Heart Rate reading (for real-time UI).
    @Published var currentHeartRate: Double = 0.0
    
    /// The most recent movement intensity (for real-time UI).
    @Published var currentVectorMagnitude: Double = 0.0
    
    /// The computed feature vector (11 values) ready for the ML predictor.
    @Published var featureVector: [Double] = []
    
    // MARK: - Analysis Properties
    
    /// Historical Heart Rate data filtered to the detected sleep session.
    @Published var hrHistory: [ChartDataPoint] = []
    
    /// The results of the last completed batch analysis.
    @Published var lastSleepReport: SleepReport? = nil
    
    /// Indicates whether a batch process is currently running.
    @Published var isAnalyzing: Bool = false
    
    // MARK: - Internal Storage
    
    /// Buffer to hold the last 15 minutes of live data for rolling window calculations.
    private var dataPoints: [SensorDataPoint] = []
    
    /// The Machine Learning predictor instance.
    private let predictor = SleepPredictor()

    // MARK: - 1. Live Data Input
    
    /// Adds a new sensor reading from the hardware and updates the live model.
    ///
    /// - Parameters:
    ///   - heartRate: The BPM value.
    ///   - accelX: Accelerometer X-axis.
    ///   - accelY: Accelerometer Y-axis.
    ///   - accelZ: Accelerometer Z-axis.
    public func add(heartRate: Double, accelX: Double, accelY: Double, accelZ: Double) {
        // Calculate vector magnitude (total movement intensity)
        let magnitude = sqrt(pow(accelX, 2) + pow(accelY, 2) + pow(accelZ, 2))
        
        // Update UI immediately
        DispatchQueue.main.async {
            self.currentHeartRate = heartRate
            self.currentVectorMagnitude = magnitude
        }
        
        // Add to history buffer
        let newDataPoint = SensorDataPoint(timestamp: Date(), heartRate: heartRate, vectorMagnitude: magnitude)
        dataPoints.append(newDataPoint)
        
        // Maintenance: Keep only the last 15 minutes of data
        let fifteenMinutesAgo = Date().addingTimeInterval(-15 * 60)
        dataPoints.removeAll { $0.timestamp < fifteenMinutesAgo }
        
        // Recalculate features for the ML model
        processNewFeatures()
    }
    
    /// Computes the 11 statistical features required by the Core ML model based on the live buffer.
    private func processNewFeatures() {
        guard !dataPoints.isEmpty else { return }
        
        // Define rolling windows relative to "now"
        let now = Date()
        let sixtySecondsAgo = now.addingTimeInterval(-60)
        let fiveMinutesAgo = now.addingTimeInterval(-5 * 60)
        
        // Filter data into windows
        let last60s = dataPoints.filter { $0.timestamp > sixtySecondsAgo }
        let last5m = dataPoints.filter { $0.timestamp > fiveMinutesAgo }
        
        // Extract raw arrays
        let hr60 = last60s.map { $0.heartRate }
        let vm60 = last60s.map { $0.vectorMagnitude }
        let hr5 = last5m.map { $0.heartRate }
        let vm5 = last5m.map { $0.vectorMagnitude }
        let hr15 = dataPoints.map { $0.heartRate }
        let vm15 = dataPoints.map { $0.vectorMagnitude }
        
        // Construct the feature vector (Order matters! Must match model training)
        let newVector = [
            hr60.mean(), hr60.stdDev(),
            hr5.mean(), hr5.stdDev(),
            hr15.mean(), hr15.stdDev(),
            vm60.mean(), vm60.stdDev(),
            vm5.mean(),
            vm15.mean(), vm15.stdDev()
        ]
        
        DispatchQueue.main.async { self.featureVector = newVector }
    }

    // MARK: - 2. Batch Analysis (Offline)
    
    /// Triggers the background processing of a CSV string.
    ///
    /// - Parameter csvContent: The full string content of a CSV file.
    func analyzeFullSession(csvContent: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.runBatchProcess(csv: csvContent)
        }
    }
    
    /// The core logic for parsing CSVs, running predictions, and generating reports.
    private func runBatchProcess(csv: String) {
        DispatchQueue.main.async { self.isAnalyzing = true }
        
        let lines = csv.components(separatedBy: .newlines)
        var tempBuffer: [(date: Date, hr: Double, vm: Double)] = []
        var sleepPredictions: [(date: Date, isAsleep: Bool)] = []
        
        // Date parsing setup
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        var referenceDate = Calendar.current.startOfDay(for: Date())
        var lastTimeInterval: TimeInterval = -1

        // 1. Parse Data
        for line in lines.dropFirst() {
            let cols = line.components(separatedBy: ",")
            if cols.count >= 5,
               let hr = Double(cols[1]),
               let ax = Double(cols[2]),
               let ay = Double(cols[3]),
               let az = Double(cols[4]),
               let datePart = formatter.date(from: cols[0]) {
                
                // Handle midnight crossover (e.g., 23:59 -> 00:01)
                let timeInterval = datePart.timeIntervalSince(Calendar.current.startOfDay(for: datePart))
                if timeInterval < lastTimeInterval {
                    referenceDate = referenceDate.addingTimeInterval(86400) // Add 1 day
                }
                lastTimeInterval = timeInterval
                
                let actualDate = referenceDate.addingTimeInterval(timeInterval)
                let vm = sqrt(pow(ax, 2) + pow(ay, 2) + pow(az, 2))
                tempBuffer.append((actualDate, hr, vm))
            }
        }
        
        // 2. Generate Predictions (Stride: 60s)
        // We skip the first 900 seconds (15 mins) to ensure we have enough history for the first window.
        for i in stride(from: 900, to: tempBuffer.count, by: 60) {
            let startIndex = i - 900
            let windowIndices = tempBuffer[startIndex...i]
            let rawWindow = windowIndices.map { (timestamp: "", hr: $0.hr, vm: $0.vm) }
            
            let vector = calculateBatchFeatures(window: rawWindow)
            let prediction = predictor.predict(features: vector)
            
            sleepPredictions.append((date: tempBuffer[i].date, isAsleep: prediction == 1))
        }
        
        // 3. Generate Report (Smart Session Detection)
        let report = generateReport(from: sleepPredictions, stepSize: 60)
        
        // 4. Generate Chart Data
        // Filter: Only process data within the detected sleep session (+/- 30 mins buffer)
        var smoothedChartPoints: [ChartDataPoint] = []
        let averageWindow = 300 // 5 minutes smoothing
        
        let chartStart = report.sessionStartDate.addingTimeInterval(-1800)
        let chartEnd = report.sessionEndDate.addingTimeInterval(1800)
        
        let sessionBuffer = tempBuffer.filter { $0.date >= chartStart && $0.date <= chartEnd }
        
        for i in stride(from: 0, to: sessionBuffer.count, by: averageWindow) {
            let endIndex = min(i + averageWindow, sessionBuffer.count)
            let chunk = sessionBuffer[i..<endIndex]
            
            if !chunk.isEmpty {
                let avgHR = chunk.map { $0.hr }.reduce(0, +) / Double(chunk.count)
                let midIndex = chunk.startIndex + (chunk.count / 2)
                let midDate = chunk[midIndex].date
                smoothedChartPoints.append(ChartDataPoint(date: midDate, value: avgHR))
            }
        }
        
        // 5. Update UI
        DispatchQueue.main.async {
            self.lastSleepReport = report
            self.hrHistory = smoothedChartPoints
            self.isAnalyzing = false
        }
    }
    
    /// Extracts statistical features from a specific window of data for the ML model.
    private func calculateBatchFeatures(window: [(timestamp: String, hr: Double, vm: Double)]) -> [Double] {
        let hrs = window.map { $0.hr }
        let vms = window.map { $0.vm }
        
        let idx60 = max(0, window.count - 60)
        let idx300 = max(0, window.count - 300)
        
        // NOTE: Explicitly converting slices to Array to allow .mean() extension to work
        let hrs60 = Array(hrs[idx60...])
        let hrs300 = Array(hrs[idx300...])
        
        let vms60 = Array(vms[idx60...])
        let vms300 = Array(vms[idx300...])
        
        return [
            hrs60.mean(), hrs60.stdDev(),
            hrs300.mean(), hrs300.stdDev(),
            hrs.mean(), hrs.stdDev(),
            vms60.mean(), vms60.stdDev(),
            vms300.mean(),
            vms.mean(), vms.stdDev()
        ]
    }
    
    /// Analyzes the prediction array to find the primary sleep session.
    ///
    /// This function filters out short naps or false positives by looking for the
    /// longest continuous block of sleep, allowing for brief "wake" gaps (up to 1 hour).
    private func generateReport(from predictions: [(date: Date, isAsleep: Bool)], stepSize: Int) -> SleepReport {
        var bestSession: (start: Int, end: Int, sleepCount: Int) = (0, 0, 0)
        var currentStart = -1
        var currentEnd = -1
        var currentSleepCount = 0
        var wakeGapCounter = 0
        
        // Allow up to 60 minutes of wakefulness before breaking a session
        let maxGapSteps = 3600 / stepSize
        
        for (index, item) in predictions.enumerated() {
            if item.isAsleep {
                if currentStart == -1 { currentStart = index }
                currentEnd = index
                currentSleepCount += 1
                wakeGapCounter = 0
            } else {
                if currentStart != -1 {
                    wakeGapCounter += 1
                    // If gap is too large, finalize this session and check if it's the best one
                    if wakeGapCounter > maxGapSteps {
                        if (currentEnd - currentStart) > (bestSession.end - bestSession.start) {
                            bestSession = (currentStart, currentEnd, currentSleepCount)
                        }
                        // Reset
                        currentStart = -1
                        currentSleepCount = 0
                    }
                }
            }
        }
        
        // Final check for a session active at the end of the file
        if currentStart != -1 && (currentEnd - currentStart) > (bestSession.end - bestSession.start) {
            bestSession = (currentStart, currentEnd, currentSleepCount)
        }
        
        // Extract start/end dates
        let startD = bestSession.end > 0 ? predictions[bestSession.start].date : Date()
        let endD = bestSession.end > 0 ? predictions[bestSession.end].date : Date()
        
        // Metric Calculations
        let secondsInBed = Double(bestSession.end - bestSession.start) * Double(stepSize)
        let actualSleepSeconds = Double(bestSession.sleepCount * stepSize)
        
        let efficiency = secondsInBed > 0 ? (actualSleepSeconds / secondsInBed) * 100 : 0
        let hours = Int(secondsInBed) / 3600
        let minutes = (Int(secondsInBed) % 3600) / 60
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        return SleepReport(
            bedTime: bestSession.end > 0 ? timeFormatter.string(from: startD) : "--:--",
            wakeTime: bestSession.end > 0 ? timeFormatter.string(from: endD) : "--:--",
            sleepDuration: "\(hours)h \(minutes)m",
            efficiency: String(format: "%.1f%%", efficiency),
            sessionStartDate: startD,
            sessionEndDate: endD
        )
    }
}

// MARK: - Math Extensions

/// Helper extension to calculate mean and standard deviation on Double arrays.
extension Array where Element == Double {
    func mean() -> Double {
        guard !isEmpty else { return 0.0 }
        return reduce(0, +) / Double(count)
    }

    func stdDev() -> Double {
        guard count > 1 else { return 0.0 }
        let meanValue = self.mean()
        let sumOfSquaredDiffs = self.map { pow($0 - meanValue, 2.0) }.reduce(0, +)
        return sqrt(sumOfSquaredDiffs / Double(count - 1))
    }
}
