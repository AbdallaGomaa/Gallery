import Foundation
import AVFoundation
import PhotosUI
import Photos

protocol CameraManDelegate: class {
  func cameraManNotAvailable(_ cameraMan: CameraMan)
  func cameraManDidStart(_ cameraMan: CameraMan)
  func cameraMan(_ cameraMan: CameraMan, didChangeInput input: AVCaptureDeviceInput)
}

class CameraMan: NSObject {
  weak var delegate: CameraManDelegate?

  let session = AVCaptureSession()
  let queue = DispatchQueue(label: "no.hyper.Gallery.Camera.SessionQueue", qos: .background)
  let savingQueue = DispatchQueue(label: "no.hyper.Gallery.Camera.SavingQueue", qos: .background)

  var backCamera: AVCaptureDeviceInput?
  var frontCamera: AVCaptureDeviceInput?
  var audioDeviceInput: AVCaptureDeviceInput?
  var stillImageOutput: AVCaptureStillImageOutput?
  var movieFileOutput: AVCaptureMovieFileOutput?
  var backgroundRecordingID: UIBackgroundTaskIdentifier? = nil
  var isVideoRecording = false
  var locationToSaveVideo: CLLocation?
  var videoCompletion:  ((PHAsset?) -> Void)?
  
  fileprivate var zoomScale = CGFloat(1.0)
  fileprivate var startingZoomScale = CGFloat(1.0)

  deinit {
    stop()
  }

  // MARK: - Setup

  func setup() {
    if Permission.Camera.status == .authorized {
      self.start()
    } else {
      self.delegate?.cameraManNotAvailable(self)
    }
  }

  func setupDevices() {
    // Input
    AVCaptureDevice
      .devices()
      .filter {
        return $0.hasMediaType(.video)
      }.forEach {
        switch $0.position {
        case .front:
          self.frontCamera = try? AVCaptureDeviceInput(device: $0)
        case .back:
          self.backCamera = try? AVCaptureDeviceInput(device: $0)
        default:
          break
        }
    }
    
    let audioDevice = AVCaptureDevice.default(for: .audio)
    self.audioDeviceInput = try? AVCaptureDeviceInput(device: audioDevice!)

    // Output
    stillImageOutput = AVCaptureStillImageOutput()
    stillImageOutput?.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
    
    movieFileOutput = AVCaptureMovieFileOutput()
  }

  func addInput(_ input: AVCaptureDeviceInput) {
    configurePreset(input)

    if session.canAddInput(input) {
      session.addInput(input)

      DispatchQueue.main.async {
        self.delegate?.cameraMan(self, didChangeInput: input)
      }
    }
  }

  // MARK: - Session

  var currentInput: AVCaptureDeviceInput? {
    return session.inputs.first as? AVCaptureDeviceInput
  }

  fileprivate func start() {
    // Devices
    setupDevices()

    guard let input = backCamera, let output = stillImageOutput, let videoOutput = movieFileOutput, let audioInput = audioDeviceInput else { return }

    addInput(input)
    if session.canAddInput(audioInput) {
      session.addInput(audioInput)
    }

    if session.canAddOutput(output) {
      session.addOutput(output)
    }
    
    if session.canAddOutput(videoOutput) {
      session.addOutput(videoOutput)
      if let connection = videoOutput.connection(with: AVMediaType.video) {
        if connection.isVideoStabilizationSupported {
          connection.preferredVideoStabilizationMode = .auto
        }
      }
    }
    
    queue.async {
      self.session.startRunning()

      DispatchQueue.main.async {
        self.delegate?.cameraManDidStart(self)
      }
    }
  }

  func stop() {
    self.session.stopRunning()
  }

  func switchCamera(_ completion: (() -> Void)? = nil) {
    guard isVideoRecording != true else {
        //TODO: Look into switching camera during video recording
        print("[Gallery]: Switching between cameras while recording video is not supported")
        completion?()
        return
    }

    guard let currentInput = currentInput
      else {
        completion?()
        return
    }

    queue.async {
      guard let input = (currentInput == self.backCamera) ? self.frontCamera : self.backCamera
        else {
          DispatchQueue.main.async {
            completion?()
          }
          return
      }

      self.configure {
        self.session.removeInput(currentInput)
        self.addInput(input)
      }

      DispatchQueue.main.async {
        completion?()
      }
    }
  }

  func takePhoto(_ previewLayer: AVCaptureVideoPreviewLayer, location: CLLocation?, completion: @escaping ((PHAsset?) -> Void)) {
    guard let connection = stillImageOutput?.connection(with: .video) else { return }

    connection.videoOrientation = Utils.videoOrientation()

    queue.async {
      self.stillImageOutput?.captureStillImageAsynchronously(from: connection) {
        buffer, error in

        guard error == nil, let buffer = buffer, CMSampleBufferIsValid(buffer),
          let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(buffer),
          let image = UIImage(data: imageData)
          else {
            DispatchQueue.main.async {
              completion(nil)
            }
            return
        }

        self.savePhoto(image, location: location, completion: completion)
      }
    }
  }
    
  func startVideoRecording() {
    guard let movieFileOutput = self.movieFileOutput else {
      return
    }
    
    queue.async { [unowned self] in
      if !movieFileOutput.isRecording {
        if UIDevice.current.isMultitaskingSupported {
          self.backgroundRecordingID = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
        }
            
        // Update the orientation on the movie file output video connection before starting recording.
        let movieFileOutputConnection = self.movieFileOutput?.connection(with: AVMediaType.video)
        
        guard let connection = self.movieFileOutput?.connection(with: .video) else { return }
        
        
        //flip video output if front facing camera is selected
        if self.currentInput == self.frontCamera {
          movieFileOutputConnection?.isVideoMirrored = true
        }
        
        connection.videoOrientation = Utils.videoOrientation()
        
        // Start recording to a temporary file.
        let outputFileName = UUID().uuidString
        let outputFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((outputFileName as NSString).appendingPathExtension("mov")!)
        movieFileOutput.startRecording(to: URL(fileURLWithPath: outputFilePath), recordingDelegate: self)
        self.isVideoRecording = true
      } else {
        movieFileOutput.stopRecording()
      }
    }
  }
    
  func stopVideoRecording(location: CLLocation?, completion: @escaping ((PHAsset?) -> Void)) {
    if self.movieFileOutput?.isRecording == true {
      self.isVideoRecording = false
      movieFileOutput!.stopRecording()
        
      locationToSaveVideo = location
      videoCompletion = completion
    } else {
      completion(nil)
    }
  }

  func savePhoto(_ image: UIImage, location: CLLocation?, completion: @escaping ((PHAsset?) -> Void)) {
    var localIdentifier: String?

    savingQueue.async {
      do {
        try PHPhotoLibrary.shared().performChangesAndWait {
          let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
          localIdentifier = request.placeholderForCreatedAsset?.localIdentifier

          request.creationDate = Date()
          request.location = location
        }

        DispatchQueue.main.async {
          if let localIdentifier = localIdentifier {
            completion(Fetcher.fetchAsset(localIdentifier))
          } else {
            completion(nil)
          }
        }
      } catch {
        DispatchQueue.main.async {
          completion(nil)
        }
      }
    }
  }

  func saveVideo(_ videoURL: URL, location: CLLocation?, completion: @escaping ((PHAsset?) -> Void)) {
    var localIdentifier: String?
    
    savingQueue.async {
      do {
        try PHPhotoLibrary.shared().performChangesAndWait {
        guard let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL) else { return }
        localIdentifier = request.placeholderForCreatedAsset?.localIdentifier
                
        request.creationDate = Date()
        request.location = location
      }
            
        DispatchQueue.main.async {
          if let localIdentifier = localIdentifier {
            completion(Fetcher.fetchAsset(localIdentifier))
          } else {
            completion(nil)
          }
        }
      } catch {
        DispatchQueue.main.async {
          completion(nil)
        }
      }
    }
  }

  func flash(_ mode: AVCaptureDevice.FlashMode) {
    guard let device = currentInput?.device , device.isFlashModeSupported(mode) else { return }

    queue.async {
      self.lock {
        device.flashMode = mode
      }
    }
  }

  func focus(_ point: CGPoint) {
    guard let device = currentInput?.device , device.isFocusModeSupported(AVCaptureDevice.FocusMode.locked) else { return }

    queue.async {
      self.lock {
        device.focusPointOfInterest = point
      }
    }
  }
  
  func beginZoom(){
    startingZoomScale = zoomScale
  }
  
  func zoom(_ scale: CGFloat) {
    guard Config.Camera.zoomAllowed == true && currentInput == self.backCamera else {
      //ignore pinch
      return
    }
    
    do {
      guard let device = currentInput?.device else { return }
      try device.lockForConfiguration()
      
      zoomScale = min(Config.Camera.maxZoomScale, max(1.0, min(startingZoomScale * scale,  device.activeFormat.videoMaxZoomFactor)))

      device.videoZoomFactor = zoomScale
      
      device.unlockForConfiguration()
      
    } catch {
      print("[Gallery]: Error locking configuration")
    }

  }

  // MARK: - Lock

  func lock(_ block: () -> Void) {
    if let device = currentInput?.device , (try? device.lockForConfiguration()) != nil {
      block()
      device.unlockForConfiguration()
    }
  }

  // MARK: - Configure
  func configure(_ block: () -> Void) {
    session.beginConfiguration()
    block()
    session.commitConfiguration()
  }

  // MARK: - Preset

  func configurePreset(_ input: AVCaptureDeviceInput) {
    for asset in preferredPresets() {
      if input.device.supportsSessionPreset(asset) && self.session.canSetSessionPreset(asset) {
        self.session.sessionPreset = asset
        return
      }
    }
  }

  func preferredPresets() -> [AVCaptureSession.Preset] {
    return [
      .high,
      .medium,
      .low
    ]
  }
}

extension CameraMan : AVCaptureFileOutputRecordingDelegate {
  func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
    if let currentBackgroundRecordingID = backgroundRecordingID {
      backgroundRecordingID = UIBackgroundTaskInvalid
        
      if currentBackgroundRecordingID != UIBackgroundTaskInvalid {
        UIApplication.shared.endBackgroundTask(currentBackgroundRecordingID)
      }
    }
    if error != nil {
      videoCompletion?(nil)
      videoCompletion = nil
    } else {
      self.saveVideo(outputFileURL, location: locationToSaveVideo, completion: videoCompletion!)
      videoCompletion = nil
    }
  }
}
