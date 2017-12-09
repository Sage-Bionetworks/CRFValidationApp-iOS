//
//  StudyOverviewViewController.swift
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

public enum CRFOnboardingError: Error {
    case invalidTaskJson(reason: String?)
}

class StudyOverviewViewController: UIViewController, ORKTaskViewControllerDelegate, SBASharedInfoController {
    
    @IBOutlet weak var loginButton: SBARoundedButton!
    
    // MARK: SBASharedInfoController
    
    lazy var sharedAppDelegate: SBAAppInfoDelegate = {
        return UIApplication.shared.delegate as! SBAAppInfoDelegate
    }()
    
    func surveySteps(from jsonFile: String) -> [ORKStep] {
        guard let json = SBAResourceFinder.shared.json(forResource: jsonFile),
            let jsonSteps = json["steps"] as? [[String: Any]]
            else {
                return []
        }
        
        let factory = SurveyFactory()
        let steps = jsonSteps.rsd_mapAndFilter { (jsonStep) -> ORKStep? in
            return factory.createSurveyStepWithDictionary(jsonStep as NSDictionary)
        }
        return steps
    }
    
    // MARK: actions
    
    @IBAction func externalIDTapped(_ sender: AnyObject) {
        
        // External ID registration assumes that the user has already been consented
        // so set the consent before signing in via external ID.
        let appDelegate = UIApplication.shared.delegate as! SBABridgeAppSDKDelegate
        appDelegate.currentUser.consentSignature = SBAConsentSignature(identifier: "signature")
        
        // Create a task with external ID, data groups, permissions, and Fitbit steps, and display the view controller
        let externalIDStep = SBAExternalIDLoginStep(identifier: "externalID")
        let onboardingSurveySteps = self.surveySteps(from: "OnboardingSurvey")
        let permissionsStep = SBAPermissionsStep(identifier: "permissions", permissions:[.camera, .coremotion, .location, .notifications])
        // Replace the location permission with a permission that always requests the permission.
        permissionsStep.permissionTypes = permissionsStep.permissionTypes.map{ (input) -> SBAPermissionObjectType in
            guard input.permissionType == .location else { return input }
            let permission = SBALocationPermissionObjectType(permissionType: .location)
            permission.always = true
            return permission
        }
        let fitbitStep = FitbitStep(identifier: "fitbit")
        fitbitStep.title = "Connect your Fitbit"
        fitbitStep.detailText = "Connecting to your Fitbit data allows the CRF module to understand the various aspects of your health such as your heart rate and daily movement."
        fitbitStep.continueButtonTitle = "Connect"
        fitbitStep.iconImage = #imageLiteral(resourceName: "fitbitLogo")
        fitbitStep.learnMoreAction = SkipLearnMoreAction(dictionaryRepresentation: ["learnMoreButtonText": "skip"])

        let steps = [externalIDStep] + onboardingSurveySteps + [permissionsStep, fitbitStep]
        let task = SBANavigableOrderedTask(identifier: "registration", steps: steps)
        let vc = SBATaskViewController(task: task, taskRun: nil)
        vc.delegate = self
        self.present(vc, animated: true, completion: nil)
    }
    
    
    // MARK: ORKTaskViewControllerDelegate
    
    func taskViewController(_ taskViewController: ORKTaskViewController, didFinishWith reason: ORKTaskViewControllerFinishReason, error: Error?) {
        taskViewController.dismiss(animated: true) { 
            if (reason == .completed), let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                // Record the selected data groups
                if let task = taskViewController.task {
                    let result = taskViewController.result
                    task.commitTrackedDataChanges(user: SBAUser.shared, taskResult: result, completion: { (error) in
                        // Show the appropriate view controller
                        appDelegate.showAppropriateViewController(animated: false)
                    })
                }
                else {
                    // Show the appropriate view controller
                    appDelegate.showAppropriateViewController(animated: false)
                }
            }
            else {
                // Discard the registration information that has been gathered so far
                self.sharedUser.resetStoredUserData()
            }
        }
    }
}

class SkipLearnMoreAction: SBALearnMoreAction {
    override open func learnMoreAction(for step: SBALearnMoreActionStep, with taskViewController: ORKTaskViewController) {
        guard let stepViewController = taskViewController.currentStepViewController else { return }
        stepViewController.skipForward()
    }
}
