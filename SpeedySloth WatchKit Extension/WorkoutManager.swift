/*
See LICENSE folder for this sample’s licensing information.

Abstract:
This file contains the business logic, which is the interface to HealthKit.
*/

import Foundation
import HealthKit
import Combine
import CoreData

extension Double {
    func format(f: String) -> String {
        return String(format: "%\(f)f", self)
    }
}

class PersistenceManager {
  let persistentContainer: NSPersistentContainer = {
      let container = NSPersistentContainer(name: "MyApplication")
      container.loadPersistentStores(completionHandler: { (storeDescription, error) in
          if let error = error as NSError? {
              fatalError("Unresolved error \(error), \(error.userInfo)")
          }
      })
      return container
  }()
}

class WorkoutManager: NSObject, ObservableObject {
    
    let persistence = PersistenceManager()
    
    /// - Tag: DeclareSessionBuilder
    let healthStore = HKHealthStore()
    var session: HKWorkoutSession!
    var builder: HKLiveWorkoutBuilder!
    
    // Publish the following:
    // - heartrate
    // - active calories
    // - distance moved
    // - elapsed time
    // - steps
    
    /// - Tag: Publishers
    @Published var heartrate: Double = 0
    @Published var activeCalories: Double = 0
    @Published var distance: Double = 0
    @Published var stepCount: Double = 0
    @Published var elapsedSeconds: Int = 0
    
    var activeCalorieGoalReached: Bool = false
    var activeCalorieGoal: Double = 5
    
    //heart rate
    var heartRateSum: Double = 0
    var heartRateCount: Double = 0
    
    var calorieCount: Double = 0
    var calorieMaxAvg: Double = 0
    
    //step count
    var stepCountSum: Double = 0
    var StepCountCount: Double = 0
    var stepCountMaxAvg: Double = 0
    
    //distance
    var distanceCount: Double = 0
    var distanceMaxAvg: Double = 0
    var distanceLastTime: Date = Date()
    
    //speed (derived)
    var speedSum: Double = 0
    var speedCount: Double = 0
    var speedMaxAvg: Double = 0
        
    // The app's workout state.
    var running: Bool = false
    
    /// - Tag: TimerSetup
    // The cancellable holds the timer publisher.
    var start: Date = Date()
    var cancellable: Cancellable?
    var accumulatedTime: Int = 0
    
    var workouts: Workouts = Workouts()
    var workout: Workout = Workout()
    
    // Set up and start the timer.
    func setUpTimer() {
        print("setUpTimer")
        start = Date()
        cancellable = Timer.publish(every: 0.1, on: .main, in: .default)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.elapsedSeconds = self.incrementElapsedTime()
            }
    }
    
    // Calculate the elapsed time.
    func incrementElapsedTime() -> Int {
        let runningTime: Int = Int(-1 * (self.start.timeIntervalSinceNow))
        return self.accumulatedTime + runningTime
    }
    
    // Request authorization to access HealthKit.
    func requestAuthorization() {
        print("requestAuthorization")
        // Requesting authorization.
        /// - Tag: RequestAuthorization
        // The quantity type to write to the health store.
        let typesToShare: Set = [
            HKQuantityType.workoutType()
        ]
        
        // The quantity types to read from the health store.
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
        ]
        
        // Request authorization for those quantity types.
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { (success, error) in
            // Handle error.
            if error != nil {
                print("healthStore.requestAuthorization error \(error!)")
            }
        }
    }
    
    // Provide the workout configuration.
    func workoutConfiguration() -> HKWorkoutConfiguration {
        print("workoutConfiguration")
        /// - Tag: WorkoutConfiguration
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor
        
        return configuration
    }
    
    func loadWorkouts(){
        let defaults = UserDefaults.standard
        guard let json = defaults.string(forKey: "workouts") else {
            print("couldnt get userdefaults for workouts")
            return
        }
        guard let jsonData: Data = json.data(using: .utf8) else {
            print("couldnt convert workouts string to Data")
            return
        }
        
        do {
            workouts = try JSONDecoder().decode(Workouts.self, from: jsonData)
        } catch { print(error) }
        
        guard let numWorkouts = workouts.workouts?.count else {
            print("couldnt get count of workouts")
            return
        }
        print("numWorkouts: \(numWorkouts)")
    }
    
    func saveWorkouts() {
        do {
            let json = try JSONEncoder().encode(workouts)
            let encode = String(data: json, encoding: .utf8)!
            let defaults = UserDefaults.standard
            defaults.set(encode, forKey: "workouts")
        } catch { print(error) }
    }
    
    // Start the workout.
    func startWorkout() {
        print("startWorkout")
        
        //load workouts from userprefs/db
        loadWorkouts()
        
        workout.startTime = Date()
        
        //print("workout \(workout)")
        // Start the timer.
        setUpTimer()
        self.running = true
        
        // Create the session and obtain the workout builder.
        /// - Tag: CreateWorkout
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: self.workoutConfiguration())
            builder = session.associatedWorkoutBuilder()
        } catch {
            print(error)
            return
        }
        
        // Setup session and builder.
        session.delegate = self
        builder.delegate = self
        
        // Set the workout builder's data source.
        /// - Tag: SetDataSource
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore,
                                                     workoutConfiguration: workoutConfiguration())
        
        // Start the workout session and begin data collection.
        /// - Tag: StartSession
        session.startActivity(with: Date())
        builder.beginCollection(withStart: Date()) { (success, error) in
            // The workout has started.
            if error != nil {
                print("builder.beginCollection error \(error!)")
            }
        }
    }
    
    // MARK: - State Control
    func togglePause() {
        print("togglePause")
        // If you have a timer, then the workout is in progress, so pause it.
        if running == true {
            self.pauseWorkout()
        } else {// if session.state == .paused { // Otherwise, resume the workout.
            resumeWorkout()
        }
    }
    
    func pauseWorkout() {
        print("pauseWorkout")
        // Pause the workout.
        session.pause()
        // Stop the timer.
        cancellable?.cancel()
        // Save the elapsed time.
        accumulatedTime = elapsedSeconds
        running = false
    }
    
    func resumeWorkout() {
        print("resumeWorkout")
        // Resume the workout.
        session.resume()
        // Start the timer.
        setUpTimer()
        running = true
    }
    
    func endWorkout() {
        print("endWorkout")
        workout.endTime = Date()
        workouts.workouts?.append(workout)
        
        //save workouts to userprefs/db
        saveWorkouts()
    
        // End the workout session.
        session.end()
        cancellable?.cancel()
    }
    
    func resetWorkout() {
        print("resetWorkout")
        // Reset the published values.
        DispatchQueue.main.async {
            self.elapsedSeconds = 0
        }
    }
    
    func addToRawData(type : WorkoutDataType, data : RawDatum){
        guard var rd: [RawDatum] = self.workout.rawData?[type] else {
            print("couldnt get rd for \(type)")
            return
        }
        rd.append(data)
        self.workout.rawData?[type] = rd
    }
    
    // MARK: - Update the UI
    // Update the published values.
    func updateForStatistics(_ statistics: HKStatistics?) {
        guard let statistics = statistics else { return }
        
        DispatchQueue.main.async {
            //print("elapsedTime \(self.elapsedSeconds)")
            switch statistics.quantityType {
            case HKQuantityType.quantityType(forIdentifier: .heartRate):
                /// - Tag: SetLabel
                let unit = HKUnit.count().unitDivided(by: HKUnit.minute())
                let value = statistics.mostRecentQuantity()?.doubleValue(for: unit)
                let roundedValue = Double( round( 1 * value! ) / 1 )
                self.heartrate = roundedValue
                self.heartRateSum += roundedValue
                
                //let avgHeartRate = (self.heartRateSum / self.heartRateCount)
                //print("healthrate \(self.heartrate) avgHeartRate \(avgHeartRate.format(f: "0.2")) heartRateCount \(self.heartRateCount)")
                
                self.addToRawData(type: WorkoutDataType.heartRate, data: RawDatum(secTime: self.elapsedSeconds, value: roundedValue))
                
                return
            case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                let unit = HKUnit.kilocalorie()
                let value = statistics.sumQuantity()?.doubleValue(for: unit)
                let roundedValue = Double( round( 1 * value! ) / 1 )
                self.activeCalories = roundedValue

                //print("activeCalories \(self.activeCalories)")
                if !self.activeCalorieGoalReached && roundedValue >= self.activeCalorieGoal {
                    //print("activeCalories Goal \(self.activeCalorieGoal) Reached")
                    self.activeCalorieGoalReached = true
                }
                
                self.addToRawData(type: WorkoutDataType.calories, data: RawDatum(secTime: self.elapsedSeconds, value: roundedValue))
                
                return
            case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning):
                let unit = HKUnit.foot()
                let value = statistics.sumQuantity()?.doubleValue(for: unit)
                let roundedValue = Double( round( 1 * value! ) / 1 )
                self.distance = roundedValue
                let diffDistance = (roundedValue - roundedValue)
                //let diffDistanceMeters = Measurement(value: diffDistance, unit: UnitLength.meters)
                //let diffDistanceFeet = diffDistanceMeters.converted(to: UnitLength.feet)
                
                
                let diffTime = self.distanceLastTime.timeIntervalSinceNow * -1
                self.distanceLastTime = Date()
                
                //let speedFeetPerSec = diffDistanceFeet.value / diffTime //feet per sec
                let speedFeetPerSec = diffDistance / diffTime //feet per sec
                let speedMilesPerHour = speedFeetPerSec * 0.681818
                
                self.speedSum += speedMilesPerHour
                let speedAvg = self.speedSum / self.distanceCount
                
                if speedAvg > self.speedMaxAvg {
                    self.speedMaxAvg = speedAvg
                    print("max speed avg BEATEN!")
                }
                
                //print("speedMetersPerSec \(speedMeterPerSec) speedFeetPerSec \(speedFeetPerSec) speedMilesPerHour \(speedMilesPerHour) speedAvg \(speedAvg) speedMaxAvg \(self.speedMaxAvg)")
                //print("speedMPH \(speedMilesPerHour.format(f:".2")) speedAvg \(speedAvg.format(f:".2")) speedMaxAvg \(self.speedMaxAvg.format(f:".2"))")
                
                self.addToRawData(type: WorkoutDataType.distance, data: RawDatum(secTime: self.elapsedSeconds, value: roundedValue))
                
                return
            case HKQuantityType.quantityType(forIdentifier: .stepCount):
                let unit = HKUnit.count()
                let value = statistics.sumQuantity()?.doubleValue(for: unit)
                let roundedValue = Double( round( 1 * value! ) / 1 )
                self.stepCount = roundedValue
                
                print("stepCount \(roundedValue)")
                
                self.addToRawData(type: WorkoutDataType.steps, data: RawDatum(secTime: self.elapsedSeconds, value: roundedValue))
                
                return
            default:
                return
            }
        }
    }
}

// MARK: - HKWorkoutSessionDelegate
extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState, date: Date) {
        print("workoutSession")
        // Wait for the session to transition states before ending the builder.
        /// - Tag: SaveWorkout
        if toState == .ended {
            print("The workout has now ended.")
            builder.endCollection(withEnd: Date()) { (success, error) in
                if error != nil {
                    print("builder.endCollection error \(error!)")
                }
                
                self.builder.finishWorkout { (workout, error) in
                    if error != nil {
                        print("builder.finishWorkout error \(error!)")
                    }
                    
                    // Optionally display a workout summary to the user.
                    self.resetWorkout()
                }
            }
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        
    }
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        //print("workoutBuilder")
        for type in collectedTypes {
            //print("type \(type)")
            guard let quantityType = type as? HKQuantityType else {
                return // Nothing to do.
            }
            
            /// - Tag: GetStatistics
            let statistics = workoutBuilder.statistics(for: quantityType)
            
            // Update the published values.
            updateForStatistics(statistics)
        }
    }
}
