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
import AppKit

@Observable class AudioMixer : AudioProcessMonitorDelegate {
    
    
    
    var chains : [AudioChain] = [AudioChain]()
    private let chainsQueue = DispatchQueue(label: "com.mixer.chains", attributes: [])
    private let queue = DispatchQueue(
        label: "com.mixer.audio.chains",
        qos: .userInteractive,
    )
    
    var audioProcessList = [AudioProcess]()
   
    var audioProcessMonitor = AudioProcessMonitor()
    
    var defaultOutputDevice: AudioDevice!
    
    var defaultOutputDeviceAddress: AudioObjectPropertyAddress = getPropertyAddress(selector: kAudioHardwarePropertyDefaultOutputDevice)
    
    private var defaultAudioDeviceToken : AudioObjectPropertyListenerBlock?

    var isShuttingDown = false
   
    init(){
        registerDefaultAudioDeviceListener()
        loadDefaultAudioDevice()
        audioProcessMonitor.delegate = self
        audioProcessMonitor.start()
    }
    
   
    func monitor(_ monitor: AudioProcessMonitor, didUpdateApps apps: [AudioApp]) {
        let chainsToDestroy = chains.filter { chain in
            !apps.contains(where: { $0.name == chain.app.name })
        }

        chainsToDestroy.forEach { $0.destroy() }

        chains.removeAll { chain in
            chainsToDestroy.contains(where: { $0 === chain })
        }
       
        for app in apps{
            if(!chains.contains(where: {chain in chain.app.name == app.name})){
                addChain(for: app, out: defaultOutputDevice)
            }
        }
    }
    
    func createChains(for apps: [AudioApp]){
        for app in apps{
            addChain(for: app, out: defaultOutputDevice)
        }
    }

    
    func unregisterListeners() {
        audioProcessMonitor.unregisterListeners()
        unregisterDefaultAudioDeviceListener()
    }
    
    private func addChain(for app: AudioApp, out outputDevice: AudioDevice){
        guard let chain = AudioChain(for: app, to: outputDevice, queue: queue) else {return}

        chainsQueue.sync {
            chains.append(chain)
        }
        
    }
        

    func shoutDown() {
        self.isShuttingDown = true
        self.unregisterListeners()
        
        let chainsToDestroy = self.chainsQueue.sync {
            let list = self.chains
            self.chains = []
            return list
        }
        
        Logger.mixer.info("Starting destruction of \(chainsToDestroy.count) chains")
        
        for chain in chainsToDestroy {
            chain.destroy()
        }
        
        Logger.mixer.info("Cleanup finished in AudioMixer")
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
    
   
    func registerDefaultAudioDeviceListener(){
        
        let defualtDeviceChanged: AudioObjectPropertyListenerBlock = { [weak self] inNumberAddresses, inAddresses in
                   guard let self else { return }
            
                   for index in 0..<inNumberAddresses {
                       let address = inAddresses[Int(index)]
                       switch address.mSelector {
                       case kAudioHardwarePropertyDefaultOutputDevice:
                           self.defaultOutputDeviceChanged()
                       default: break
                       }
                   }
               }
               
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultOutputDeviceAddress,
            DispatchQueue.main,
            defualtDeviceChanged)
        
        self.defaultAudioDeviceToken = defualtDeviceChanged
        
    }
    
    func unregisterDefaultAudioDeviceListener(){
        if let token = defaultAudioDeviceToken {
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &defaultOutputDeviceAddress,
                DispatchQueue.main,
                token)
            defaultAudioDeviceToken = nil
        }
    }
    
    func defaultOutputDeviceChanged(){
        loadDefaultAudioDevice()
        
        for chain in chains{
            chain.aggregateDevice.changeOutputDevice(for: defaultOutputDevice)
        }
    }
    
}


public func getPropertyAddress(selector: AudioObjectPropertySelector,
                                   scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                                   element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain) -> AudioObjectPropertyAddress {
        return AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
}

public func readProperty<T>(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, defualtValue: T) throws -> T {
   
    var address = getPropertyAddress(selector: selector, scope: scope)
    var value = defualtValue
    var size = UInt32(MemoryLayout<AudioObjectID>.size)
    let error = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &value)
  
    guard error == noErr else{
        throw NSError(domain: NSOSStatusErrorDomain, code: Int(error))
    }
    
    return value
}

public func readProperty<T>(for id: AudioObjectID, _ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, defualtValue: T) throws -> T {
   
    var address = getPropertyAddress(selector: selector, scope: scope)
    var value = defualtValue
    var size = UInt32(MemoryLayout<T>.size)
    let error = AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value)
  
    guard error == noErr else{
        throw NSError(domain: NSOSStatusErrorDomain, code: Int(error))
    }
    
    return value
}

