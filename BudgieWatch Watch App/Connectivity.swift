//
//  WatchSettings.swift
//  Budgie DietWatch Watch App
//
//  Created by Joe Baldwin on 06/09/2024.
//

import Foundation
import WatchConnectivity

final class Connectivity: NSObject, ObservableObject {
    @Published var settings: [String:Any] = [:]
    @Published var updated: Bool = false
    static let shared = Connectivity()
    
    override init() {
        super.init()
        
        #if !os(watchOS)
        guard WCSession.isSupported() else {
            return
        }
        #endif
        
        WCSession.default.delegate = self
        WCSession.default.activate()
    }
    
    public func send(settings: [String:Any]) {
        guard WCSession.default.activationState == .activated else {
            return
        }
        
        #if os(watchOS)
        guard WCSession.default.isCompanionAppInstalled else {
            return
        }
        #else
        guard WCSession.default.isWatchAppInstalled else {
            return
        }
        #endif
        
        WCSession.default.transferUserInfo(settings)
        do {
            try WCSession.default.updateApplicationContext(settings)
        } catch {
            print("Failed!")
        }
    }
}

extension Connectivity: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    
    }
    
    func session(_ session: WCSession, didReceiveUserInfo settings:[String:Any] = [:])
    {
        print("Received settings update!")
        let uds = UserDefaults(suiteName: "group.JoeBaldwin.Budgie")
        for (key, value) in settings {
            uds?.setValue(value, forKey: key)
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext settings:[String:Any] = [:])
    {
        print("Received settings update via DRAC!")
        let uds = UserDefaults(suiteName: "group.JoeBaldwin.Budgie")
        for (key, value) in settings {
            uds?.setValue(value, forKey: key)
        }
        self.updated = true
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif
}
