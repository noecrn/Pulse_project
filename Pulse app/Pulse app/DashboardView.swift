//
//  DashboardView.swift
//  Pulse app
//
//  Created by Noé Cornu on 23/12/2025.
//

import SwiftUI
import Charts

struct DashboardView: View {
    @ObservedObject var bleManager: BLEManager
    @ObservedObject var dataProcessor: DataProcessor
    
    // Logic
    private let predictor = SleepPredictor()
    @State private var isSleeping: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                // 1. GLOBAL BACKGROUND (Deep Night Theme)
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.05, blue: 0.15), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        
                        // 2. HERO STATUS (Dynamic Glow)
                        StatusHeader(isSleeping: isSleeping)
                            .padding(.top, 20)

                        // 3. LIVE METRICS (Glass Cards)
                        HStack(spacing: 15) {
                            MetricCard(
                                title: "Heart Rate",
                                value: String(format: "%.0f", dataProcessor.currentHeartRate),
                                unit: "BPM",
                                icon: "heart.fill",
                                color: .red
                            )
                            
                            MetricCard(
                                title: "Movement",
                                value: String(format: "%.1f", dataProcessor.currentVectorMagnitude),
                                unit: "G",
                                icon: "waveform.path.ecg",
                                color: .blue
                            )
                        }

                        // 4. SLEEP REPORT & CHART
                        if let report = dataProcessor.lastSleepReport {
                            VStack(spacing: 0) {
                                // Header
                                Text("Last Session Analysis")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding([.top, .leading, .trailing])
                                
                                // Chart
                                ModernChart(data: dataProcessor.hrHistory)
                                    .frame(height: 200)
                                    .padding(.vertical)
                                
                                Divider().background(Color.white.opacity(0.1))
                                
                                // Stats Grid
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                                    StatItem(label: "Bedtime", value: report.bedTime, icon: "moon.zzz.fill", color: .indigo)
                                    StatItem(label: "Wake Up", value: report.wakeTime, icon: "sun.max.fill", color: .orange)
                                    StatItem(label: "Duration", value: report.sleepDuration, icon: "hourglass", color: .teal)
                                    StatItem(label: "Efficiency", value: report.efficiency, icon: "percent", color: .green)
                                }
                                .padding()
                            }
                            .background(.ultraThinMaterial) // Glass Effect
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        } else if dataProcessor.isAnalyzing {
                            // Loading State
                            VStack(spacing: 15) {
                                ProgressView()
                                    .tint(.white)
                                Text("Processing Night Data...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(40)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                        }
                        
                        // 5. DEBUG (Subtle Footer)
                        VStack(alignment: .leading) {
                            Text("ML FEATURE VECTOR")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.tertiary)
                            
                            let vectorString = dataProcessor.featureVector.map { String(format: "%.1f", $0) }.joined(separator: ", ")
                            Text(vectorString.isEmpty ? "Waiting for sensors..." : vectorString)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 20)
                    }
                    .padding()
                }
            }
            .navigationTitle("Pulse Monitor")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onReceive(dataProcessor.$featureVector) { newFeatures in
            guard !newFeatures.isEmpty else { return }
            let result = predictor.predict(features: newFeatures)
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                self.isSleeping = (result == 1)
            }
        }
    }
}

// MARK: - MODERN SUBVIEWS

struct StatusHeader: View {
    let isSleeping: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("CURRENT STATE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                
                Text(isSleeping ? "Asleep" : "Awake")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            
            Spacer()
            
            // Animated Status Icon
            ZStack {
                Circle()
                    .fill(isSleeping ? Color.indigo : Color.orange)
                    .frame(width: 60, height: 60)
                    .blur(radius: 20) // Glow effect
                    .opacity(0.6)
                
                Image(systemName: isSleeping ? "moon.stars.fill" : "figure.run")
                    .font(.system(size: 30))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: isSleeping) // iOS 17 animation
            }
        }
        .padding(25)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color(white: 0.1))
        )
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText()) // Smooth number animation
                
                Text(unit)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }
}

struct ModernChart: View {
    let data: [ChartDataPoint]
    
    var body: some View {
        Chart(data) { point in
            // 1. The Gradient Fill Area
            AreaMark(
                x: .value("Time", point.date),
                y: .value("BPM", point.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.red.opacity(0.4), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)
            
            // 2. The Sharp Line on top
            LineMark(
                x: .value("Time", point.date),
                y: .value("BPM", point.value)
            )
            .foregroundStyle(Color.red)
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2))
        }
        .chartYScale(domain: 40...140)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 2)) {
                AxisValueLabel(format: .dateTime.hour(), centered: true)
                    .foregroundStyle(Color.white.opacity(0.5))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) {
                AxisGridLine().foregroundStyle(Color.white.opacity(0.1))
                AxisValueLabel().foregroundStyle(Color.white.opacity(0.5))
            }
        }
        .padding(.horizontal)
    }
}

struct StatItem: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.2))
                .clipShape(Circle())
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text(label)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.gray)
            }
        }
    }
}
