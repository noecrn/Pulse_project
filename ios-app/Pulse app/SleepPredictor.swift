//
//  SleepPredictor.swift
//  Pulse app
//
//  Created by Noé Cornu on 23/12/2025.
//

import CoreML
import Foundation

class SleepPredictor {

    private let model: PulseClassifier?

    init() {
        self.model = try? PulseClassifier(configuration: MLModelConfiguration())
    }

    // Predicts 0 (Awake) or 1 (Asleep) from 11 features
    func predict(features: [Double]) -> Int64 {
        guard let model = model, features.count == 11 else { return 0 }
        
        do {
            // Convert input to MLMultiArray (1x11, Float32)
            let inputMatrix = try MLMultiArray(shape: [1, 11], dataType: .float32)
            for (i, feature) in features.enumerated() {
                inputMatrix[i] = NSNumber(value: feature)
            }
            
            // Run prediction ('x_1' is the input name)
            let input = PulseClassifierInput(x_1: inputMatrix)
            let output = try model.prediction(input: input)
            
            // Return result ('var_125' is the output name)
            return output.var_125[0].int64Value
            
        } catch {
            print("Prediction Error: \(error)")
            return 0
        }
    }
}
