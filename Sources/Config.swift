import UIKit
import AVFoundation

// MARK: - Configurations

public struct Title {
    public static var text = "Scan barcode"

    public static var font = UIFont.boldSystemFont(ofSize: 17)

    public static var color = UIColor.black

    public static var backgroundColor = UIColor.white
}

public struct CloseButton {
    public static var text = "Close"

    public static var font = UIFont.boldSystemFont(ofSize: 17)

    public static var color = UIColor.black
}



public struct Info {
    public static var text = "Place the barcode within the window to scan. The search will start automatically."

    public static var loadingText = "Looking for your product..."

    public static var notFoundText = "No product found."

    public static var settingsText = "In order to scan barcodes you have to allow camera under your settings."

    public static var font = UIFont.boldSystemFont(ofSize: 14)

    public static var textColor = UIColor.black

    public static var tint = UIColor.black

    public static var loadingFont = UIFont.boldSystemFont(ofSize: 16)

    public static var loadingTint = UIColor.black

    public static var notFoundTint = UIColor.red
}

/**
 Returns image with a given name from the resource bundle.

 - Parameter name: Image name.
 - Returns: An image.
 */
func imageNamed(_ name: String) -> UIImage {

    let cls = BarcodeScannerController.self
    var bundle = Bundle(for: cls)
    let traitCollection = UITraitCollection(displayScale: 3)

    if let path = bundle.resourcePath,
       let resourceBundle = Bundle(path: path + "/BarcodeScanner.bundle") {
        bundle = resourceBundle
    }

    guard let image = UIImage(named: name, in: bundle,
                              compatibleWith: traitCollection)
            else { return UIImage() }

    return image
}

func localizedString(_ key: String) -> String {

    if let path = Bundle(for: BarcodeScannerController.self).resourcePath,
       let resourceBundle = Bundle(path: path + "/Localization.bundle") {
        return resourceBundle.localizedString(forKey: key, value: nil, table: "Localizable")
    }
    return key
}

/**
 `AVCaptureMetadataOutput` metadata object types.
 */
public var metadata = [
    AVMetadataObject.ObjectType.upce,
    AVMetadataObject.ObjectType.code39,
    AVMetadataObject.ObjectType.code39Mod43,
    AVMetadataObject.ObjectType.ean13,
    AVMetadataObject.ObjectType.ean8,
    AVMetadataObject.ObjectType.code93,
    AVMetadataObject.ObjectType.code128,
    AVMetadataObject.ObjectType.pdf417,
    AVMetadataObject.ObjectType.qr,
    AVMetadataObject.ObjectType.aztec,
    AVMetadataObject.ObjectType.itf14
]


extension AVMetadataObject.ObjectType {
    
    public static let upca: AVMetadataObject.ObjectType = AVMetadataObject.ObjectType(rawValue: "org.gs1.UPC-A")
}
