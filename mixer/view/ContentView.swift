//
//  ContentView.swift
//  mixer
//
//  Created by DawidKozaczuk on 26/01/2026.
//

import SwiftUI

struct ProcessRow: View {
    var process: AudioProcess


    var body: some View {
        HStack( spacing: 3) {
            if let nsImage = process.getIcon(){
             Image(nsImage: nsImage)
            }
            Text(process.name)
                .foregroundColor(.primary)
                .font(.headline)
            Text(String(process.id))
        }
    }
}

struct ContentView: View {
    @Environment(AudioMixer.self) private var mixer
    var body: some View {
        List(mixer.audioChainManager.chains){ chain in
            Slider(value: Binding(
                        get: { Double(chain.volume) },
                        set: { chain.volume = Double(Float($0)) }
            ), in: 0...1.5)
        }
    }
}

#Preview {
    ContentView()
}
