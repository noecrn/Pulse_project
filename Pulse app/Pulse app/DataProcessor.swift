//
//  DataProcessor.swift
//  Pulse app
//
//  Created by Noé Cornu on 20/10/2025.
//

import Foundation
import Combine

// MARK: - Helper Structures

struct SensorDataPoint {
    let timestamp: Date
    let heartRate: Double
    let vectorMagnitude: Double
}

struct SleepReport {
    let bedTime: String
    let wakeTime: String
    let sleepDuration: String
    let efficiency: String
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

// MARK: - Main Processor Class

class DataProcessor: ObservableObject {
    
    // --- Live Data Properties ---
    @Published var currentHeartRate: Double = 0.0
    @Published var currentVectorMagnitude: Double = 0.0
    @Published var featureVector: [Double] = []
    @Published var hrHistory: [ChartDataPoint] = []
    
    // --- Batch Report Properties ---
    @Published var lastSleepReport: SleepReport? = nil
    @Published var isAnalyzing: Bool = false
    
    // --- Internal Storage ---
    private var dataPoints: [SensorDataPoint] = []
    private let predictor = SleepPredictor()

    // MARK: - 1. Live Data Input
    
    public func add(heartRate: Double, accelX: Double, accelY: Double, accelZ: Double) {
        let magnitude = sqrt(pow(accelX, 2) + pow(accelY, 2) + pow(accelZ, 2))
        
        DispatchQueue.main.async {
            self.currentHeartRate = heartRate
            self.currentVectorMagnitude = magnitude
        }
        
        let newDataPoint = SensorDataPoint(timestamp: Date(), heartRate: heartRate, vectorMagnitude: magnitude)
        dataPoints.append(newDataPoint)
        
        let fifteenMinutesAgo = Date().addingTimeInterval(-15 * 60)
        dataPoints.removeAll { $0.timestamp < fifteenMinutesAgo }
        
        processNewFeatures()
    }
    
    private func processNewFeatures() {
        guard !dataPoints.isEmpty else { return }
        
        let now = Date()
        let sixtySecondsAgo = now.addingTimeInterval(-60)
        let fiveMinutesAgo = now.addingTimeInterval(-5 * 60)
        
        let last60s = dataPoints.filter { $0.timestamp > sixtySecondsAgo }
        let last5m = dataPoints.filter { $0.timestamp > fiveMinutesAgo }
        let last15m = dataPoints
        
        let hr60 = last60s.map { $0.heartRate }
        let vm60 = last60s.map { $0.vectorMagnitude }
        let hr5 = last5m.map { $0.heartRate }
        let vm5 = last5m.map { $0.vectorMagnitude }
        let hr15 = last15m.map { $0.heartRate }
        let vm15 = last15m.map { $0.vectorMagnitude }
        
        let newVector = [
            hr60.mean(), hr60.stdDev(),
            hr5.mean(), hr5.stdDev(),
            hr15.mean(), hr15.stdDev(),
            
            vm60.mean(), vm60.stdDev(),
            vm5.mean(),
            vm15.mean(), vm15.stdDev()
        ]
        
        DispatchQueue.main.async {
            self.featureVector = newVector
        }
    }

    // MARK: - 2. Batch Analysis (Instant Report)
    
    func analyzeFullSession(csvContent: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.runBatchProcess(csv: csvContent)
        }
    }
    
    private func runBatchProcess(csv: String) {
        DispatchQueue.main.async { self.isAnalyzing = true }
        
        let lines = csv.components(separatedBy: .newlines)
        
        var tempBuffer: [(date: Date, hr: Double, vm: Double)] = []
        var sleepPredictions: [(time: String, isAsleep: Bool)] = []
        
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
                
                let timeInterval = datePart.timeIntervalSince(Calendar.current.startOfDay(for: datePart))
                if timeInterval < lastTimeInterval {
                    referenceDate = referenceDate.addingTimeInterval(86400)
                }
                lastTimeInterval = timeInterval
                
                let actualDate = referenceDate.addingTimeInterval(timeInterval)
                let vm = sqrt(pow(ax, 2) + pow(ay, 2) + pow(az, 2))
                
                tempBuffer.append((actualDate, hr, vm))
            }
        }
        
        // 2. CHART DATA
        var smoothedChartPoints: [ChartDataPoint] = []
        let averageWindow = 300 // 5 minutes
        
        for i in stride(from: 0, to: tempBuffer.count, by: averageWindow) {
            let endIndex = min(i + averageWindow, tempBuffer.count)
            let chunk = tempBuffer[i..<endIndex]
            
            if !chunk.isEmpty {
                let avgHR = chunk.map { $0.hr }.reduce(0, +) / Double(chunk.count)
                let midIndex = chunk.startIndex + (chunk.count / 2)
                let midDate = chunk[midIndex].date
                smoothedChartPoints.append(ChartDataPoint(date: midDate, value: avgHR))
            }
        }
        
        // 3. Run Predictions
        for i in stride(from: 900, to: tempBuffer.count, by: 60) {
            let startIndex = i - 900
            let windowIndices = tempBuffer[startIndex...i]
            let rawWindow = windowIndices.map { (timestamp: "", hr: $0.hr, vm: $0.vm) }
            
            let vector = calculateBatchFeatures(window: rawWindow)
            let prediction = predictor.predict(features: vector)
            let timeString = formatter.string(from: tempBuffer[i].date)
            
            sleepPredictions.append((time: timeString, isAsleep: prediction == 1))
        }
        
        // 4. Generate Smart Report
        let report = generateReport(from: sleepPredictions, stepSize: 60)
        
        DispatchQueue.main.async {
            self.lastSleepReport = report
            self.hrHistory = smoothedChartPoints
            self.isAnalyzing = false
        }
    }
    
    private func calculateBatchFeatures(window: [(timestamp: String, hr: Double, vm: Double)]) -> [Double] {
        let hrs = window.map { $0.hr }
        let vms = window.map { $0.vm }
        let idx60 = max(0, window.count - 60)
        let idx300 = max(0, window.count - 300)
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
    
    // --- SMART REPORT GENERATION ---
    // Ignores short "false positive" sleep blocks.
    private func generateReport(from predictions: [(time: String, isAsleep: Bool)], stepSize: Int) -> SleepReport {
        
        // 1. Identify Sleep Blocks
        // We look for the LONGEST continuous session, allowing for 60-min wake gaps.
        var bestSession: (start: Int, end: Int, sleepCount: Int) = (0, 0, 0)
        var currentStart = -1
        var currentEnd = -1
        var currentSleepCount = 0
        var wakeGapCounter = 0
        
        // Threshold: 60 mins of wakefulness breaks the session
        let maxGapSteps = 3600 / stepSize
        
        for (index, item) in predictions.enumerated() {
            if item.isAsleep {
                if currentStart == -1 { currentStart = index } // Start new session
                currentEnd = index
                currentSleepCount += 1
                wakeGapCounter = 0 // Reset gap
            } else {
                if currentStart != -1 {
                    wakeGapCounter += 1
                    if wakeGapCounter > maxGapSteps {
                        // Gap too long, finalize this session
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
        
        // Check final session
        if currentStart != -1 && (currentEnd - currentStart) > (bestSession.end - bestSession.start) {
            bestSession = (currentStart, currentEnd, currentSleepCount)
        }
        
        // If no significant sleep found
        if bestSession.end == 0 {
             return SleepReport(bedTime: "--:--", wakeTime: "--:--", sleepDuration: "0h 0m", efficiency: "0%")
        }

        // 2. Extract Data from Best Session
        let bedTime = predictions[bestSession.start].time
        let wakeTime = predictions[bestSession.end].time
        
        let secondsInBed = Double(bestSession.end - bestSession.start) * Double(stepSize)
        let actualSleepSeconds = Double(bestSession.sleepCount * stepSize)
        
        let efficiency = secondsInBed > 0 ? (actualSleepSeconds / secondsInBed) * 100 : 0
        let hours = Int(secondsInBed) / 3600
        let minutes = (Int(secondsInBed) % 3600) / 60
        
        return SleepReport(
            bedTime: bedTime,
            wakeTime: wakeTime,
            sleepDuration: "\(hours)h \(minutes)m",
            efficiency: String(format: "%.1f%%", efficiency)
        )
    }
}

// MARK: - Math Extensions
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
