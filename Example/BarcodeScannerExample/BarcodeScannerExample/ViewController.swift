import UIKit
import BarcodeScanner

class ViewController: UIViewController {
    
    lazy var button: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.black
        button.titleLabel?.font = UIFont.systemFont(ofSize: 28)
        button.setTitleColor(UIColor.white, for: UIControlState())
        button.setTitle("Scan", for: UIControlState())
        button.addTarget(self, action: #selector(buttonDidPress), for: .touchUpInside)
        
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.white
        view.addSubview(button)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        button.frame.size = CGSize(width: 250, height: 80)
        button.center = view.center
    }
    
    @objc func buttonDidPress() {
        let controller = BarcodeScannerController()
        controller.delegate = self
        
        present(controller, animated: true, completion: nil)
    }
}

public func getTopMostController() -> UIViewController? {
    
    if var topController = UIApplication.shared.keyWindow?.rootViewController {
        while let presentedViewController = topController.presentedViewController {
            topController = presentedViewController
        }
        return topController
    }
    return nil
}


extension ViewController: BarcodeScannerDelegate {
    
    func barcodeScanner(_ controller: BarcodeScannerController, didCaptureItem item: ScannedItem) {
        print(item.code)
        print(item.type)
        
        
        let vc = UIViewController()
        vc.view.backgroundColor = item.image == nil ? UIColor.gray : UIColor(patternImage: item.image!)
        self.present(vc, animated: true, completion: nil)
        
        let delayTime = DispatchTime.now() + Double(Int64(6 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: delayTime) {
//            controller.resetWithError()
            controller.reset()

        }
        
    }
    
    
    func barcodeScanner(_ controller: BarcodeScannerController, didReceiveError error: Error) {
        print(error)
    }
    
    func barcodeScannerDidDismiss(_ controller: BarcodeScannerController) {
        controller.dismiss(animated: true, completion: nil)
    }
}

