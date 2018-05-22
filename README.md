# BiometricLocker

### Example:
Here's a simple example implementation through the AppDelegate.

```swift
import BiometricLocker

// App Delegate
@UIApplicationMain class AppDelegate: UIResponder, UIApplicationDelegate {

  let biometricLocker = BiometricLocker(localizedReason: "Code the pins", automaticallyLocksOnBackgroundOrQuit: true, withUnlockedTimeAllowance: 0)
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
	  …
	  self.lockAppIfNeeded()
	  …
	  return true
  }

  public func applicationWillEnterForeground(_ application: UIApplication) {
	  self.lockAppIfNeeded()
  }

	private func lockAppIfNeeded() {
        guard let locker = Session.current?.locker else { return }

        if locker.isLocked {
            (self.rootNavigationController.topViewController as? RootViewController)?.topViewController.dismiss(animated: false)

            // We add a forced delay here, because of UIKit, even a non-animated dimissal like above takes time.
            // 0.25 seems to work fine.
            DispatchQueue.main.asyncAfter(seconds: 0.5) {
                UIView.transition(with: self.window!, duration: 0.5, options: .transitionFlipFromRight, animations: {
                    let authenticationController = AuthenticationController()
                    // We set the locker delegate here to handle locking/unlocking inside it.
                    locker.delegate = authenticationController
                    authenticationController.delegate = self
                    self.window?.rootViewController = authenticationController
                }, completion: nil)
            }
        }
    }
}

// AuthenticationController

class AuthenticationController: UIViewController {
		override func viewDidLoad() {
			super.viewDidLoad()
			
			self.authenticateWithBiometricAuthentication()
		}
		
		private func authenticateWithBiometricAuthentication() {
        guard let locker = Session.current?.locker else { return }

        locker.authenticateWithBiometrics()
    }
}

extension AuthenticationController: AuthenticationDelegate {
    func didAuthenticateSuccessfully() {
        self.delegate?.didAuthenticateSuccessFully()
        self.positiveFeedbackGenerator.impactOccurred()
    }

    func didFailAuthentication(error: LAError) {
        self.negativeFeedbackGenerator.impactOccurred()

        switch error.code {
        case .userFallback, .userCancel:
            break
        default:
            self.showAlert(for: error)
        }
    }

    func didRequestFallbackAuthentication() {

    }
}

```