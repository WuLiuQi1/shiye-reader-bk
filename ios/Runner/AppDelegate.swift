import Flutter
import UIKit

@objc(ReaderFlutterViewController) class ReaderFlutterViewController: FlutterViewController {
  private var readerImmersiveEnabled = false {
    didSet {
      if oldValue != readerImmersiveEnabled {
        refreshImmersiveUI()
      }
    }
  }

  override var prefersHomeIndicatorAutoHidden: Bool {
    readerImmersiveEnabled
  }

  override var prefersStatusBarHidden: Bool {
    readerImmersiveEnabled
  }

  override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
    .fade
  }

  override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
    readerImmersiveEnabled ? .all : []
  }

  @objc func setReaderImmersiveEnabled(_ enabled: Bool) {
    readerImmersiveEnabled = enabled
    if enabled {
      refreshImmersiveUI()
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if readerImmersiveEnabled {
      refreshImmersiveUI()
    }
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    if readerImmersiveEnabled {
      refreshImmersiveUI()
    }
  }

  private func refreshImmersiveUI() {
    setNeedsStatusBarAppearanceUpdate()
    setNeedsUpdateOfHomeIndicatorAutoHidden()
    setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterPluginRegistrant {
  private var readerImmersiveEnabled = false
  private var storageBridge: StorageBridge?
  private var incomingBookBridge: IncomingBookBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    pluginRegistrant = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func register(with registry: FlutterPluginRegistry) {
    GeneratedPluginRegistrant.register(with: registry)

    guard let messenger = registry.registrar(forPlugin: "ReaderUIBridge")?.messenger() else {
      NSLog("Reader bridge init failed: binaryMessenger unavailable")
      return
    }

    let readerUIChannel = FlutterMethodChannel(
      name: "com.niki.xxread/reader_ui",
      binaryMessenger: messenger
    )
    readerUIChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "setReaderImmersive":
        guard let args = call.arguments as? [String: Any],
              let enabled = args["enabled"] as? Bool else {
          result(
            FlutterError(
              code: "invalid_args",
              message: "expected {enabled: bool}",
              details: nil
            )
          )
          return
        }
        self?.readerImmersiveEnabled = enabled
        self?.applyReaderImmersiveIfPossible()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let readerStatusChannel = FlutterMethodChannel(
      name: "com.niki.xxread/reader_status",
      binaryMessenger: messenger
    )
    readerStatusChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "getBatteryStatus":
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        guard level >= 0 else {
          result(nil)
          return
        }
        let state = UIDevice.current.batteryState
        result([
          "level": Int((level * 100).rounded()),
          "charging": state == .charging || state == .full,
        ])
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let iCloudBackupChannel = FlutterMethodChannel(
      name: "com.niki.xxread/icloud_backup",
      binaryMessenger: messenger
    )
    iCloudBackupChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      let manager = FileManager.default
      switch call.method {
      case "isAvailable":
        DispatchQueue.global(qos: .userInitiated).async {
          let available = manager.url(forUbiquityContainerIdentifier: "iCloud.com.niki.xxread") != nil
          DispatchQueue.main.async { result(available) }
        }
      case "writeBackup":
        guard let args = call.arguments as? [String: Any],
              let payload = args["payload"] as? String else {
          result(FlutterError(code: "invalid_args", message: "Missing backup payload.", details: nil))
          return
        }
        DispatchQueue.global(qos: .userInitiated).async {
          guard let container = manager.url(forUbiquityContainerIdentifier: "iCloud.com.niki.xxread") else {
            DispatchQueue.main.async {
              result(FlutterError(code: "icloud_unavailable", message: "iCloud is unavailable.", details: nil))
            }
            return
          }
          do {
            let directory = container.appendingPathComponent("Documents", isDirectory: true)
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
            let destination = directory.appendingPathComponent("OpenReadingBackup.json")
            try Data(payload.utf8).write(to: destination, options: .atomic)
            DispatchQueue.main.async { result(nil) }
          } catch {
            DispatchQueue.main.async {
              result(FlutterError(code: "icloud_write_failed", message: error.localizedDescription, details: nil))
            }
          }
        }
      case "readBackup":
        DispatchQueue.global(qos: .userInitiated).async {
          guard let container = manager.url(forUbiquityContainerIdentifier: "iCloud.com.niki.xxread") else {
            DispatchQueue.main.async {
              result(FlutterError(code: "icloud_unavailable", message: "iCloud is unavailable.", details: nil))
            }
            return
          }
          let source = container
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("OpenReadingBackup.json")
          guard manager.fileExists(atPath: source.path) else {
            DispatchQueue.main.async { result(nil) }
            return
          }
          do {
            let payload = try String(contentsOf: source, encoding: .utf8)
            DispatchQueue.main.async { result(payload) }
          } catch {
            DispatchQueue.main.async {
              result(FlutterError(code: "icloud_read_failed", message: error.localizedDescription, details: nil))
            }
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    storageBridge = StorageBridge(messenger: messenger)
    incomingBookBridge = IncomingBookBridge(messenger: messenger)

  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    applyReaderImmersiveIfPossible()
    IncomingBookInbox.shared.consumeSharedExtensionInboxIfConfigured()
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if !IncomingBookInbox.uniqueSupportedFileURLs([url]).isEmpty {
      IncomingBookInbox.shared.accept(urls: [url], action: "open")
      return true
    }
    return super.application(app, open: url, options: options)
  }

  private func applyReaderImmersiveIfPossible() {
    guard let controller = currentReaderController() else { return }
    controller.setReaderImmersiveEnabled(readerImmersiveEnabled)
  }

  private func currentReaderController() -> ReaderFlutterViewController? {
    if #available(iOS 13.0, *) {
      for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
        let keyWindow = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
        if let found = findReaderController(in: keyWindow?.rootViewController) {
          return found
        }
      }
      return nil
    }
    return findReaderController(in: window?.rootViewController)
  }

  private func findReaderController(in viewController: UIViewController?) -> ReaderFlutterViewController? {
    guard let viewController else { return nil }
    if let reader = viewController as? ReaderFlutterViewController {
      return reader
    }
    if let presented = viewController.presentedViewController,
       let found = findReaderController(in: presented) {
      return found
    }
    if let nav = viewController as? UINavigationController {
      for vc in nav.viewControllers {
        if let found = findReaderController(in: vc) {
          return found
        }
      }
    }
    if let tab = viewController as? UITabBarController {
      for vc in tab.viewControllers ?? [] {
        if let found = findReaderController(in: vc) {
          return found
        }
      }
    }
    for child in viewController.children {
      if let found = findReaderController(in: child) {
        return found
      }
    }
    return nil
  }
}
