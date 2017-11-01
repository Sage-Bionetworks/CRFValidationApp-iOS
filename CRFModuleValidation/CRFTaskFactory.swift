//
//  CRFTaskFactory.swift
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

import ResearchSuite

open class CRFTaskFactory: RSDFactory {
    
    public enum CRFStepType: String {
        case heartRate
    }
    
    open override func decodeStep(from decoder:Decoder, with typeName: String) throws -> RSDStep? {
        if let type = CRFStepType(rawValue: typeName) {
            return try decodeStep(from: decoder, with: type)
        } else {
            return try super.decodeStep(from: decoder, with: typeName)
        }
    }
    
    open func decodeStep(from decoder: Decoder, with type: CRFTaskFactory.CRFStepType) throws -> RSDStep? {
        switch type {
        case .heartRate:
            return try buildHeartRateStep(from: decoder)
        }
    }
    
    private func buildHeartRateStep(from decoder: Decoder) throws -> RSDStep {
        let taskInfo = try RSDTaskInfoStepObject(from: decoder)
        let task = try self.decodeTask(with: taskInfo.taskTransformer as!
            RSDResourceTransformer, taskInfo: taskInfo)
        var steps = (task.stepNavigator as! RSDConditionalStepNavigator).steps
        
        // Replace the title and text with the task info title and subtitle
        let firstStep = steps.first as! RSDUIStepObject
        firstStep.title = taskInfo.title ?? firstStep.title
        firstStep.text = taskInfo.text ?? firstStep.text
        steps.remove(at: 0)
        steps.insert(firstStep, at: 0)
        
        // Replace the detail the last step with the detail from the task info
        let lastStep = steps.popLast() as! RSDUIStepObject
        lastStep.detail = taskInfo.detail ?? lastStep.detail
        steps.append(lastStep)
        
        return RSDSectionStepObject(identifier: taskInfo.identifier, steps: steps)
    }
}
