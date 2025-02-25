//
//  ViewController.swift
//  ZSBarcodeScanner
//
//  Created by Zandor300 on 04/06/2021.
//  Copyright (c) 2021 Zandor300. All rights reserved.
//

import UIKit
import ZSBarcodeScanner

class ViewController: UIViewController {

    @IBOutlet weak var resultLabel: UILabel!

    @IBAction func didTapOpenScanner(_ sender: Any) {
        let barcodeScanner = ZSBarcodeScannerViewController()
        barcodeScanner.delegate = self
        let navigationController = UINavigationController(rootViewController: barcodeScanner)
        self.present(navigationController, animated: true)
    }

    @IBAction func didTapPushScanner(_ sender: Any) {
        let barcodeScanner = ZSBarcodeScannerViewController()
        barcodeScanner.delegate = self
        barcodeScanner.leftBarButtonItemType = .none
        barcodeScanner.rightBarButtonItemType = .flash
        self.navigationController?.pushViewController(barcodeScanner, animated: true)
    }

    @IBAction func didTapSlowScanner(_ sender: Any) {
        let barcodeScanner = ZSBarcodeScannerViewController()
        barcodeScanner.delegate = self
        barcodeScanner.leftBarButtonItemType = .none
        barcodeScanner.rightBarButtonItemType = .flash
        barcodeScanner.scanAnimationDuration = 5
        barcodeScanner.scanPostAnimationDelay = 5
        self.navigationController?.pushViewController(barcodeScanner, animated: true)
    }

}

extension ViewController: ZSBarcodeScannerDelegate {

    func barcodeRead(scanner: ZSBarcodeScannerViewController, data: String) {
        resultLabel.text = data
    }

}
