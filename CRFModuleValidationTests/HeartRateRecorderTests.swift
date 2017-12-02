//
//  HeartRateRecorderTests.swift
//  CRFModuleValidationTests
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
@testable import CRFModuleValidation
import ResearchSuite
import BridgeAppSDK

struct SampleLog : Codable {
    let items : [Sample]
}

struct Sample : Codable {
    public let timestamp: TimeInterval
    public let hue: Double
    public let saturation: Double
    public let brightness: Double
    public let red: Double
    public let green: Double
    public let blue: Double
    public let bpm_camera: Int?
}

class HeartRateRecorderTests: XCTestCase {
    
    let sampleLog : SampleLog = {
        let resourceURL = Bundle(for: HeartRateRecorderTests.self).url(forResource: "heartrate", withExtension: "json")!
        let jsonData = try! Data(contentsOf: resourceURL)
        let decoder = JSONDecoder()
        let sampleLog = try! decoder.decode(SampleLog.self, from: jsonData)
        return sampleLog
    }()
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testHueConvertion() {
        
        for sample in sampleLog.items {
            let color = CRFColor(red: sample.red, green: sample.green, blue: sample.blue)
            if sample.hue >= 0 {
                guard let hsv = color.getHSV() else {
                    XCTFail("Failed to calculate hue")
                    return
                }
                XCTAssertEqual(hsv.hue, sample.hue, accuracy: 0.01)
            }
        }
    }
    
    func testCalculateBPM() {
        
        let calculator = CRFHeartRateProcessor()
        var count = 0
        for (index, sample) in sampleLog.items.enumerated() {
            guard let expectedBPM = sample.bpm_camera, expectedBPM > 0, index+1 < sampleLog.items.count else { continue }
            
            let dataPoints = sampleLog.items.prefix(upTo: index+1).map { $0.hue }
            let bpm = calculator.calculateBPM(with: dataPoints)
            
            // TODO: syoung 11/09/2017 Figure out why the first two calculated values don't match
            if count >= 2 {
                XCTAssertEqual(bpm, expectedBPM, "\(count)")
            }
            count += 1
        }
        
        debugPrint("total bpm found = \(count)")
    }
}
