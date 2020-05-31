//
//  scanner.swift

import Foundation
import AVFoundation
import UIKit

extension String {
    static func random(length: Int = 12) -> String {
        let base = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var randomString: String = ""
        for _ in 0..<length {
            let randomValue = arc4random_uniform(UInt32(base.count))
            randomString += "\(base[base.index(base.startIndex, offsetBy: Int(randomValue))])"
        }
        return randomString
    }
}

func toggleTorch(on: Bool) {
    guard let device = AVCaptureDevice.default(for: .video) else { return }
    if device.hasTorch {
        do {
            try device.lockForConfiguration()
            if on == true { device.torchMode = .on
            } else { device.torchMode = .off }
            device.unlockForConfiguration()
        } catch { print("Torch could not be used") }
    } else { print("Torch is not available") }
}

extension ScannerViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput1(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let imageData = photo.fileDataRepresentation()
        if let data = imageData, let img = UIImage(data: data) {
            print(img)
            var documentsUrl: URL {
                return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            }
            let imagePath = documentsUrl.appendingPathComponent(self.filename)
            AudioServicesPlaySystemSound(SystemSoundID(1015))
            print ("DING RAW SAVE", imagePath)
            let data = img.pngData()
            do {
                try data?.write(to: imagePath)
            } catch {
                print ("ERROR SAVE FILE")
            }
        }
    }
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation() else {
            print("Error while generating image from photo capture data.");
            return
        }
        guard let qrImage = UIImage(data: imageData) else {
            print("Unable to generate UIImage from image data.");
            return
        }
        var documentsUrl: URL {
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        }
        let imagePath = documentsUrl.appendingPathComponent(self.filename)
        AudioServicesPlaySystemSound(SystemSoundID(1015))
        print ("DING RAW SAVE", imagePath)
        let data = qrImage.pngData()
        do {
            try data?.write(to: imagePath)
        } catch {
            print ("ERROR SAVE FILE")
        }
        captureSession.stopRunning()
     }
}

class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var delegate: QRCodeScannerDelegate?
    private let phOutput = AVCapturePhotoOutput() // added
    private var filename: String = "toto.png"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black
        captureSession = AVCaptureSession()
        captureSession.addOutput(phOutput) // added
        //guard let videoCaptureDevice = AVCaptureDevice.DiscoverySession(deviceTypes: //[AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, //position: AVCaptureDevice.Position.front).devices.first else { return }
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {return}
        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            failed()
            return
        }
        let metadataOutput = AVCaptureMetadataOutput()
        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            failed()
            return
        }
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        captureSession.startRunning()
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.editedImage] as? UIImage else {
            print("No image found")
            return
        }
        print("IMAGE", image.size)
    }
    
    func failed() {
        let ac = UIAlertController(title: "Scanning not supported", message: "", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
        captureSession = nil
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if (captureSession?.isRunning == false) {
            captureSession.startRunning()
            print ("start scanning")
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if (captureSession?.isRunning == true) {
            captureSession.stopRunning()
            print ("stop scanning")
        }
    }

    func metadataOutput1(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        print ("STOP CAPTURE")
        captureSession.stopRunning()
        
        // take picture after stoping !
        let photoSettings = AVCapturePhotoSettings()
        phOutput.capturePhoto(with: photoSettings, delegate: self)
        
        
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            print ("DING SAVE")
            //AudioServicesPlaySystemSound(SystemSoundID(1015))
            found(code: stringValue)
            self.filename = stringValue + ".png"
            print ("SAVE NAME", self.filename)
        }
        dismiss(animated: true)
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        //print ("STOP CAPTURE")
        //captureSession.stopRunning()
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            //AudioServicesPlaySystemSound(SystemSoundID(1015))
            found(code: stringValue)
            self.filename = stringValue + ".png"
            print ("FOUND FILE NAME IN METADATA", self.filename)
        }
        let photoSettings = AVCapturePhotoSettings()
        phOutput.capturePhoto(with: photoSettings, delegate: self)
        
        dismiss(animated: true)
    }

    func found(code: String) {
        self.delegate?.codeDidFind(code)
        //DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.captureSession.startRunning()
        //}
    }

    override var prefersStatusBarHidden: Bool {return true}
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {return .portrait}
}

func getTumb(_ size:Int, _ img:UIImage) -> UIImage {
    var thumbnail = UIImage()
    if let imageData = img.pngData(){
        let options = [
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: size] as CFDictionary
        imageData.withUnsafeBytes { ptr in
            guard let bytes = ptr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return}
            if let cfData = CFDataCreate(kCFAllocatorDefault, bytes, imageData.count){
                let source = CGImageSourceCreateWithData(cfData, nil)!
                let imageReference = CGImageSourceCreateThumbnailAtIndex(source, 0, options)!
                thumbnail = UIImage(cgImage: imageReference)
            }
        }
    }
    return thumbnail
}

protocol QRCodeScannerDelegate {
    func codeDidFind(_ code: String)
}
