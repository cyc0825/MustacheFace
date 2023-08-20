//
//  ViewController.swift
//  MustacheFace
//
//  Created by 曹越程 on 2023/8/16.
//

import UIKit
import ARKit
import AVFoundation
import CoreData

class ViewController: UIViewController {

    @IBOutlet weak var mustacheCollectionView: UICollectionView!
    @IBOutlet weak var arView: ARSCNView!
    @IBAction func stopButtonTapped(_ sender: UIButton) {
        if isRecordingARContent {
            print("Stopping...")
            stopRecording()
            sender.setBackgroundImage(UIImage(systemName: "record.circle"), for: .normal)
        } else {
            print("Starting...")
            startRecording()
            sender.setBackgroundImage(UIImage(systemName: "record.circle.fill"), for: .normal)
        }
    }
    var captureSession: AVCaptureSession?
    var videoOutput: AVCaptureMovieFileOutput?
    var previewLayer: AVCaptureVideoPreviewLayer!
    var currentMustacheImage: UIImage?
    var currentMustacheNode: SCNNode?
    var videos: [VideoEntity] = []
    
    var assetWriter: AVAssetWriter?
    var assetWriterInput: AVAssetWriterInput?
    var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    var isRecordingARContent = false
    var recordingStartTime: CMTime?
    var recordingStartDate: Date?
    var recordingTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mustacheCollectionView.register(MustacheViewCell.nib(), forCellWithReuseIdentifier: MustacheViewCell.identifier)
        mustacheCollectionView.backgroundColor = .clear
        
        //
        if ARFaceTrackingConfiguration.isSupported {
            let configuration = ARFaceTrackingConfiguration()
            arView.session.run(configuration)
        }
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 150, height: 50)

        arView.delegate = self
        mustacheCollectionView.collectionViewLayout = layout
        mustacheCollectionView.delegate = self
        mustacheCollectionView.dataSource = self
        configureCaptureSession()
        configurePreviewLayer()
        fetchVideosFromCoreData()
        // Do any additional setup after loading the view.
    }
    
    func createPixelBuffer(from image: UIImage) -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         Int(image.size.width),
                                         Int(image.size.height),
                                         kCVPixelFormatType_32ARGB,
                                         attrs,
                                         &pixelBuffer)

        guard status == kCVReturnSuccess else {
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer!, [])
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)

        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData,
                                width: Int(image.size.width),
                                height: Int(image.size.height),
                                bitsPerComponent: 8,
                                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!),
                                space: rgbColorSpace,
                                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)

        context?.translateBy(x: 0, y: image.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)
        UIGraphicsPushContext(context!)
        image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        UIGraphicsPopContext()

        CVPixelBufferUnlockBaseAddress(pixelBuffer!, [])

        return pixelBuffer
    }

    
    func configurePreviewLayer() {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        previewLayer.frame = arView.bounds
        previewLayer.videoGravity = .resizeAspectFill
        
        // Insert the previewLayer below the ARSCNView's main layer
        arView.layer.insertSublayer(previewLayer, at: 0)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = arView.bounds
    }

    func saveVideoToDocuments(from tempURL: URL) -> URL? {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let newVideoURL = documentsURL.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        
        do {
            try fileManager.moveItem(at: tempURL, to: newVideoURL)
            print("Video moved to: \(newVideoURL)") // Add this line
            return newVideoURL
        } catch {
            print("Error moving video file: \(error.localizedDescription)")
            return nil
        }
    }
    
    func saveVideoMetadataToCoreData(videoURL: URL, tag: String, duration: Double) {
        // Reference to managed object context
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        
        let newVideo = VideoEntity(context: context)
        newVideo.videoURL = videoURL.absoluteString
        newVideo.tag = tag
        newVideo.duration = duration
        
        do {
            try context.save()
            print("Saved video metadata to Core Data.")
        } catch {
            print("Error saving video metadata: \(error.localizedDescription)")
        }
    }
    
    func fetchVideosFromCoreData() {
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<VideoEntity> = VideoEntity.fetchRequest()
        do {
            videos = try context.fetch(fetchRequest)
        } catch {
            print("Failed to fetch videos: \(error)")
        }
    }
    
    func getVideoDuration(from url: URL) -> Double {
        let asset = AVURLAsset(url: url)
        let duration = asset.duration
        return CMTimeGetSeconds(duration)
    }
    
    func configureCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .high
        
        // Setup video input
        if let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
           let videoInput = try? AVCaptureDeviceInput(device: videoDevice) {
            if captureSession?.canAddInput(videoInput) == true {
                captureSession?.addInput(videoInput)
                print("video check")
            }
        }
        
        // Setup audio input
        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice) {
            if captureSession?.canAddInput(audioInput) == true {
                captureSession?.addInput(audioInput)
                print("audio check")
            }
        }
        
        // Setup video output
        videoOutput = AVCaptureMovieFileOutput()
        if captureSession?.canAddOutput(videoOutput!) == true {
            captureSession?.addOutput(videoOutput!)
        }
    }
    
    func recordARContent(to url: URL) {
        do {
            assetWriter = try AVAssetWriter(outputURL: url, fileType: .mov)
        } catch {
            print("Error creating asset writer: \(error.localizedDescription)")
            return
        }
        
        let outputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: arView.bounds.width,
            AVVideoHeightKey: arView.bounds.height
        ]
        assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        assetWriter?.add(assetWriterInput!)
        
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB)
        ]
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterInput!, sourcePixelBufferAttributes: pixelBufferAttributes)
        
        recordingStartTime = nil
        assetWriter?.startWriting()
        
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            if self.assetWriterInput?.isReadyForMoreMediaData == true {
                let snapshotImage = self.arView.snapshot()
                if let pixelBuffer = self.createPixelBuffer(from: snapshotImage) {
                    if self.recordingStartTime == nil {
                        self.recordingStartTime = CMTimeMakeWithSeconds(0.0, preferredTimescale: 1000)
                        self.recordingStartDate = Date()
                        self.assetWriter?.startSession(atSourceTime: self.recordingStartTime!)
                    } else {
                        let currentTime = CMTimeMakeWithSeconds(timer.fireDate.timeIntervalSince(self.recordingStartDate!), preferredTimescale: 1000)

                        let elapsedTime = CMTimeSubtract(currentTime, self.recordingStartTime!)
                        self.pixelBufferAdaptor?.append(pixelBuffer, withPresentationTime: elapsedTime)
                    }
                }
            }
        }
        
        isRecordingARContent = true
    }
    
    func startRecording() {
        // Define the output URL
        let directory = FileManager.default.temporaryDirectory
        let fileName = UUID().uuidString + ".mov"
        let fileURL = directory.appendingPathComponent(fileName)

        // Start recording AR content
        recordARContent(to: fileURL)
    }
    
    func stopRecording() {
        isRecordingARContent = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        assetWriterInput?.markAsFinished()
        
        assetWriter?.finishWriting { [weak self] in
            guard let self = self else { return }
            if let outputURL = self.assetWriter?.outputURL {
                self.assetWriter = nil
                self.assetWriterInput = nil
                self.pixelBufferAdaptor = nil
                self.recordingStartTime = nil
                DispatchQueue.main.async {
                    if let savedVideoURL = self.saveVideoToDocuments(from: outputURL) {
                        // Get video duration
                        let videoDuration = self.getVideoDuration(from: savedVideoURL)
                        
                        self.presentTagInput { [weak self] enteredTag in
                            guard let tag = enteredTag else {
                                print("Tag not entered or action was cancelled.")
                                return
                            }
                            self?.saveVideoMetadataToCoreData(videoURL: savedVideoURL, tag: tag, duration: videoDuration)
                        }
                    }
                    print("Saved AR content to \(outputURL)")
                }
            }
        }
    }
    
    func createMustacheFor(faceAnchor: ARFaceAnchor, imageName: String) -> SCNNode {
        let mustacheImage = UIImage(named: imageName)!
        let mustachePlane = SCNPlane(width: 0.15, height: 0.05)
        mustachePlane.firstMaterial?.diffuse.contents = mustacheImage
        mustachePlane.firstMaterial?.isDoubleSided = true

        let mustacheNode = SCNNode(geometry: mustachePlane)
        mustacheNode.position.y -= 0.05

        return mustacheNode
    }
    
    func updateMustacheImage(to imageName: String) {
        guard let mustacheNode = currentMustacheNode, let material = mustacheNode.geometry?.firstMaterial else { return }
        material.diffuse.contents = UIImage(named: imageName)
    }
    
    func presentTagInput(completion: @escaping (String?) -> Void) {
        let alertController = UIAlertController(title: "Enter Tag", message: nil, preferredStyle: .alert)
        
        alertController.addTextField { (textField) in
            textField.placeholder = "Tag for the recording"
        }
        
        let saveAction = UIAlertAction(title: "Save", style: .default) { [weak alertController] _ in
            let tag = alertController?.textFields?.first?.text
            completion(tag) // Pass the entered tag to the completion handler
        }
        alertController.addAction(saveAction)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completion(nil) // Pass nil if user cancels
        }
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    

}

extension ViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if let faceAnchor = anchor as? ARFaceAnchor {
            let mouthLeft = faceAnchor.geometry.vertices[24]
            let mouthRight = faceAnchor.geometry.vertices[25]
            let mouthUp = faceAnchor.geometry.vertices[26]
            let mouthDown = faceAnchor.geometry.vertices[27]

            let mouthCenterX = (mouthLeft.x + mouthRight.x) / 2
            let mouthCenterY = (mouthUp.y + mouthDown.y) / 2
            let mouthCenterZ = (mouthLeft.z + mouthRight.z) / 2

            // Create the mustache node
            let mustacheNode = createMustacheFor(faceAnchor: faceAnchor, imageName: "mustache1")
            currentMustacheNode = mustacheNode
            
            // Set the mustache node's position to the mouth's center and adjust it slightly above the upper lip
            mustacheNode.position = SCNVector3(mouthCenterX, mouthCenterY + 0.015, mouthCenterZ) // The 0.02 value is just an approximation. Adjust it to suit your needs
            
            node.addChildNode(mustacheNode)
        }
    }
}

extension ViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func switchMustacheTo(imageNamed: String) {
        currentMustacheImage = UIImage(named: imageNamed)
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 3
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MustacheViewCell.identifier, for: indexPath) as! MustacheViewCell
        cell.configure(with: UIImage(named: "mustache\(indexPath.item + 1)")!)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        updateMustacheImage(to: "mustache\(indexPath.item + 1)")
        print("switch to mustache\(indexPath.item + 1)")
    }
}

extension ViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 150, height: 150)
    }
}
/*
extension ViewController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        // Called when recording starts
        DispatchQueue.main.async {
            print("R")
        }
        print("Recording started at \(fileURL).")
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Error recording: \(error.localizedDescription)")
        } else {
            print("Recording finished successfully.")
            
            if let savedVideoURL = saveVideoToDocuments(from: outputFileURL) {
                // Get video duration
                let videoDuration = getVideoDuration(from: savedVideoURL)
                
                presentTagInput { [weak self] enteredTag in
                    guard let tag = enteredTag else {
                        print("Tag not entered or action was cancelled.")
                        return
                    }
                    self?.saveVideoMetadataToCoreData(videoURL: savedVideoURL, tag: tag, duration: videoDuration)
                }
            }
        }
    }
} */
