/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The context to pass to the workout session interface controller.
*/

import Foundation
import HealthKit

class WorkoutSessionContext {
    
    let configuration: HKWorkoutConfiguration
    let healthStore: HKHealthStore
    
    init(healthStore: HKHealthStore, configuration: HKWorkoutConfiguration) {
        self.healthStore = healthStore
        self.configuration = configuration
    }
    
}
