//
//  ZSBarcodeScannerViewController.swift
//  ZSBarcodeScanner
//
//  Created by Zandor Smith on 06/04/2021.
//

import UIKit
import AVFoundation
import QuartzCore

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

    // Scan effects
    public static var defaultShowScanningBox = true
    public static var defaultScanAnimation = true
    public static var defaultScanAnimationDuration = 0.25
    public static var defaultScanPostAnimationDelay = 0.25

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

    public var showScanningBox = defaultShowScanningBox
    public var scanAnimation = defaultScanAnimation
    public var scanAnimationDuration = defaultScanAnimationDuration
    public var scanPostAnimationDelay = defaultScanPostAnimationDelay

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

    let barcodeFrameView = UIView()
    var borderLayer: CAShapeLayer?
    var maskLayer: CAShapeLayer?

    public override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    public override func viewDidLoad() {
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
//                            if #available(iOS 10.0, *), let settingsUrl = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(settingsUrl) {
//                                alert.addAction(UIAlertAction(title: self.errorSettingsButtonText, style: .default, handler: { _ in
//                                    UIApplication.shared.open(settingsUrl, options: [:])
//                                    self.dismiss(animated: true, completion: nil)
//                                }))
//                            }
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

        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.75)
            self.navigationItem.scrollEdgeAppearance = appearance
        }

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

    func getPoints(from rect: CGRect) -> [CGPoint] {
        return [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.minY)
        ]
    }

    func getCutoutPath(rect: CGRect) -> CGPath {
        return getCutoutPath(points: getPoints(from: rect))
    }

    func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        return hypot(p1.x - p2.x, p1.y - p2.y)
    }

    func move(from: CGPoint, to: CGPoint, magnitude: CGFloat) -> CGPoint {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let angle = atan2(dy, dx)
        let velX = cos(angle) * magnitude
        let velY = sin(angle) * magnitude
        return CGPoint(x: from.x + velX, y: from.y + velY)
    }

    func angle(_ p0: CGPoint, _ p1: CGPoint) -> CGFloat {
        return atan2(p0.x - p1.x, p0.y - p1.y)
    }

    func getCutoutPath(points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()

        let radius: CGFloat = 50

        let pointTopLeft = points[0]
        let pointBottomLeft = points[1]
        let pointBottomRight = points[2]
        let pointTopRight = points[3]

        // Line position - Point position on line
        let leftTop = move(from: pointTopLeft, to: pointBottomLeft, magnitude: radius)
        let leftBottom = move(from: pointBottomLeft, to: pointTopLeft, magnitude: radius)

        let bottomLeft = move(from: pointBottomLeft, to: pointBottomRight, magnitude: radius)
        let bottomRight = move(from: pointBottomRight, to: pointBottomLeft, magnitude: radius)

        let rightBottom = move(from: pointBottomRight, to: pointTopRight, magnitude: radius)
        let rightTop = move(from: pointTopRight, to: pointBottomRight, magnitude: radius)

        let topRight = move(from: pointTopRight, to: pointTopLeft, magnitude: radius)
        let topLeft = move(from: pointTopLeft, to: pointTopRight, magnitude: radius)

//        let arcCenterTopLeft = move(from: topLeft, to: bottomLeft, magnitude: radius)
//        let arcCenterBottomLeft = move(from: leftBottom, to: rightBottom, magnitude: radius)
//        let arcCenterBottomRight = move(from: bottomRight, to: topRight, magnitude: radius)
//        let arcCenterTopRight = move(from: rightTop, to: leftTop, magnitude: radius)

        path.move(to: move(from: leftTop, to: leftBottom, magnitude: distance(leftTop, leftBottom) / 2))
//        path.addLine(to: leftBottom)
//        path.addArc(center: arcCenterBottomLeft, radius: radius, startAngle: angle(pointTopLeft, pointBottomLeft), endAngle: angle(pointBottomRight, pointBottomLeft), clockwise: true)
        path.addArc(tangent1End: pointBottomLeft, tangent2End: bottomLeft, radius: radius)
        path.addLine(to: bottomLeft)
//        path.addLine(to: bottomRight)
//        path.addArc(center: arcCenterBottomRight, radius: radius, startAngle: angle(pointBottomRight, pointBottomLeft), endAngle: angle(pointBottomRight, pointTopRight), clockwise: true)
        path.addArc(tangent1End: pointBottomRight, tangent2End: rightBottom, radius: radius)
        path.addLine(to: rightBottom)
//        path.addLine(to: rightTop)
//        path.addArc(center: arcCenterTopRight, radius: radius, startAngle: angle(pointBottomRight, pointTopRight), endAngle: angle(pointTopLeft, pointTopRight), clockwise: true)
        path.addArc(tangent1End: pointTopRight, tangent2End: topRight, radius: radius)
        path.addLine(to: topRight)
//        path.addLine(to: topLeft)
//        path.addArc(center: arcCenterTopLeft, radius: radius, startAngle: angle(pointTopLeft, pointTopRight), endAngle: angle(pointTopLeft, pointBottomLeft), clockwise: true)
        path.addArc(tangent1End: pointTopLeft, tangent2End: leftTop, radius: radius)
//        path.addLine(to: leftTop)
//        path.closeSubpath()
//        path.addArc(tangent1End: p2, tangent2End: move(from: p2, to: p3, magnitude: radius), radius: radius)
//        path.addLine(to: move(from: p3, to: p2, magnitude: radius))
//        path.addLine(to: move(from: p0, to: p3, magnitude: radius))
//        path.addArc(center: move(from: move(from: p0, to: p3, magnitude: radius), to: move(from: p1, to: p2, magnitude: radius), magnitude: radius), radius: radius, startAngle: angle(p0, p1), endAngle: angle(p1, p2), clockwise: false)

//        let p0 = points[0]
//        let p1 = points[1]
//        let p2 = points[2]
//        let p3 = points[3]

//        let radius: CGFloat = 50
//        path.move(to: move(from: p0, to: p1, magnitude: radius))
//        path.addLine(to: move(from: p1, to: p0, magnitude: radius))
//        path.addArc(tangent1End: p1, tangent2End: move(from: p1, to: p2, magnitude: radius), radius: radius)
//        path.addLine(to: move(from: p2, to: p1, magnitude: radius))
//        path.addArc(tangent1End: p2, tangent2End: move(from: p2, to: p3, magnitude: radius), radius: radius)
//        path.addLine(to: move(from: p3, to: p2, magnitude: radius))
//        path.addArc(tangent1End: p3, tangent2End: move(from: p3, to: p0, magnitude: radius), radius: radius)
//        path.addLine(to: move(from: p0, to: p3, magnitude: radius))
//        path.addArc(center: move(from: move(from: p0, to: p3, magnitude: radius), to: move(from: p1, to: p2, magnitude: radius), magnitude: radius), radius: radius, startAngle: angle(p0, p1), endAngle: angle(p1, p2), clockwise: false)
//        path.addArc(tangent1End: p0, tangent2End: move(from: p0, to: p1, magnitude: radius), radius: radius)
//        path.addLine(to: move(from: p1, to: p0, magnitude: radius))

//        path.move(to: CGPoint(x: (points[0].x + points[3].x) / 2, y: (points[0].y + points[3].y) / 2))
//        path.addLine(to: points[0])
//        path.addLine(to: points[1])
//        path.addLine(to: points[2])
//        path.addLine(to: points[3])
//        path.addLine(to: CGPoint(x: (points[0].x + points[3].x) / 2, y: (points[0].y + points[3].y) / 2))
//        path.closeSubpath()

//        let radius: CGFloat = 15
//        path.move(to: CGPoint(x: (points[0].x + points[3].x) / 2, y: (points[0].y + points[3].y) / 2))
//        path.addArc(tangent1End: points[0], tangent2End: points[1], radius: radius)
//        path.addArc(tangent1End: points[1], tangent2End: points[2], radius: radius)
//        path.addArc(tangent1End: points[2], tangent2End: points[3], radius: radius)
//        path.addArc(tangent1End: points[3], tangent2End: points[0], radius: radius)
//        path.closeSubpath()

//        let radius: CGFloat = 15
//        path.move(to: CGPoint(x: points[0].x, y: points[0].y - radius))
//        path.closeSubpath()
//        path.addLine(to: points[1])
//        path.addLine(to: points[2])
//        path.addLine(to: points[3])
//        path.addLine(to: points[0])

//        return UIBezierPath(cgPath: path)
        return path
    }

    func getOverlayCutoutPath(frame: CGRect, rect: CGRect) -> CGPath {
        return getOverlayCutoutPath(frame: frame, points: getPoints(from: rect))
    }

    func getOverlayCutoutPath(frame: CGRect, points: [CGPoint]) -> CGPath {
//        let path = UIBezierPath(rect: frame)
//        path.append(getCutoutPath(points: points))
//        return path
        let path = CGMutablePath(rect: frame, transform: nil)
        path.addPath(getCutoutPath(points: points))
        return path
    }

    private func setupFrameView() {
        guard showScanningBox else {
            return
        }

        let size = min(view.bounds.width, view.bounds.height) - 100

        let overlay = UIView(frame: view.bounds)
        overlay.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)

        maskLayer = CAShapeLayer()
        guard let maskLayer = maskLayer else {
            return
        }
        maskLayer.frame = overlay.bounds

        maskLayer.fillColor = UIColor.black.cgColor
        maskLayer.fillRule = CAShapeLayerFillRule.evenOdd

        let maskRect = CGRect(x: overlay.frame.midX - size / 2, y: overlay.frame.midY - size / 2, width: size, height: size)
        maskLayer.path = getOverlayCutoutPath(frame: overlay.bounds, rect: maskRect)
        overlay.layer.mask = maskLayer

        self.view.addSubview(overlay)

        let border = UIView(frame: view.bounds)

        borderLayer = CAShapeLayer()
        guard let borderLayer = borderLayer else {
            return
        }
        let borderRect = CGRect(x: border.bounds.midX - size / 2, y: border.bounds.midY - size / 2, width: size, height: size)
        borderLayer.path = getCutoutPath(rect: borderRect)
        borderLayer.lineWidth = 10
        borderLayer.strokeColor = UIColor.white.cgColor
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.frame = border.bounds
        border.layer.addSublayer(borderLayer)

        self.view.addSubview(border)

//        barcodeFrameView.layer.opacity = 1
//        barcodeFrameView.layer.borderColor = UIColor.white.cgColor
//        barcodeFrameView.layer.borderWidth = 3
//        barcodeFrameView.layer.cornerRadius = 15
        barcodeFrameView.frame.size = CGSize(width: size, height: size)
        barcodeFrameView.center = view.center

        if !barcodeFrameView.isDescendant(of: view) {
            view.addSubview(barcodeFrameView)
            view.bringSubviewToFront(barcodeFrameView)
        }
    }

    private func animateScanBox(to rect: CGRect, completion: @escaping () -> Void) {
        animateScanBox(to: getPoints(from: rect), completion: completion)
//        UIView.animate(withDuration: scanAnimationDuration, delay: 0, options: .curveEaseInOut) {
//            self.barcodeFrameView.frame = rect
//        } completion: { _ in
//            completion()
//        }
//
//        if let maskLayer = maskLayer {
//            let animation = CABasicAnimation(keyPath: "path")
//            animation.duration = scanAnimationDuration
//            animation.toValue = self.getOverlayCutoutPath(frame: view.bounds, rect: rect).cgPath
//            animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
//            animation.fillMode = CAMediaTimingFillMode.forwards
//            animation.isRemovedOnCompletion = false
//            maskLayer.add(animation, forKey: "path")
//        }
    }

    private func animateScanBox(to points: [CGPoint], completion: @escaping () -> Void) {
        UIView.animate(withDuration: scanAnimationDuration, delay: 0, options: .curveEaseInOut) {
            // TODO: Implement
            self.barcodeFrameView.frame = self.view.bounds
        } completion: { _ in
            completion()
        }

        if let maskLayer = maskLayer {
            let animation = CABasicAnimation(keyPath: "path")
            animation.duration = scanAnimationDuration
            animation.toValue = self.getOverlayCutoutPath(frame: view.bounds, points: points)
            animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
            animation.fillMode = CAMediaTimingFillMode.forwards
            animation.isRemovedOnCompletion = false
            maskLayer.add(animation, forKey: "path")
        }
        if let borderLayer = borderLayer {
            let animation = CABasicAnimation(keyPath: "path")
            animation.duration = scanAnimationDuration
            animation.toValue = self.getCutoutPath(points: points)
            animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
            animation.fillMode = CAMediaTimingFillMode.forwards
            animation.isRemovedOnCompletion = false
            borderLayer.add(animation, forKey: "path")
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
            self.setupFrameView()
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
                print("BarcodeScanner: Scanned '" + code + "'")
                outputBarcode = code
                if self.captureSession.isRunning {
                    self.captureSession.stopRunning()
                }
                self.currentDevice?.unlockForConfiguration()
                DispatchQueue.main.async {
                    if self.showScanningBox, self.scanAnimation, let barCodeObject = self.previewLayer?.transformedMetadataObject(for: readableObject) as? AVMetadataMachineReadableCodeObject {
                        print(barCodeObject.corners)
                        self.animateScanBox(to: barCodeObject.corners) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + self.scanPostAnimationDelay) {
                                self.dismiss(animated: true, completion: {
                                    self.delegate?.barcodeRead(scanner: self, data: code)
                                })
                            }
                        }
                    } else {
                        self.dismiss(animated: true, completion: {
                            self.delegate?.barcodeRead(scanner: self, data: code)
                        })
                    }
                }
                return
            }
        }
    }

}
