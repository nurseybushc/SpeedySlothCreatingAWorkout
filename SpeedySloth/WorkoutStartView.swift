/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Description about what the file includes goes here.
*/

import UIKit
import HealthKit

class WorkoutStartView: UIViewController {

    let healthStore = HKHealthStore()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "SpeedySloth"
        navigationController?.navigationBar.prefersLargeTitles = true
        
        let typesToShare: Set = [
            HKQuantityType.workoutType()
        ]
        
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { (success, error) in
            // Handle error
            
        }
    }
    
}

