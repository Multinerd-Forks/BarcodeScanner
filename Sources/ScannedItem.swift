//
//  ScannedItem.swift
//  BarcodeScanner
//
//  Created by Michael Hedaitulla on 9/18/17.
//

import Foundation
import AVFoundation


public struct ScannedItem  {
    public let code: String
    public let type: AVMetadataObject.ObjectType
    public let image: UIImage?
}
