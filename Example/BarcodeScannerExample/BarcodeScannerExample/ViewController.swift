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

extension ViewController: BarcodeScannerDelegate {

  func barcodeScanner(_ controller: BarcodeScannerController, didCaptureCode code: String, type: String) {
    print(code)
    print(type)

    let delayTime = DispatchTime.now() + Double(Int64(6 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
    DispatchQueue.main.asyncAfter(deadline: delayTime) {
      controller.resetWithError()
    }
  }

  func barcodeScanner(_ controller: BarcodeScannerController, didReceiveError error: Error) {
    print(error)
  }

  func barcodeScannerDidDismiss(_ controller: BarcodeScannerController) {
    controller.dismiss(animated: true, completion: nil)
  }
}
