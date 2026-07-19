//
//  Item.swift
//  Disk Visualizer
//
//  Created by François Monniot on 7/19/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
