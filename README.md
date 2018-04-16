# BiometricLocker

### Example:
Here's a simple example implementation through the AppDelegate.

```swift
import BiometricLocker

@UIApplicationMain class AppDelegate: UIResponder, UIApplicationDelegate {
  var biometricLocker = BiometricLocker()
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    self.lockAppIfNeeded()
    
    ///…
    
    return true
  }

  func applicationDidEnterBackground(_ application: UIApplication) {
    self.biometricLocker.lock()
  }
	
  func applicationWillEnterForeground(_ application: UIApplication) {
    self.lockAppIfNeeded()
  }
	
  func applicationWillTerminate(_ application: UIApplication) {
    var backgroundTask = UIBackgroundTaskInvalid

    backgroundTask = application.beginBackgroundTask {
      application.endBackgroundTask(backgroundTask)
      backgroundTask = UIBackgroundTaskInvalid
    }

    DispatchQueue.global(qos: .default).async {
      // Ensures the app is locked, regardless of our timeout allowance.
      self.biometricLocker.deactivate(Date.distantPast)

      application.endBackgroundTask(backgroundTask)
      backgroundTask = UIBackgroundTaskInvalid
    }
  }
	
  private func lockAppIfNeeded() {
    if self.biometricLocker.isBackgroundLocked {
      UIView.transition(with: self.window!, duration: 0.5, options: .transitionFlipFromRight, animations: {
        let authenticationController = AuthenticationController()
        authenticationController.delegate = self
        self.window?.rootViewController = authenticationController
      }, completion: nil)
    }
  }
}

extension AppDelegate: AuthenticationDelegate {
  func didAuthenticateSuccessfully() {
    UIView.transition(with: self.window!, duration: 0.5, options: .transitionFlipFromRight, animations: {
      self.window?.rootViewController = self.rootNavigationController
    }, completion: { _ in
      // Done!
    })
  }
}
```