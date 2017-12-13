//
//  FitbitStep.swift
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

import BridgeAppSDK

open class FitbitSkipRule: ORKSkipStepNavigationRule {
    
    /**
     Whether or not the rule should be applied
     @param taskResult  Ignored.
     @return            `YES` if Fitbit is alrady connectd
    */
    open override func stepShouldSkip(with taskResult: ORKTaskResult) -> Bool {
        // TODO emm 2017-11-09 check if Fitbit is already connected
        return false
    }
}

open class FitbitStep: SBAInstructionStep, SBANavigationSkipRule {

    override public init(identifier: String) {
        super.init(identifier: identifier)
        commonInit()
    }
    
    public override init(inputItem: SBASurveyItem) {
        super.init(inputItem: inputItem)
        commonInit()
    }
    
    fileprivate func commonInit() {
        if self.title == nil {
            // TODO emm 2017-11-09 localize
            self.title = "Connect your Fitbit"
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override open func stepViewControllerClass() -> AnyClass {
        return FitbitStepViewController.classForCoder()
    }

    override open func isInstructionStep() -> Bool {
        return true
    }
    
    // MARK: SBANavigationSkipRule
    
    open func shouldSkipStep(with result: ORKTaskResult, and additionalTaskResults: [ORKTaskResult]?) -> Bool {
        // TODO emm 2017-11-09 check if they've already authorized Fitbit
        return false
    }
    
}

open class FitbitStepViewController: SBAInstructionStepViewController {
    
    var fitbitConnected: Bool = false
    
    override open var result: ORKStepResult? {
        guard let result = super.result else { return nil }
        
        // Add a result for whether or not Fitbit was connected
        let connectedResult = ORKBooleanQuestionResult(identifier: result.identifier)
        connectedResult.booleanAnswer = NSNumber(value: fitbitConnected)
        result.results = [connectedResult]
        
        return result
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Let test users skip Fitbit auth, participants not so much. We use the SkipLearnMoreAction to skip.
        self.learnMoreButton?.isHidden = true
        let dataGroups = SBAUser.shared.dataGroups ?? [String]()
        if let task = taskViewController?.task, let result = taskViewController?.result {
            let (newGroups, _) = task.union(currentGroups: dataGroups, with: result)
            guard let groups = newGroups else { return }
            if groups.contains("test_user") {
                self.learnMoreButton?.isHidden = false
            }
        }

    }
    
    override open func goForward() {
        guard let fitbitStep = self.step as? FitbitStep,
                let appDelegate = UIApplication.shared.delegate as? AppDelegate
            else {
                assertionFailure("Step is not of expected type")
                super.goForward()
                return
        }
        
        // Show a loading view to indicate that something is happening
        self.showLoadingView()
        appDelegate.connectToFitbit(completionHandler: { [weak self] (URL, error) in
            let connected: Bool = (URL != nil)
            self?.hideLoadingView()
            if connected || fitbitStep.isOptional {
                self?.fitbitConnected = connected
                self?.goNext()
            }
            else if let strongSelf = self, let strongDelegate = strongSelf.delegate {
                let error = NSError(domain: "FitbitStepDomain", code: 1, userInfo: nil)
                strongDelegate.stepViewControllerDidFail(strongSelf, withError: error)
            }
        })
    }
    
    override open func skipForward() {
        goNext()
    }
    
    fileprivate func goNext() {
        super.goForward()
    }
    
    open override var cancelButtonItem: UIBarButtonItem? {
        // Override the cancel button to *not* display. User must tap the "Continue" button.
        get { return nil }
        set {}
    }
}
