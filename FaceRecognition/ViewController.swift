//
//  ViewController.swift
//  FaceRecognition
//
//  Created by xuanze on 2019/9/16.
//  Copyright © 2019 xuanze. All rights reserved.
//

import UIKit
import AVFoundation
class ViewController: UIViewController {

    private var captureSession: AVCaptureSession!
    private var photoOutput:AVCapturePhotoOutput!
    private var metadataOutput: AVCaptureMetadataOutput!
    private var videoInput: AVCaptureDeviceInput!
    private var activeVideoInput: AVCaptureDeviceInput!
    
    
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var overlayLayer: CALayer!
    private var faceLayers = [Int: CALayer]()
    override func viewDidLoad() {
        super.viewDidLoad()
        self.initFaceRecognition()
        self.setupPreviewLayer()
        
        if !self.captureSession.isRunning {
            DispatchQueue.global().async {
                self.captureSession.startRunning()
            }
        }
        
        if self.videoInput.device.position == AVCaptureDevice.Position.back {
            let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: .video, position: .front)
            let devices = discoverySession.devices
            for device in devices {
                if device.position == .front {
                    var input: AVCaptureDeviceInput! = nil
                    do {
                        let deviceInput = try AVCaptureDeviceInput(device: device)
                        input = deviceInput
                    } catch {
                        
                    }
                    
                    if input != nil {
                        self.captureSession.beginConfiguration()
                        self.captureSession.removeInput(self.videoInput)
                        self.captureSession.sessionPreset = .high
                        if self.captureSession.canAddInput(input) {
                            self.captureSession.addInput(input)
                            self.videoInput = input
                        } else {
                            self.captureSession.addInput(self.videoInput)
                        }
                        self.captureSession.commitConfiguration()
                    }
                }
            }
        }
    }

    private func initFaceRecognition() {
        self.captureSession = AVCaptureSession()
        if self.captureSession.canSetSessionPreset(.high) {
            self.captureSession.sessionPreset = .high
        }
        
        if let videoDevice = AVCaptureDevice.default(for: .video) {
            do {
                videoInput = try AVCaptureDeviceInput(device: videoDevice)
            } catch {
                
            }
        }
        if self.captureSession.canAddInput(videoInput) {
            self.captureSession.addInput(videoInput)
        }
        
        self.photoOutput = AVCapturePhotoOutput()
        if self.captureSession.canAddOutput(self.photoOutput) {
            self.captureSession.addOutput(self.photoOutput)
        }
        
        self.metadataOutput = AVCaptureMetadataOutput()
        if self.captureSession.canAddOutput(self.metadataOutput) {
            self.captureSession.addOutput(self.metadataOutput)
            
            self.metadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.face]
            self.metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        }
    }
    
    private func setupPreviewLayer() {
        self.previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
        self.previewLayer.frame = self.view.bounds
        self.previewLayer.videoGravity = .resizeAspectFill
        self.view.layer.addSublayer(self.previewLayer)
        self.view.layer.masksToBounds = true
        
        self.overlayLayer = CALayer()
        self.overlayLayer.frame = self.view.bounds
        self.overlayLayer.sublayerTransform = self.THMakePerspectiveTransform(eyePosition: 10000)
        self.previewLayer.addSublayer(self.overlayLayer)
    }
    
    private func THMakePerspectiveTransform(eyePosition: CGFloat) -> CATransform3D {
        var transform = CATransform3DIdentity
        transform.m34 = -1.0 / eyePosition
        return transform
    }
}

extension ViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        let transformFaces = self.transformFacesFromFaces(faces: metadataObjects)
        
        
        var lastFaces = [Int]()
        for faceId in faceLayers.keys {
            lastFaces.append(faceId)
        }
        for face in transformFaces {
            if let tFace = face as? AVMetadataFaceObject {
                let faceId = tFace.faceID
                if let index = lastFaces.lastIndex(of: faceId) {
                    lastFaces.remove(at: index)
                }
                
                var layer = self.faceLayers[faceId]
                if layer == nil {
                    layer = self.makerLayer()
                    self.overlayLayer.addSublayer(layer!)
                    self.faceLayers[faceId] = layer
                }
                layer?.transform = CATransform3DIdentity
                layer?.frame = face.bounds
            }
        }
        
        for id in lastFaces {
            let layer = self.faceLayers[id]
            layer?.removeFromSuperlayer()
            self.faceLayers.removeValue(forKey: id)
        }
    }
    
    func transformFacesFromFaces(faces: [AVMetadataObject]) -> [AVMetadataObject] {
        var transformdFaces = [AVMetadataObject]()
        
        for face in faces {
            if let transformFace = self.previewLayer.transformedMetadataObject(for: face) {
               transformdFaces.append(transformFace)
            }
        }
        
        return transformdFaces
    }
    
    func makerLayer() -> CALayer{
        let layer = CALayer()
        layer.borderWidth = 5
        layer.borderColor = UIColor(displayP3Red: 0.188, green: 0.517, blue: 0.877, alpha: 1.0).cgColor
        return layer
    }
}
