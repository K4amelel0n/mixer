/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A class that models and uniquely identifies base audio device objects.
*/
import CoreAudio

class AudioDevice: Identifiable, Hashable {
    var id: AudioObjectID
    var uid: String = ""
    
    init(id: AudioObjectID) {
        self.id = id
        
        var propertyAddress = getPropertyAddress(selector: kAudioDevicePropertyDeviceUID)
        var propertySize = UInt32(MemoryLayout<CFString>.stride)
        var uid: CFString = "" as CFString
        _ = withUnsafeMutablePointer(to: &uid) { uid in
            AudioObjectGetPropertyData(id, &propertyAddress, 0, nil, &propertySize, uid)
        }
        self.uid = uid as String
    }
    
    static func == (lhs: AudioDevice, rhs: AudioDevice) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
