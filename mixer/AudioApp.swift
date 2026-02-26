//
//  AudioApp.swift
//  mixer
//
//  Created by DawidKozaczuk on 23/02/2026.
//
import Foundation
import AppKit

class AudioApp {
  
    let name: String
    let processes: [AudioProcess]
    let icon: NSImage?
    
    init(name: String, processes: [AudioProcess], icon:NSImage?){
        self.name = name
        self.processes = processes
        self.icon = icon
    }
    
    

}




