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
        
        // Capture heart rate
        runTest_HeartRateStep(app: app, progressLabel: step1Of3StaticText, feedbackLabel: app.staticTexts["Your heart rate is"])
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
        
        // Capture heart rate
        runTest_HeartRateStep(app: app, progressLabel: step3Of3StaticText, feedbackLabel: app.staticTexts["Your heart rate changed to"])

        app.buttons["Done"].tap()
    }
    
    func testStairStep() {
        
        let app = XCUIApplication()
        app.tables/*@START_MENU_TOKEN@*/.staticTexts["Cardio Stair Step"]/*[[".cells.staticTexts[\"Cardio Stair Step\"]",".staticTexts[\"Cardio Stair Step\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()

        // -- Introduction
        XCTAssertTrue(app.staticTexts["Stair Step"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["5 minutes"].exists)
        
        // Check learn more text
        app.buttons["infoIcon"].tap()
        let webViewsQuery = app.webViews
        XCTAssertTrue(webViewsQuery/*@START_MENU_TOKEN@*/.staticTexts["About Stair Step test"]/*[[".otherElements[\"Stair Step\"]",".otherElements[\"About Stair Step test\"]",".staticTexts[\"1\"]",".staticTexts[\"About Stair Step test\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/.waitForExistence(timeout: 2))
        webViewsQuery/*@START_MENU_TOKEN@*/.staticTexts["Why this test"]/*[[".otherElements[\"Stair Step\"]",".otherElements[\"Why this test\"]",".staticTexts[\"2\"]",".staticTexts[\"Why this test\"]"],[[[-1,3],[-1,1,2],[-1,0,1]],[[-1,3],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/.tap()
        webViewsQuery/*@START_MENU_TOKEN@*/.staticTexts["Recording your heart rate recovery after going up and down a stair step for 3 minutes has been used to assess ones cardiovascular fitness level."]/*[[".otherElements[\"Stair Step\"].staticTexts[\"Recording your heart rate recovery after going up and down a stair step for 3 minutes has been used to assess ones cardiovascular fitness level.\"]",".staticTexts[\"Recording your heart rate recovery after going up and down a stair step for 3 minutes has been used to assess ones cardiovascular fitness level.\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        webViewsQuery/*@START_MENU_TOKEN@*/.staticTexts["What to do"]/*[[".otherElements[\"Stair Step\"]",".otherElements[\"What to do\"]",".staticTexts[\"2\"]",".staticTexts[\"What to do\"]"],[[[-1,3],[-1,1,2],[-1,0,1]],[[-1,3],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/.tap()
        webViewsQuery/*@START_MENU_TOKEN@*/.staticTexts["Find a stair step that you are comfortable going up and down for 3 minutes (can be inside or outside)."]/*[[".otherElements[\"Stair Step\"].staticTexts[\"Find a stair step that you are comfortable going up and down for 3 minutes (can be inside or outside).\"]",".staticTexts[\"Find a stair step that you are comfortable going up and down for 3 minutes (can be inside or outside).\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        webViewsQuery/*@START_MENU_TOKEN@*/.staticTexts["Take a picture of the step that you will being going up and down."]/*[[".otherElements[\"Stair Step\"].staticTexts[\"Take a picture of the step that you will being going up and down.\"]",".staticTexts[\"Take a picture of the step that you will being going up and down.\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        webViewsQuery/*@START_MENU_TOKEN@*/.staticTexts["Measure your heart rate within this app before running for 12 minutes."]/*[[".otherElements[\"Stair Step\"].staticTexts[\"Measure your heart rate within this app before running for 12 minutes.\"]",".staticTexts[\"Measure your heart rate within this app before running for 12 minutes.\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        webViewsQuery/*@START_MENU_TOKEN@*/.staticTexts["Step up and then down a single step at a speed of 24 steps per minute for 3 minutes."]/*[[".otherElements[\"Stair Step\"].staticTexts[\"Step up and then down a single step at a speed of 24 steps per minute for 3 minutes.\"]",".staticTexts[\"Step up and then down a single step at a speed of 24 steps per minute for 3 minutes.\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        webViewsQuery/*@START_MENU_TOKEN@*/.staticTexts["Measure your heart rate immediately after the 3 minute stair step session."]/*[[".otherElements[\"Stair Step\"].staticTexts[\"Measure your heart rate immediately after the 3 minute stair step session.\"]",".staticTexts[\"Measure your heart rate immediately after the 3 minute stair step session.\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        
        // Continue to next step
        app.navigationBars.buttons["Close"].tap()
        XCTAssertTrue(app.staticTexts["Stair Step"].waitForExistence(timeout: 2))
        app.buttons["Start"].tap()
        
        // -- Heart risk
        let heartRiskInstruction = app.tables["Potential heart risk, Do not attempt this test if you have experienced unstable angina, a myocardial infarction (heart attack) during the previous month, need supplemental oxygen to walk, or if you feel that running or walking for 12 minutes will be a challenge for you."]
        XCTAssertTrue(heartRiskInstruction.waitForExistence(timeout: 2))
        app.buttons["Got it"].tap()
        
        // -- Step 1 - take a picture
        XCTAssertTrue(app.staticTexts["Step 1 of 6"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Take a picture of your step"].exists)
        XCTAssertTrue(app.staticTexts["Start by taking a picture with your phone of the step with your fitibit next to the step that you will be using."].exists)
        app.buttons["Capture picture"].tap()
        app.buttons["Capture Button"].tap()
        
        // -- Step 2 - fitbit instruction
        XCTAssertTrue(app.staticTexts["Step 2 of 6"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Wearing your fitbit?"].exists)
        XCTAssertTrue(app.staticTexts["Before continuing on with the Stair Step test, please make sure you have your fitbit on your wrist."].exists)
        app.buttons["It’s on"].tap()
        
        // -- Step 3 - volumn up instruction
        XCTAssertTrue(app.staticTexts["Step 3 of 6"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Volume turned up?"].exists)
        XCTAssertTrue(app.staticTexts["Bring your phone with you and turn up your phone volume so you can hear the instructions while you are moving."].exists)
        app.buttons["It’s turned on"].tap()
        
        // -- Step 4 - Heart rate before
        let step4Of6StaticText = app.staticTexts["Step 4 of 6"]
        XCTAssertTrue(step4Of6StaticText.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Capture heart rate"].exists)
        XCTAssertTrue(app.staticTexts["Use your finger to cover the camera and flash on the back of your phone."].exists)
        XCTAssertTrue(app.staticTexts["Press to Start"].exists)
        
        // Capture heart rate
        runTest_HeartRateStep(app: app, progressLabel: step4Of6StaticText, feedbackLabel: app.staticTexts["Your heart rate is"])
        app.buttons["Next"].tap()

        // -- Step 5 - stair step
        let step5Of6StaticText = app.staticTexts["Step 5 of 6"]
        XCTAssertTrue(step5Of6StaticText.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Please step with your phone"].exists)
        XCTAssertTrue(app.staticTexts["You will step up and down for 3 minutes. Try to step with the pace."].exists)
        XCTAssertTrue(app.staticTexts["Press to Start"].exists)
        app.buttons["stairStepButton"].tap()
        
        // count down step
        XCTAssertTrue(app.staticTexts["Start in"].waitForExistence(timeout: 2))
        XCTAssertTrue(step5Of6StaticText.exists)
        sleep(10)
        
        // stair step
        XCTAssertTrue(app.staticTexts["Up"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Down"].waitForExistence(timeout: 5))
        sleep(160)
        XCTAssertTrue(app.staticTexts["Stand still"].waitForExistence(timeout: 25))
        
        // -- Step 6 - Heart rate after
        let step6Of6StaticText = app.staticTexts["Step 6 of 6"]
        XCTAssertTrue(step6Of6StaticText.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Stand still for 1 minute"].exists)
        XCTAssertTrue(app.staticTexts["Almost done! Stand still for a minute to measure your heart rate recovery."].exists)
        XCTAssertTrue(app.staticTexts["Press to Start"].exists)
        
        // Capture heart rate
        runTest_HeartRateStep(app: app, progressLabel: step6Of6StaticText, feedbackLabel: app.staticTexts["Your heart rate changed to"])
        app.buttons["Next"].tap()
        
        // -- Completion
        XCTAssertTrue(app.staticTexts["Great job!"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Your heart rate changed by"].exists)
        XCTAssertTrue(app.staticTexts["BPM"].exists)
        app.buttons["Done"].tap()
    }
    
    func test12MT() {
        
        let app = XCUIApplication()
        let tablesQuery = app.tables
        tablesQuery/*@START_MENU_TOKEN@*/.staticTexts["Cardio 12MT"]/*[[".cells.staticTexts[\"Cardio 12MT\"]",".staticTexts[\"Cardio 12MT\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        
        // -- Introduction
        XCTAssertTrue(app.staticTexts["12 minute test"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["15 minutes"].exists)
        
        // Check learn more text
        app.buttons["infoIcon"].tap()
        let webViewsQuery = app.webViews
        XCTAssertTrue(webViewsQuery/*@START_MENU_TOKEN@*/.staticTexts["About 12 minute test"]/*[[".otherElements[\"Instructions\"]",".otherElements[\"About 12 minute test\"]",".staticTexts[\"1\"]",".staticTexts[\"About 12 minute test\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/.waitForExistence(timeout: 2))
        webViewsQuery/*@START_MENU_TOKEN@*/.staticTexts["Why this test"]/*[[".otherElements[\"Instructions\"]",".otherElements[\"Why this test\"]",".staticTexts[\"2\"]",".staticTexts[\"Why this test\"]"],[[[-1,3],[-1,1,2],[-1,0,1]],[[-1,3],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/.tap()
        webViewsQuery/*@START_MENU_TOKEN@*/.staticTexts["Recording a 12 minute test is an important measure of your overall health. It is associated with overall mortality and many common diseases in the US such as cardiovascular disease and Alzheimer’s Disease."]/*[[".otherElements[\"Instructions\"].staticTexts[\"Recording a 12 minute test is an important measure of your overall health. It is associated with overall mortality and many common diseases in the US such as cardiovascular disease and Alzheimer’s Disease.\"]",".staticTexts[\"Recording a 12 minute test is an important measure of your overall health. It is associated with overall mortality and many common diseases in the US such as cardiovascular disease and Alzheimer’s Disease.\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        webViewsQuery/*@START_MENU_TOKEN@*/.staticTexts["What to do"]/*[[".otherElements[\"Instructions\"]",".otherElements[\"What to do\"]",".staticTexts[\"2\"]",".staticTexts[\"What to do\"]"],[[[-1,3],[-1,1,2],[-1,0,1]],[[-1,3],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/.tap()
        
        // Continue to next step
        app.navigationBars.buttons["Close"].tap()
        XCTAssertTrue(app.staticTexts["12 minute test"].waitForExistence(timeout: 2))
        app.buttons["Start"].tap()
        
        // -- Heart risk
        let heartRiskInstruction = app.tables["Potential heart risk, Do not attempt this test if you have experienced unstable angina, a myocardial infarction (heart attack) during the previous month, need supplemental oxygen to walk, or if you feel that running or walking for 12 minutes will be a challenge for you."]
        XCTAssertTrue(heartRiskInstruction.waitForExistence(timeout: 2))
        app.buttons["Got it"].tap()
        
        // -- Step 1 - fitbit instruction
        XCTAssertTrue(app.staticTexts["Step 1 of 7"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Wearing your fitbit?"].exists)
        XCTAssertTrue(app.staticTexts["Before continuing on with the 12 minute test, please make sure you have your fitbit on your wrist."].exists)
        app.buttons["It’s on"].tap()
        
        // -- Step 2 - volume up instruction
        XCTAssertTrue(app.staticTexts["Step 2 of 7"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Volume turned up?"].exists)
        XCTAssertTrue(app.staticTexts["Bring your phone with you and turn up your phone volume so you can hear the instructions while you are moving."].exists)
        app.buttons["It’s turned on"].tap()
        
        // -- Step 3 - Go outside
        XCTAssertTrue(app.staticTexts["Step 3 of 7"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Go outside"].exists)
        XCTAssertTrue(app.staticTexts["Start by going oustide and standing still to measure your resting heart rate before you start moving."].exists)
        app.buttons["I am outside"].tap()
        
        // -- Step 4 - Heart rate before
        let step4Of7StaticText = app.staticTexts["Step 4 of 7"]
        XCTAssertTrue(step4Of7StaticText.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Capture heart rate"].exists)
        XCTAssertTrue(app.staticTexts["Use your finger to cover the camera and flash on the back of your phone."].exists)
        XCTAssertTrue(app.staticTexts["Press to Start"].exists)
        
        // Capture heart rate
        runTest_HeartRateStep(app: app, progressLabel: step4Of7StaticText, feedbackLabel: app.staticTexts["Your pre run heart rate is"])
        app.buttons["Next"].tap()
        
        // - Step 5 - Run
        let step5Of7StaticText = app.staticTexts["Step 5 of 7"]
        XCTAssertTrue(step5Of7StaticText.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Take your phone with you"].exists)
        XCTAssertTrue(app.staticTexts["Cover as much distance as you can on a flat course in 12 minutes by running or walking."].exists)
        app.buttons["runStartButton"].tap()
        
        // Countdown
        XCTAssertTrue(app.staticTexts["Start in"].waitForExistence(timeout: 2))
        XCTAssertTrue(step5Of7StaticText.exists)
        sleep(10)

        // Run
        sleep(720)
        
        // -- Step 6 - Heart rate after
        let step6Of7StaticText = app.staticTexts["Step 6 of 7"]
        XCTAssertTrue(step6Of7StaticText.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Stand still for 1 minute"].exists)
        XCTAssertTrue(app.staticTexts["Almost done! Stand still for a minute to measure your heart rate recovery."].exists)
        XCTAssertTrue(app.staticTexts["Press to Start"].exists)
        
        // Capture heart rate
        runTest_HeartRateStep(app: app, progressLabel: step6Of7StaticText, feedbackLabel: app.staticTexts["Your heart rate changed to"])
        app.buttons["Next"].tap()
        
        // -- Step 7 - survey
        XCTAssertTrue(tablesQuery.staticTexts["Step 7 of 7"].waitForExistence(timeout: 2))
        XCTAssertTrue(tablesQuery.otherElements["What, if anything, kept you from going further?"].exists)
        XCTAssertTrue(tablesQuery/*@START_MENU_TOKEN@*/.cells.staticTexts["Nothing, was my best effort"]/*[[".cells.staticTexts[\"Nothing, was my best effort\"]",".staticTexts[\"Nothing, was my best effort\"]"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/.exists)
        XCTAssertTrue(tablesQuery/*@START_MENU_TOKEN@*/.cells.staticTexts["Feeling tired"]/*[[".cells.staticTexts[\"Feeling tired\"]",".staticTexts[\"Feeling tired\"]"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/.exists)
        XCTAssertTrue(tablesQuery/*@START_MENU_TOKEN@*/.cells.staticTexts["Pain or physical discomfort"]/*[[".cells.staticTexts[\"Pain or physical discomfort\"]",".staticTexts[\"Pain or physical discomfort\"]"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/.exists)
        tablesQuery/*@START_MENU_TOKEN@*/.cells.staticTexts["Interrupted"]/*[[".cells.staticTexts[\"Interrupted\"]",".staticTexts[\"Interrupted\"]"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/.tap()
        app.buttons["Next"].tap()

        // -- Completion
        XCTAssertTrue(app.staticTexts["Great job!"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["You just went"].exists)
        XCTAssertTrue(app.staticTexts["in 12 minutes"].exists)
        app.buttons["Done"].tap()
    }
    
    func runTest_HeartRateStep(app: XCUIApplication, progressLabel: XCUIElement, feedbackLabel: XCUIElement) {
        
        let capturestartbuttonButton = app.buttons["captureStartButton"]
        capturestartbuttonButton.tap()

        let initialHeartRateText = app.staticTexts["Gently cover both the camera and flash with your finger."]
        let halfWayHeartRateText = app.staticTexts["You’re half way there!"]
        let fifteenLeftHeartRateText = app.staticTexts["Just 15 seconds left"]
        let allDoneHeartRateText = app.staticTexts["You’re all done!"]
        
        XCTAssertTrue(initialHeartRateText.waitForExistence(timeout: 5))
        XCTAssertTrue(progressLabel.exists)
        sleep(30)
        XCTAssertTrue(halfWayHeartRateText.waitForExistence(timeout: 5))
        sleep(10)
        XCTAssertTrue(fifteenLeftHeartRateText.waitForExistence(timeout: 10))
        sleep(10)
        XCTAssertTrue(allDoneHeartRateText.waitForExistence(timeout: 10))
        
        // Heart rate feedback
        let heartRate65 = app.staticTexts["65"]
        let bpmLabel = app.staticTexts["BPM"]
        
        XCTAssertTrue(feedbackLabel.waitForExistence(timeout: 5))
        XCTAssertTrue(progressLabel.exists)
        XCTAssertTrue(allDoneHeartRateText.exists)
        XCTAssertTrue(heartRate65.exists)
        XCTAssertTrue(bpmLabel.exists)
    }
}
