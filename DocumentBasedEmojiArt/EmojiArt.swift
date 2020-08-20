//
//  EmojiArt.swift
//  EmojiArt
//
//  Created by Dmitry Reshetnik on 19.08.2020.
//  Copyright © 2020 Dmitry Reshetnik. All rights reserved.
//

import Foundation

struct EmojiArt: Codable {
    struct EmojiInfo: Codable {
        let x: Int
        let y: Int
        let text: String
        let size: Int
    }
    
    var url: URL
    var emojis = [EmojiInfo]()
    var json: Data? {
        return try? JSONEncoder().encode(self)
    }
    
    init(url: URL, emojis: [EmojiInfo]) {
        self.url = url
        self.emojis = emojis
    }
    
    init?(json: Data) {
        if let newValue = try? JSONDecoder().decode(EmojiArt.self, from: json) {
            self = newValue
        } else {
            return nil
        }
    }
}
