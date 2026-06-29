// Copyright 2026 Joseph Baldwin
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
// documentation files (the "Software"), to deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of
// the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
// OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
// OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

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
