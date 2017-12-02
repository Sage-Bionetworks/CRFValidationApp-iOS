//
//  BackgroundSurveyUITests.swift
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

extension XCUIElement {
    func hasFocus() -> Bool {
        return (self.value(forKey: "hasKeyboardFocus") as? Bool) ?? false
    }
}

class  BackgroundSurveyUITests: XCTestCase {
        
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
    
    func testBackgroundSurvey() {
        
        let app = XCUIApplication()
        let tablesQuery = app.tables
        let window = app.children(matching: .window).element(boundBy: 1)
        let nextButton = app.buttons["Next"]
        let keyboardNextButton = window.buttons["Next"]

        // Select the task
        tablesQuery/*@START_MENU_TOKEN@*/.cells.staticTexts["Background Survey"]/*[[".cells.staticTexts[\"Background Survey\"]",".staticTexts[\"Background Survey\"]"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/.tap()
        
        // -- Step 1 - birthdate
        XCTAssertTrue(tablesQuery.staticTexts["Step 1 of 10"].waitForExistence(timeout: 2))
        XCTAssertTrue(tablesQuery.otherElements["What is your birthdate?"].exists)
        
        // Check that the keyboard "Next" button is *not* enabled
        XCTAssertFalse(keyboardNextButton.isEnabled)

        // Enter year
        let yearField = tablesQuery.cells.containing(.staticText, identifier:"Year").children(matching: .textField).element
        XCTAssertTrue(yearField.hasFocus())
        yearField.typeText("1971")
        keyboardNextButton.tap()
        
        // Enter invalid month
        let monthField = tablesQuery.cells.containing(.staticText, identifier:"Month").children(matching: .textField).element
        XCTAssertTrue(monthField.hasFocus())
        monthField.typeText("80")
        keyboardNextButton.tap()
        
        // Check that entering a month outside range pops an alert
        let alertsQuery = app.alerts
        XCTAssertTrue(alertsQuery.staticTexts["The number entered is more than 12."].exists)
        let okButton = alertsQuery.buttons["OK"]
        okButton.tap()
        
        // Enter valid month and tap next
        monthField.typeText("8")
        keyboardNextButton.tap()
        
        
        // -- Step 2 - sex
        XCTAssertTrue(tablesQuery.staticTexts["Step 2 of 10"].waitForExistence(timeout: 2))
        XCTAssertTrue(tablesQuery.otherElements["What is your sex?"].exists)
        XCTAssertTrue(tablesQuery/*@START_MENU_TOKEN@*/.cells.staticTexts["Male"]/*[[".cells.staticTexts[\"Male\"]",".staticTexts[\"Male\"]"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/.exists)
        let femaleCell = tablesQuery/*@START_MENU_TOKEN@*/.cells.staticTexts["Female"]/*[[".cells.staticTexts[\"Female\"]",".staticTexts[\"Female\"]"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/
        XCTAssertTrue(femaleCell.exists)

        // Button should be disabled before selection
        XCTAssertFalse(nextButton.isEnabled)

        // Make a selection and then tap the next button
        femaleCell.tap()
        nextButton.tap()
        
        // -- Step 3 - Hispanic or Latino
        XCTAssertTrue(tablesQuery.staticTexts["Step 3 of 10"].waitForExistence(timeout: 2))
        XCTAssertTrue(tablesQuery.otherElements["Are you of Hispanic or Latino origin?"].exists)
        let yesCell = tablesQuery/*@START_MENU_TOKEN@*/.cells.staticTexts["Yes"]/*[[".cells.staticTexts[\"Yes\"]",".staticTexts[\"Yes\"]"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/
        let noCell = tablesQuery/*@START_MENU_TOKEN@*/.cells.staticTexts["No"]/*[[".cells.staticTexts[\"No\"]",".staticTexts[\"No\"]"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/
        XCTAssertTrue(yesCell.exists)
        XCTAssertTrue(noCell.exists)
        
        // Button should be disabled before selection
        XCTAssertFalse(nextButton.isEnabled)
        
        // Make a selection and then tap the next button
        noCell.tap()
        nextButton.tap()

        // -- Step 4 - race
        XCTAssertTrue(tablesQuery.staticTexts["Step 4 of 10"].waitForExistence(timeout: 2))
        XCTAssertTrue(tablesQuery.otherElements["Which race best describes you?"].exists)
        XCTAssertTrue(tablesQuery.staticTexts["(select all that apply)"].exists)
        
        let whiteOrCaucasionStaticText = tablesQuery/*@START_MENU_TOKEN@*/.cells.staticTexts["White or Caucasian"]/*[[".cells.staticTexts[\"White or Caucasian\"]",".staticTexts[\"White or Caucasian\"]"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/
        XCTAssertTrue(whiteOrCaucasionStaticText.exists)
        XCTAssertFalse(whiteOrCaucasionStaticText.isSelected)
        
        let blackOrAfricanAmericanStaticText = tablesQuery/*@START_MENU_TOKEN@*/.cells.staticTexts["Black or African American"]/*[[".cells.staticTexts[\"Black or African American\"]",".staticTexts[\"Black or African American\"]"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/
        XCTAssertTrue(blackOrAfricanAmericanStaticText.exists)
        XCTAssertFalse(blackOrAfricanAmericanStaticText.isSelected)
        
        let nativeHawaiianOrOtherPacificIslanderStaticText = tablesQuery/*@START_MENU_TOKEN@*/.cells.staticTexts["Native Hawaiian or other Pacific Islander"]/*[[".cells.staticTexts[\"Native Hawaiian or other Pacific Islander\"]",".staticTexts[\"Native Hawaiian or other Pacific Islander\"]"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/
        XCTAssertTrue(nativeHawaiianOrOtherPacificIslanderStaticText.exists)
        XCTAssertFalse(nativeHawaiianOrOtherPacificIslanderStaticText.isSelected)
        
        let asianStaticText = tablesQuery/*@START_MENU_TOKEN@*/.cells.staticTexts["Asian"]/*[[".cells.staticTexts[\"Asian\"]",".staticTexts[\"Asian\"]"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/
        XCTAssertTrue(asianStaticText.exists)
        XCTAssertFalse(asianStaticText.isSelected)
        
        let otherStaticText = tablesQuery/*@START_MENU_TOKEN@*/.cells.staticTexts["Other"]/*[[".cells.staticTexts[\"Other\"]",".staticTexts[\"Other\"]"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/
        XCTAssertTrue(otherStaticText.exists)
        XCTAssertFalse(otherStaticText.isSelected)
        
        // Button should be disabled before selection
        XCTAssertFalse(nextButton.isEnabled)
        
        // Select a choice and tap next
        whiteOrCaucasionStaticText.tap()
        nextButton.tap()
        
        // -- Step 4 - race
        XCTAssertTrue(tablesQuery.staticTexts["Step 5 of 10"].waitForExistence(timeout: 2))
        tablesQuery.otherElements["What is the highest grade in school you have finished?"].tap()
        tablesQuery.staticTexts["(select one)"].tap()
        tablesQuery/*@START_MENU_TOKEN@*/.cells.staticTexts["Did not finish elementary school"]/*[[".cells.staticTexts[\"Did not finish elementary school\"]",".staticTexts[\"Did not finish elementary school\"]"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/.tap()
        tablesQuery/*@START_MENU_TOKEN@*/.cells.staticTexts["Finished middle school (8th grade)"]/*[[".cells.staticTexts[\"Finished middle school (8th grade)\"]",".staticTexts[\"Finished middle school (8th grade)\"]"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/.tap()
        tablesQuery/*@START_MENU_TOKEN@*/.cells.staticTexts["Finished some high school"]/*[[".cells.staticTexts[\"Finished some high school\"]",".staticTexts[\"Finished some high school\"]"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/.tap()
        tablesQuery/*@START_MENU_TOKEN@*/.cells.staticTexts["High school graduate or G.E.D"]/*[[".cells.staticTexts[\"High school graduate or G.E.D\"]",".staticTexts[\"High school graduate or G.E.D\"]"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/.tap()
        
        let vocationalOrTrainingSchoolAfterHighSchoolStaticText = tablesQuery/*@START_MENU_TOKEN@*/.cells.staticTexts["Vocational or training school after high school"]/*[[".cells.staticTexts[\"Vocational or training school after high school\"]",".staticTexts[\"Vocational or training school after high school\"]"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/
        vocationalOrTrainingSchoolAfterHighSchoolStaticText.swipeUp()
        tablesQuery/*@START_MENU_TOKEN@*/.cells.staticTexts["Some College or Associate degree"]/*[[".cells.staticTexts[\"Some College or Associate degree\"]",".staticTexts[\"Some College or Associate degree\"]"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/.tap()
        
        let collegeGraduateOrBaccalaureateDegreeStaticText = tablesQuery/*@START_MENU_TOKEN@*/.cells.staticTexts["College graduate or Baccalaureate Degree"]/*[[".cells.staticTexts[\"College graduate or Baccalaureate Degree\"]",".staticTexts[\"College graduate or Baccalaureate Degree\"]"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/
        collegeGraduateOrBaccalaureateDegreeStaticText.swipeUp()
        
        tablesQuery/*@START_MENU_TOKEN@*/.cells.staticTexts["Masters or Doctoral Degree (PhD, MD, JD, etc)"]/*[[".cells.staticTexts[\"Masters or Doctoral Degree (PhD, MD, JD, etc)\"]",".staticTexts[\"Masters or Doctoral Degree (PhD, MD, JD, etc)\"]"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/.tap()
        nextButton.tap()
        
        // -- Step 6 - IPAQ instruction
        let ipaq_instruction = app.tables["Step 6 of 10, INTERNATIONAL PHYSICAL ACTIVITY QUESTIONNAIRE, We are interested in finding out about the kinds of physical activities that people do as part of their everyday lives.  The questions will ask you about the time you spent being physically active in the last 7 days.  Please answer each question even if you do not consider yourself to be an active person.  Please think about the activities you do at work, as part of your house and yard work, to get from place to place, and in your spare time for recreation, exercise or sport."]
        XCTAssertTrue(ipaq_instruction.waitForExistence(timeout: 2))
        nextButton.tap()
        
        // -- Step 7 - vigorous activity
        let step7Of10StaticText = tablesQuery.staticTexts["Step 7 of 10"]
        XCTAssertTrue(step7Of10StaticText.waitForExistence(timeout: 2))
        let vigorous_instruction =
        tablesQuery.otherElements["Think about all the VIGOROUS activities that you did in the last 7 days. Vigorous physical activities refer to activities that take hard physical effort and make you breathe much harder than normal. Think only about those physical activities that you did for at least 10 minutes at a time.\n\nDuring the last 7 days, have you done any VIGOROUS physical activities like heavy lifting, digging, aerobics, or fast bicycling?"]
        XCTAssertTrue(vigorous_instruction.exists)
        
        // Select "Yes" and continue
        XCTAssertTrue(tablesQuery/*@START_MENU_TOKEN@*/.cells.staticTexts["No vigorous physical activities"]/*[[".cells.staticTexts[\"No vigorous physical activities\"]",".staticTexts[\"No vigorous physical activities\"]"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/.exists)
        tablesQuery/*@START_MENU_TOKEN@*/.staticTexts["Yes, I have done vigorous activities"]/*[[".cells.staticTexts[\"Yes, I have done vigorous activities\"]",".staticTexts[\"Yes, I have done vigorous activities\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        nextButton.tap()

        // Check that the next question asks about number of days and that the step number is the same
        XCTAssertTrue(tablesQuery.otherElements["During the last 7 days, on how many days did you do VIGOROUS physical activities?"].waitForExistence(timeout: 2))
        XCTAssertTrue(step7Of10StaticText.exists)
        
        // Enter a value and tap the next button
        let textField2 = tablesQuery.cells.children(matching: .textField).element
        textField2.typeText("5")
        keyboardNextButton.tap()
        
        // Check that the next question asks about number of hours and that the step number is the same
        XCTAssertTrue(tablesQuery.otherElements["How much time did you usually spend doing VIGOROUS physical activities on one of those days?"].waitForExistence(timeout: 2))
        app.swipeDown()
        XCTAssertTrue(step7Of10StaticText.exists)

        let hoursPerDayStaticText = tablesQuery/*@START_MENU_TOKEN@*/.cells.staticTexts["hours per day"]/*[[".cells.staticTexts[\"hours per day\"]",".staticTexts[\"hours per day\"]"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/
        let minutesPerDayStaticText = tablesQuery/*@START_MENU_TOKEN@*/.cells.staticTexts["minutes per day"]/*[[".cells.staticTexts[\"minutes per day\"]",".staticTexts[\"minutes per day\"]"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/
        XCTAssertTrue(hoursPerDayStaticText.exists)
        XCTAssertTrue(minutesPerDayStaticText.exists)
        
        // Enter a value and tap the next button
        let textField3 = tablesQuery.cells.containing(.staticText, identifier:"hours per day").children(matching: .textField).element
        textField3.typeText("1")
        keyboardNextButton.tap()
        keyboardNextButton.tap()
        
        // -- Step 8 - moderate activity
        let step8Of10StaticText = tablesQuery.staticTexts["Step 8 of 10"]
        XCTAssertTrue(step8Of10StaticText.waitForExistence(timeout: 2))
        let moderateInstruction = tablesQuery.otherElements["Think about all the MODERATE activities that you did in the last 7 days. Moderate activities refer to activities that take moderate physical effort and make you breathe somewhat harder than normal. Think only about those physical activities that you did for at least 10 minutes at a time.\n\nDuring the last 7 days, have you done any MODERATE physical activities like carrying light loads, bicycling at a regular pace, or doubles tennis?  Do not include walking."]
        XCTAssertTrue(moderateInstruction.exists)
        tablesQuery/*@START_MENU_TOKEN@*/.cells.staticTexts["No moderate physical activities"]/*[[".cells.staticTexts[\"No moderate physical activities\"]",".staticTexts[\"No moderate physical activities\"]"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/.tap()
        tablesQuery/*@START_MENU_TOKEN@*/.cells.staticTexts["Yes, I have done moderate activities"]/*[[".cells.staticTexts[\"Yes, I have done moderate activities\"]",".staticTexts[\"Yes, I have done moderate activities\"]"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/.tap()
        nextButton.tap()
        
        // Number of days
        XCTAssertTrue(tablesQuery.otherElements["During the last 7 days, on how many days did you do MODERATE physical activities?"].waitForExistence(timeout: 2))
        XCTAssertTrue(step8Of10StaticText.exists)
        XCTAssertTrue(tablesQuery.staticTexts["Do not include walking."].exists)
        textField2.typeText("2")
        keyboardNextButton.tap()

        // hours and minutes per day
        XCTAssertTrue(tablesQuery.otherElements["How much time did you usually spend doing MODERATE physical activities on one of those days?"].waitForExistence(timeout: 2))
        textField3.swipeDown()
        XCTAssertTrue(step8Of10StaticText.exists)
        XCTAssertTrue(hoursPerDayStaticText.exists)
        XCTAssertTrue(minutesPerDayStaticText.exists)
        
        // Enter values and continue
        textField3.typeText("1")
        let textField4 = tablesQuery.cells.containing(.staticText, identifier:"minutes per day").children(matching: .textField).element
        textField3.swipeUp()
        textField4.tap()
        textField4.typeText("30")
        keyboardNextButton.tap()
        
        // -- Step 9 - walking activity
        let step9Of10StaticText = tablesQuery.staticTexts["Step 9 of 10"]
        XCTAssertTrue(step9Of10StaticText.waitForExistence(timeout: 2))
        let walkingInstructions = tablesQuery.otherElements["Think about the time you spent WALKING in the last 7 days.  This includes at work and at home, walking to travel from place to place, and any other walking that you have done solely for recreation, sport, exercise, or leisure.\n\nDuring the last 7 days, have you WALKED for at least 10 minutes at a time?"]
        XCTAssertTrue(walkingInstructions.exists)

        // Make a selection and continue
        tablesQuery/*@START_MENU_TOKEN@*/.cells.staticTexts["No walking"]/*[[".cells.staticTexts[\"No walking\"]",".staticTexts[\"No walking\"]"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/.tap()
        tablesQuery/*@START_MENU_TOKEN@*/.cells.staticTexts["Yes, I have walked"]/*[[".cells.staticTexts[\"Yes, I have walked\"]",".staticTexts[\"Yes, I have walked\"]"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/.tap()
        nextButton.tap()
        
        // days per week
        XCTAssertTrue(tablesQuery.otherElements["During the last 7 days, on how many days did you WALK for at least 10 minutes at a time?"].waitForExistence(timeout: 2))
        XCTAssertTrue(step9Of10StaticText.exists)
        textField2.typeText("5")
        keyboardNextButton.tap()
        
        // hours and minutes
        XCTAssertTrue(tablesQuery.otherElements["How much time did you usually spend WALKING on one of those days?"].waitForExistence(timeout: 2))
        hoursPerDayStaticText.swipeDown()
        XCTAssertTrue(step9Of10StaticText.exists)
        XCTAssertTrue(hoursPerDayStaticText.exists)
        XCTAssertTrue(minutesPerDayStaticText.exists)
        textField3.typeText("2")
        textField4.tap()
        textField4.typeText("30")
        keyboardNextButton.tap()
        
        // -- Step 10 - sitting
        XCTAssertTrue(tablesQuery.staticTexts["Step 10 of 10"].waitForExistence(timeout: 2))
        let sittingInstruction = app.tables["Step 10 of 10, The last question is about the time you spent SITTING on weekdays during the last 7 days.  Include time spent at work, at home, while doing course work and during leisure time.  This may include time spent sitting at a desk, visiting friends, reading, or sitting or lying down to watch television."]
        XCTAssertTrue(sittingInstruction.waitForExistence(timeout: 2))
        nextButton.tap()
        
        XCTAssertTrue(tablesQuery.otherElements["During the last 7 days, how much time did you spend SITTING on a week day?"].waitForExistence(timeout: 2))
        XCTAssertTrue(tablesQuery.staticTexts["Step 10 of 10"].exists)
        XCTAssertTrue(hoursPerDayStaticText.exists)
        XCTAssertTrue(minutesPerDayStaticText.exists)
        textField3.typeText("5")
        window.buttons["Done"].tap()
    }
    
}
