//
//  Untitled.swift
//  mixer
//
//  Created by DawidKozaczuk on 21/02/2026.
//
import Foundation
import os
import CoreAudio
import AppKit

protocol AudioProcessMonitorDelegate: AnyObject{
    func monitor(_ monitor: AudioProcessMonitor, didUpdateApps apps: [AudioApp])
}

class AudioProcessMonitor {
    
    var audioProcessList = [AudioProcess]()
    
    var processListAddress: AudioObjectPropertyAddress = getPropertyAddress(selector: kAudioHardwarePropertyProcessObjectList)
    
    var listsChangedToken: AudioObjectPropertyListenerBlock?
    
    weak var delegate: AudioProcessMonitorDelegate?
   
    
    func start(){
        registerListener()
        loadProcessList()
    }
 
    
    func registerListener(){
        let listsChanged: AudioObjectPropertyListenerBlock = { [weak self] inNumberAddresses, inAddresses in
                   guard let self else { return }
            
                   for index in 0..<inNumberAddresses {
                       let address = inAddresses[Int(index)]
                       switch address.mSelector {
                       case kAudioHardwarePropertyProcessObjectList:
                           self.loadProcessList()
                       default: break
                       }
                   }
               }
               
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &processListAddress,
            DispatchQueue.main,
            listsChanged)
        
        self.listsChangedToken = listsChanged
    }
    
    func unregisterListeners(){
        
        if let token = listsChangedToken {
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &processListAddress,
                DispatchQueue.main,
                token)
            listsChangedToken = nil
        }
    }
        
    private func loadProcessList(){
      
        let newAudioProcessList : [AudioProcess] = getProcessList()
        let audioProcessWithoutAppleOneAndOwn : [AudioProcess] = newAudioProcessList.filter({!$0.bundleID.localizedCaseInsensitiveContains("com.apple")}).filter({$0.pid != ProcessInfo.processInfo.processIdentifier})
        
      
        let groups = filterAndGroupApps(audioProcessList: audioProcessWithoutAppleOneAndOwn)
        var apps : [AudioApp] = [AudioApp]()
        
        for group in groups{
            let app = AudioApp(name: group[0].name, processes: group, icon: group[0].getIcon())
            apps.append(app)
        }
        
        for app in apps{
            print(app.name)
        }
        
        delegate?.monitor(self, didUpdateApps: apps)
    }
    
   
    private func getProcessList() -> [AudioProcess] {
       
        var newAudioProcessList : [AudioProcess] = [AudioProcess]()

        var propertySize: UInt32 = 0
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &processListAddress, 0, nil, &propertySize)
        let processCount = Int(propertySize) / MemoryLayout<AudioObjectID>.stride
        var list: [AudioObjectID] = [AudioObjectID](repeating: 0, count: processCount)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &processListAddress, 0, nil, &propertySize, &list)
        
        for index in 0..<list.count {
            newAudioProcessList.append(AudioProcess(id: list[index]))
        }
      
        return newAudioProcessList
    }
    
    
    func findProcess(name: String ) -> AudioProcess?{
        for process in self.audioProcessList{
            if(process.name == name){
                return process
            }
        }
        return nil
    }
   
    func groupAudioProcesses(_ audioProcessList: [AudioProcess]) -> [[AudioProcess]] {
        let sortedList = audioProcessList.sorted { $0.bundleID.count < $1.bundleID.count }
        
        var groups = [[AudioProcess]]()
        var assignedPIDs = Set<AudioObjectID>()

        for process in sortedList {
            if assignedPIDs.contains(process.id) { continue }
            
            var currentGroup = [AudioProcess]()
            currentGroup.append(process)
            assignedPIDs.insert(process.id)
            
            for potentialMatch in sortedList {
                if assignedPIDs.contains(potentialMatch.id) { continue }
                
                if potentialMatch.bundleID.localizedCaseInsensitiveContains(process.bundleID) {
                    currentGroup.append(potentialMatch)
                    assignedPIDs.insert(potentialMatch.id)
                }
            }
            groups.append(currentGroup)
        }
        
        return groups
    }
    
    func filterAndGroupApps(audioProcessList: [AudioProcess]) -> [[AudioProcess]] {
        let allGroups = groupAudioProcesses(audioProcessList)
        
        let appGroups = allGroups.filter { group in
            guard let leader = group.first else { return false }
            
            if let runningApp = NSRunningApplication(processIdentifier: leader.pid) {
                return runningApp.bundleURL != nil
            }
            
            return false
        }
        
        return appGroups
    }
    
}
