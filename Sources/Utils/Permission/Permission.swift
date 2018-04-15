import Foundation
import Photos
import AVFoundation

struct Permission {

  enum Status {
    case notDetermined
    case restricted
    case denied
    case authorized
  }

  struct Photos {
    static var status: Status {
      switch PHPhotoLibrary.authorizationStatus() {
      case .notDetermined:
        return .notDetermined
      case .restricted:
        return .restricted
      case .denied:
        return .denied
      case .authorized:
        return .authorized
      }
    }

    static func request(_ completion: @escaping () -> Void) {
      PHPhotoLibrary.requestAuthorization { status in
        completion()
      }
    }
  }

  struct Camera {
    static var needsPermission: Bool {
      return Config.tabsToShow.index(of: .cameraTab) != nil
    }
    
    static var needsMicrophonePermission: Bool {
      return Config.Camera.tabsToShow.index(of: .videoTab) != nil
    }

    static var status: Status {
      switch AVCaptureDevice.authorizationStatus(for: .video) {
      case .notDetermined:
        return .notDetermined
      case .restricted:
        return .restricted
      case .denied:
        return .denied
      case .authorized:
        return .authorized
      }
    }
    
    static var microphoneStatus: Status {
      switch AVCaptureDevice.authorizationStatus(for: .audio) {
      case .notDetermined:
        return .notDetermined
      case .restricted:
        return .restricted
      case .denied:
        return .denied
      case .authorized:
        return .authorized
      }
    }

    static func request(_ completion: @escaping () -> Void) {
      AVCaptureDevice.requestAccess(for: .video) { granted in
        if needsMicrophonePermission {
          AVCaptureDevice.requestAccess(for: .audio) { granted in
            completion()
          }
        } else {
          completion()
        }
      }
    }
  }
}
