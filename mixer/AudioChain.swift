//
//  AudioChainManager.swift
//  mixer
//
//  Created by DawidKozaczuk on 17/02/2026.
//

import Foundation
import CoreAudio
import os


@Observable class AudioChain : Identifiable {
    let app: AudioApp
    let tap: AudioTap
    let aggregateDevice: AudioAggregateDevice
    var ioProcID: AudioDeviceIOProcID?

    var volume: Double = 1.0

   
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
                self.processAudio(inInputData, to: outOutputData, volume: Float(self.volume))
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
            
            for i in 0..<outputBuffers.count {
                let inputBuffer = inputBuffers[i]
                let outputBuffer = outputBuffers[i]
                
                guard let inputData = inputBuffer.mData?.assumingMemoryBound(to: Float32.self),
                      
                        let outputData = outputBuffer.mData?.assumingMemoryBound(to: Float32.self) else { continue }
                
                let sampleCount = Int(inputBuffer.mDataByteSize) / MemoryLayout<Float32>.size
                
                for j in 0..<sampleCount {
                    outputData[j] = inputData[j] * volume
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
