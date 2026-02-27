//
//  AudioChainManager.swift
//  mixer
//
//  Created by DawidKozaczuk on 17/02/2026.
//

import Foundation
import CoreAudio
import os
import Synchronization

@Observable class AudioChain : Identifiable {
    let app: AudioApp
    let tap: AudioTap
    let aggregateDevice: AudioAggregateDevice
    var ioProcID: AudioDeviceIOProcID?

    var volume: Double = 1.0{
        didSet{
            atomicTargetVolume.store(Float(volume), ordering: .relaxed)
        }
    }
    
    private let atomicTargetVolume : Atomic<Float> = Atomic<Float>(1.0)
    
    private var currentVolume : Float = 1.0
    private var nsamples : Float = 822.0

   
    init?(for app: AudioApp, to outputDevice:AudioDevice, queue: DispatchQueue){
        guard let tap = AudioTap(for: app) else {return nil}
        
        guard let aggregateDevice = AudioAggregateDevice(for: app, in: tap, out: outputDevice) else {
            tap.destroy()
            return nil
        }
        
        self.app = app
        self.tap = tap
        self.aggregateDevice = aggregateDevice
        
        actiavte(queue: queue)
    }
           
        func actiavte(queue: DispatchQueue){
            
            let err = AudioDeviceCreateIOProcIDWithBlock(&self.ioProcID, aggregateDevice.id, queue) { [weak self] _, inInputData, _, outOutputData, _ in
                guard let self else { return }
                let currentVolume = atomicTargetVolume.load(ordering: .relaxed)
                let sampleRate = aggregateDevice.getSampleRate()
                
                if(sampleRate != nil){
                    nsamples = Float(sampleRate!) * 0.02
                }else{
                    nsamples = 960
                }
                
                
                self.processAudio(inInputData, to: outOutputData, volume: currentVolume)
            }
            
            guard err == noErr else {
                tap.destroy()
                aggregateDevice.destroy()
                return
            }
            
            let error = AudioDeviceStart(self.aggregateDevice.id, self.ioProcID)
            guard error == noErr else {
                return
            }
           
            Logger.mixer.info("AudioDevice started")
            
        }
        
    private func processAudio(_ inputBufferList: UnsafePointer<AudioBufferList>, to outputBufferList: UnsafeMutablePointer<AudioBufferList>, volume: Float) {
        let inputBuffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inputBufferList))
        let outputBuffers = UnsafeMutableAudioBufferListPointer(outputBufferList)
        
        let step = (volume - currentVolume) / nsamples
        
        for i in 0..<outputBuffers.count {
            guard let inputData = inputBuffers[i].mData?.assumingMemoryBound(to: Float32.self),
                  let outputData = outputBuffers[i].mData?.assumingMemoryBound(to: Float32.self) else { continue }
            
            let sampleCount = Int(inputBuffers[i].mDataByteSize) / MemoryLayout<Float32>.size
            
            var tempVolume = currentVolume
            
            for j in 0..<sampleCount {
                if abs(volume - tempVolume) > 1e-5 {
                    tempVolume += step
                } else {
                    tempVolume = volume                 }
                outputData[j] = inputData[j] * tempVolume
            }
            
            if i == outputBuffers.count - 1 {
                currentVolume = tempVolume
            }
        }
    }
   
    func destroy(){
        if let ioProcID = ioProcID{
            AudioDeviceStop(aggregateDevice.id, ioProcID)
            
            Thread.sleep(forTimeInterval: 0.05)
            
            AudioDeviceDestroyIOProcID(aggregateDevice.id, ioProcID)
            Logger.mixer.info("IOProc stopped and destroyed for device")
        }
        
        aggregateDevice.destroy()
        tap.destroy()
    }
}
