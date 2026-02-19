//
//  AudioChainManager.swift
//  mixer
//
//  Created by DawidKozaczuk on 17/02/2026.
//

import Foundation
import CoreAudio
import os

struct Tap{
    let id: AudioObjectID
    let uuid: String
}

class AudioChain : Identifiable {
    let process: AudioProcess
    let tap: Tap
    let aggregateDevice: AudioObjectID
    var ioProcID: AudioDeviceIOProcID?

    var volume: Double = 1.0

    init(process: AudioProcess, tap: Tap, aggregateDevice: AudioObjectID, ioProcID: AudioDeviceIOProcID?) {
        self.process = process
        self.tap = tap
        self.aggregateDevice = aggregateDevice
        self.ioProcID = ioProcID
    }
}

enum ChainManagerErrors : Error{
    case createTapFailed
    case createAggregateDeviceFailed
}

class AudioChainManager {
   
    var chains : [AudioChain] = [AudioChain]()
    private let chainsQueue = DispatchQueue(label: "com.mixer.chains", attributes: [])
    private var isShuttingDown = false
  
    func createChain(for process: AudioProcess, to outputDevice:AudioDevice){
        guard let tap = try? createTap(for: process) else {return}
        guard let aggregateDevice = try? createAggregateDevice(for:tap , for: outputDevice, name: "Mixer - \(process.pid)") else {return}
        var deviceProcID: AudioDeviceIOProcID?
        let queue = DispatchQueue(
            label: "com.myapp.audio.chain.\(process.id)",  // Unikalna nazwa
            qos: .userInteractive,                         // Wysoki priorytet
            attributes: [],
            target: nil
        )

        let newChain = AudioChain(process: process, tap: tap, aggregateDevice: aggregateDevice, ioProcID: nil)

        
        let err = AudioDeviceCreateIOProcIDWithBlock(&deviceProcID, aggregateDevice, queue) { [weak self] _, inInputData, _, outOutputData, _ in
                    guard let self, !self.isShuttingDown else { return }
                    let chain = newChain
                    self.processAudio(inInputData, to: outOutputData, volume: Float(chain.volume))
            }
        
        guard err == noErr else {
            return
        }

        newChain.ioProcID = deviceProcID


        let error = AudioDeviceStart(aggregateDevice, deviceProcID)
        guard error == noErr else {
             return
        }
        
        chainsQueue.sync {
            chains.append(newChain)
        }
    }
    
    private func createTap(for process: AudioProcess) throws(ChainManagerErrors) -> Tap{
        let tapDesc = CATapDescription(stereoMixdownOfProcesses: [process.id])
        tapDesc.uuid = UUID()
        tapDesc.muteBehavior = .mutedWhenTapped
        
        var tapID: AudioObjectID = AudioObjectID(kAudioObjectUnknown)
        let error = AudioHardwareCreateProcessTap(tapDesc, &tapID)
        if(error != noErr){
            throw .createTapFailed
        }
        Logger.mixer.info("Tap created \(tapID)")
        return Tap(id: tapID, uuid: tapDesc.uuid.uuidString)
    }
    
    private func createAggregateDevice(for tap: Tap, for outputDevice: AudioDevice, name: String) throws(ChainManagerErrors) -> AudioDeviceID{
        
        let subDevices: [[String: Any]] = [
               [
                   kAudioSubDeviceUIDKey: outputDevice.uid,
                   kAudioSubDeviceDriftCompensationKey: true // Output device does drift compensation
               ]
           ]
           
           let description = [
               kAudioAggregateDeviceNameKey: name,
               kAudioAggregateDeviceUIDKey: UUID().uuidString,
               
               kAudioAggregateDeviceMainSubDeviceKey: outputDevice.uid,
               kAudioAggregateDeviceClockDeviceKey: outputDevice.uid,
               
               kAudioAggregateDeviceIsPrivateKey: true, // Private to avoid UI updates
               kAudioAggregateDeviceIsStackedKey: true,
               kAudioAggregateDeviceTapAutoStartKey: false, // Don't auto-start to avoid conflicts
               
               kAudioAggregateDeviceSubDeviceListKey: subDevices,
               
               kAudioAggregateDeviceTapListKey: [
                   [
                       kAudioSubTapDriftCompensationKey: false, // Tap is master, no drift compensation
                       kAudioSubTapUIDKey: tap.uuid
                   ]
               ]
           ] as [String : Any]
           
       
        var id: AudioObjectID = AudioObjectID(kAudioObjectUnknown)
        let error =  AudioHardwareCreateAggregateDevice(description as CFDictionary, &id)

        if error != noErr{
            throw .createAggregateDeviceFailed
        }
        Logger.mixer.info("Aggregate device created \(id)")
       return id
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
        
        // Pętla DSP z głośnością konkretnego procesu
        for j in 0..<sampleCount {
            outputData[j] = inputData[j] * volume
        }
    }
    }
   
    func unchainAll(){
        
        Logger.mixer.info("chains cleans")
        
        chainsQueue.sync {
            isShuttingDown = true
        }
        
        let chainsToClean = chainsQueue.sync { chains }
        
        for chain in chainsToClean{
            if let ioProcID = chain.ioProcID {
                AudioDeviceStop(chain.aggregateDevice, ioProcID)
                
                Thread.sleep(forTimeInterval: 0.05)
                
                AudioDeviceDestroyIOProcID(chain.aggregateDevice, ioProcID)
                Logger.mixer.info("IOProc stopped and destroyed for device \(chain.aggregateDevice)")
            }
            
            AudioHardwareDestroyAggregateDevice(chain.aggregateDevice)
            AudioHardwareDestroyProcessTap(chain.tap.id)
            Logger.mixer.info("Tap destroy \(chain.tap.id)")
        }
        
        chainsQueue.sync {
            chains.removeAll()
        }
    }
}
