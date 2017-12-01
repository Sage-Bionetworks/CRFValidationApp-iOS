//
//  CardioUITests.swift
//  CRFModuleTestAppUITests
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


import XCTest

class CardioUITests: XCTestCase {
        
    override func setUp() {
        super.setUp()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        XCUIApplication().launch()

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testCardioStressTest() {
        
        let app = XCUIApplication()
        app.tables/*@START_MENU_TOKEN@*/.staticTexts["Cardio Stress"]/*[[".cells.staticTexts[\"Cardio Stress\"]",".staticTexts[\"Cardio Stress\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        
        // -- Introduction
        XCTAssertTrue(app.staticTexts["Cardiovascular stress test"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["20 minutes"].exists)
        
        // Check learn more text
        app.buttons["infoIcon"].tap()
        let webViewsQuery = app.webViews
        XCTAssertTrue(webViewsQuery/*@START_MENU_TOKEN@*/.staticTexts["About Cardiovascular Stress test"]/*[[".otherElements[\"Stair Step\"]",".otherElements[\"About Cardiovascular Stress test\"]",".staticTexts[\"1\"]",".staticTexts[\"About Cardiovascular Stress test\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/.waitForExistence(timeout: 2))
        webViewsQuery/*@START_MENU_TOKEN@*/.staticTexts["Why a stress test"]/*[[".otherElements[\"Stair Step\"]",".otherElements[\"Why a stress test\"]",".staticTexts[\"2\"]",".staticTexts[\"Why a stress test\"]"],[[[-1,3],[-1,1,2],[-1,0,1]],[[-1,3],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/.tap()
        webViewsQuery/*@START_MENU_TOKEN@*/.staticTexts["It is used to determine how well your heart responds during times when it is working the hardest. Completing the test will provide data that scientists can use to assess the accuracy of digital versions of the tests."]/*[[".otherElements[\"Stair Step\"].staticTexts[\"It is used to determine how well your heart responds during times when it is working the hardest. Completing the test will provide data that scientists can use to assess the accuracy of digital versions of the tests.\"]",".staticTexts[\"It is used to determine how well your heart responds during times when it is working the hardest. Completing the test will provide data that scientists can use to assess the accuracy of digital versions of the tests.\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        webViewsQuery/*@START_MENU_TOKEN@*/.staticTexts["What to do"]/*[[".otherElements[\"Stair Step\"]",".otherElements[\"What to do\"]",".staticTexts[\"2\"]",".staticTexts[\"What to do\"]"],[[[-1,3],[-1,1,2],[-1,0,1]],[[-1,3],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/.tap()
        
        let nurseWillCheckYourHeartRateAndBreathingBeforeYouBeginExercisingStaticText = webViewsQuery/*@START_MENU_TOKEN@*/.staticTexts["Nurse will check your heart rate and breathing before you begin exercising."]/*[[".otherElements[\"Stair Step\"].staticTexts[\"Nurse will check your heart rate and breathing before you begin exercising.\"]",".staticTexts[\"Nurse will check your heart rate and breathing before you begin exercising.\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
        nurseWillCheckYourHeartRateAndBreathingBeforeYouBeginExercisingStaticText.tap()
        webViewsQuery/*@START_MENU_TOKEN@*/.staticTexts["You’ll be hooked up to the EKG machine."]/*[[".otherElements[\"Stair Step\"].staticTexts[\"You’ll be hooked up to the EKG machine.\"]",".staticTexts[\"You’ll be hooked up to the EKG machine.\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        nurseWillCheckYourHeartRateAndBreathingBeforeYouBeginExercisingStaticText.tap()
        webViewsQuery/*@START_MENU_TOKEN@*/.staticTexts["You’ll start off slowly on a stationary bicycle or treadmill. The speed and grade will be increased through the test duration."]/*[[".otherElements[\"Stair Step\"].staticTexts[\"You’ll start off slowly on a stationary bicycle or treadmill. The speed and grade will be increased through the test duration.\"]",".staticTexts[\"You’ll start off slowly on a stationary bicycle or treadmill. The speed and grade will be increased through the test duration.\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        webViewsQuery/*@START_MENU_TOKEN@*/.staticTexts["You will be asked to continue until you feel exhausted."]/*[[".otherElements[\"Stair Step\"].staticTexts[\"You will be asked to continue until you feel exhausted.\"]",".staticTexts[\"You will be asked to continue until you feel exhausted.\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        webViewsQuery/*@START_MENU_TOKEN@*/.staticTexts["Your heart rate and breathing will continue to be monitored for a short while after the test."]/*[[".otherElements[\"Stair Step\"].staticTexts[\"Your heart rate and breathing will continue to be monitored for a short while after the test.\"]",".staticTexts[\"Your heart rate and breathing will continue to be monitored for a short while after the test.\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        
        // Continue to next step
        app.navigationBars.buttons["Close"].tap()
        XCTAssertTrue(app.staticTexts["Cardiovascular stress test"].waitForExistence(timeout: 2))
        app.buttons["Start"].tap()
        
        // -- Step 1 - Heart Rate before
        let step1Of3StaticText = app.staticTexts["Step 1 of 3"]
        XCTAssertTrue(step1Of3StaticText.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Capture heart rate"].exists)
        XCTAssertTrue(app.staticTexts["Use your finger to cover the camera and flash on the back of your phone."].exists)
        XCTAssertTrue(app.staticTexts["Press to Start"].exists)
        
        let capturestartbuttonButton = app.buttons["captureStartButton"]
        capturestartbuttonButton.tap()
        
        // Heart rate capture
        let initialHeartRateText = app.staticTexts["Gently cover both the camera and flash with your finger."]
        let halfWayHeartRateText = app.staticTexts["You’re half way there!"]
        let fifteenLeftHeartRateText = app.staticTexts["Just 15 seconds left"]
        let allDoneHeartRateText = app.staticTexts["You’re all done!"]
        
        XCTAssertTrue(initialHeartRateText.waitForExistence(timeout: 5))
        XCTAssertTrue(step1Of3StaticText.exists)
        XCTAssertTrue(halfWayHeartRateText.waitForExistence(timeout: 35))
        XCTAssertTrue(fifteenLeftHeartRateText.waitForExistence(timeout: 20))
        XCTAssertTrue(allDoneHeartRateText.waitForExistence(timeout: 20))
        
        // Heart rate feedback
        let heartRate65 = app.staticTexts["65"]
        let bpmLabel = app.staticTexts["BPM"]
        
        XCTAssertTrue(app.staticTexts["Your heart rate is"].waitForExistence(timeout: 5))
        XCTAssertTrue(allDoneHeartRateText.exists)
        XCTAssertTrue(heartRate65.exists)
        XCTAssertTrue(bpmLabel.exists)
        app.buttons["Next"].tap()
        
        // -- Step 2 - ready to run
        let step2Of3StaticText = app.staticTexts["Step 2 of 3"]
        XCTAssertTrue(step2Of3StaticText.waitForExistence(timeout: 2))
        
        XCTAssertTrue(app.staticTexts["Ready to run on the treadmill?"].exists)
        XCTAssertTrue(app.staticTexts["You’ll start off slowly, and speed and grade will be increased through the test duration."].exists)
        XCTAssertTrue(app.staticTexts["Press to Start"].exists)
        app.buttons["treadmillStartButton"].tap()
        
        // run complete
        XCTAssertTrue(app.staticTexts["Did you complete the test on the treadmill?"].waitForExistence(timeout: 2))
        XCTAssertTrue(step2Of3StaticText.exists)
        app.buttons["Yes"].tap()
        
        // -- Step 3 - Heart rate after
        let step3Of3StaticText = app.staticTexts["Step 3 of 3"]
        XCTAssertTrue(step3Of3StaticText.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Stand still for 1 minute"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Almost done! Stand still for a minute to measure your heart rate recovery."].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Press to Start"].exists)
        capturestartbuttonButton.tap()
        
        // Heart rate capture
        XCTAssertTrue(initialHeartRateText.waitForExistence(timeout: 5))
        XCTAssertTrue(step3Of3StaticText.exists)
        XCTAssertTrue(halfWayHeartRateText.waitForExistence(timeout: 35))
        XCTAssertTrue(fifteenLeftHeartRateText.waitForExistence(timeout: 20))
        XCTAssertTrue(allDoneHeartRateText.waitForExistence(timeout: 20))
        
        // Heart rate feedback
        XCTAssertTrue(app.staticTexts["Your heart rate changed to"].waitForExistence(timeout: 5))
        XCTAssertTrue(allDoneHeartRateText.exists)
        XCTAssertTrue(heartRate65.exists)
        XCTAssertTrue(bpmLabel.exists)
        
        app.buttons["Done"].tap()
    }
}
