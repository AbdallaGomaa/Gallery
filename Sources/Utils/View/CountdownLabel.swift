//
//  CountdownLabel.swift
//  Cache
//
//  Created by Abdallah Walid on 2018-04-14.
//

import UIKit

protocol CountdownLabelDelegate: class {
  func countdownLabelReachedLimit(_ countdownLabel: CountdownLabel)
}


class CountdownLabel : UILabel {
  
  private var timer: Timer?
  private var startDate: Date?
  private lazy var dateFormatter: DateFormatter! = self.makeDateFormatter()
  private var date1970: Date!
  public var timeLimit: TimeInterval!
  
  weak var delegate: CountdownLabelDelegate?

  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    self.setup()
  }
  
  override func removeFromSuperview() {
    if timer != nil {
      timer?.invalidate()
      timer = nil
    }
    
    super.removeFromSuperview()
  }
  
  private func setup(){
    date1970 = Date(timeIntervalSince1970: 0)
    updateLabel()
  }
  
  public func start(){
    timer?.invalidate()
    timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(updateLabel), userInfo: nil, repeats: true)
    RunLoop.current.add(timer!, forMode: .commonModes)
    startDate = Date()
    timer?.fire()
  }
  
  public func reset(){
    startDate = nil
    updateLabel()
  }
  
  @objc private func updateLabel(){
    guard let startDate = startDate else {
      self.text = "00:00:00"
      return
    }
    let timeDifference: TimeInterval = Date().timeIntervalSince(startDate)
    let timeToShow: Date = date1970.addingTimeInterval(timeDifference)
    self.text = dateFormatter.string(from: timeToShow)
    
    if(timeLimit != 0 && timeDifference >= timeLimit){
      delegate?.countdownLabelReachedLimit(self)
    }
  }
  
  // MARK: - Controls
  func makeDateFormatter() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.timeZone = TimeZone(identifier: "GMT")
    formatter.dateFormat = "HH:mm:ss"
    return formatter
  }
  
}
