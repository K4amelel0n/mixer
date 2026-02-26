//
//  ContentView.swift
//  mixer
//
//  Created by DawidKozaczuk on 26/01/2026.
//

import SwiftUI
import Foundation


enum Tabs: Equatable, Hashable, Identifiable {
    case chains
    case processes
    var id: Self { self }
}

struct MixerRow: View {
    @Bindable var chain: AudioChain
    
    var body: some View {
        HStack(spacing: 15) {
            if let icon = chain.app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
            }
            
            Text(chain.app.name)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 120, alignment: .leading)
            
            Slider(value: $chain.volume, in: 0...1)
                .tint(.accentColor)
            
            Text("\(Int(chain.volume * 100))%")
                .font(.system(.body, design: .monospaced))
                .frame(width: 45, alignment: .trailing)
        }
        .padding(.horizontal)
        .frame(height: 40)
    }
}

struct ContentView: View {
    @Environment(AudioMixer.self) private var mixer
    
    @State private var selectedTab :Tabs = .chains
    var body: some View {
        
        TabView(selection: $selectedTab){
            Tab("Chains", systemImage: "play", value: .chains){
                
                if !mixer.isShuttingDown {
                    List(mixer.chains){ chain in
                        MixerRow(chain: chain)
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
