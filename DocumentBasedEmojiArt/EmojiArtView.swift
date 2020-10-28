//
//  EmojiArtView.swift
//  EmojiArt
//
//  Created by Dmitry Reshetnik on 9/28/19.
//  Copyright © 2019 Dmitry Reshetnik. All rights reserved.
//

import UIKit

protocol EmojiArtViewDelegate: class {
    func emojiArtViewDidChange(_ sender: EmojiArtView)
}

class EmojiArtView: UIView, UIDropInteractionDelegate {

    private var labelObservation: [UIView: NSKeyValueObservation] = [:]
    weak var delegate: EmojiArtViewDelegate?
    var backgroundImage: UIImage? {
        didSet {
            setNeedsDisplay()
        }
    }
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
        backgroundImage?.draw(in: bounds)
    }
    
    override func willRemoveSubview(_ subview: UIView) {
        super.willRemoveSubview(subview)
        
        if labelObservation[subview] != nil {
            labelObservation[subview] = nil
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        addInteraction(UIDropInteraction(delegate: self))
    }
    
    func addLabel(with attributedString: NSAttributedString, centeredAt point: CGPoint) {
        let label = UILabel()
        label.backgroundColor = UIColor.clear
        label.attributedText = attributedString
        label.center = point
        label.sizeToFit()
        addEmojiArtGestureRecognizers(to: label)
        addSubview(label)
        labelObservation[label] = label.observe(\.center, changeHandler: { (label, change) in
            self.delegate?.emojiArtViewDidChange(self)
            NotificationCenter.default.post(name: NSNotification.Name.EmojiArtViewDidChange, object: self)
        })
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: NSAttributedString.self)
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        return UIDropProposal(operation: UIDropOperation.copy)
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        session.loadObjects(ofClass: NSAttributedString.self) { (providers) in
            let dropPoint = session.location(in: self)
            for attributedString in providers as? [NSAttributedString] ?? [] {
                self.addLabel(with: attributedString, centeredAt: dropPoint)
                self.delegate?.emojiArtViewDidChange(self)
                NotificationCenter.default.post(name: NSNotification.Name.EmojiArtViewDidChange, object: self)
            }
        }
    }
    

}

extension Notification.Name {
    static let EmojiArtViewDidChange = Notification.Name("EmojiArtViewDidChange")
}
