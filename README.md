# SpeedySloth: Creating a Workout

Use the Workout Builder API to start, stop, and to save workouts on Apple Watch.

## Overview

This sample demonstrates how to create an Apple Watch workout app using the Workout Builder API. The sample displays real-time data, such as heart rate, distance traveled, and elapsed time during an active workout. The user can tap on a button on the inital interface to start the workout, and force-press on the workout interface to bring up the context menu to pause or to stop the workout.

## Configure the Sample Code Project

To build and run this sample on your devices, you must first change the bundle IDs to the pattern described in order to provision the apps correctly in your environment:

- **iOS target:** `<Your iOS app bundle ID>`
- **WatchKit app target:** `<Your iOS app bundle ID>.watchkitapp`
- **WatchKit Extension target:** `<Your iOS app bundle ID>.watchkitapp.watchkitextension`

Follow these steps to change the bundle IDs:

1. Open the sample with the latest version of Xcode.
2. Select the top-level project.
3. For the three targets, change the bundle identifier to the appropriate value.
4. For the targets, select the correct team in the Signing section (next to Team) to let Xcode automatically manage your provisioning profile. 

Additionally, configure the `Info.plist` files with the correct bundle IDs:

1. Open the `Info.plist` file of the WatchKit app target, and change the value of `WKCompanionAppBundleIdentifier` key to `<Your iOS app bundle ID>`.
2. Open the `Info.plist` file of the WatchKit Extension target, and change the value of the `NSExtension > NSExtensionAttributes > WKAppBundleIdentifier` key to `<Your iOS app bundle ID>.watchkitapp`.

Make a clean build and run the apps on your devices. Restart the devices in case Xcode is unable to install and run the apps.

## Request Authorization

Workout apps access the HealthKit data store for real-time data, and to save workouts. The app must request authorization from the user to access the data and save the workout.

``` swift
// The quantity type to write to the health store.
let typesToShare: Set = [
    HKQuantityType.workoutType()
]

// The quantity types to read from the health store.
let typesToRead: Set = [
    HKQuantityType.quantityType(forIdentifier: .heartRate)!,
    HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
    HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
]

// Request authorization for those quantity types.
healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { (success, error) in
    // Handle error. No error handling in this sample project.
}
```
[View in Source](x-source-tag://RequestAuthorization)

You must make this request in both the WatchKit extension and in the companion iOS app, because watchOS will ask the user to give authorization on the companion iPhone.

## Create the Workout Session and Live Workout Builder
First, the app creates an [`HKWorkoutConfiguration`]( https://developer.apple.com/documentation/healthkit/hkworkoutconfiguration ) object, and sets its properties to describe the type of activity corresponding to this workout. In this case, the app sets the `activityType` property to `.running` to represent a running workout activity. HealthKit provides constants for dozens of popular workout and fitness activities.
``` swift
let configuration = HKWorkoutConfiguration()
configuration.activityType = .running
configuration.locationType = .outdoor
```
[View in Source](x-source-tag://WorkoutConfiguration)

Then the app creates the [`HKWorkoutSession`]( https://developer.apple.com/documentation/healthkit/hkworkoutsession ), which is required in order to save a workout in the HealthKit store. This initialization can throw an exception if the workout configuration parameter is invalid. Then the app asks the workout session object for the associated [`HKLiveWorkoutBuilder`]( https://developer.apple.com/documentation/healthkit/hkliveworkoutbuilder ) object. The `HKLiveWorkoutBuilder` object automates the collection of HealthKit quantity types that the app displays to the user during the workout.
``` swift
do {
    session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
    builder = session.associatedWorkoutBuilder()
} catch {
    dismiss()
    return
}
```
[View in Source](x-source-tag://CreateWorkout)

## Set the Data Source
The app initializes a new [`HKLiveWorkoutDataSource`]( https://developer.apple.com/documentation/healthkit/hkliveworkoutdatasource ) object, configured with the same workout configuration object used earlier in creating the workout session. As a result, the data source infers the quantity types to collect. The app sets the `HKLiveWorkoutDataSource` object as the workout builder object's data source. 
``` swift
builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore,
                                             workoutConfiguration: configuration)
```
[View in Source](x-source-tag://SetDataSource)

## Start the Session and the Builder
The workout session and workout builder objects are now fully set up, so the app starts the workout session and the workout builder's data collection.
``` swift
session.startActivity(with: Date())
builder.beginCollection(withStart: Date()) { (success, error) in
    self.setDurationTimerDate(.running)
}
```
[View in Source](x-source-tag://StartSession)

## Update the Workout Timer
To let the user know how long the workout has been in progress, the app implements the workout timer as a [`WKInterfaceTimer`]( https://developer.apple.com/documentation/watchkit/wkinterfacetimer ) object. The timer updates every time the workout builder collects an [`HKWorkoutEvent`]( https://developer.apple.com/documentation/healthkit/hkworkoutevent ) event. To do this, the app implements the [`HKLiveWorkoutBuilderDelegate`]( https://developer.apple.com/documentation/healthkit/hkliveworkoutbuilderdelegate ) protocol's [`workoutBuilderDidCollectEvent(_:)`]( https://developer.apple.com/documentation/healthkit/hkliveworkoutbuilderdelegate/2994347-workoutbuilderdidcollectevent ) method, which updates the timer using the value of the elapsed time from the workout builder.
``` swift
let timerDate = Date(timeInterval: -self.builder.elapsedTime, since: Date())
```
[View in Source](x-source-tag://ObtainElapsedTime)

Next, if the workout session is running, the app starts the timer. If the session is not running, the app stops the timer. 
``` swift
sessionState == .running ? self.timer.start() : self.timer.stop()
```
[View in Source](x-source-tag://UpdateTimer)

## Update the User Interface
When HealthKit has new quantities available, it calls the `HKLiveWorkoutBuilderDelegate` protocol's [`workoutBuilder(_:didCollectDataOf:)`]( https://developer.apple.com/documentation/healthkit/hkliveworkoutbuilderdelegate/2962897-workoutbuilder ) method. The app iterates on the collected quantity types to retrieve the most recent values and to update the user interface. For example, the app uses the following process to update the label for the heart rate. First, the app calls the workout builder's' [`statistics(for:)`]( https://developer.apple.com/documentation/healthkit/hkworkoutbuilder/2962922-statistics ) method to obtain the  [`HKStatistics`]( https://developer.apple.com/documentation/healthkit/hkstatistics  ) object corresponding to the quantity type in the current iteration.
``` swift
let statistics = workoutBuilder.statistics(for: quantityType)
```
[View in Source](x-source-tag://GetStatistics)

Then, the app retrieves the most recent value collected from the `HKStatistics` object, rounds it, and sets the label's text.
``` swift
let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
let value = statistics.mostRecentQuantity()?.doubleValue(for: heartRateUnit)
let roundedValue = Double( round( 1 * value! ) / 1 )
label.setText("\(roundedValue) BPM")
```
[View in Source](x-source-tag://SetLabel)

## Save the Workout

When the user has finished working out, they tap on the Stop button in the context menu. In response, the app should stop collecting data and end the workout session. The app calls the workout builder's [`endCollection(withEnd:completion:)`]( https://developer.apple.com/documentation/healthkit/hkworkoutbuilder/3000762-endcollection ) method to end the collection of data. Then the app saves the workout along with the associated collected samples and events by calling [`finishWorkout(completion:)`]( https://developer.apple.com/documentation/healthkit/hkworkoutbuilder/3000764-finishworkout ). In the completion block, the app dismisses the workout interface, and presents the initial interface again.
``` swift
session.end()
builder.endCollection(withEnd: Date()) { (success, error) in
    self.builder.finishWorkout { (workout, error) in
        // Dispatch to main, because we are updating the interface.
        DispatchQueue.main.async() {
            self.dismiss()
        }
    }
}
```
[View in Source](x-source-tag://SaveWorkout)

