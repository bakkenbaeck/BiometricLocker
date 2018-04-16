//
//  BiometricLocker.swift
//  BiometricLocker
//
//  Created by Igor Ranieri on 16.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation
import LocalAuthentication

public protocol AuthenticationDelegate: class {
    func didAuthenticateSuccessfully()
    func didRequestFallbackAuthentication()
    func didFailAuthentication(error: LAError)
}

final public class BiometricLocker {
    public enum Key: String {
        case applicationDidEnterBackgroundDate = "com.bakkenbaeck.BiometricLocker.applicationDidEnterBackgroundDate"
    }

    public weak var delegate: AuthenticationDelegate?

    public var policy: LAPolicy = .deviceOwnerAuthenticationWithBiometrics

    public var localizedReason: String = ""

    private var authenticationContext: LAContext {
        // Prevents re-using an `LAContext`, once it can no longer evaluate our policy.
        // Just reusing the `LAContext` can cause it to call the success completion block
        // without the user having to enter their biometric ID.
        if !self._authenticationContext.canEvaluatePolicy(self.policy, error: nil) {
            self._authenticationContext = self.newContext()
        }

        return self._authenticationContext
    }

    private lazy var _authenticationContext: LAContext = {
        return self.newContext()
    }()

    private var defaults = UserDefaults.standard

    private lazy var negativeFeedbackGenerator: UIImpactFeedbackGenerator = {
        UIImpactFeedbackGenerator(style: .heavy)
    }()

    private lazy var positiveFeedbackGenerator: UIImpactFeedbackGenerator = {
        UIImpactFeedbackGenerator(style: .light)
    }()

    /// The duration for which the biometric authentication reuse is allowable.
    ///
    /// If the device was successfully authenticated using biometrics within the specified time interval,
    /// then authentication for the receiver succeeds automatically, without prompting the user again.
    ///
    /// - Important: Values are only valid between 0 and `LATouchIDAuthenticationMaximumAllowableReuseDuration` (checked on iOS 11.2 to be 5 minutes). If it's more, it will be reveted to `LATouchIDAuthenticationMaximumAllowableReuseDuration`, and if it's negative, to 0.
    public var biometricAuthenticationAllowableReuseDuration: TimeInterval = 0 {
        didSet {
            self.authenticationContext.touchIDAuthenticationAllowableReuseDuration = self.biometricAuthenticationAllowableReuseDuration
        }
    }

    /// Defines how long we keep the app unlocked once it's been sent to the background. Defaults to LATouchIDAuthenticationMaximumAllowableReuseDuration (checked on iOS 11.2 to be 5 minutes).
    ///
    /// **Important**: Does not apply to apps that are killed by the user. In those cases, we always force-lock.
    public var unlockedTimeAllowance: TimeInterval = LATouchIDAuthenticationMaximumAllowableReuseDuration

    /// **True** if the app has been in the background for more than our `unlockedTimeAllowace`, or killed by the user.
    ///
    /// **False** otherwise.
    public var isLocked: Bool {
        if let applicationDidEnterBackgroundDate = self.defaults.value(forKey: Key.applicationDidEnterBackgroundDate.rawValue) as? Date {

            let appWasInBackgroundForLongerThan5Minutes = Date().timeIntervalSince(applicationDidEnterBackgroundDate) > self.unlockedTimeAllowance

            return appWasInBackgroundForLongerThan5Minutes
        }

        return false
    }

    /// Locks the app.
    ///
    /// - Parameter date: Tells the locker when the app was sent to the background (or any other situation, when applicable), so that we can calculate if the app should be locked.
    public func lock(at date: Date = Date()) {
        // if we are already deactivated, return. Otherwise you can just kill the app and try again to bypass touch ID.
        if self.isLocked { return }

        self.defaults.set(date, forKey: Key.applicationDidEnterBackgroundDate.rawValue)
        self.defaults.synchronize()
    }

    /// Unlocks the app.
    ///
    /// Call it from the `AuthenticationDelegate`'s `didAuthenticateSuccessfully` method, or if the user session was destroyed. (No sense in locking the app if the user logs out).
    public func unlock() {
        UserDefaults.standard.removeObject(forKey: Key.applicationDidEnterBackgroundDate.rawValue)
    }

    /// Requests that the user authenticate with biometrics. Feel free to allow a fallback, like a pincode or password screen.

    public func authenticateWithBiometrics() {
        var error: NSError?
        guard self.authenticationContext.canEvaluatePolicy(self.policy, error: &error) else {
            return
        }

        self.authenticationContext.evaluatePolicy(self.policy, localizedReason: self.localizedReason) { success, error in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return }
                
                if success {
                    strongSelf.delegate?.didAuthenticateSuccessfully()
                    strongSelf.positiveFeedbackGenerator.impactOccurred()
                    strongSelf.unlock()
                } else {
                    strongSelf.negativeFeedbackGenerator.impactOccurred()

                    // This should not actually fail. Not sure why the API doesn't simply return it as an `LAError` directly.
                    guard let error = (error as? LocalAuthentication.LAError) else { return }
                    switch error.code {
                    case .userFallback:
                        strongSelf.delegate?.didRequestFallbackAuthentication()
                    case .userCancel:
                        // User manually cancelled the biometric check.
                        break
                    default:
                        strongSelf.delegate?.didFailAuthentication(error: error)
                    }
                }
            }

            // Prevents the context from being re-used.
            self.authenticationContext.invalidate()
        }
    }

    private func newContext() -> LAContext {
        let context = LAContext()
        context.touchIDAuthenticationAllowableReuseDuration = self.biometricAuthenticationAllowableReuseDuration

        return context
    }
}
