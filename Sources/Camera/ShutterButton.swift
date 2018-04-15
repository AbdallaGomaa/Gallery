import UIKit

class ShutterButton: UIButton {
  
  lazy var roundLayer: CAShapeLayer = self.makeRoundLayer()
  lazy var squareLayer: CAShapeLayer = self.makeSquareLayer()
  lazy var circleLayer: CAShapeLayer = self.makeCircleLayer()
  // Stores and sets the animation
  var layerAnimation = CABasicAnimation(keyPath: "path")
  
  var isVideo: Bool = false
  // MARK: - Initialization
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    
    setup()
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Layout
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    let squareFrame = bounds.insetBy(dx: 15, dy: 15)
    let square = squarePathWithCenter(origin: squareFrame.origin, side: squareFrame.size.width, cornerRadius: 5)
    squareLayer.path = square.cgPath
    
    let circleFrame = bounds.insetBy(dx: 3, dy: 3)
    let circle = squarePathWithCenter(origin: circleFrame.origin, side: circleFrame.size.width, cornerRadius: circleFrame.size.width/2)
    circleLayer.path = circle.cgPath
    
    roundLayer.path = UIBezierPath(ovalIn: bounds).cgPath
    layer.cornerRadius = bounds.size.width/2
  }
  
  // MARK: - Setup
  
  func setup() {
    backgroundColor = UIColor.clear
    
    // Setup animation values that dont change
    layerAnimation.duration = 0.5
    // Sets the animation style. You can change these to see how it will affect the animations.
    layerAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
    layerAnimation.fillMode = kCAFillModeForwards
    // Dont remove the shape when the animation has been completed
    layerAnimation.isRemovedOnCompletion = false
    
    layer.addSublayer(circleLayer)
    layer.addSublayer(roundLayer)
  }
  
  func switchToVideo(){
    circleLayer.fillColor = UIColor.red.cgColor
    isVideo = true
  }
  
  func startTakingVideo(animated: Bool){
    layerAnimation.fromValue = circleLayer.path
    layerAnimation.toValue = squareLayer.path
    self.circleLayer.add(layerAnimation, forKey: "animatePath");
  }
  
  func stopTakingVideo(animated: Bool){
    layerAnimation.fromValue = squareLayer.path
    layerAnimation.toValue = circleLayer.path
    self.circleLayer.add(layerAnimation, forKey: "animatePath");
  }
  
  func switchToImage(){
    circleLayer.fillColor = UIColor.white.cgColor
    isVideo = false
  }
  
  func squarePathWithCenter(origin: CGPoint, side: CGFloat, cornerRadius: CGFloat) -> UIBezierPath {
    let path = UIBezierPath()
    let startX = origin.x
    let startY = origin.y
    
    path.addArc(withCenter:CGPoint(x: startX+side-cornerRadius, y: startY+side-cornerRadius), radius:cornerRadius, startAngle:0, endAngle: CGFloat(Double.pi/2), clockwise: true)
    path.addArc(withCenter:CGPoint(x:startX+cornerRadius, y:startY+side-cornerRadius), radius:cornerRadius, startAngle:CGFloat(Double.pi/2), endAngle:CGFloat(Double.pi), clockwise: true)// 2rd rounded corner
    path.addArc(withCenter:CGPoint(x: startX+cornerRadius, y:startY+cornerRadius), radius:cornerRadius, startAngle:CGFloat(Double.pi), endAngle:CGFloat(3 * Double.pi / 2), clockwise: true)// 3rd rounded corner
    path.addArc(withCenter:CGPoint(x: startX+side-cornerRadius, y: startY+cornerRadius), radius: cornerRadius, startAngle: CGFloat(3 * Double.pi / 2), endAngle: CGFloat(2 * Double.pi ), clockwise: true)
    path.close()
    return path
  }
  
  
  // MARK: - Controls
  func makeSquareLayer() -> CAShapeLayer {
    let layer = CAShapeLayer()
    layer.fillColor = UIColor.white.cgColor
    
    return layer
  }
  
  func makeCircleLayer() -> CAShapeLayer {
    let layer = CAShapeLayer()
    layer.fillColor = UIColor.white.cgColor
    
    return layer
  }
  
  func makeRoundLayer() -> CAShapeLayer {
    let layer = CAShapeLayer()
    layer.strokeColor = UIColor.white.cgColor
    layer.lineWidth = 2
    layer.fillColor = nil
    
    return layer
  }
  
  // MARK: - Highlight
  
  override var isHighlighted: Bool {
    didSet {
      circleLayer.fillColor = isHighlighted ? UIColor.gray.cgColor : isVideo ? UIColor.red.cgColor : UIColor.white.cgColor
    }
  }
}
