# BiometricLocker

BiometricLocker helps you handle biometric checks in your application, be it FaceID or TouchID. By abstracting away most of the complications and giving you behaviour for free (like automatically locking the app when going into the background, with a time allowance also possible). 

Keep in mind that the BiometricLocker does not actually lock your app. It does not provide UI, except for the system provided alerts for biometric checks. We provide the backing logic only, that will tell your app whether or not it should be locked.

Also to keep in mind: the biometric locker instance should not be deallocated. It should live for as long as the application live.

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