import UIKit
import AVFoundation
import AVKit

class CameraController: UIViewController {

  var locationManager: LocationManager?
  lazy var cameraMan: CameraMan = self.makeCameraMan()
  lazy var cameraView: CameraView = self.makeCameraView()
  let once = Once()
  let cart: Cart

  // MARK: - Init

  public required init(cart: Cart) {
    self.cart = cart
    super.init(nibName: nil, bundle: nil)
    cart.delegates.add(self)
  }

  public required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Life cycle

  override func viewDidLoad() {
    super.viewDidLoad()

    setup()
    setupLocation()
    NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    locationManager?.start()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)

    if cameraMan.isVideoRecording{
      shutterButtonTouched(cameraView.shutterButton)
    }
    
    locationManager?.stop()
  }

  @objc fileprivate func didEnterBackground() {
    if cameraMan.isVideoRecording{
      shutterButtonTouched(cameraView.shutterButton)
    }
  }
  
  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    coordinator.animate(alongsideTransition: { _ in
      if let connection = self.cameraView.previewLayer?.connection,
        connection.isVideoOrientationSupported {
        connection.videoOrientation = Utils.videoOrientation()
      }
    }, completion: nil)

    super.viewWillTransition(to: size, with: coordinator)
  }

  // MARK: - Setup

  func setup() {
    view.addSubview(cameraView)
    cameraView.g_pinEdges()

    cameraView.closeButton.addTarget(self, action: #selector(closeButtonTouched(_:)), for: .touchUpInside)
    cameraView.flashButton.addTarget(self, action: #selector(flashButtonTouched(_:)), for: .touchUpInside)
    cameraView.rotateButton.addTarget(self, action: #selector(rotateButtonTouched(_:)), for: .touchUpInside)
    cameraView.stackView.addTarget(self, action: #selector(stackViewTouched(_:)), for: .touchUpInside)
    cameraView.shutterButton.addTarget(self, action: #selector(shutterButtonTouched(_:)), for: .touchUpInside)
    cameraView.doneButton.addTarget(self, action: #selector(doneButtonTouched(_:)), for: .touchUpInside)
    
    cameraView.videoBox.delegate = self
    cameraView.countdowLabel.delegate = self
  }

  func setupLocation() {
    if Config.Camera.recordLocation {
      locationManager = LocationManager()
    }
  }

  // MARK: - Action

  @objc func closeButtonTouched(_ button: UIButton) {
    EventHub.shared.close?()
  }

  @objc func flashButtonTouched(_ button: UIButton) {
    cameraView.flashButton.toggle()

    if let flashMode = AVCaptureDevice.FlashMode(rawValue: cameraView.flashButton.selectedIndex) {
      cameraMan.flash(flashMode)
    }
  }

  @objc func rotateButtonTouched(_ button: UIButton) {
    UIView.animate(withDuration: 0.3, animations: {
      self.cameraView.rotateOverlayView.alpha = 1
    }, completion: { _ in
      self.cameraMan.switchCamera {
        UIView.animate(withDuration: 0.7, animations: {
          self.cameraView.rotateOverlayView.alpha = 0
        }) 
      }
    })
  }

  @objc func stackViewTouched(_ stackView: StackView) {
    EventHub.shared.stackViewTouched?()
  }

  @objc func shutterButtonTouched(_ button: ShutterButton) {
    if(cameraView.selectedTab == .imageTab){
      guard isBelowImageLimit() || Config.Camera.imageLimit == 1 else { return }
      guard let previewLayer = cameraView.previewLayer else { return }
      
      button.isEnabled = false
      UIView.animate(withDuration: 0.1, animations: {
        self.cameraView.shutterOverlayView.alpha = 1
      }, completion: { _ in
        UIView.animate(withDuration: 0.1, animations: {
          self.cameraView.shutterOverlayView.alpha = 0
        })
      })

      self.cameraView.stackView.startLoading()
      cameraMan.takePhoto(previewLayer, location: locationManager?.latestLocation) { [weak self] asset in
        guard let strongSelf = self else {
          return
        }

        button.isEnabled = true
        strongSelf.cameraView.stackView.stopLoading()

        if let asset = asset {
          if Config.Camera.imageLimit == 1 && strongSelf.cart.images.count == 1{
            strongSelf.cart.remove(strongSelf.cart.images.first!)
          }
          strongSelf.cart.add(Image(asset: asset), newlyTaken: true)
        }
      }
    } else {
      if(cameraMan.isVideoRecording){
        [cameraView.rotateButton, cameraView.flashButton, cameraView.closeButton].forEach {
          $0.g_fade(visible: true)
        }
        cameraView.videoTopView.g_fade(visible: false)
        cameraView.countdowLabel.reset()
        
        cameraView.shutterButton.stopTakingVideo(animated: true)
        cameraMan.stopVideoRecording(location: locationManager?.latestLocation) { [weak self] asset in
          guard let strongSelf = self else {
            return
          }
          
          button.isEnabled = true
          
          if let asset = asset {
            strongSelf.cart.video = Video(asset: asset)
            strongSelf.refreshView()
          }
        }
      } else {
        [cameraView.rotateButton, cameraView.flashButton, cameraView.closeButton].forEach {
          $0.g_fade(visible: false)
        }
        cameraView.videoTopView.g_fade(visible: true)
        cameraView.countdowLabel.start()
        cameraView.shutterButton.startTakingVideo(animated: true)
        cameraMan.startVideoRecording()
      }
    }
  }
    
  @objc func doneButtonTouched(_ button: UIButton) {
    if(cameraView.selectedTab == .imageTab){
      EventHub.shared.doneWithImages?()
    } else if(cameraView.selectedTab == .videoTab){
      EventHub.shared.doneWithVideos?()
    }
  }
    
  fileprivate func isBelowImageLimit() -> Bool {
    return (Config.Camera.imageLimit == 0 || Config.Camera.imageLimit > cart.images.count)
    }
    
  // MARK: - View

  func refreshView() {
    if(cameraView.selectedTab == .imageTab){
      let hasImages = !cart.images.isEmpty
      cameraView.bottomView.g_fade(visible: hasImages)
    } else {
      if let capturedVideo = cart.video {
        cameraView.videoBox.imageView.g_loadImage(capturedVideo.asset)
      } else {
        cameraView.videoBox.imageView.image = nil
      }

      let hasVideo = (cart.video != nil)
      cameraView.bottomView.g_fade(visible: hasVideo)
    }
  }

  // MARK: - Controls

  func makeCameraMan() -> CameraMan {
    let man = CameraMan()
    man.delegate = self

    return man
  }

  func makeCameraView() -> CameraView {
    let view = CameraView()
    view.delegate = self

    return view
  }
}

extension CameraController: CartDelegate {

  func cart(_ cart: Cart, didAdd image: Image, newlyTaken: Bool) {
    cameraView.stackView.reload(cart.images, added: true)
    refreshView()
  }

  func cart(_ cart: Cart, didRemove image: Image) {
    cameraView.stackView.reload(cart.images)
    refreshView()
  }

  func cartDidReload(_ cart: Cart) {
    cameraView.stackView.reload(cart.images)
    refreshView()
  }
}

extension CameraController: PageAware {

  func pageDidShow() {
    once.run {
      cameraMan.setup()
    }
  }
}

extension CameraController: CameraViewDelegate {

  func cameraView(_ cameraView: CameraView, didTouch point: CGPoint) {
    cameraMan.focus(point)
  }
  
  func cameraView(_ cameraView: CameraView, didPinch pinchScale: CGFloat) {
    cameraMan.zoom(pinchScale)
  }
  
  func cameraViewDidBeginZoom(_ cameraView: CameraView) {
    cameraMan.beginZoom()
  }
  
  func cameraView(_ cameraView: CameraView, didSwitch tab: Config.Camera.CameraTab) {
    refreshView()
  }
}

extension CameraController: CameraManDelegate {

  func cameraManDidStart(_ cameraMan: CameraMan) {
    cameraView.setupPreviewLayer(cameraMan.session)
  }

  func cameraManNotAvailable(_ cameraMan: CameraMan) {
    cameraView.focusImageView.isHidden = true
  }

  func cameraMan(_ cameraMan: CameraMan, didChangeInput input: AVCaptureDeviceInput) {
    cameraView.flashButton.isHidden = !input.device.hasFlash
  }

}

extension CameraController: VideoBoxDelegate {
  
  func videoBoxDidTap(_ videoBox: VideoBox) {
    cart.video?.fetchPlayerItem { item in
      guard let item = item else { return }
      
      DispatchQueue.main.async {
        let controller = AVPlayerViewController()
        let player = AVPlayer(playerItem: item)
        controller.player = player
        
        self.present(controller, animated: true) {
          player.play()
        }
      }
    }
  }
}

extension CameraController: CountdownLabelDelegate{
  
  func countdownLabelReachedLimit(_ countdownLabel: CountdownLabel) {
    shutterButtonTouched(cameraView.shutterButton)
  }
}

