//
//  AudioAggregateDevice.swift
//  mixer
//
//  Created by DawidKozaczuk on 19/02/2026.
//
import Foundation
import os
import CoreAudio

struct AggregateDescription {
    let name: String
    let tapUUID: String
    let outputDeviceUID: String
    
    var dictionary: [String: Any] {
        let subDevices: [[String: Any]] = [[
            kAudioSubDeviceUIDKey: outputDeviceUID,
            kAudioSubDeviceDriftCompensationKey: true
        ]]
        
        return [
            kAudioAggregateDeviceNameKey: name,
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputDeviceUID,
            kAudioAggregateDeviceClockDeviceKey: outputDeviceUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: true,
            kAudioAggregateDeviceTapAutoStartKey: false,
            kAudioAggregateDeviceSubDeviceListKey: subDevices,
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapDriftCompensationKey: false,
                kAudioSubTapUIDKey: tapUUID
            ]]
        ]
    }
}


class AudioAggregateDevice {
    let id: AudioObjectID
    
    init?(for app: AudioApp,in audioTap: AudioTap, out outputDevice: AudioDevice, ){
        let aggregateDescription = AggregateDescription(name: "Mixer-\(app.name)", tapUUID: audioTap.uuid, outputDeviceUID: outputDevice.uid)
       
        var aggregateDeviceID: AudioObjectID = AudioObjectID(kAudioObjectUnknown)
        
        let error =  AudioHardwareCreateAggregateDevice(aggregateDescription.dictionary as CFDictionary, &aggregateDeviceID)

        if error != noErr{
            return nil
        }
        Logger.mixer.info("Aggregate device created \(aggregateDeviceID)")
        self.id = aggregateDeviceID
    }
    
    func destroy(){
        AudioHardwareDestroyAggregateDevice(self.id)
    }
}

