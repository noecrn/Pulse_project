//
//  BLEManager.swift
//  Pulse app
//
//  Created by Noé Cornu on 20/10/2025.
//

import Foundation
import CoreBluetooth
import Combine

/// A singleton-like manager responsible for all Bluetooth Low Energy (BLE) interactions.
///
/// This class handles the lifecycle of the Bluetooth connection, including:
/// - Scanning for specific peripherals (e.g., "Forerunner 255").
/// - Connecting and discovering services.
/// - Subscribing to characteristic notifications (specifically Heart Rate).
/// - Decoding raw byte data into usable integer values.
class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    // MARK: - Properties
    
    /// The central manager that orchestrates all Bluetooth actions.
    var centralManager: CBCentralManager!
    
    /// The connected peripheral device (e.g., the Pulse bracelet or Garmin watch).
    /// We keep a strong reference to prevent it from being deallocated during connection.
    var pulsePeripheral: CBPeripheral?
    
    /// Reference to the data processor for ingesting live sensor readings.
    var dataProcessor: DataProcessor?

    // MARK: - Published States
    
    /// A user-friendly string describing the current connection state (e.g., "Scanning...", "Connected").
    @Published var connectionStatus: String = "Disconnected"
    
    /// A boolean flag indicating if the device is currently connected and ready.
    @Published var isConnected: Bool = false
    
    /// The latest heart rate value received from the device, in Beats Per Minute (BPM).
    @Published var heartRate: Int? = nil
    
    // MARK: - Constants
    
    /// The standard BLE UUID for the Heart Rate Measurement characteristic (0x2A37).
    private let heartRateCharacteristicUUID = CBUUID(string: "2A37")
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        // Initialize the Central Manager.
        // 'delegate: self' ensures this class receives state updates and discovery events.
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - CBCentralManagerDelegate Methods

    /// Called whenever the Bluetooth hardware state changes (Powered On, Off, Unauthorized, etc.).
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            connectionStatus = "Bluetooth ON. Scanning..."
            // Start scanning for devices. Passing nil scans for all devices (not recommended for production, but useful for testing).
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        } else {
            connectionStatus = "Bluetooth unavailable."
            isConnected = false
        }
    }

    /// Called when a peripheral is discovered during the scan.
    ///
    /// - Parameters:
    ///   - central: The central manager providing the update.
    ///   - peripheral: The discovered peripheral device.
    ///   - advertisementData: A dictionary containing advertisement data.
    ///   - RSSI: The current signal strength (Received Signal Strength Indicator).
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Filter devices by name.
        // TODO: Replace "Forerunner 255" with your specific device name.
        if let peripheralName = peripheral.name, peripheralName.contains("Forerunner 255") {
            print("Pulse Device Found: \(peripheralName)")
            
            // 1. Save reference to the peripheral
            self.pulsePeripheral = peripheral
            self.pulsePeripheral?.delegate = self
            
            // 2. Stop scanning to save battery
            centralManager.stopScan()
            
            // 3. Initiate connection
            centralManager.connect(peripheral, options: nil)
            connectionStatus = "Connecting to \(peripheralName)..."
        }
    }

    /// Called when the connection to the peripheral is successful.
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionStatus = "Connected to \(peripheral.name ?? "Pulse Device")"
        isConnected = true
        print("Connection Successful!")
        
        // Discover available services on the device.
        peripheral.discoverServices(nil)
    }

    /// Called when the device disconnects (unexpectedly or intentionally).
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectionStatus = "Disconnected"
        isConnected = false
        print("Device disconnected. Restarting scan...")
        
        // Automatically restart scanning to attempt reconnection.
        centralManager.scanForPeripherals(withServices: nil, options: nil)
    }
    
    // MARK: - CBPeripheralDelegate Methods (Services & Characteristics)

    /// Called when services are discovered on the connected peripheral.
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            print("Service Discovered: \(service.uuid.uuidString)")
            // Discover characteristics for each service.
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    /// Called when characteristics are discovered for a specific service.
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            print("Characteristic Discovered: \(characteristic.uuid.uuidString)")
            
            // Check if the characteristic supports notifications (real-time data stream).
            if characteristic.properties.contains(.notify) {
                print("Subscribing to characteristic \(characteristic.uuid.uuidString)...")
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    // MARK: - Data Handling

    /// Called when a characteristic updates its value (e.g., new heart rate data arrives).
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        
        // Handle Heart Rate Measurement (UUID 2A37)
        if characteristic.uuid == heartRateCharacteristicUUID {
            
            let hrValue = parseHeartRate(from: data)
            print(">>> Heart Rate: \(hrValue) BPM")

            // Update the UI and DataProcessor on the main thread
            DispatchQueue.main.async {
                self.heartRate = hrValue
                // Pass data to the processor (Accelerometer data is mocked as 0.0 for now if using a standard HR monitor)
                self.dataProcessor?.add(heartRate: Double(hrValue), accelX: 0.0, accelY: 0.0, accelZ: 0.0)
            }
            
        } else {
            // Handle other characteristics here
            print("Received data from: \(characteristic.uuid.uuidString) - \(data.count) bytes")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Decodes the raw byte data from the standard BLE Heart Rate characteristic.
    ///
    /// The standard defines flags in the first byte that determine the format of the subsequent bytes.
    /// - Parameter data: The raw `Data` object received from Bluetooth.
    /// - Returns: The heart rate as an `Int`.
    private func parseHeartRate(from data: Data) -> Int {
        let bytes = [UInt8](data)
        guard !bytes.isEmpty else { return 0 }
        
        // The first byte contains flags
        let flags = bytes[0]
        
        // Check the first bit (Bit 0) to determine format:
        // 0 = 8-bit Heart Rate (UINT8)
        // 1 = 16-bit Heart Rate (UINT16)
        let is16Bit = (flags & 0x01) != 0
        
        if is16Bit {
            // HR Value is in the 2nd and 3rd bytes (Little Endian)
            if bytes.count >= 3 {
                let heartRate = (UInt16(bytes[1]) & 0xFF) | (UInt16(bytes[2]) << 8)
                return Int(heartRate)
            }
        } else {
            // HR Value is in the 2nd byte
            if bytes.count >= 2 {
                let heartRate = bytes[1]
                return Int(heartRate)
            }
        }
        
        return 0 // Fallback if data is malformed
    }
}
