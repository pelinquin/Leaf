//
//  capture.swift
//  Leaf
//
//  Created by Laurent Fournier on 28/05/2020.
//  Copyright © 2020 Laurent Fournier. All rights reserved.
//

// for SPARE LIFI CAPTURE

import Foundation
import SwiftUI
import AVFoundation
import CoreImage.CIFilterBuiltins
import AVFoundation
import Combine
import CoreLocation

struct Response: Codable {
    var results: [Result]
}

struct Result: Codable {
    var trackId: Int
    var trackName: String
    var collectionName: String
}

struct CaptureView: View {
    @State private var toto : Bool = false
    @State private var nb : Int = 0
    @State private var results = [Result]()
    @State private var page:String = "none"
    
    func foundCode(_ code: String) {
        print ("found")
    }
    func loadData() {
        print ("start loading data")
        guard let url = URL(string: "https://adox.io") else {
            print("Invalid URL")
            return
        }
        let request = URLRequest(url: url)
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data {
                if let decodedResponse = try? JSONDecoder().decode(Response.self, from: data) {
                    DispatchQueue.main.async {
                        self.results = decodedResponse.results
                    }
                    return
                }
            }
        }.resume()
    }
    func loadText() {
        print ("start loading text")
        if let url = URL(string: "https://adox.io") {
            do {
                let contents = try String(contentsOf: url)
                print(contents)
            } catch {
                print("error")
            }
        } else {
            print ("bad url")
        }
    }
    var body: some View {
        VStack() {
            ZStack() {
                CaptureCodeScan(onCodeScanned: {self.foundCode($0)})
                    .edgesIgnoringSafeArea(.all)
                    .opacity(self.toto ? 1.0 : 0.0)
                Text("Hello")
                    .font(.system(size: 100))
                    .foregroundColor(Color.gray).opacity(0.3)
            }
        }.background(Color.orange)
        .onTapGesture() {
            self.toto = !self.toto
            for _ in 0...3 {
                usleep(20000)
                toggleTorch(on:true)
                usleep(20000)
                toggleTorch(on:false)
            }
            //print(FileManager.default.urls(for: .documentDirectory) ?? "empty!")
        }
        .onAppear(perform: self.loadText)
    }
    
}

struct CaptureCodeScan: UIViewControllerRepresentable {
    var onCodeScanned: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self)}
    func makeUIViewController(context: Context) -> CaptureViewController {
        let vc = CaptureViewController()
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ vc: CaptureViewController, context: Context) {}
    class Coordinator: NSObject, CaptureCodeScannerDelegate {
        func codeDidFind(_ code: String) {parent.onCodeScanned(code)}
        var parent: CaptureCodeScan
        init(_ parent: CaptureCodeScan) {self.parent = parent}
    }
}


extension CaptureViewController: AVCapturePhotoCaptureDelegate {
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
     func photoOutput1(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            print("Fail to capture photo: \(String(describing: error))")
            return
        }
        guard let imageData = photo.fileDataRepresentation() else {
            print("Fail to convert pixel buffer")
            return
        }
        guard let capturedImage = UIImage.init(data: imageData , scale: 1.0) else {
            print("Fail to convert image data to UIImage")
            return
        }
        let imgWidth = capturedImage.size.width
        let imgHeight = capturedImage.size.height
        let imgOrigin = CGPoint(x: (imgWidth - imgHeight)/2, y: (imgHeight - imgHeight)/2)
        let imgSize = CGSize(width: imgHeight, height: imgHeight)
        guard let imageRef = capturedImage.cgImage?.cropping(to: CGRect(origin: imgOrigin, size: imgSize)) else {
            print("Fail to crop image")
            return
        }
        let imageToSave = UIImage(cgImage: imageRef, scale: 1.0, orientation: .down)
        UIImageWriteToSavedPhotosAlbum(imageToSave, nil, nil, nil)
        captureSession.stopRunning()
    }
}

class CaptureViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var delegate: CaptureCodeScannerDelegate?
    private let phOutput = AVCapturePhotoOutput() // added
    private var photoSettings = AVCapturePhotoSettings() // added
    private var filename: String = "img1.png"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black
        captureSession = AVCaptureSession()
        captureSession.addOutput(phOutput) // added
        self.photoSettings = AVCapturePhotoSettings.init(format: [AVVideoCodecKey: AVVideoCodecType.jpeg]) // added
        self.photoSettings.flashMode = .off // added
        
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

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        print ("STOP CAPTURE")
        captureSession.stopRunning()
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            //AudioServicesPlaySystemSound(SystemSoundID(1015))
            found(code: stringValue)
            //self.filename = stringValue + ".png"
            self.filename = "img1.png"
            print ("FOUND FILE NAME IN METADATA", self.filename)
        }
        //let photoSettings = AVCapturePhotoSettings()
        phOutput.capturePhoto(with: self.photoSettings, delegate: self)
        
        dismiss(animated: true)
    }

    func found(code: String) {
        self.delegate?.codeDidFind(code)
    }

    override var prefersStatusBarHidden: Bool {return true}
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {return .portrait}
}

protocol CaptureCodeScannerDelegate {
    func codeDidFind(_ code: String)
}
