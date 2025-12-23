//
//  Untitled.swift
//  Pulse app
//
//  Created by Noé Cornu on 23/12/2025.
//

import CoreML
import Foundation

class SleepPredictor {
    private let model: PulseClassifier?

    init() {
        // PulseClassifier is the auto-generated class from your .mlmodel file
        self.model = try? PulseClassifier(configuration: MLModelConfiguration())
    }

    func predict(features: [Double]) -> Int64 {
        guard let model = model, features.count == 11 else { return 0 }
        
        do {
            // 1. Create the MLMultiArray
            let inputMatrix = try MLMultiArray(shape: [1, 11], dataType: .float32)
            for (index, feature) in features.enumerated() {
                inputMatrix[index] = NSNumber(value: feature)
            }
            
            // 2. Wrap it in the expected PulseClassifierInput type
            // Use 'x_1' as the input key (based on your conversion logs)
            let input = PulseClassifierInput(x_1: inputMatrix)
            
            // 3. Get the prediction results
            let output = try model.prediction(input: input)
            
            // 4. Extract the integer from the output MLMultiArray (var_125)
            // We access the first element [0] and convert it to Int64
            let resultValue = output.var_125[0].int64Value
            
            return resultValue // Returns 0 (Awake) or 1 (Asleep)
        } catch {
            print("Prediction error: \(error)")
            return 0
        }
    }
}
