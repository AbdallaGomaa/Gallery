import UIKit
import AVFoundation

protocol CameraViewDelegate: class {
  func cameraView(_ cameraView: CameraView, didTouch point: CGPoint)
  func cameraView(_ cameraView: CameraView, didPinch pinchScale: CGFloat)
  func cameraViewDidBeginZoom(_ cameraView: CameraView)
  func cameraView(_ cameraView: CameraView, didSwitch tab: Config.Camera.CameraTab)
}

class CameraView: UIView, UIGestureRecognizerDelegate {

  lazy var closeButton: UIButton = self.makeCloseButton()
  lazy var flashButton: TripleButton = self.makeFlashButton()
  lazy var rotateButton: UIButton = self.makeRotateButton()
  fileprivate lazy var bottomContainer: UIView = self.makeBottomContainer()
  lazy var bottomView: UIView = self.makeBottomView()
  lazy var stackView: StackView = self.makeStackView()
  lazy var shutterButton: ShutterButton = self.makeShutterButton()
  lazy var doneButton: UIButton = self.makeDoneButton()
  lazy var focusImageView: UIImageView = self.makeFocusImageView()
  lazy var tapGR: UITapGestureRecognizer = self.makeTapGR()
  lazy var pinchGR: UIPinchGestureRecognizer = self.makePinchGR()
  lazy var rotateOverlayView: UIView = self.makeRotateOverlayView()
  lazy var shutterOverlayView: UIView = self.makeShutterOverlayView()
  lazy var blurView: UIVisualEffectView = self.makeBlurView()
  lazy var pageIndicator: PageIndicator = self.makePageIndicator()
  lazy var videoTopView: UIView = self.makeVideoTopView()
  lazy var countdowLabel: CountdownLabel = self.makeCountdowLabel()
  lazy var videoBox: VideoBox = self.makeVideoBox()
  
  var timer: Timer?
  var previewLayer: AVCaptureVideoPreviewLayer?
  weak var delegate: CameraViewDelegate?
  var selectedTab: Config.Camera.CameraTab = .imageTab

  // MARK: - Initialization

  override init(frame: CGRect) {
    super.init(frame: frame)

    backgroundColor = UIColor.black
    setup()
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Setup

  func setup() {
    addGestureRecognizer(tapGR)
    addGestureRecognizer(pinchGR)

    [closeButton, flashButton, rotateButton, bottomContainer, videoTopView].forEach {
      addSubview($0)
    }

    [bottomView, shutterButton].forEach {
      bottomContainer.addSubview($0)
    }

    [stackView, doneButton, videoBox].forEach {
      bottomView.addSubview($0 as! UIView)
    }

    [closeButton, flashButton, rotateButton].forEach {
      $0.g_addShadow()
    }

    rotateOverlayView.addSubview(blurView)
    insertSubview(rotateOverlayView, belowSubview: rotateButton)
    insertSubview(focusImageView, belowSubview: bottomContainer)
    insertSubview(shutterOverlayView, belowSubview: bottomContainer)

    videoTopView.addSubview(countdowLabel)
    
    videoTopView.g_pinUpward()
    videoTopView.g_pin(height: 44)
    
    countdowLabel.g_pin(on: .centerX)
    countdowLabel.g_pin(on: .centerY)
    
    closeButton.g_pin(on: .left)
    closeButton.g_pin(size: CGSize(width: 44, height: 44))

    flashButton.g_pin(on: .centerY, view: closeButton)
    flashButton.g_pin(on: .centerX)
    flashButton.g_pin(size: CGSize(width: 60, height: 44))

    rotateButton.g_pin(on: .right)
    rotateButton.g_pin(size: CGSize(width: 44, height: 44))

    let usePageIndicator = Config.Camera.tabsToShow.count > 1
    if usePageIndicator {
      addSubview(pageIndicator)
      Constraint.on(
        pageIndicator.leftAnchor.constraint(equalTo: pageIndicator.superview!.leftAnchor),
        pageIndicator.rightAnchor.constraint(equalTo: pageIndicator.superview!.rightAnchor),
        pageIndicator.heightAnchor.constraint(equalToConstant: 40),
        pageIndicator.bottomAnchor.constraint(equalTo: pageIndicator.superview!.bottomAnchor)
      )
    }

    if #available(iOS 11, *) {
      Constraint.on(
        closeButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
        rotateButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor)
      )
    } else {
      Constraint.on(
        closeButton.topAnchor.constraint(equalTo: topAnchor),
        rotateButton.topAnchor.constraint(equalTo: topAnchor)
      )
    }

    if(usePageIndicator){
      bottomContainer.g_pin(on: .bottom, view: pageIndicator, on: .top)
      bottomContainer.g_pin(on: .left)
      bottomContainer.g_pin(on: .right)
    } else {
      bottomContainer.g_pinDownward()
    }
    bottomContainer.g_pin(height: 80)
    bottomView.g_pinEdges()
    
    stackView.g_pin(on: .centerY, constant: -4)
    stackView.g_pin(on: .left, constant: 38)
    stackView.g_pin(size: CGSize(width: 56, height: 56))

    videoBox.g_pin(size: CGSize(width: 44, height: 44))
    videoBox.g_pin(on: .centerY)
    videoBox.g_pin(on: .left, constant: 38)

    shutterButton.g_pinCenter()
    shutterButton.g_pin(size: CGSize(width: 60, height: 60))
    
    doneButton.g_pin(on: .centerY)
    doneButton.g_pin(on: .right, constant: -38)

    rotateOverlayView.g_pinEdges()
    blurView.g_pinEdges()
    shutterOverlayView.g_pinEdges()
  }

  func setupPreviewLayer(_ session: AVCaptureSession) {
    guard previewLayer == nil else { return }

    let layer = AVCaptureVideoPreviewLayer(session: session)
    layer.autoreverses = true
    layer.videoGravity = .resizeAspectFill

    self.layer.insertSublayer(layer, at: 0)
    layer.frame = self.layer.bounds

    previewLayer = layer
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    previewLayer?.frame = self.layer.bounds
  }

  // MARK: - Action

  @objc func viewTapped(_ gr: UITapGestureRecognizer) {
    let point = gr.location(in: self)

    focusImageView.transform = CGAffineTransform.identity
    timer?.invalidate()
    delegate?.cameraView(self, didTouch: point)

    focusImageView.center = point

    UIView.animate(withDuration: 0.5, animations: {
      self.focusImageView.alpha = 1
      self.focusImageView.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
    }, completion: { _ in
      self.timer = Timer.scheduledTimer(timeInterval: 1, target: self,
        selector: #selector(CameraView.timerFired(_:)), userInfo: nil, repeats: false)
    })
  }
  
  @objc func viewZoomed(pinch: UIPinchGestureRecognizer) {
    delegate?.cameraView(self, didPinch: pinch.scale)
  }

  // MARK: - Timer

  @objc func timerFired(_ timer: Timer) {
    UIView.animate(withDuration: 0.3, animations: {
      self.focusImageView.alpha = 0
    }, completion: { _ in
      self.focusImageView.transform = CGAffineTransform.identity
    })
  }

  // MARK: - UIGestureRecognizerDelegate
  override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    if gestureRecognizer.isKind(of: UITapGestureRecognizer.self) {
      let point = gestureRecognizer.location(in: self)

      return point.y > closeButton.frame.maxY
        && point.y < bottomContainer.frame.origin.y
    } else if gestureRecognizer.isKind(of: UIPinchGestureRecognizer.self) {
      delegate?.cameraViewDidBeginZoom(self)
      return true
    }
    
    return false
  }

  // MARK: - Controls

  func makeCloseButton() -> UIButton {
    let button = UIButton(type: .custom)
    button.setImage(GalleryBundle.image("gallery_close"), for: UIControlState())

    return button
  }

  func makeFlashButton() -> TripleButton {
    let states: [TripleButton.State] = [
      TripleButton.State(title: "Gallery.Camera.Flash.Off".g_localize(fallback: "OFF"), image: GalleryBundle.image("gallery_camera_flash_off")!),
      TripleButton.State(title: "Gallery.Camera.Flash.On".g_localize(fallback: "ON"), image: GalleryBundle.image("gallery_camera_flash_on")!),
      TripleButton.State(title: "Gallery.Camera.Flash.Auto".g_localize(fallback: "AUTO"), image: GalleryBundle.image("gallery_camera_flash_auto")!)
    ]

    let button = TripleButton(states: states)

    return button
  }

  func makeRotateButton() -> UIButton {
    let button = UIButton(type: .custom)
    button.setImage(GalleryBundle.image("gallery_camera_rotate"), for: UIControlState())

    return button
  }

  func makeBottomContainer() -> UIView {
    let view = UIView()

    return view
  }

  func makeBottomView() -> UIView {
    let view = UIView()
    view.backgroundColor = Config.Camera.BottomContainer.backgroundColor
    view.alpha = 0

    return view
  }

  func makeStackView() -> StackView {
    let view = StackView()

    return view
  }

  func makeShutterButton() -> ShutterButton {
    let button = ShutterButton()
    button.g_addShadow()

    return button
  }

  func makeDoneButton() -> UIButton {
    let button = UIButton(type: .system)
    button.setTitleColor(UIColor.white, for: UIControlState())
    button.setTitleColor(UIColor.lightGray, for: .disabled)
    button.titleLabel?.font = Config.Font.Text.regular.withSize(16)
    button.setTitle("Gallery.Done".g_localize(fallback: "Done"), for: UIControlState())

    return button
  }

  func makeFocusImageView() -> UIImageView {
    let view = UIImageView()
    view.frame.size = CGSize(width: 110, height: 110)
    view.image = GalleryBundle.image("gallery_camera_focus")
    view.backgroundColor = .clear
    view.alpha = 0

    return view
  }

  func makeTapGR() -> UITapGestureRecognizer {
    let gr = UITapGestureRecognizer(target: self, action: #selector(viewTapped(_:)))
    gr.delegate = self

    return gr
  }
  
  func makePinchGR() -> UIPinchGestureRecognizer {
    let gr = UIPinchGestureRecognizer(target: self, action: #selector(viewZoomed(pinch:)))
    gr.delegate = self
    
    return gr
  }

  func makeRotateOverlayView() -> UIView {
    let view = UIView()
    view.alpha = 0

    return view
  }

  func makeShutterOverlayView() -> UIView {
    let view = UIView()
    view.alpha = 0
    view.backgroundColor = UIColor.black

    return view
  }

  func makeBlurView() -> UIVisualEffectView {
    let effect = UIBlurEffect(style: .dark)
    let blurView = UIVisualEffectView(effect: effect)

    return blurView
  }
  
  func makePageIndicator() -> PageIndicator {
    let items = ["Gallery.Videos.Camera.Photo.Title".g_localize(fallback: "PHOTO"),
                 "Gallery.Videos.Camera.Video.Title".g_localize(fallback: "VIDEO")]
    let indicator = PageIndicator(items: items)
    indicator.delegate = self
    
    return indicator
  }
  
  func makeVideoTopView() -> UIView {
    let view = UIView()
    view.alpha = 0
    view.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.3)
    
    return view
  }
  
  func makeCountdowLabel() -> CountdownLabel {
    let label = CountdownLabel()
    label.textColor = UIColor.white
    label.font = UIFont.systemFont(ofSize: 20)
    label.timeLimit = Config.VideoEditor.maximumDuration
    
    return label
  }
  
  func makeVideoBox() -> VideoBox {
    let videoBox = VideoBox()
    videoBox.alpha = 0
    
    return videoBox
  }
}

extension CameraView: PageIndicatorDelegate {
  func pageIndicator(_ pageIndicator: PageIndicator, didSelect index: Int) {
    selectedTab = Config.Camera.tabsToShow[index]
    if(selectedTab == .imageTab){
      shutterButton.switchToImage()
      videoBox.alpha = 0
      stackView.alpha = 1
    } else {
      shutterButton.switchToVideo()
      videoBox.alpha = 1
      stackView.alpha = 0
    }
    
    delegate?.cameraView(self, didSwitch: selectedTab)
  }
}
