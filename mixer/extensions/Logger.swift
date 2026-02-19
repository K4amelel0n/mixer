//
//  Logger.swift
//  mixer
//
//  Created by DawidKozaczuk on 16/02/2026.
//
import Foundation
import os

extension Logger{
    private static var subsystem = Bundle.main.bundleIdentifier ?? "com.mixer.audio"
   
    static let mixer = Logger(subsystem: subsystem, category: "Mixer")
    
}

