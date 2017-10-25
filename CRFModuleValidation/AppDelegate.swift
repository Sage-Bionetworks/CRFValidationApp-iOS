//
//  AppDelegate.swift
//  CRFModuleValidation
//
//  Copyright © 2017 Sage Bionetworks. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
// 1.  Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
//
// 2.  Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation and/or
// other materials provided with the distribution.
//
// 3.  Neither the name of the copyright holder(s) nor the names of any contributors
// may be used to endorse or promote products derived from this software without
// specific prior written permission. No license is granted to the trademarks of
// the copyright holders even if such marks are included in this software.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import UIKit
import BridgeAppSDK
import SafariServices

@UIApplicationMain
class AppDelegate: SBAAppDelegate {
    
    var authSession: SFAuthenticationSession?
    
    override func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        ORKStepViewController.setCustomContinueButtonClass(SBARoundedButton.self)
        
        if let tintColor = UIColor.taskNavigationBarTintColor {
            UINavigationBar.appearance().barTintColor = tintColor
        }
        if let tintColor = UIColor.taskNavigationButtonTintColor {
            UINavigationBar.appearance().tintColor = tintColor
        }
        
        return super.application(application, willFinishLaunchingWithOptions: launchOptions)
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]?) -> Void) -> Bool {
        debugPrint("\(String(describing: userActivity.webpageURL))")
        guard let successURL = userActivity.webpageURL else { return false }
        let codeArg = NSURLComponents(string: (successURL.absoluteString))?.queryItems?.filter({$0.name == "code"}).first
        let authCode = codeArg?.value
        debugPrint("auth code: \(String(describing: authCode))")
        // TODO emm 2017-10-25 when Bridge API for this is implemented and supported in BridgeSDK, call it with authCode and do something with the returned access token

        // Close the auth session. This unfortunately ends up calling its completion handler with an error.
        self.authSession?.cancel()
        self.authSession = nil
        debugPrint("Safari auth session ended")
        
        return true
    }
    
    func connectToFitbit() {
        // Fitbit Authorization Code Grant Flow URL
        guard let authURL = URL(string: "https://www.fitbit.com/oauth2/authorize?response_type=code&client_id=22CK8G&redirect_uri=https%3A%2F%2Fdocs.sagebridge.org%2Fcrf-module%2F&scope=heartrate&expires_in=604800") else { return }
        
        debugPrint("Starting Safari auth session: \(authURL)")
        
        // Fitbit only lets us give one callback URL per app, so if we want to use the same Fitbit app for both iOS and Android (and potentially web clients)
        // we need to *not* use a custom URL scheme. But SFAuthenticationSession's completion handler requires it to be a custom URL scheme. So instead we will
        // handle the callback in the place that Universal Links are handled, i.e., application(_:, continue:, restorationHandler:), and close the
        // SFAuthenticationSession from there. Also note that the only way to close the auth session without crashing is to cancel it, which calls
        // the completion handler with the same error as if the user canceled the login, rendering the completion handler pretty much useless to us. emm 2017-10-25
        self.authSession = SFAuthenticationSession(url: authURL, callbackURLScheme: nil, completionHandler: {_,_ in })
        authSession!.start()
    }
    
}
