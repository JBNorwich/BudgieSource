//
//  Untitled.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 20/03/2025.
//
import SwiftUI
import HealthKitUI

struct ActivityRingView: UIViewRepresentable {

    var activitySummary: HKActivitySummary

    func makeUIView(context: Context) -> HKActivityRingView {
        let frame = CGRect(x: 0, y: 0, width: 90, height: 90)
        let view = HKActivityRingView(frame: frame)
            
        return view
    }

    func updateUIView(_ uiView: HKActivityRingView, context: Context) {
        uiView.activitySummary = self.activitySummary
    }
}

struct FitnessView: View {
    @EnvironmentObject var todayLump: TodayLump
    
    var body: some View {
        ActivityRingView(activitySummary: todayLump.activitySummary)
            .background(.clear)
            .frame(width: 90, height: 90)
            .onTapGesture {
                UIApplication.shared.open(URL(string: "fitnessapp://")!)
        }
    }
}
