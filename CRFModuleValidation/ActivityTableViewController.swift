//
//  ActivityTableViewController.swift
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

class ActivityTableViewController: SBAActivityTableViewController {
    
    var authSession: SFAuthenticationSession?
    
    @IBAction func fitbitButtonTapped(_ sender: Any) {
        let handler:SFAuthenticationSession.CompletionHandler = { (callBack:URL?, error:Error? ) in
            guard error == nil, let successURL = callBack else {
                return
            }
            let authCode = NSURLComponents(string: (successURL.absoluteString))?.queryItems?.filter({$0.name == "code"}).first
            
            debugPrint("auth code: \(String(describing: authCode))")
        }

        // Fitbit Authorization Code Grant Flow URL
        guard let authURL = URL(string: "https://www.fitbit.com/oauth2/authorize?response_type=code&client_id=22CK8G&redirect_uri=https%3A%2F%2Fdocs.sagebridge.org%2Fcrf-module%2F&scope=heartrate&expires_in=604800") else { return }
        
        debugPrint("Starting Safari auth session: \(authURL)")
        self.authSession = SFAuthenticationSession(url: authURL, callbackURLScheme: nil, completionHandler: handler)
        authSession!.start()
    }

    override var scheduledActivityDataSource: SBAScheduledActivityDataSource {
        return scheduledActivityManager
    }
    
    lazy var scheduledActivityManager : ScheduledActivityManager = {
        return ScheduledActivityManager(delegate: self)
    }()
}
