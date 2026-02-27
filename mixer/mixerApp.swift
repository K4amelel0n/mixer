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
        
        guard let mixer = mixer else {return .terminateNow}
        
        mixer.shoutDown()
            
        Logger.mixer.info("Cleanup complete")
        sender.reply(toApplicationShouldTerminate: true)
        
        return .terminateLater
    }
}



@main
struct mixerApp: App {
 
    @State private var mixer = AudioMixer()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
            NSApplication.shared.setActivationPolicy(.accessory)
        }
    
    var body: some Scene {
        
        MenuBarExtra("", systemImage: "point.topleft.down.curvedto.point.bottomright.up"){
            
            ContentView()
                .environment(mixer)
                
        }
        .menuBarExtraStyle(.window)
        .onChange(of: true, initial: true){
                appDelegate.mixer = mixer
        }
    }
}
