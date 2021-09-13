//
//  ZSBarcodeScannerViewController.swift
//  ZSBarcodeScanner
//
//  Created by Zandor Smith on 06/04/2021.
//

import UIKit
import AVFoundation

public class ZSBarcodeScannerViewController: UIViewController {

    // MARK: Customizable variables

    public var allowedBarcodeTypes:  [AVMetadataObject.ObjectType] = [.qr, .ean13, .upce, .dataMatrix, .code39, .code128, .code93]
    public var allowedCameras: [AVCaptureDevice.DeviceType] = {
        var cameras: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera, .builtInTelephotoCamera]
        if #available(iOS 13.0, *) {
            cameras.append(.builtInUltraWideCamera)
        }
        return cameras
    }()
    public var cameraNames: [AVCaptureDevice.DeviceType: String] = {
        var cameras: [AVCaptureDevice.DeviceType: String] = [
            .builtInWideAngleCamera: "Wide",
            .builtInTelephotoCamera: "Telephoto"
        ]
        if #available(iOS 13.0, *) {
            cameras[.builtInUltraWideCamera] = "Ultrawide"
        }
        return cameras
    }()

    // Default variables that can be set once during application didFinishLaunchingWithOptions.
    public static var defaultPrompt: String? = "Point your camera at a barcode."
    public static var defaultErrorAlertTitle = "Error"
    public static var defaultErrorAlertDescription = "An error occured. Please try again later."
    public static var defaultErrorNoCameraPermissionTitle = "No permission"
    public static var defaultErrorNoCameraPermissionDescription = "The app doesn't have permission to access the camera. Please enable access in iOS settings."
    public static var defaultErrorOkButtonText = "OK"
    public static var defaultErrorSettingsButtonText = "Settings"

    public static var defaultCloseGlyph = UIImage(named: "Close", in: Bundle(for: classForCoder()), compatibleWith: nil)
    public static var defaultFlashOnGlyph = UIImage(named: "FlashOn", in: Bundle(for: classForCoder()), compatibleWith: nil)
    public static var defaultFlashOffGlyph = UIImage(named: "FlashOff", in: Bundle(for: classForCoder()), compatibleWith: nil)

    // Variables to customize the barcode scanner during launching from default settings.
    public var prompt: String? = defaultPrompt
    public var errorAlertTitle = defaultErrorAlertTitle
    public var errorAlertDescription = defaultErrorAlertDescription
    public var errorNoCameraPermissionTitle = defaultErrorNoCameraPermissionTitle
    public var errorNoCameraPermissionDescription = defaultErrorNoCameraPermissionDescription
    public var errorOkButtonText = defaultErrorOkButtonText
    public var errorSettingsButtonText = defaultErrorSettingsButtonText

    public var closeGlyph = defaultCloseGlyph
    public var flashOnGlyph = defaultFlashOnGlyph
    public var flashOffGlyph = defaultFlashOffGlyph

    // MARK: Main code

    public weak var delegate: ZSBarcodeScannerDelegate?

    var output = AVCaptureMetadataOutput()
    var previewLayer: AVCaptureVideoPreviewLayer?

    var captureSession = AVCaptureSession()

    var currentDevice: AVCaptureDevice?
    var devices = [AVCaptureDevice]()

    var flashButton = UIBarButtonItem()
    var segmentedControl = UISegmentedControl()

    var outputBarcode: String?

    public override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.setNeedsStatusBarAppearanceUpdate()

        if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
            DispatchQueue.main.async {
                self.setupCameras()
            }
        } else {
            AVCaptureDevice.requestAccess(for: .video) { (granted) in
                DispatchQueue.main.async {
                    if granted == true {
                        self.setupCameras()
                    } else {
                        let alert = UIAlertController(title: self.errorNoCameraPermissionTitle, message: self.errorNoCameraPermissionDescription, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: self.errorSettingsButtonText, style: .default, handler: { _ in
                            if #available(iOS 10.0, *), let settingsUrl = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(settingsUrl) {
                                alert.addAction(UIAlertAction(title: self.errorSettingsButtonText, style: .default, handler: { _ in
                                    UIApplication.shared.open(settingsUrl, options: [:])
                                    self.dismiss(animated: true, completion: nil)
                                }))
                            }
                            self.dismiss(animated: true, completion: nil)
                        }))
                        alert.addAction(UIAlertAction(title: self.errorOkButtonText, style: .cancel, handler: { _ in
                            self.dismiss(animated: true, completion: nil)
                        }))
                        self.present(alert, animated: true, completion: nil)
                    }
                }
            }
        }

        self.navigationItem.prompt = prompt
        self.navigationController?.navigationBar.barStyle = .black
        self.view.backgroundColor = .black

        let backButton = UIBarButtonItem(image: closeGlyph, style: .plain, target: self, action: #selector(cancel))
        backButton.tintColor = .orange
        self.navigationItem.rightBarButtonItem = backButton
    }

    @objc func cancel() {
        self.dismiss(animated: true, completion: nil)
    }

    @objc func toggleFlash() {
        self.flashSetState(!(currentDevice?.isTorchActive ?? false))
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        DispatchQueue.global(qos: .background).async {
            if self.captureSession.isRunning {
                print("BarcodeScanner: Stop running...")
                self.captureSession.stopRunning()
                print("BarcodeScanner: Stopped.")
            }
        }
    }

    func startCaptureSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            if !self.captureSession.isRunning {
                print("BarcodeScanner: Start running...")
                self.captureSession.startRunning()
                print("BarcodeScanner: Started.")
                self.setupPreviewLayer()
            }
        }
    }

    private func setupCameras() {
        var deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera, .builtInTelephotoCamera]
        if #available(iOS 13.0, *) {
            deviceTypes.append(.builtInUltraWideCamera)
        }
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: nil, position: .back)
        let devices = discoverySession.devices
        if devices.isEmpty {
            showGeneralErrorAlert()
            return
        }

        for allowedCamera in allowedCameras {
            if let device = devices.first(where: { device -> Bool in return device.deviceType == allowedCamera }) {
                self.devices.append(device)
            }
        }

        if devices.count > 1 {
            let items: [String] = self.devices.map { device -> String in
                return cameraNames[device.deviceType] ?? "Unknown"
            }
            segmentedControl = UISegmentedControl(items: items)
            segmentedControl.tintColor = .white
            segmentedControl.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.white], for: .normal)
            segmentedControl.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.black], for: .selected)
            segmentedControl.selectedSegmentIndex = 0
            segmentedControl.addTarget(self, action: #selector(didSelectSegmentedControl), for: .valueChanged)
            self.navigationItem.titleView = segmentedControl
        }

        self.currentDevice = self.devices.first!
        setupTorch()
        setupCapture(with: currentDevice!)
    }

    @objc private func didSelectSegmentedControl() {
        let device = devices[segmentedControl.selectedSegmentIndex]
        currentDevice = device
        changeDevice(to: device)
    }

    private func setupTorch() {
        if currentDevice?.hasTorch ?? false {
            flashButton = UIBarButtonItem(image: flashOffGlyph, style: .plain, target: self, action: #selector(toggleFlash))
            flashButton.tintColor = UIColor.orange
            self.navigationItem.leftBarButtonItem = flashButton
        } else {
            self.navigationItem.leftBarButtonItem = nil
        }
    }

    private func setupCapture(with device: AVCaptureDevice) {
        guard let input = try? AVCaptureDeviceInput(device: device) else {
            showGeneralErrorAlert()
            return
        }

        DispatchQueue.global(qos: .background).async {
            if self.captureSession.canAddInput(input) {
                self.captureSession.addInput(input)
            }

            let metadataOutput = AVCaptureMetadataOutput()

            if self.captureSession.canAddOutput(metadataOutput) {
                self.captureSession.addOutput(metadataOutput)

                metadataOutput.setMetadataObjectsDelegate(self, queue: .global(qos: .background))
                metadataOutput.metadataObjectTypes = self.allowedBarcodeTypes
            } else {
                print("Could not add metadata output")
            }

            self.startCaptureSession()
        }
    }

    private func changeDevice(to device: AVCaptureDevice) {
        let torchState = currentDevice?.isTorchActive ?? false
        if self.captureSession.isRunning {
            self.captureSession.stopRunning()
        }
        for input in self.captureSession.inputs {
            self.captureSession.removeInput(input)
        }
        guard let input = try? AVCaptureDeviceInput(device: device) else {
            showGeneralErrorAlert()
            return
        }
        self.captureSession.addInput(input)
        self.captureSession.startRunning()
        setupTorch()
        flashSetState(torchState)
    }

    func setupPreviewLayer() {
        self.previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
        self.previewLayer?.videoGravity = .resizeAspectFill

        DispatchQueue.main.async {
            self.previewLayer?.frame = self.view.bounds
            self.view.layer.addSublayer(self.previewLayer!)
            self.handleDeviceRotation()
        }
    }

    private func flashSetState(_ state: Bool) {
        do {
            if let device = self.currentDevice, device.hasTorch {
                try device.lockForConfiguration()
                device.torchMode = state ? .on : .off
                device.unlockForConfiguration()
                self.flashButton.image = state ? flashOnGlyph : flashOffGlyph
            }
        } catch {
            print("Device Flash Error")
        }
    }

    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.handleDeviceRotation()
        }, completion: nil)
    }

    func handleDeviceRotation() {
        if let connection = self.previewLayer?.connection {
            if connection.isVideoOrientationSupported {
                switch UIDevice.current.orientation {
                case .portrait:
                    connection.videoOrientation = .portrait
                case .landscapeRight:
                    connection.videoOrientation = .landscapeLeft
                case .landscapeLeft:
                    connection.videoOrientation = .landscapeRight
                case .portraitUpsideDown:
                    connection.videoOrientation = .portraitUpsideDown

                default:
                    connection.videoOrientation = .portrait
                }
            }
        }
        self.previewLayer?.frame = self.view.bounds
    }

    func showGeneralErrorAlert() {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: self.errorAlertTitle, message: self.errorAlertDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: self.errorOkButtonText, style: .cancel, handler: { _ in
                self.dismiss(animated: true, completion: nil)
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }

}

extension ZSBarcodeScannerViewController: AVCaptureMetadataOutputObjectsDelegate {

    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        for metadata in metadataObjects {
            if let readableObject = metadata as? AVMetadataMachineReadableCodeObject, let code = readableObject.stringValue {
                print(code)
                outputBarcode = code
                if self.captureSession.isRunning {
                    self.captureSession.stopRunning()
                }
                DispatchQueue.main.async {
                    self.dismiss(animated: true, completion: {
                        self.delegate?.barcodeRead(scanner: self, data: code)
                    })
                }
                return
            }
        }
    }

}
