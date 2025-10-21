//
//  DataProcessor.swift
//  Pulse app
//
//  Created by Noé Cornu on 20/10/2025.
//

import Foundation
import Combine

// Une structure pour stocker proprement chaque point de donnée reçu.
// C'est plus propre que de manipuler plein de variables séparées.
struct SensorDataPoint {
    let timestamp: Date
    let heartRate: Double
    let vectorMagnitude: Double
}

// Notre classe principale pour le traitement des données.
// Elle est aussi ObservableObject pour pouvoir communiquer ses résultats facilement.
class DataProcessor: ObservableObject {

    // MARK: - Propriétés
    
    // Le "cahier de notes" de notre processeur. Il garde en mémoire
    // les données des 15 dernières minutes.
    private var dataPoints: [SensorDataPoint] = []
    
    // quand ce vecteur est mis à jour.
    @Published var featureVector: [Double] = []
    
    // Constante pour définir la durée de notre historique (15 minutes en secondes).
    private let storageInterval: TimeInterval = 15 * 60

    // TODO: Plus tard, nous ajouterons une propriété @Published pour le vecteur de caractéristiques final.
    // @Published var featureVector: [Double] = []

    // MARK: - Méthode d'Entrée Publique

    /// Ajoute une nouvelle mesure de capteur à notre historique.
    /// C'est cette fonction que le BLEManager appellera.
    public func add(heartRate: Double, accelX: Double, accelY: Double, accelZ: Double) {
        
        // 1. Calculer la magnitude du vecteur de l'accéléromètre.
        // C'est une mesure globale du mouvement.
        let magnitude = sqrt(pow(accelX, 2) + pow(accelY, 2) + pow(accelZ, 2))
        
        // 2. Créer un nouveau point de donnée avec un horodatage actuel.
        let newDataPoint = SensorDataPoint(timestamp: Date(), heartRate: heartRate, vectorMagnitude: magnitude)
        
        // 3. Ajouter ce point à notre historique.
        dataPoints.append(newDataPoint)
        
        // 4. Nettoyer les données qui sont trop vieilles (plus de 15 minutes).
        cleanupOldData()

        // Décommente cette ligne pour déclencher les calculs à chaque nouvelle donnée.
        processNewFeatures()
        
        // Pour le débogage, on peut afficher le nombre de points que l'on a.
        print("Point de donnée ajouté. Total en mémoire: \(dataPoints.count)")
    }
    
    // MARK: - Logique Interne

    /// Supprime les points de données qui datent de plus de 15 minutes pour ne pas surcharger la mémoire.
    private func cleanupOldData() {
        let fifteenMinutesAgo = Date().addingTimeInterval(-storageInterval)
        
        // On ne garde que les points dont le timestamp est plus récent que "il y a 15 minutes".
        dataPoints.removeAll { $0.timestamp < fifteenMinutesAgo }
    }
    
    /// Calcule toutes les caractéristiques statistiques à partir de l'historique des données.
    private func processNewFeatures() {
        // On s'assure d'avoir au moins quelques données avant de commencer les calculs.
        guard !dataPoints.isEmpty else { return }
        
        // --- 1. Définir les fenêtres de temps ---
        let now = Date()
        let sixtySecondsAgo = now.addingTimeInterval(-60)
        let fiveMinutesAgo = now.addingTimeInterval(-5 * 60)
        let fifteenMinutesAgo = now.addingTimeInterval(-15 * 60) // Déjà défini, mais plus clair ici

        // --- 2. Filtrer les données pour chaque fenêtre ---
        // On crée des sous-tableaux contenant uniquement les données pertinentes pour chaque période.
        let last60sData = dataPoints.filter { $0.timestamp > sixtySecondsAgo }
        let last5minData = dataPoints.filter { $0.timestamp > fiveMinutesAgo }
        // Pour les 15 minutes, on peut simplement utiliser toutes les données en mémoire.
        let last15minData = dataPoints
        
        // --- 3. Extraire les valeurs brutes (HR et Mouvement) pour chaque fenêtre ---
        // On transforme nos tableaux de "SensorDataPoint" en simples tableaux de nombres [Double].
        let hr60s = last60sData.map { $0.heartRate }
        let vm60s = last60sData.map { $0.vectorMagnitude }
        
        let hr5min = last5minData.map { $0.heartRate }
        let vm5min = last5minData.map { $0.vectorMagnitude }
        
        let hr15min = last15minData.map { $0.heartRate }
        let vm15min = last15minData.map { $0.vectorMagnitude }

        // --- 4. Calculer toutes les statistiques ---
        // On utilise nos super fonctions .mean() et .stdDev() qu'on a créées plus tôt.
        // Période de 60 secondes
        let hr_mean_60s = hr60s.mean()
        let hr_std_60s = hr60s.stdDev()
        let vm_mean_60s = vm60s.mean()
        let vm_std_60s = vm60s.stdDev()

        // Période de 5 minutes
        let hr_mean_5min = hr5min.mean()
        let hr_std_5min = hr5min.stdDev()
        let vm_mean_5min = vm5min.mean()
        let vm_std_5min = vm5min.stdDev()

        // Période de 15 minutes
        let hr_mean_15min = hr15min.mean()
        let hr_std_15min = hr15min.stdDev()
        let vm_mean_15min = vm15min.mean()
        let vm_std_15min = vm15min.stdDev()

        // --- 5. Assembler le vecteur de caractéristiques final ---
        // L'ORDRE EST TRÈS IMPORTANT. Il doit correspondre exactement
        // à l'ordre des données avec lequel le modèle a été entraîné.
        let newFeatureVector = [
            hr_mean_60s, hr_std_60s, vm_mean_60s, vm_std_60s,
            hr_mean_5min, hr_std_5min, vm_mean_5min, vm_std_5min,
            hr_mean_15min, hr_std_15min, vm_mean_15min, vm_std_15min
        ]
        
        // --- 6. Mettre à jour la propriété @Published ---
        // En faisant cela, on notifie toute l'application que de nouvelles caractéristiques sont prêtes.
        // On s'assure que cette mise à jour se fait sur le thread principal pour l'UI.
        DispatchQueue.main.async {
            self.featureVector = newFeatureVector
            
            // Pour le débogage, affichons le vecteur dans la console.
            // On formate les nombres pour que ce soit plus lisible.
            let formattedVector = self.featureVector.map { String(format: "%.2f", $0) }.joined(separator: ", ")
            print("Feature Vector: [\(formattedVector)]")
        }
    }
}

// Extension pour faciliter les calculs sur nos listes de données.
// C'est une manière propre d'ajouter des fonctions comme "mean" ou "stdDev"
// à n'importe quel tableau de nombres.
extension Array where Element == Double {
    /// Calcule la moyenne d'un tableau de Double.
    func mean() -> Double {
        guard !isEmpty else { return 0.0 }
        return reduce(0, +) / Double(count)
    }

    /// Calcule l'écart-type d'un tableau de Double.
    func stdDev() -> Double {
        guard count > 1 else { return 0.0 }
        let meanValue = self.mean()
        let sumOfSquaredDiffs = self.map { pow($0 - meanValue, 2.0) }.reduce(0, +)
        return sqrt(sumOfSquaredDiffs / Double(count - 1))
    }
}
