//
//  BLEManager.swift
//  Pulse app
//
//  Created by Noé Cornu on 20/10/2025.
//

import Foundation
import CoreBluetooth
import Combine

// Rend notre classe observable par SwiftUI pour que l'interface se mette à jour.
class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    // MARK: - Propriétés
    
    // Le "chef d'orchestre" du Bluetooth. Il scanne, se connecte, etc.
    var centralManager: CBCentralManager!
    // L'appareil Pulse auquel nous sommes connectés.
    var pulsePeripheral: CBPeripheral?
    // Contient la référence vers notre DataProcessor.
    var dataProcessor: DataProcessor?

    // @Published permet à SwiftUI de réagir automatiquement aux changements de ces variables.
    @Published var connectionStatus: String = "Déconnecté"
    @Published var isConnected: Bool = false
    
    // MARK: - Initialisation
    
    override init() {
        super.init()
        // On initialise le chef d'orchestre. Le "delegate: self" signifie que
        // cette classe (BLEManager) recevra tous les événements Bluetooth.
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Logique de Scan et Connexion

    // Cette fonction est appelée automatiquement quand l'état du Bluetooth change (allumé, éteint...).
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            connectionStatus = "Bluetooth activé. Recherche..."
            // Le Bluetooth est prêt, on lance le scan pour trouver notre appareil.
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        } else {
            connectionStatus = "Bluetooth non disponible."
            isConnected = false
        }
    }

    // Cette fonction est appelée chaque fois qu'un appareil BLE est trouvé.
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // NOTE: Il faudra adapter cette condition au nom de ton appareil.
        // Pour l'instant, on se connecte au premier appareil trouvé qui a un nom.
        if let peripheralName = peripheral.name, peripheralName.contains("Forerunner 255") {
            print("Appareil Pulse trouvé: \(peripheralName)")
            
            self.pulsePeripheral = peripheral
            self.pulsePeripheral?.delegate = self
            
            // On a trouvé notre appareil, on arrête de scanner.
            centralManager.stopScan()
            
            // On se connecte à l'appareil.
            centralManager.connect(peripheral, options: nil)
            connectionStatus = "Connexion à \(peripheralName)..."
        }
    }

    // Cette fonction est appelée quand la connexion réussit.
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionStatus = "Connecté à \(peripheral.name ?? "Pulse")"
        isConnected = true
        print("Connexion réussie !")
        
        // Maintenant qu'on est connecté, on cherche les "services" qu'il propose.
        peripheral.discoverServices(nil)
    }

    // Cette fonction est appelée si la connexion échoue ou est perdue.
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectionStatus = "Déconnecté"
        isConnected = false
        print("Appareil déconnecté. Reprise du scan...")
        // On relance le scan pour le retrouver.
        centralManager.scanForPeripherals(withServices: nil, options: nil)
    }
    
    // MARK: - Découverte des Services et Caractéristiques

    // Cette fonction est appelée quand les services de l'appareil ont été trouvés.
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            print("Service trouvé: \(service.uuid.uuidString)")
            // Pour chaque service, on cherche les "caractéristiques" (les canaux de communication).
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    // Cette fonction est appelée quand les caractéristiques d'un service ont été trouvées.
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            print("Caractéristique trouvée: \(characteristic.uuid.uuidString)")
            
            // On vérifie si c'est la caractéristique qui nous intéresse (celle qui envoie des données).
            // On s'abonne aux notifications pour recevoir les données en temps réel.
            if characteristic.properties.contains(.notify) {
                print("Abonnement aux données de la caractéristique \(characteristic.uuid.uuidString)...")
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    // MARK: - Réception des Données

    // Cette fonction est appelée chaque fois que l'appareil Pulse envoie de nouvelles données.
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        
        // 'data' contient les octets bruts envoyés par l'appareil.
        // C'est ici que tu devras ajouter la logique pour décoder ces données
        // et les envoyer au DataProcessor.
        
        // On garde notre exemple de décodage de chaîne de caractères
        if let stringData = String(data: data, encoding: .utf8) {
            print("Données décodées (String): \(stringData)")

            // On sépare la chaîne "72.5,0.1,0.2,0.9" en un tableau de nombres
            let values = stringData.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }

            // On s'assure qu'on a bien reçu 4 valeurs (HR, X, Y, Z)
            if values.count == 4 {
                let heartRate = values[0]
                let accelX = values[1]
                let accelY = values[2]
                let accelZ = values[3]

                // On envoie les données au DataProcessor !
                DispatchQueue.main.async {
                    self.dataProcessor?.add(heartRate: heartRate, accelX: accelX, accelY: accelY, accelZ: accelZ)
                }
            }
        }
    }
}
