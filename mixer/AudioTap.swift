//
//  AudioTap.swift
//  mixer
//
//  Created by DawidKozaczuk on 19/02/2026.
//
import Foundation
import os
import CoreAudio

class AudioTap {
    let id: AudioObjectID
    let uuid: String
    
    init?(for process: AudioProcess) {
        let tapDesc = CATapDescription(stereoMixdownOfProcesses: [process.id])
        tapDesc.uuid = UUID()
        tapDesc.muteBehavior = .mutedWhenTapped
        
        var tapID: AudioObjectID = AudioObjectID(kAudioObjectUnknown)
        let error = AudioHardwareCreateProcessTap(tapDesc, &tapID)
        if(error != noErr){
            return nil
        }
        Logger.mixer.info("Tap created \(tapID)")
        self.id = tapID
        self.uuid = tapDesc.uuid.uuidString
    }
   
    func destroy(){
        AudioHardwareDestroyProcessTap(self.id)
    }
    
}
