//
//  DashboardView.swift
//  Pulse app
//
//  Created by Noé Cornu on 23/12/2025.
//

import SwiftUI
import Charts

/// The primary interface for the sleep tracking dashboard.
///
/// This view manages three distinct application states:
/// 1. **Empty State:** When no device is connected and no data is imported.
/// 2. **Loading State:** When the app is processing a large dataset (e.g., CSV import).
/// 3. **Dashboard State:** Displaying live metrics or post-sleep analysis reports.
struct DashboardView: View {
    
    // MARK: - Dependencies
    
    @ObservedObject var bleManager: BLEManager
    @ObservedObject var dataProcessor: DataProcessor
    
    // MARK: - Private Properties
    
    /// The Core ML wrapper responsible for predicting sleep stages.
    private let predictor = SleepPredictor()
    
    /// Tracks the real-time sleep status (Awake/Asleep) for UI updates.
    @State private var isSleeping: Bool = false

    // MARK: - View Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 1. Global Background (Deep Night Theme)
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.05, blue: 0.15), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // 2. Main Content Switcher based on App State
                if dataProcessor.isAnalyzing {
                    LoadingView()
                    
                } else if isDataAvailable {
                    mainDashboardContent
                    
                } else {
                    EmptyStateView()
                }
            }
            .navigationTitle("Pulse Monitor")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        // React to new sensor data for live sleep prediction
        .onReceive(dataProcessor.$featureVector) { newFeatures in
            guard !newFeatures.isEmpty else { return }
            
            // Perform prediction
            let result = predictor.predict(features: newFeatures)
            
            // Update UI state with a smooth spring animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                self.isSleeping = (result == 1)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// The main scrollable content view shown when data is present.
    private var mainDashboardContent: some View {
        ScrollView {
            VStack(spacing: 25) {
                
                // A. Live Heart Rate Card
                // Only displayed when live sensor data is actively streaming.
                if !dataProcessor.featureVector.isEmpty {
                    MetricCard(
                        title: "Heart Rate",
                        value: String(format: "%.0f", dataProcessor.currentHeartRate),
                        unit: "BPM",
                        icon: "heart.fill",
                        color: .red
                    )
                    .padding(.top, 20)
                }

                // B. Sleep Session Report
                // Displayed when a full session (live or CSV) has been analyzed.
                if let report = dataProcessor.lastSleepReport {
                    SleepReportCard(report: report, data: dataProcessor.hrHistory)
                        .padding(.top, dataProcessor.featureVector.isEmpty ? 20 : 0)
                }
            }
            .padding()
        }
    }
    
    /// Determines if the dashboard should show content or the empty state.
    private var isDataAvailable: Bool {
        return !dataProcessor.featureVector.isEmpty || dataProcessor.lastSleepReport != nil
    }
}

// MARK: - Subviews & Components

/// A placeholder view shown when no data source is active.
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sensor.tag.radiowaves.forward")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.3))
                .padding(.bottom, 10)
            
            Text("No Device Synced")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            Text("Try to sync the bracelet or import manually a CSV file")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial.opacity(0.3))
    }
}

/// A loading indicator shown during batch analysis.
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 15) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.5)
            Text("Processing Night Data...")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.5))
    }
}

/// A generic card component for displaying a single live metric.
struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                        .font(.title3)
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(value)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    
                    Text(unit)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(25)
        .background(.ultraThinMaterial)
        .cornerRadius(25)
    }
}

/// Displays a comprehensive report of a sleep session, including stats and a chart.
struct SleepReportCard: View {
    let report: SleepReport
    let data: [ChartDataPoint]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Last Session Analysis")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.top, .leading, .trailing])
            
            // Interactive Chart
            ModernChart(data: data)
                .frame(height: 200)
                .padding(.vertical)
            
            Divider().background(Color.white.opacity(0.1))
            
            // Statistics Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                StatItem(label: "Bedtime", value: report.bedTime, icon: "moon.zzz.fill", color: .indigo)
                StatItem(label: "Wake Up", value: report.wakeTime, icon: "sun.max.fill", color: .orange)
                StatItem(label: "Duration", value: report.sleepDuration, icon: "hourglass", color: .teal)
                StatItem(label: "Efficiency", value: report.efficiency, icon: "percent", color: .green)
            }
            .padding()
        }
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Chart Components

/// An interactive chart visualizing Heart Rate history over time.
/// Supports drag gestures to inspect specific data points.
struct ModernChart: View {
    let data: [ChartDataPoint]
    
    // Interaction State
    @State private var selectedDate: Date?
    @State private var selectedHR: Double?
    
    // Dynamic Scale Calculation
    var minHR: Double { data.map { $0.value }.min() ?? 40 }
    var maxHR: Double { data.map { $0.value }.max() ?? 140 }
    
    var body: some View {
        VStack(alignment: .leading) {
            // Context Header: Shows details when dragging, or a hint otherwise.
            if let selectedHR, let selectedDate {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(Int(selectedHR)) BPM")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("at " + selectedDate.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                .transition(.opacity)
            } else {
                Text("Swipe to see details")
                    .font(.caption)
                    .foregroundStyle(.gray.opacity(0.5))
            }
            
            // Chart Implementation
            Chart {
                ForEach(data) { point in
                    LineMark(
                        x: .value("Time", point.date),
                        y: .value("BPM", point.value)
                    )
                    .foregroundStyle(Color.red)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                }
                
                // Interactive Cursor (Visible on Drag)
                if let selectedDate, let selectedHR {
                    RuleMark(x: .value("Selected Time", selectedDate))
                        .foregroundStyle(Color.white.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                        .annotation(position: .top) {
                            VStack(spacing: 0) {
                                Text("\(Int(selectedHR))")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white)
                                    .cornerRadius(8)
                                Image(systemName: "arrowtriangle.down.fill")
                                    .font(.system(size: 6))
                                    .foregroundStyle(.white)
                                    .offset(y: -1)
                            }
                        }
                    
                    PointMark(
                        x: .value("Selected Time", selectedDate),
                        y: .value("Value", selectedHR)
                    )
                    .foregroundStyle(.white)
                    .symbolSize(50)
                }
            }
            .chartYScale(domain: (minHR - 5)...(maxHR + 5))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) {
                    AxisValueLabel(format: .dateTime.hour().minute(), centered: true)
                        .foregroundStyle(Color.white.opacity(0.5))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) {
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.1))
                    AxisValueLabel().foregroundStyle(Color.white.opacity(0.5))
                }
            }
            // Gesture Handling for Interactivity
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let startX = value.location.x
                                    // Map X position to Date
                                    if let currentXDate: Date = proxy.value(atX: startX) {
                                        // Find closest data point
                                        if let closestPoint = data.min(by: { abs($0.date.timeIntervalSince(currentXDate)) < abs($1.date.timeIntervalSince(currentXDate)) }) {
                                            self.selectedDate = closestPoint.date
                                            self.selectedHR = closestPoint.value
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    // Reset interaction state
                                    withAnimation {
                                        self.selectedDate = nil
                                        self.selectedHR = nil
                                    }
                                }
                        )
                }
            }
            .frame(height: 200)
        }
        .padding(.horizontal)
    }
}

/// Helper view for individual statistics within the sleep report grid.
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
