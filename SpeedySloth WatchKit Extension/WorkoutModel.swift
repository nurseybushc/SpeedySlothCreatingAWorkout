//
//  WorkoutModel.swift
//  SpeedySloth WatchKit Extension
//
//  Created by Admin on 2/9/21.
//  Copyright © 2021 Apple. All rights reserved.
//

import Foundation

struct Workouts : Codable {
    init(){
        self.workouts = [Workout]()
    }
    var workouts: [Workout]?
}

struct Workout : Codable {
    init() {
        self.rawData = [WorkoutDataType:[RawDatum]]()
        self.rawData![WorkoutDataType.distance] = [RawDatum]()
        self.rawData![WorkoutDataType.calories] = [RawDatum]()
        self.rawData![WorkoutDataType.heartRate] = [RawDatum]()
        self.rawData![WorkoutDataType.steps] = [RawDatum]()
        
        self.statData = [WorkoutDataType:[StatDatum]]()
        self.statData![WorkoutDataType.distance] = [StatDatum]()
        self.statData![WorkoutDataType.calories] = [StatDatum]()
        self.statData![WorkoutDataType.heartRate] = [StatDatum]()
        self.statData![WorkoutDataType.steps] = [StatDatum]()
    }
    
    var startTime: Date?
    var endTime: Date?
    var rawData: [WorkoutDataType : [RawDatum]]?
    var statData: [WorkoutDataType : [StatDatum]]?
}

struct RawDatum : Codable {
    var secTime: Int?
    var value: Double?
}

struct StatDatum : Codable {
    var secTime: Int?
    var value: Double?
    var type: StatType?
}

enum StatType : String, Codable {
    case sum
    case avg
    case max
    case maxAvg
}

enum WorkoutDataType : String, Codable {
    case calories
    case heartRate
    case distance
    case steps
}
