import UIKit
import AVFoundation

// MARK: - Delegates

/// Delegate to handle the captured code.

public protocol BarcodeScannerDelegate: class {
    func barcodeScanner(_ controller: BarcodeScannerController, didCaptureItem item: ScannedItem)

    func barcodeScanner(_ controller: BarcodeScannerController, didReceiveError error: Error)

}

// MARK: - Controller

/**
 Barcode scanner controller with 4 sates:
 - Scanning mode
 - Processing animation
 - Unauthorized mode
 - Not found error message
 */
open class BarcodeScannerController: UIViewController {
    
    var input: AVCaptureDeviceInput!
    lazy var output = AVCaptureMetadataOutput()
    lazy var stillOutput = AVCaptureStillImageOutput()
    
    
    /// Video capture device.
    lazy var captureDevice: AVCaptureDevice = AVCaptureDevice.default(for: AVMediaType.video)!

    /// Capture session.
    lazy var captureSession: AVCaptureSession = AVCaptureSession()

    /// Information view with description label.
    lazy var infoView: InfoView = InfoView()

    /// Button to change torch mode.
    public lazy var flashButton: UIButton = { [unowned self] in
        let button = UIButton(type: .custom)
        button.addTarget(self, action: #selector(flashButtonDidPress), for: .touchUpInside)
        return button
    }()

    /// Animated focus view.
    lazy var focusView: UIView = {
        let view = UIView()
        view.layer.borderColor = UIColor.white.cgColor
        view.layer.borderWidth = 2
        view.layer.cornerRadius = 5
        view.layer.shadowColor = UIColor.white.cgColor
        view.layer.shadowRadius = 10.0
        view.layer.shadowOpacity = 0.9
        view.layer.shadowOffset = CGSize.zero
        view.layer.masksToBounds = false

        return view
    }()

    /// Video preview layer.
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?

    /// The current controller's status mode.
    var status: Status = Status(state: .scanning) {
        didSet {
            let duration = status.animated &&
                           (status.state == .processing
                            || oldValue.state == .processing
                            || oldValue.state == .notFound
                           ) ? 0.5 : 0.0

            guard status.state != .notFound else {
                infoView.status = status

                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2.0) {
                    self.status = Status(state: .scanning)
                }

                return
            }

            let delayReset = oldValue.state == .processing || oldValue.state == .notFound

            if !delayReset {
                resetState()
            }

            UIView.animate(withDuration: duration,
                           animations: {
                               self.infoView.frame = self.infoFrame
                               self.infoView.status = self.status
                           },
                           completion: { _ in
                               if delayReset {
                                   self.resetState()
                               }

                               self.infoView.layer.removeAllAnimations()
                               if self.status.state == .processing {
                                   self.infoView.animateLoading()
                               }
                           })
        }
    }

    public var barCodeFocusViewType: FocusViewType = .animated

    /// The current torch mode on the capture device.
    var torchMode: TorchMode = .off {
        didSet {
            guard captureDevice.hasFlash else { return }

            do {
                try captureDevice.lockForConfiguration()
                captureDevice.torchMode = torchMode.captureTorchMode
                captureDevice.unlockForConfiguration()
            } catch {}

            flashButton.setImage(torchMode.image, for: UIControl.State())
        }
    }

    /// Calculated frame for the info view.
    var infoFrame: CGRect {
        let height = status.state != .processing ? 75 : view.bounds.height
        return CGRect(x: 0, y: view.bounds.height - height,
                      width: view.bounds.width, height: height)
    }

    /// When the flag is set to `true` controller returns a captured code
    /// and waits for the next reset action.
    public var isOneTimeSearch = true
    

    public var willSaveImage = true

    /// Delegate to handle the captured code.
    public weak var delegate: BarcodeScannerDelegate?

    /// Flag to lock session from capturing.
    var locked = false

    // MARK: - Initialization

    deinit {

        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - View lifecycle

    open override func viewDidLoad() {

        super.viewDidLoad()

        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
        videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill

        view.backgroundColor = UIColor.black

        guard let videoPreviewLayer = videoPreviewLayer else {
            return
        }

        view.layer.addSublayer(videoPreviewLayer)

        [ infoView, flashButton, focusView ].forEach {
            view.addSubview($0)
            view.bringSubviewToFront($0)
        }

        torchMode = .off
        focusView.isHidden = true

        setupCamera()

        NotificationCenter.default.addObserver(
                self, selector: #selector(appWillEnterForeground),
                name: UIApplication.willEnterForegroundNotification,
                object: nil)
    }

    open override func viewWillAppear(_ animated: Bool) {

        super.viewWillAppear(animated)
    }

    open override func viewDidAppear(_ animated: Bool) {

        super.viewDidAppear(animated)
        animateFocusView()
        startScan()
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScan()
    }

    open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {

        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { (context) in
            self.setupFrame()
        }) { (context) in
            self.focusView.layer.removeAllAnimations()
            self.animateFocusView()
        }
    }

    /**
     `UIApplicationWillEnterForegroundNotification` action.
     */
    @objc func appWillEnterForeground() {

        torchMode = .off
        animateFocusView()
    }

    // MARK: - Configuration

    /**
     Sets up camera and checks for camera permissions.
     */
    func setupCamera() {

        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)

        if authorizationStatus == .authorized {
            setupSession()
            status = Status(state: .scanning)
        }

        
        else {
            status = Status(state: .unauthorized)
        }
    }

    /**
     Sets up capture input, output and session.
     */
    func setupSession() {

        do {
            input = try AVCaptureDeviceInput(device: captureDevice)
            if captureSession.canAddInput(input!) { captureSession.addInput(input!) }
        } catch {
            delegate?.barcodeScanner(self, didReceiveError: error)
        }


        if captureSession.canAddOutput(output) { captureSession.addOutput(output) }
        if captureSession.canAddOutput(stillOutput) { captureSession.addOutput(stillOutput) }
        
        
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = metadata
        videoPreviewLayer?.session = captureSession

        view.setNeedsLayout()
    }

    // MARK: - Reset

    /**
     Shows error message and goes back to the scanning mode.

     - Parameter errorMessage: Error message that overrides the message from the config.
     */
    public func resetWithError(message: String? = nil) {

        status = Status(state: .notFound, text: message)
    }

    /**
     Resets the controller to the scanning mode.

     - Parameter animated: Flag to show scanner with or without animation.
     */
    public func reset(animated: Bool = true) {

        status = Status(state: .scanning, animated: animated)
    }

    
    public func startScan() {
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }
    
    public func stopScan()  {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }


    /**
     Resets the current state.
     */
    func resetState() {

        let alpha: CGFloat = status.state == .scanning ? 1 : 0

        torchMode = .off
        locked = status.state == .processing && isOneTimeSearch

        status.state == .scanning
                ? captureSession.startRunning()
                : captureSession.stopRunning()

        focusView.alpha = alpha
        flashButton.alpha = alpha
    }

    // MARK: - Layout
    func setupFrame() {

        flashButton.frame = CGRect(x: view.frame.width - 50, y: 0, width: 37, height: 37)
        infoView.frame = infoFrame

        if let videoPreviewLayer = videoPreviewLayer {
            videoPreviewLayer.frame = view.layer.bounds
            if let connection = videoPreviewLayer.connection, connection.isVideoOrientationSupported {
                switch (UIApplication.shared.statusBarOrientation) {
                    case .portrait: connection.videoOrientation = .portrait
                    case .landscapeRight: connection.videoOrientation = .landscapeRight
                    case .landscapeLeft: connection.videoOrientation = .landscapeLeft
                    case .portraitUpsideDown: connection.videoOrientation = .portraitUpsideDown
                    default: connection.videoOrientation = .portrait
                }
            }
        }

        if barCodeFocusViewType == .oneDimension {
            center(subview: focusView, inSize: CGSize(width: 280, height: 80))
        } else {
            center(subview: focusView, inSize: CGSize(width: 218, height: 150))
        }
    }

    /**
     Sets a new size and center aligns subview's position.

     - Parameter subview: The subview.
     - Parameter size: A new size.
    */
    func center(subview: UIView, inSize size: CGSize) {

        subview.frame = CGRect(
                x: (view.frame.width - size.width) / 2,
                y: (view.frame.height - size.height) / 2,
                width: size.width,
                height: size.height)
    }

    // MARK: - Animations

    /**
     Simulates flash animation.

     - Parameter processing: Flag to set the current state to `.Processing`.
     */
    func animateFlash(whenProcessing: Bool = false) {

        let flashView = UIView(frame: view.bounds)
        flashView.backgroundColor = UIColor.white
        flashView.alpha = 1

        view.addSubview(flashView)
        view.bringSubviewToFront(flashView)

        UIView.animate(withDuration: 0.2,
                       animations: { flashView.alpha = 0.0  },
                       completion: { _ in
                           flashView.removeFromSuperview()

                           if whenProcessing {
                               self.status = Status(state: .processing)
                           }
                       })
    }

    /**
     Performs focus view animation.
     */
    func animateFocusView() {

        focusView.layer.removeAllAnimations()
        focusView.isHidden = false

        setupFrame()

        if barCodeFocusViewType == .animated {
            UIView.animate(withDuration: 1.0, delay: 0,
                           options: [ .repeat, .autoreverse, .beginFromCurrentState ],
                           animations: {
                               self.center(subview: self.focusView, inSize: CGSize(width: 280, height: 80))
                           }, completion: nil)
        }
        view.setNeedsLayout()
    }

    // MARK: - Actions

    /**
     Sets the next torch mode.
     */
    @objc func flashButtonDidPress() {

        torchMode = torchMode.next
    }
    
    
    
    func captureImage(forCode code: String, forType type: AVMetadataObject.ObjectType) {
        
        let stillImageConnection = connectionWithMediaType(mediaType: .video, connections: stillOutput.connections)
        stillOutput.captureStillImageAsynchronously(from: stillImageConnection!, completionHandler: { [weak self] (imageDataSampleBuffer, error) -> Void in
            guard let `self` = self else { return }
            guard let buffer = imageDataSampleBuffer else { return }
            guard let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(buffer) else { return }
            
            let item = ScannedItem(code: code, type: type, image: UIImage(data: imageData)!)
            self.animateFlash(whenProcessing: self.isOneTimeSearch)
            self.delegate?.barcodeScanner(self, didCaptureItem: item)
        })
    }
    
    func connectionWithMediaType(mediaType: AVMediaType, connections:[AVCaptureConnection]) -> AVCaptureConnection? {
        for connection in connections {
            for port in connection.inputPorts {
                if port.mediaType == mediaType {
                    return connection
                }
            }
        }
        return nil
    } 
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension BarcodeScannerController: AVCaptureMetadataOutputObjectsDelegate {

    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {

        guard !locked else { return }
        guard !metadataObjects.isEmpty else { return }

        guard
                let metadataObj = metadataObjects[0] as? AVMetadataMachineReadableCodeObject,
                var code = metadataObj.stringValue,
                metadata.contains(metadataObj.type)
                else { return }

        if isOneTimeSearch {
            locked = true
        }

        /*
         See: https://stackoverflow.com/questions/22767584/ios7-barcode-scanner-api-adds-a-zero-to-upca-barcode-format
         According to the Uniform Code Council, an EAN-13 barcode beginning with a zero is by definition a 12-digit
         UPC-A barcode. To follow this rule, when a scanner device reads an EAN-13 barcode beginning with a zero, drops
         the leading 0, truncates the barcode to 12 digits and appends the UPC-A (instead of EAN-13) type, before
         passing to the Operating System.
         
         The Operating System has no way to recognize that this UPC-A label that was passed to it by the scanner device
         was initially an EAN-13 label beginning with a zero.
         */
        let type = metadataObj.type
        if type == AVMetadataObject.ObjectType.ean13 && code.hasPrefix("0") {
            code = String(code.suffix(12))
//            type = AVMetadataObject.ObjectType.upca
        }
        
        if willSaveImage {
            captureImage(forCode: code, forType: type)
        } else {
            let item = ScannedItem(code: code, type: type, image: nil)
            animateFlash(whenProcessing: isOneTimeSearch)
            delegate?.barcodeScanner(self, didCaptureItem: item)
        }

        
    }
    
    
    

}

