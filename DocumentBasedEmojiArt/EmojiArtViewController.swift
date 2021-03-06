//
//  ViewController.swift
//  EmojiArt
//
//  Created by Dmitry Reshetnik on 9/26/19.
//  Copyright © 2019 Dmitry Reshetnik. All rights reserved.
//

import UIKit

class EmojiArtViewController: UIViewController, UIDropInteractionDelegate, UIScrollViewDelegate, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource, UICollectionViewDragDelegate, UICollectionViewDropDelegate, UIPopoverPresentationControllerDelegate {
    
    // MARK: - Model
    
    var document: EmojiArtDocument?
    var emojiArt: EmojiArt? {
        get {
            if let url = emojiArtBackgroundImage.url {
                let emojis = emojiArtView.subviews.compactMap { (view) -> UILabel? in
                    return view as? UILabel
                }.compactMap { (label) -> EmojiArt.EmojiInfo? in
                    return EmojiArt.EmojiInfo(label: label)
                }
                return EmojiArt(url: url, emojis: emojis)
            }
            return nil
        }
        set {
            emojiArtBackgroundImage = (nil, nil)
            emojiArtView.superview.flatMap { (view) -> [UILabel?] in
                return [view as? UILabel]
                }?.forEach({ (label) in
                    label?.removeFromSuperview()
                }
            )
            if let url = newValue?.url {
                imageFetcher = ImageFetcher(fetch: url, handler: { (url, image) in
                    DispatchQueue.main.async {
                        self.emojiArtBackgroundImage = (url, image)
                        newValue?.emojis.forEach({ (emoji) in
                            let attributedText = emoji.text.attributedString(withTextStyle: .body, ofSize: CGFloat(emoji.size))
                            self.emojiArtView.addLabel(with: attributedText, centeredAt: CGPoint(x: emoji.x, y: emoji.y))
                        })
                    }
                })
            }
        }
    }
    
    // MARK: - Storyboard

    @IBOutlet weak var dropZone: UIView! {
        didSet {
            dropZone.addInteraction(UIDropInteraction(delegate: self))
        }
    }
    @IBOutlet weak var scrollView: UIScrollView! {
        didSet {
            scrollView.minimumZoomScale = 0.1
            scrollView.maximumZoomScale = 5.0
            scrollView.delegate = self
            scrollView.addSubview(emojiArtView)
        }
    }
    @IBOutlet weak var emojiCollectionView: UICollectionView! {
        didSet {
            emojiCollectionView.dataSource = self
            emojiCollectionView.delegate = self
            emojiCollectionView.dragDelegate = self
            emojiCollectionView.dropDelegate = self
        }
    }
    @IBOutlet weak var scrollViewWidth: NSLayoutConstraint!
    @IBOutlet weak var scrollViewHeight: NSLayoutConstraint!
    @IBOutlet weak var embeddedDocumentInfoWidth: NSLayoutConstraint!
    @IBOutlet weak var embeddedDocumentInfoHeight: NSLayoutConstraint!
    var emojiArtView: EmojiArtView = EmojiArtView()
    var imageFetcher: ImageFetcher!
    var emojiArtBackgroundImage: (url: URL?, image: UIImage?) {
        get {
            return (_emojiArtBackgroundImageURL, emojiArtView.backgroundImage)
        }
        set {
            _emojiArtBackgroundImageURL = newValue.url
            scrollView?.zoomScale = 1.0
            emojiArtView.backgroundImage = newValue.image
            let size = newValue.image?.size ?? CGSize.zero
            emojiArtView.frame = CGRect(origin: CGPoint.zero, size: size)
            scrollView?.contentSize = size
            scrollViewWidth?.constant = size.width
            scrollViewHeight?.constant = size.height
            if let dropZone = self.dropZone, size.width > 0, size.height > 0 {
                scrollView?.zoomScale = max(dropZone.bounds.size.width / size.width, dropZone.bounds.size.height / size.height)
            }
        }
    }
    var emojis: [String] = "😀🎁✈️🎱🍎🐶🐝☕️🎼🚲♣️👨‍🎓✏️🌈🤡🎓👻☎️".map { (symbol) -> String in
        return String(symbol)
    }
    
    private var _emojiArtBackgroundImageURL: URL?
    private var addingEmoji: Bool = false
    private var suppressBadURLWarnings: Bool = false
    private var documentObserver: NSObjectProtocol?
    private var emojiArtViewObserver: NSObjectProtocol?
    private var embeddedDocumentInfo: DocumentInfoViewController?
    private var font: UIFont {
        return UIFontMetrics(forTextStyle: UIFont.TextStyle.body).scaledFont(for: UIFont.preferredFont(forTextStyle: UIFont.TextStyle.body).withSize(64.0))
    }
    
    @IBAction func addEmoji(_ sender: UIButton) {
        addingEmoji = true
        emojiCollectionView.reloadSections(IndexSet(integer: 0))
    }
    
    @IBAction func done(_ sender: UIBarButtonItem? = nil) {
        if let observer = emojiArtViewObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        if document?.emojiArt != nil {
            document?.thumbnail = emojiArtView.snapshot
        }
        
        presentingViewController?.dismiss(animated: true) {
            self.document?.close(completionHandler: { (success) in
                if let observer = self.documentObserver {
                    NotificationCenter.default.removeObserver(observer)
                }
            })
        }
    }
    
    @IBAction func close(bySegue: UIStoryboardSegue) {
        done()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        documentObserver = NotificationCenter.default.addObserver(
            forName: UIDocument.stateChangedNotification,
            object: document,
            queue: OperationQueue.main,
            using: { (notification) in
                print("documentState changed to \(String(describing: self.document?.documentState))")
                if self.document?.documentState == UIDocument.State.normal, let documentInfoVC = self.embeddedDocumentInfo {
                    documentInfoVC.document = self.document
                    self.embeddedDocumentInfoWidth.constant = documentInfoVC.preferredContentSize.width
                    self.embeddedDocumentInfoHeight.constant = documentInfoVC.preferredContentSize.height
                }
            }
        )
        document?.open(completionHandler: { (success) in
            if success {
                self.title = self.document?.localizedName
                self.emojiArt = self.document?.emojiArt
                self.emojiArtViewObserver = NotificationCenter.default.addObserver(
                    forName: Notification.Name.EmojiArtViewDidChange,
                    object: self.emojiArtView,
                    queue: OperationQueue.main,
                    using: { (notification) in
                        self.documentChanged()
                    }
                )
            }
        })
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "Show Document Info" {
            if let destination = segue.destination.contents as? DocumentInfoViewController {
                document?.thumbnail = emojiArtView.snapshot
                destination.document = document
                if let ppc = destination.popoverPresentationController {
                    ppc.delegate = self
                }
            }
        } else if segue.identifier == "Embed Document Info" {
            embeddedDocumentInfo = segue.destination.contents as? DocumentInfoViewController
        }
    }
    
    private func dragItems(at indexPath: IndexPath) -> [UIDragItem] {
        if !addingEmoji, let attributedString = (emojiCollectionView.cellForItem(at: indexPath) as? EmojiCollectionViewCell)?.label.attributedText {
            let dragItem = UIDragItem(itemProvider: NSItemProvider(object: attributedString))
            dragItem.localObject = attributedString
            return [dragItem]
        } else {
            return []
        }
    }
    
    private func presentBadURLWarning(for url: URL) {
        if !suppressBadURLWarnings {
            let alert = UIAlertController(
                title: "Image Transfer Failed",
                message: "Couldn't transfer the dropped image from its source. \nShow this warning in the futer?",
                preferredStyle: UIAlertController.Style.alert
            )
            
            alert.addAction(UIAlertAction(title: "Keep Warning", style: UIAlertAction.Style.default))
            alert.addAction(UIAlertAction(title: "Stop Warning", style: UIAlertAction.Style.destructive, handler: { (action) in
                self.suppressBadURLWarnings = true
            }))
            
            present(alert, animated: true)
        }
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }
    
    func emojiArtViewDidChange(_ sender: EmojiArtView) {
        documentChanged()
    }
    
    func documentChanged() {
        document?.emojiArt = emojiArt
        if document?.emojiArt != nil {
            document?.updateChangeCount(UIDocument.ChangeKind.done)
        }
    }
    
    // MARK: - UICollectionViewDelegate
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 1
        case 1:
            return emojis.count
        default:
            return 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 1 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EmojiCell", for: indexPath)
            if let emojiCell = cell as? EmojiCollectionViewCell {
                let text = NSAttributedString(string: emojis[indexPath.item], attributes: [NSAttributedString.Key.font : font])
                emojiCell.label.attributedText = text
            }
            return cell
        } else if addingEmoji {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EmojiInputCell", for: indexPath)
            if let inputCell = cell as? TextFieldCollectionViewCell {
                inputCell.resignationHandler = { [weak self, unowned inputCell] in
                    if let text = inputCell.textField.text {
                        self?.emojis = (text.map { String($0) } + self!.emojis).uniquified
                    }
                    self?.addingEmoji = false
                    self?.emojiCollectionView.reloadData()
                }
            }
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AddEmojiButtonCell", for: indexPath)
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if addingEmoji && indexPath.section == 0 {
            return CGSize(width: 300, height: 80)
        } else {
            return CGSize(width: 80, height: 80)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let inputCell = cell as? TextFieldCollectionViewCell {
            inputCell.textField.becomeFirstResponder()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        session.localContext = collectionView
        return dragItems(at: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, itemsForAddingTo session: UIDragSession, at indexPath: IndexPath, point: CGPoint) -> [UIDragItem] {
        return dragItems(at: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: NSAttributedString.self)
    }
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        if let indexPath = destinationIndexPath, indexPath.section == 1 {
            let isThisSession = (session.localDragSession?.localContext as? UICollectionView) == collectionView
            return UICollectionViewDropProposal(operation: isThisSession ? UIDropOperation.move : UIDropOperation.copy, intent: UICollectionViewDropProposal.Intent.insertAtDestinationIndexPath)
        } else {
            return UICollectionViewDropProposal(operation: UIDropOperation.cancel)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        let destinationIndexPath = coordinator.destinationIndexPath ?? IndexPath(item: 0, section: 0)
        for item in coordinator.items {
            if let sourceIndexPath = item.sourceIndexPath {
                if let attributedString = item.dragItem.localObject as? NSAttributedString {
                    collectionView.performBatchUpdates({
                        emojis.remove(at: sourceIndexPath.item)
                        emojis.insert(attributedString.string, at: destinationIndexPath.item)
                        collectionView.deleteItems(at: [sourceIndexPath])
                        collectionView.insertItems(at: [destinationIndexPath])
                    }, completion: nil)
                    coordinator.drop(item.dragItem, toItemAt: destinationIndexPath)
                }
            } else {
                let placeholderContext = coordinator.drop(item.dragItem, to: UICollectionViewDropPlaceholder(insertionIndexPath: destinationIndexPath, reuseIdentifier: "DropPlaceholderCell"))
                item.dragItem.itemProvider.loadObject(ofClass: NSAttributedString.self) { (provider, error) in
                    DispatchQueue.main.async {
                        if let attributedString = provider as? NSAttributedString {
                            placeholderContext.commitInsertion { (insertionIndexPath) in
                                self.emojis.insert(attributedString.string, at: insertionIndexPath.item)
                            }
                        } else {
                            placeholderContext.deletePlaceholder()
                        }
                    }
                }
            }
        }
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return emojiArtView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        scrollViewWidth.constant = scrollView.contentSize.width
        scrollViewHeight.constant = scrollView.contentSize.height
    }
    
    // MARK: - UICollectionViewDropDelegate
    
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: NSURL.self) && session.canLoadObjects(ofClass: UIImage.self)
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        return UIDropProposal(operation: UIDropOperation.copy)
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        imageFetcher = ImageFetcher() { (url, image) in
            DispatchQueue.main.async {
                self.emojiArtBackgroundImage = (url, image)
                self.documentChanged()
            }
        }
        session.loadObjects(ofClass: NSURL.self) { (nsurls) in
            if let url = nsurls.first as? URL {
//                self.imageFetcher.fetch(url)
                DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async {
                    if let imageData = try? Data(contentsOf: url.imageURL), let image = UIImage(data: imageData) {
                        DispatchQueue.main.async {
                            self.emojiArtBackgroundImage = (url, image)
                            self.documentChanged()
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.presentBadURLWarning(for: url)
                        }
                    }
                }
            }
        }
        session.loadObjects(ofClass: UIImage.self) { (images) in
            if let image = images.first as? UIImage {
                self.imageFetcher.backup = image
            }
        }
    }


}

extension EmojiArt.EmojiInfo {
    init?(label: UILabel) {
        if let attributedText = label.attributedText, let font = attributedText.font {
            x = Int(label.center.x)
            y = Int(label.center.y)
            text = attributedText.string
            size = Int(font.pointSize)
        } else {
            return nil
        }
    }
}

