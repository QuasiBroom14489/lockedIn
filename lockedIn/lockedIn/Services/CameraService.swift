import Foundation
import AVFoundation
import UIKit
import Combine

class CameraService: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var isCameraActive = false
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var lastCapturedImage: UIImage?
    @Published var error: CameraError?

    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoOutput: AVCaptureVideoDataOutput?

    override init() {
        super.init()
        checkAuthorization()
    }

    // MARK: - Authorization

    func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            requestAuthorization()
        case .denied, .restricted:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }

    private func requestAuthorization() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
            }
        }
    }

    // MARK: - Session Setup

    func setupSession() {
        guard isAuthorized else {
            error = .notAuthorized
            return
        }

        let session = AVCaptureSession()
        session.sessionPreset = .medium

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            error = .cameraNotAvailable
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
            }

            let photo = AVCapturePhotoOutput()
            if session.canAddOutput(photo) {
                session.addOutput(photo)
                photoOutput = photo
            }

            let video = AVCaptureVideoDataOutput()
            video.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            if session.canAddOutput(video) {
                session.addOutput(video)
                videoOutput = video
            }

            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill

            DispatchQueue.main.async {
                self.previewLayer = preview
            }

            captureSession = session

        } catch {
            self.error = .setupFailed(error.localizedDescription)
        }
    }

    // MARK: - Session Control

    func startSession() {
        guard let session = captureSession, !session.isRunning else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
            DispatchQueue.main.async {
                self.isCameraActive = true
            }
        }
    }

    func stopSession() {
        guard let session = captureSession, session.isRunning else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            session.stopRunning()
            DispatchQueue.main.async {
                self.isCameraActive = false
            }
        }
    }

    // MARK: - Photo Capture

    func capturePhoto() {
        guard let photoOutput = photoOutput else {
            error = .captureError("Photo output not available")
            return
        }

        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - Cleanup

    func cleanup() {
        stopSession()
        captureSession = nil
        photoOutput = nil
        videoOutput = nil
        previewLayer = nil
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            self.error = .captureError(error.localizedDescription)
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            self.error = .captureError("Failed to process photo")
            return
        }

        DispatchQueue.main.async {
            self.lastCapturedImage = image
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Can be used for real-time presence detection in the future
    }
}

// MARK: - Camera Preview View

import SwiftUI

struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer?

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black

        if let layer = previewLayer {
            layer.frame = view.bounds
            view.layer.addSublayer(layer)
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = previewLayer {
            layer.frame = uiView.bounds
        }
    }
}

// MARK: - Errors

enum CameraError: LocalizedError {
    case notAuthorized
    case cameraNotAvailable
    case setupFailed(String)
    case captureError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Camera access not authorized. Please enable in Settings."
        case .cameraNotAvailable:
            return "Camera is not available on this device"
        case .setupFailed(let message):
            return "Camera setup failed: \(message)"
        case .captureError(let message):
            return "Failed to capture: \(message)"
        }
    }
}
