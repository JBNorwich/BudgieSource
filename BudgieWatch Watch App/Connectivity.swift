//
//  WatchSettings.swift
//  Budgie DietWatch Watch App
//
//  Created by Joe Baldwin on 06/09/2024.
//

import Foundation
import WatchConnectivity

final class Connectivity {
    static let shared = Connectivity()
    
    private init() {
        #if !os(watchOS)
        guard WCSession.isSupported() else {
            return
        }
        #endif
        
        WCSession.default.activate()
    }
}

