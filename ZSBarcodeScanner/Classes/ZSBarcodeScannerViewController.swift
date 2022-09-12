//
//  ZSBarcodeScannerViewController.swift
//  ZSBarcodeScanner
//
//  Created by Zandor Smith on 06/04/2021.
//

import UIKit
import AVFoundation
import QuartzCore

open class ZSBarcodeScannerViewController: UIViewController {

    public enum BarButtonItemType {
        case close
        case flash
        case none
    }

    private let generator = UINotificationFeedbackGenerator()

    // Default variables that can be set once during application didFinishLaunchingWithOptions.
    public static var defaultAllowedBarcodeTypes: [AVMetadataObject.ObjectType] = [.qr, .ean13, .upce, .dataMatrix, .code39, .code128, .code93]
    public static var defaultAllowedCameras: [AVCaptureDevice.DeviceType] = {
        var cameras: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera, .builtInTelephotoCamera]
        if #available(iOS 13.0, *) {
            cameras.append(.builtInUltraWideCamera)
        }
        return cameras
    }()
    public static var defaultCameraNames: [AVCaptureDevice.DeviceType: String] = {
        var cameras: [AVCaptureDevice.DeviceType: String] = [
            .builtInWideAngleCamera: "Wide",
            .builtInTelephotoCamera: "Telephoto"
        ]
        if #available(iOS 13.0, *) {
            cameras[.builtInUltraWideCamera] = "Ultrawide"
        }
        return cameras
    }()

    public static var defaultPrompt: String? = "Point your camera at a barcode."
    public static var defaultErrorAlertTitle = "Error"
    public static var defaultErrorAlertDescription = "An error occured. Please try again later."
    public static var defaultErrorNoCameraPermissionTitle = "No permission"
    public static var defaultErrorNoCameraPermissionDescription = "The app doesn't have permission to access the camera. Please enable access in iOS settings."
    public static var defaultErrorOkButtonText = "OK"
    public static var defaultErrorSettingsButtonText = "Settings"

    private static var internalDefaultCloseGlyph: UIImage? {
        if #available(iOS 13.0, *) {
            return UIImage(systemName: "multiply.circle.fill")
        } else {
            return UIImage(named: "Close", in: Bundle(for: classForCoder()), compatibleWith: nil)
        }
    }
    private static var internalDefaultFlashOnGlyph: UIImage? {
        if #available(iOS 13.0, *) {
            return UIImage(systemName: "bolt.fill")
        } else {
            return UIImage(named: "FlashOn", in: Bundle(for: classForCoder()), compatibleWith: nil)
        }
    }
    private static var internalDefaultFlashOffGlyph: UIImage? {
        if #available(iOS 13.0, *) {
            return UIImage(systemName: "bolt.slash.fill")
        } else {
            return UIImage(named: "FlashOff", in: Bundle(for: classForCoder()), compatibleWith: nil)
        }
    }
    public static var defaultCloseGlyph = internalDefaultCloseGlyph
    public static var defaultFlashOnGlyph = internalDefaultFlashOnGlyph
    public static var defaultFlashOffGlyph = internalDefaultFlashOffGlyph

    public static var defaultLeftBarButtonItemType = BarButtonItemType.flash
    public static var defaultRightBarButtonItemType = BarButtonItemType.close

    // Scan effects
    public static var defaultShowScanningBox = true
    public static var defaultScanAnimation = true
    public static var defaultScanAnimationDuration = 0.25
    public static var defaultScanPostAnimationDelay = 0.25
    public static var defaultScanHapticFeedback = true

    // Variables to customize the barcode scanner during launching from default settings.
    public var allowedBarcodeTypes = defaultAllowedBarcodeTypes
    public var allowedCameras = defaultAllowedCameras
    public var cameraNames = defaultCameraNames

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

    public var leftBarButtonItemType = defaultLeftBarButtonItemType
    public var rightBarButtonItemType = defaultRightBarButtonItemType

    public var showScanningBox = defaultShowScanningBox
    public var scanAnimation = defaultScanAnimation
    public var scanAnimationDuration = defaultScanAnimationDuration
    public var scanPostAnimationDelay = defaultScanPostAnimationDelay
    public var scanHapticFeedback = defaultScanHapticFeedback

    public var automaticallyDismissOnBarcodeScan: Bool = true

    // MARK: Main code

    public weak var delegate: ZSBarcodeScannerDelegate?

    var output = AVCaptureMetadataOutput()
    var previewLayer: AVCaptureVideoPreviewLayer?

    var captureSession = AVCaptureSession()

    var currentDevice: AVCaptureDevice?
    var devices = [AVCaptureDevice]()

    var flashButton: UIBarButtonItem?
    var segmentedControl = UISegmentedControl()

    var outputBarcode: String?

    let barcodeFrameView = UIView()
    let overlayView = UIView()
    var maskLayer: CAShapeLayer?

    public override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

        if ZSBarcodeScannerViewController.defaultCloseGlyph == nil {
            print("ZSBarcodeScanner Warning: defaultCloseGlyph is nil")
        }
        if ZSBarcodeScannerViewController.defaultFlashOnGlyph == nil {
            print("ZSBarcodeScanner Warning: defaultFlashOnGlyph is nil")
        }
        if ZSBarcodeScannerViewController.defaultFlashOffGlyph == nil {
            print("ZSBarcodeScanner Warning: defaultFlashOffGlyph is nil")
        }

        self.setNeedsStatusBarAppearanceUpdate()

        self.navigationItem.prompt = prompt
        self.navigationController?.navigationBar.barStyle = .black
        self.view.backgroundColor = .black

        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.75)
            self.navigationItem.scrollEdgeAppearance = appearance
        }

        let backButton = UIBarButtonItem(image: closeGlyph, style: .plain, target: self, action: #selector(cancel))
        backButton.tintColor = .orange
        if leftBarButtonItemType == .close {
            self.navigationItem.leftBarButtonItem = backButton
        }
        if rightBarButtonItemType == .close {
            self.navigationItem.rightBarButtonItem = backButton
        }
    }

    public func resetScanner() {
        self.startCaptureSession()
        self.outputBarcode = nil
    }

    @objc func cancel() {
        handleDismiss()
    }

    @objc func toggleFlash() {
        self.flashSetState(!(currentDevice?.isTorchActive ?? false))
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        DispatchQueue.global(qos: .background).async {
            if self.captureSession.isRunning {
                print("BarcodeScanner: Stop running...")
                self.captureSession.stopRunning()
                print("BarcodeScanner: Stopped.")
            }
        }
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.outputBarcode = nil

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
                        if #available(iOS 10.0, *), let settingsUrl = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(settingsUrl) {
                            alert.addAction(UIAlertAction(title: self.errorSettingsButtonText, style: .default, handler: { _ in
                                UIApplication.shared.open(settingsUrl, options: [:])
                                if self.automaticallyDismissOnBarcodeScan {
                                    self.cancel()
                                }
                            }))
                        }
                        alert.addAction(UIAlertAction(title: self.errorOkButtonText, style: .cancel, handler: { _ in
                            if self.automaticallyDismissOnBarcodeScan {
                                self.cancel()
                            }
                        }))
                        self.present(alert, animated: true, completion: nil)
                    }
                }
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

        if self.devices.count == 0 {
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

            self.currentDevice = self.devices.first!

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
        }

        setupTorch()
        setupCapture(with: currentDevice!)
    }

    @objc private func didSelectSegmentedControl() {
        let device = devices[segmentedControl.selectedSegmentIndex]
        currentDevice = device
        changeDevice(to: device)
    }

    private func setupTorch() {
        if let currentDevice = currentDevice, currentDevice.hasTorch {
            flashButton = UIBarButtonItem(image: currentDevice.torchMode == .on ? flashOnGlyph : flashOffGlyph, style: .plain, target: self, action: #selector(toggleFlash))
            flashButton?.tintColor = UIColor.orange
        } else {
            flashButton = nil
        }

        if leftBarButtonItemType == .flash {
            self.navigationItem.leftBarButtonItem = flashButton
        }
        if rightBarButtonItemType == .flash {
            self.navigationItem.rightBarButtonItem = flashButton
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
            }

            self.startCaptureSession()
        }
    }

    func getOverlayCutoutPath(frame: CGRect, rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath(rect: frame)
        let pathCutout = UIBezierPath(roundedRect: rect, byRoundingCorners: .allCorners, cornerRadii: CGSize(width: 15, height: 15))
        path.append(pathCutout)
        return path
    }

    private func setupFrameView() {
        guard showScanningBox else {
            return
        }

        var size: CGFloat {
            if #available(iOS 11.0, *) {
                let value = min(view.bounds.width - view.safeAreaInsets.left - view.safeAreaInsets.right, view.bounds.height - view.safeAreaInsets.top - view.safeAreaInsets.bottom)
                return value * 0.8
            } else {
                let value = min(view.bounds.width, view.bounds.height)
                return value * 0.8
            }
        }
        var center: CGPoint {
            if #available(iOS 11.0, *) {
                return CGPoint(x: view.center.x + view.safeAreaInsets.left / 2 - view.safeAreaInsets.right / 2, y: view.center.y + view.safeAreaInsets.top / 2 - view.safeAreaInsets.bottom / 2)
            } else {
                return view.center
            }
        }

        barcodeFrameView.layer.borderColor = UIColor.white.cgColor
        barcodeFrameView.layer.borderWidth = 3
        barcodeFrameView.layer.cornerRadius = 15
        barcodeFrameView.frame.size = CGSize(width: size, height: size)
        barcodeFrameView.center = center

        overlayView.frame = view.bounds
        overlayView.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)

        maskLayer = CAShapeLayer()
        guard let maskLayer = maskLayer else {
            return
        }
        maskLayer.frame = overlayView.bounds
        maskLayer.fillColor = UIColor.black.cgColor
        maskLayer.fillRule = CAShapeLayerFillRule.evenOdd

        let rect = CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)
        maskLayer.path = getOverlayCutoutPath(frame: overlayView.bounds, rect: rect).cgPath
        overlayView.layer.mask = maskLayer

        if !overlayView.isDescendant(of: view) {
            view.addSubview(overlayView)
        }
        view.bringSubviewToFront(overlayView)

        if !barcodeFrameView.isDescendant(of: view) {
            barcodeFrameView.layer.opacity = 0
            view.addSubview(barcodeFrameView)
        }
        view.bringSubviewToFront(barcodeFrameView)

        UIView.animate(withDuration: 0.1, delay: 0, options: .curveLinear) {
            self.barcodeFrameView.layer.opacity = 1
        }

        delegate?.didSetupScannerView()
    }

    private func animateScanBox(to rect: CGRect, completion: @escaping () -> Void) {
        UIView.animate(withDuration: scanAnimationDuration, delay: 0, options: .curveEaseInOut) {
            self.barcodeFrameView.frame = rect
        } completion: { _ in
            completion()
        }

        if let maskLayer = maskLayer {
            let animation = CABasicAnimation(keyPath: "path")
            animation.duration = scanAnimationDuration
            animation.toValue = self.getOverlayCutoutPath(frame: view.bounds, rect: rect).cgPath
            animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
            animation.fillMode = CAMediaTimingFillMode.forwards
            animation.isRemovedOnCompletion = false
            maskLayer.add(animation, forKey: "path")
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
        if self.previewLayer == nil {
            self.previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
            self.previewLayer?.videoGravity = .resizeAspectFill
        }

        DispatchQueue.main.async {
            self.previewLayer?.frame = self.view.bounds
            self.previewLayer?.removeFromSuperlayer()
            self.view.layer.addSublayer(self.previewLayer!)
            self.handleDeviceRotation()
            self.setupFrameView()
        }
    }

    private func flashSetState(_ state: Bool) {
        do {
            if let device = self.currentDevice, device.hasTorch {
                try device.lockForConfiguration()
                device.torchMode = state ? .on : .off
                device.unlockForConfiguration()
                self.flashButton?.image = state ? flashOnGlyph : flashOffGlyph
            }
        } catch {
            print("Device Flash Error")
        }
    }

    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.handleDeviceRotation()
            self.setupFrameView()
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
                if self.automaticallyDismissOnBarcodeScan {
                    self.cancel()
                }
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }

    func handleDismiss(_ onCompletion: (() -> Void)? = nil) {
        if let navigationController = self.navigationController, navigationController.viewControllers.first != self {
            navigationController.popViewController(animated: true)
            if let onCompletion = onCompletion {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                    onCompletion()
                }
            }
        } else {
            self.dismiss(animated: true) {
                if let onCompletion = onCompletion {
                    onCompletion()
                }
            }
        }
    }

}

extension ZSBarcodeScannerViewController: AVCaptureMetadataOutputObjectsDelegate {

    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard outputBarcode == nil else {
            return
        }
        for metadata in metadataObjects {
            if let readableObject = metadata as? AVMetadataMachineReadableCodeObject, let code = readableObject.stringValue {
                print(code)
                outputBarcode = code
                if self.captureSession.isRunning {
                    self.captureSession.stopRunning()
                }
                self.currentDevice?.unlockForConfiguration()

                let afterAnimation = {
                    if self.automaticallyDismissOnBarcodeScan {
                        self.handleDismiss {
                            self.delegate?.barcodeRead(scanner: self, data: code)
                        }
                    } else {
                        self.delegate?.barcodeRead(scanner: self, data: code)
                    }
                }

                DispatchQueue.main.async {
                    if self.scanHapticFeedback {
                        self.generator.notificationOccurred(.success)
                    }
                    if self.showScanningBox, self.scanAnimation, let barCodeObject = self.previewLayer?.transformedMetadataObject(for: metadata) {
                        self.animateScanBox(to: barCodeObject.bounds) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + self.scanPostAnimationDelay) {
                                afterAnimation()
                            }
                        }
                    } else {
                        afterAnimation()
                    }
                }
                return
            }
        }
    }

}
