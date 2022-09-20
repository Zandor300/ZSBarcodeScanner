//
//  ZSBarcodeScannerDelegate.swift
//  ZSBarcodeScanner
//
//  Created by Zandor Smith on 06/04/2021.
//

import Foundation
import AVFoundation

public protocol ZSBarcodeScannerDelegate: AnyObject {

    func barcodeRead(scanner: ZSBarcodeScannerViewController, data: String)

    @available(*, deprecated, renamed: "didSetupScannerView(scanner:)")
    func didSetupScannerView()

    func didSetupScannerView(scanner: ZSBarcodeScannerViewController)

}

public extension ZSBarcodeScannerDelegate {

    func didSetupScannerView() {}

    func didSetupScannerView(scanner: ZSBarcodeScannerViewController) {}

}
