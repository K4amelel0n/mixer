//
//  AudioMixer.swift
//  mixer
//
//  Created by DawidKozaczuk on 26/01/2026.
//

import Foundation
import CoreAudio
import os
import QuartzCore

@Observable class AudioMixer {
    
    var chains : [AudioChain] = [AudioChain]()
    private let chainsQueue = DispatchQueue(label: "com.mixer.chains", attributes: [])
    private let queue = DispatchQueue(
        label: "com.mixer.audio.chains",
        qos: .userInteractive,
    )
    
    var audioProcessList = [AudioProcess]()
    
    var defaultOutputDevice: AudioDevice!
    
    var processListAddress: AudioObjectPropertyAddress = getPropertyAddress(selector: kAudioHardwarePropertyProcessObjectList)
    var tapListAddress: AudioObjectPropertyAddress = getPropertyAddress(selector: kAudioHardwarePropertyTapList)
    var defaultOutputDeviceAddress: AudioObjectPropertyAddress = getPropertyAddress(selector: kAudioHardwarePropertyDefaultOutputDevice)
    
    var listsChangedToken: AudioObjectPropertyListenerBlock?

    var isShuttingDown = false
   
    init(){
        loadProcessList()
        loadDefaultAudioDevice()
        
        if let spotify = findProcess(name:"Spotify"){
            Logger.mixer.info("spotify found \(spotify.id)")
            self.addChain(for: spotify , out: defaultOutputDevice )
        }
        
        if let brave = findProcess(name:"Brave Browser He"){
            Logger.mixer.info("brave found \(brave.id)")
            self.addChain(for: brave , out: defaultOutputDevice )
        }
    }
 
    func setupListeners() {
//        let listsChanged: AudioObjectPropertyListenerBlock = { inNumberAddresses, inAddresses in
//            guard let mixer = AudioMixer.shared else { return}
//            
//            for i in 0..<Int(inNumberAddresses) {
//                let address = inAddresses[i]
//            }
//        }
//        
//        
//        AudioObjectAddPropertyListenerBlock(
//            AudioObjectID(kAudioObjectSystemObject),
//            &tapListAddress,
//            DispatchQueue.main,
//            listsChanged
//        )
//        
//        self.listsChangedToken = listsChanged
    }
    
   
    func addChain(for process: AudioProcess, out outputDevice: AudioDevice){
        guard let chain = AudioChain(for: process, to: outputDevice, queue: queue) else {return}
       
        chainsQueue.sync {
            chains.append(chain)
        }
        
    }
    
    
    func loadProcessList(){
        
        var propertySize: UInt32 = 0
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &processListAddress, 0, nil, &propertySize)
        let processCount = Int(propertySize) / MemoryLayout<AudioObjectID>.stride
        var list: [AudioObjectID] = [AudioObjectID](repeating: 0, count: processCount)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &processListAddress, 0, nil, &propertySize, &list)
        
        for index in 0..<list.count {
            audioProcessList.append(AudioProcess(id: list[index]))
        }
    }
    
    func shoutDown() {
        self.isShuttingDown = true
        
        let chainsToDestroy = self.chains
        self.chains = []
        
        chainsQueue.async {
            for chain in chainsToDestroy {
                chain.destroy()
            }
            
            Logger.mixer.info("Cleanup finished. Safe to exit.")
        }
    }
    
    private func performHardwareCleanup(for chains: [AudioChain]) {
        self.chainsQueue.async {
            for chain in chains{
                chain.destroy()
            }
        }
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
