//
//  GoalsView.swift
//  SpeedySloth WatchKit Extension
//
//  Created by Admin on 11/29/20.
//  Copyright © 2020 Apple. All rights reserved.
//

import SwiftUI

struct GoalsView: View {
    @EnvironmentObject var workoutSession: WorkoutManager
    
    var body: some View {
        VStack(alignment: .leading) {
            // The workout elapsed time.
            Text("\(elapsedTimeString(elapsed: secondsToHoursMinutesSeconds(seconds: workoutSession.elapsedSeconds)))").frame(alignment: .leading)
                .font(Font.system(size: 26, weight: .semibold, design: .default).monospacedDigit())
                
            // The active calories burned.
            Text("\(workoutSession.activeCalorieGoal, specifier: "%.1f") cal")
            .font(Font.system(size: 26, weight: .regular, design: .default).monospacedDigit())
            .frame(alignment: .leading)
            
            // The current heartrate.
            Text("\(workoutSession.heartrate, specifier: "%.1f") BPM")
            .font(Font.system(size: 26, weight: .regular, design: .default).monospacedDigit())
            
            // The distance traveled.
            Text("\(workoutSession.distance, specifier: "%.1f") m")
            .font(Font.system(size: 26, weight: .regular, design: .default).monospacedDigit())
            Spacer().frame(width: 1, height: 8, alignment: .leading)
             
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .leading)
    }
    
    // Convert the seconds into seconds, minutes, hours.
    func secondsToHoursMinutesSeconds (seconds: Int) -> (Int, Int, Int) {
      return (seconds / 3600, (seconds % 3600) / 60, (seconds % 3600) % 60)
    }
    
    // Convert the seconds, minutes, hours into a string.
    func elapsedTimeString(elapsed: (h: Int, m: Int, s: Int)) -> String {
        return String(format: "%d:%02d:%02d", elapsed.h, elapsed.m, elapsed.s)
    }
}

struct GoalsView_Previews: PreviewProvider {
    static var previews: some View {
        GoalsView().environmentObject(WorkoutManager())
    }
}
