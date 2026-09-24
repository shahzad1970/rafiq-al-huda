import CoreLocation
import Flutter
import UIKit

/// Optional foreground-only setup. No background tracking or location history.
final class PrayerLocationService: NSObject, CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  private let geocoder = CLGeocoder()
  private let channel: FlutterMethodChannel
  private var pending: FlutterResult?
  private var requestID = UUID()
  private var locating = false
  private var timeout: Timer?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "org.quranteacher/prayer-location", binaryMessenger: messenger)
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyKilometer
    NotificationCenter.default.addObserver(self, selector: #selector(backgrounded),
      name: UIApplication.didEnterBackgroundNotification, object: nil)
    channel.setMethodCallHandler { [weak self] call, result in self?.handle(call, result) }
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    if call.method == "cancel" { cancel(); result(nil); return }
    guard call.method == "locate" || call.method == "search" else { result(FlutterMethodNotImplemented); return }
    guard pending == nil else { result(error("busy", "A location request is already running.")); return }
    requestID = UUID()
    let id = requestID
    pending = result
    timeout = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
      guard let self else { return }
      self.finish(self.error("timeout", "Location timed out. Choose an offline city or enter coordinates."))
    }
    if call.method == "locate" {
      locating = true
      if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
      else { requestAuthorizedLocation() }
    } else {
      let query = (call.arguments as? [String: Any])?["query"] as? String ?? ""
      guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, query.count <= 200 else {
        finish(error("query", "Enter a city and country.")); return
      }
      geocoder.geocodeAddressString(query) { [weak self] places, _ in
        DispatchQueue.main.async {
          guard let self, self.pending != nil, self.requestID == id else { return }
          guard let place = places?.first, let location = place.location, let zone = place.timeZone else {
            self.finish(self.error("not_found", "City not found. Search needs internet; try a city and country, or choose an offline city.")); return
          }
          let name = [place.locality ?? place.name, place.administrativeArea, place.country]
            .compactMap { $0 }.joined(separator: ", ")
          self.finish(self.value(location, name: name.isEmpty ? query : name, zone: zone.identifier))
        }
      }
    }
  }

  private func requestAuthorizedLocation() {
    guard locating, pending != nil else { return }
    switch manager.authorizationStatus {
    case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
    case .denied, .restricted:
      finish(error("permission", "Location access is off. Choose a city, or enable location for this app in iPhone Settings."))
    case .notDetermined: break
    @unknown default: finish(error("permission", "Location is unavailable. Choose a city instead."))
    }
  }
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { requestAuthorizedLocation() }
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard locating, pending != nil else { return }
    guard let location = locations.last, location.horizontalAccuracy >= 0,
      abs(location.timestamp.timeIntervalSinceNow) <= 300 else {
      finish(error("stale", "A recent location could not be obtained. Please try again.")); return
    }
    finish(value(location, name: "Current location", zone: TimeZone.current.identifier))
  }
  func locationManager(_ manager: CLLocationManager, didFailWithError failure: Error) {
    guard locating else { return }
    finish(error("location", "Could not determine location. Choose an offline city or enter coordinates."))
  }
  private func value(_ location: CLLocation, name: String, zone: String) -> [String: Any] {
    ["name": name, "latitude": location.coordinate.latitude, "longitude": location.coordinate.longitude, "zone": zone]
  }
  private func error(_ code: String, _ message: String) -> FlutterError { FlutterError(code: code, message: message, details: nil) }
  private func finish(_ value: Any?) {
    let callback = pending
    pending = nil
    locating = false
    requestID = UUID()
    timeout?.invalidate(); timeout = nil
    manager.stopUpdatingLocation()
    geocoder.cancelGeocode()
    callback?(value)
  }
  private func cancel() { finish(error("cancelled", "Location request cancelled.")) }
  @objc private func backgrounded() { cancel() }
  deinit { NotificationCenter.default.removeObserver(self); timeout?.invalidate() }
}

/// Foreground-only true-north compass. Independent of one-shot prayer setup.
final class QiblaCompassService: NSObject, FlutterStreamHandler, CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  private let channel: FlutterEventChannel
  private var sink: FlutterEventSink?
  private var location: CLLocation?
  private var lastEmit: TimeInterval = 0
  private var active = false

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterEventChannel(name: "org.quranteacher/qibla", binaryMessenger: messenger)
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    manager.distanceFilter = kCLDistanceFilterNone
    manager.pausesLocationUpdatesAutomatically = false
    // Continue callbacks while stationary so stale detection can be meaningful.
    manager.headingFilter = kCLHeadingFilterNone
    channel.setStreamHandler(self)
    NotificationCenter.default.addObserver(self, selector: #selector(backgrounded),
      name: UIApplication.didEnterBackgroundNotification, object: nil)
  }
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    stop(); sink = events; active = true; lastEmit = 0
    guard CLLocationManager.headingAvailable() else {
      status("This device has no compass. Use a physical iPhone."); return nil
    }
    if manager.authorizationStatus == .notDetermined {
      status("Allow location access to calculate true north.")
      manager.requestWhenInUseAuthorization()
    } else { startAuthorized() }
    return nil
  }
  func onCancel(withArguments arguments: Any?) -> FlutterError? { stop(); sink = nil; return nil }
  private func startAuthorized() {
    guard active, CLLocationManager.headingAvailable() else { return }
    switch manager.authorizationStatus {
    case .authorizedAlways, .authorizedWhenInUse:
      status("Finding your location and true north…")
      manager.headingOrientation = screenOrientation()
      // Apple requires location updates for a valid trueHeading.
      manager.startUpdatingLocation(); manager.startUpdatingHeading()
    case .denied, .restricted:
      manager.stopUpdatingHeading(); manager.stopUpdatingLocation(); location = nil
      status("Enable location for this app in iPhone Settings to use the true-north compass.")
    case .notDetermined: break
    @unknown default: status("Location permission unavailable.")
    }
  }
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { startAuthorized() }
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard active else { return }
    location = locations.last
  }
  func locationManager(_ manager: CLLocationManager, didUpdateHeading heading: CLHeading) {
    guard active else { return }
    let orientation = screenOrientation()
    if manager.headingOrientation != orientation {
      manager.headingOrientation = orientation
      status("Adjusting to screen orientation…")
      return
    }
    let now = Date().timeIntervalSince1970
    guard now - lastEmit >= 0.1 else { return }
    lastEmit = now
    guard let location, location.horizontalAccuracy >= 0,
      abs(location.timestamp.timeIntervalSinceNow) <= 120 else {
      status("Waiting for a fresh location fix…"); return
    }
    guard heading.trueHeading >= 0, heading.headingAccuracy >= 0 else {
      status("Compass needs calibration. Move away from magnets and gently move your phone in a figure eight."); return
    }
    sink?(["state": "reading", "heading": heading.trueHeading,
      "accuracy": heading.headingAccuracy, "headingTime": heading.timestamp.timeIntervalSince1970 * 1000,
      "latitude": location.coordinate.latitude, "longitude": location.coordinate.longitude,
      "locationAccuracy": location.horizontalAccuracy, "locationTime": location.timestamp.timeIntervalSince1970 * 1000,
      "orientation": String(orientation.rawValue)])
  }
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    guard active else { return }; location = nil
    status("Current location unavailable. Check permission and try near a window or outside.")
  }
  func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool { active }
  private func screenOrientation() -> CLDeviceOrientation {
    let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
    switch scene?.interfaceOrientation {
    case .landscapeLeft: return .landscapeRight
    case .landscapeRight: return .landscapeLeft
    case .portraitUpsideDown: return .portraitUpsideDown
    default: return .portrait
    }
  }
  private func status(_ message: String) { sink?(["state": "waiting", "message": message]) }
  private func stop() { active = false; manager.stopUpdatingHeading(); manager.stopUpdatingLocation(); location = nil }
  @objc private func backgrounded() { stop(); status("Compass paused.") }
  deinit { NotificationCenter.default.removeObserver(self) }
}
