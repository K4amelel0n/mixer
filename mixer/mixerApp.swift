//
//  mixerApp.swift
//  mixer
//
//  Created by DawidKozaczuk on 26/01/2026.
//

import SwiftUI
import os
class AppDelegate: NSObject, NSApplicationDelegate{
    var mixer: AudioMixer?
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Logger.mixer.info("App terminating - cleaning up")
        
        // Perform cleanup on background thread to avoid blocking main thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.mixer?.shoutDown()
            
            // Signal that we're ready to terminate
            DispatchQueue.main.async {
                Logger.mixer.info("Cleanup complete")
                sender.reply(toApplicationShouldTerminate: true)
            }
        }
        
        // Tell the system to wait for us
        return .terminateLater
    }
}



@main
struct mixerApp: App {
 
    @State private var mixer = AudioMixer()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init(){
        

    }
    var body: some Scene {
        WindowGroup {
            ContentView().environment(mixer).onAppear{
                appDelegate.mixer = mixer
            }
        }
    }
}
