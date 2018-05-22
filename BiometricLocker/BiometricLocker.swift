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

public final class BiometricLocker {
    /// Defines the behaviour of the `lock` function.
    ///
    /// - now: sets the app as locked immediatelly.
    /// - afterTimeAllowance: sets the app as locked after the `unlockedTimeAllowace` interval at checking time.
    /// - afterTimeInterval(TimeInterval): sets the app as locked after the given time interval.
    public enum LockingTime {
        case now
        case afterTimeAllowance
        case afterTimeInterval(TimeInterval)
    }

    /// Defines the UserDefaults key we'll use to store the date.
    public enum Key: String {
        case applicationDidEnterBackgroundDate = "com.bakkenbaeck.BiometricLocker.applicationDidEnterBackgroundDate"
    }

    public weak var delegate: AuthenticationDelegate?

    /**
     Define which policy we have for the device owner to be authenticated using a biometric method (Touch ID or Face ID).
     Defaults to `deviceOwnerAuthenticationWithBiometrics`.

     See [LocalAuthentication](apple-reference-documentation://cslocalauthentication) for a more detailed explanation.
     */
    public var policy: LAPolicy = .deviceOwnerAuthenticationWithBiometrics

    /// The app-provided reason for requesting authentication, which displays in the authentication dialog presented to the user.
    public var localizedReason: String

    @available(iOS 11.0, *)
    public var biometryType: LABiometryType {
        return self.authenticationContext.biometryType
    }

    private var authenticationContext: LAContext {
        // Prevents re-using an `LAContext`, once it can no longer evaluate our policy.
        // Just reusing the `LAContext` can cause it to call the success completion block
        // without the user having to enter their biometric ID.
        if !self._authenticationContext.canEvaluatePolicy(self.policy, error: nil) {
            self._authenticationContext = self.newContext()
        }

        return self._authenticationContext
    }

    /// Should be set to `self.newContext()`, to ensure we're using the correct configurations.
    private lazy var _authenticationContext: LAContext = {
        self.newContext()
    }()

    private var defaults = UserDefaults.standard

    private let negativeFeedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let positiveFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    /// The duration for which the biometric authentication reuse is allowable.
    ///
    /// If the device was successfully authenticated using biometrics within the specified time interval,
    /// then authentication for the receiver succeeds automatically, without prompting the user again.
    ///
    /// - Important: Values are only valid between 0 and `LATouchIDAuthenticationMaximumAllowableReuseDuration` (checked on iOS 11.2 to be 5 minutes). If it's more, it will be reveterd to `LATouchIDAuthenticationMaximumAllowableReuseDuration`, and if it's negative, to 0.
    public var biometricAuthenticationAllowableReuseDuration: TimeInterval = 0 {
        didSet {
            self.authenticationContext.touchIDAuthenticationAllowableReuseDuration = self.biometricAuthenticationAllowableReuseDuration
        }
    }

    /// Defines how long we keep the app unlocked once it's been sent to the background.
    /// Defaults to LATouchIDAuthenticationMaximumAllowableReuseDuration (checked on iOS 11.2 to be 5 minutes).
    ///
    /// *Does not apply to apps that are killed by the user. In those cases, we always force-lock.*
    ///
    public private(set) var unlockedTimeAllowance: TimeInterval

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

    /// Creates a new BiometricLocker. Use it to track if the app is locked or unlocked. Does not provide UI.
    ///
    /// - Parameters:
    ///   - localizedReason: The app-provided reason for requesting authentication, which displays in the authentication dialog presented to the user.
    ///   - automaticallyLocksOnBackgroundOrQuit: Whether the app should autolock when the user leaves or quits the app. Default is `true`.
    ///   - timeAllowance: How longer after the user leaves the app / after `lock()` is called, should it autolock. Can't be changed after initialisation. Default is `LATouchIDAuthenticationMaximumAllowableReuseDuration`.
    public init(localizedReason: String, automaticallyLocksOnBackgroundOrQuit: Bool = true, withUnlockedTimeAllowance timeAllowance: TimeInterval = LATouchIDAuthenticationMaximumAllowableReuseDuration) {
        self.localizedReason = localizedReason

        self.unlockedTimeAllowance = timeAllowance

        if automaticallyLocksOnBackgroundOrQuit {
            NotificationCenter.default.addObserver(forName: .UIApplicationDidEnterBackground, object: nil, queue: .main) { _ in
                // If app goes into background, we start the clocks to lock the app.
                self.lock()
            }

            NotificationCenter.default.addObserver(forName: .UIApplicationWillTerminate, object: nil, queue: .main) { _ in
                // If the app is killed, lock it instantly.
                self.lock(.now)
            }
        }
    }

    /**
     Tells the biometric locker to lock the app. Defaults to the currently defined time allowance (5min by default).

     - Parameter when: An enum defining when the app should lock. Now, after the time allowance, or after a custom time interval.
     */
    public func lock(_ when: LockingTime = .afterTimeAllowance) {
        // if we are already deactivated, return. Otherwise you can just kill the app and try again to bypass touch ID.
        if self.isLocked { return }

        let date: Date
        switch when {
        case .now:
            date = Date.distantPast
        case .afterTimeAllowance:
            date = Date()
        case .afterTimeInterval(let interval):
            // We subtract our `unlockedTimeAllowance` here, to offset when checking again
            // inside `isLocked`, otherwise it would be up to the user to know how we implement this internally
            // and manually calculate the time difference.
            date = Date(timeIntervalSinceNow: (interval - self.unlockedTimeAllowance))
        }

        self.defaults.set(date, forKey: Key.applicationDidEnterBackgroundDate.rawValue)
        self.defaults.synchronize()
    }

    /// Unlocks the app.
    ///
    /// - Important: Should be called if the user session is destroyed, if your app has them, otherwise you risk having the app locked whilst there's no user, preventing people from logging in / signing up.
    public func unlock() {
        UserDefaults.standard.removeObject(forKey: Key.applicationDidEnterBackgroundDate.rawValue)
    }

    /// Preflights an authentication policy to see if it is possible for authentication to succeed.
    ///
    /// - Parameters:
    ///   - policy: The policy to evaluate. For possible values, see [LAPolicy](https://developer.apple.com/documentation/localauthentication/lapolicy).
    ///   - error: If an error occurs, upon return contains an NSError object containing the error information. See LAError.Code for possible error codes.
    ///
    /// You may specify nil for this parameter if you do not want the error information.
    /// - Returns: true if the policy can be evaluated, otherwise false.
    public func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer) -> Bool {
        return self.authenticationContext.canEvaluatePolicy(policy, error: error)
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
