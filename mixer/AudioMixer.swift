//
//  AudioMixer.swift
//  mixer
//
//  Created by DawidKozaczuk on 26/01/2026.
//

import Foundation
import CoreAudio
import os

@Observable class AudioMixer {
    
   
    var audioProcessList = [AudioProcess]()
    
    var defaultOutputDevice: AudioDevice!
    let audioChainManager: AudioChainManager = AudioChainManager()
    
    var processListAddress: AudioObjectPropertyAddress = getPropertyAddress(selector: kAudioHardwarePropertyProcessObjectList)
    var tapListAddress: AudioObjectPropertyAddress = getPropertyAddress(selector: kAudioHardwarePropertyTapList)
    var defaultOutputDeviceAddress: AudioObjectPropertyAddress = getPropertyAddress(selector: kAudioHardwarePropertyDefaultOutputDevice)
    
    static var shared: AudioMixer?
    var listsChangedToken: AudioObjectPropertyListenerBlock?

   
    init(){
        Self.shared = self
        loadProcessList()
        loadDefaultAudioDevice()
        
        if let spotify = findProcess(name:"Spotify"){
            Logger.mixer.info("spotify found \(spotify.id)")
            audioChainManager.createChain(for: spotify, to: self.defaultOutputDevice)
        }
    }
 
    func setupListeners() {
        let listsChanged: AudioObjectPropertyListenerBlock = { inNumberAddresses, inAddresses in
            guard let mixer = AudioMixer.shared else { return}
            
            for i in 0..<Int(inNumberAddresses) {
                let address = inAddresses[i]
            }
        }
        
        // Ważne: Przechowuj token, aby listener nie został zwolniony z pamięci!
        
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &tapListAddress,
            DispatchQueue.main,
            listsChanged
        )
        
        self.listsChangedToken = listsChanged
    }
    
    
    func loadProcessList(){
        
        audioProcessList = [AudioProcess]()
        
        var propertySize: UInt32 = 0
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &processListAddress, 0, nil, &propertySize)
        let processCount = Int(propertySize) / MemoryLayout<AudioObjectID>.stride
        var list: [AudioObjectID] = [AudioObjectID](repeating: 0, count: processCount)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &processListAddress, 0, nil, &propertySize, &list)
        
        for index in 0..<list.count {
            audioProcessList.append(AudioProcess(id: list[index]))
        }
    }
    
    func shoutDown(){
        audioChainManager.unchainAll()
    }
    
    func findProcess(name: String ) -> AudioProcess?{
        for process in self.audioProcessList{
            if(process.name == name){
                return process
            }
        }
        return nil
    }
    
    func processStopped(){
        
    }
}


extension AudioMixer{
   
    func loadDefaultAudioDevice(){
        var address = defaultOutputDeviceAddress
        var deviceID: AudioObjectID = 0
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let error = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        if(error == noErr){
            self.defaultOutputDevice = AudioDevice(id: deviceID)
            Logger.mixer.info("Sucessfuly get defualt output device ID \(deviceID)")
        }else{
            Logger.mixer.error("Cant get defualt output device ID")
        }
    }
}


public func getPropertyAddress(selector: AudioObjectPropertySelector,
                                   scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                                   element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain) -> AudioObjectPropertyAddress {
        return AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
}
