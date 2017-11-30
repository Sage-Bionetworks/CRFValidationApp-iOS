//
//  TableViewController.swift
//  CRFModuleTestApp
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
import ResearchSuite
import ResearchSuiteUI

class TableViewController: UITableViewController, RSDTaskViewControllerDelegate {

    var taskGroup: RSDTaskGroupObject!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up the factory
        RSDFactory.shared = CRFTaskFactory()
        
        // Set up a task group
        let taskRefs = ["Background_Survey", "Cardio_12MT", "Cardio_Stair_Step", "Cardio_Stress"]
        let tasks: [RSDTaskInfoStep] = taskRefs.map {
            var taskInfo = RSDTaskInfoStepObject(with: $0)
            taskInfo.title = $0.replacingOccurrences(of: "_", with: " ")
            taskInfo.taskTransformer = RSDResourceTransformerObject(resourceName: $0)
            return taskInfo
        }
        taskGroup = RSDTaskGroupObject(with: "all", tasks: tasks)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return taskGroup.tasks.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseId = "basic"
        var cell = tableView.dequeueReusableCell(withIdentifier: reuseId)
        if cell == nil {
            cell = UITableViewCell(style: .default, reuseIdentifier: reuseId)
        }
        cell!.textLabel!.text = taskGroup.tasks[indexPath.row].title
        return cell!
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let taskInfo = taskGroup.tasks[indexPath.row]
        let taskViewController = RSDTaskViewController(taskInfo: taskInfo)
        taskViewController.delegate = self
        
        self.present(taskViewController, animated: true, completion: nil)
    }

    // Mark: RSDTaskViewControllerDelegate
    
    let offMainQueue = DispatchQueue(label: "org.sagebase.CRFModule.Test")
    
    open func deleteOutputDirectory(_ outputDirectory: URL?) {
        guard let outputDirectory = outputDirectory else { return }
        do {
            try FileManager.default.removeItem(at: outputDirectory)
        } catch let error {
            print("Error removing ResearchKit output directory: \(error.localizedDescription)")
            debugPrint("\tat: \(outputDirectory)")
        }
    }
    
    func taskViewController(_ taskViewController: (UIViewController & RSDTaskController), didFinishWith reason: RSDTaskFinishReason, error: Error?) {
        
        // dismiss the view controller
        let outputDirectory = taskViewController.taskPath.outputDirectory
        taskViewController.dismiss(animated: true) {
            self.offMainQueue.async {
                self.deleteOutputDirectory(outputDirectory)
            }
        }
        
        var debugResult: String = taskViewController.taskPath.description
        
        if reason == .completed {
            do {
                let encoder = RSDFactory.shared.createJSONEncoder()
                let taskJSON = try taskViewController.taskPath.encodeResult(to: encoder)
                if let string = String(data: taskJSON, encoding: .utf8) {
                    debugResult.append("\n\n\(string)")
                }
            } catch let error {
                debugResult.append("\n\n=== Failed to encode the result: \(error)")
            }
        }
        else {
            debugResult.append("\n\n=== Failed: \(String(describing: error))")
        }
        
        debugPrint(debugResult)
    }
    
    func taskViewController(_ taskViewController: (UIViewController & RSDTaskController), viewControllerFor step: RSDStep) -> (UIViewController & RSDStepController)? {
        return nil
    }
    
    func taskViewController(_ taskViewController: (UIViewController & RSDTaskController), asyncActionControllerFor configuration: RSDAsyncActionConfiguration) -> RSDAsyncActionController? {
        return nil
    }
    
    func taskViewController(_ taskViewController: (UIViewController & RSDTaskController), readyToSave taskPath: RSDTaskPath) {
        // do nothing - This is just a test
    }
    
    func taskViewControllerShouldAutomaticallyForward(_ taskViewController: (UIViewController & RSDTaskController)) -> Bool {
        return true
    }
}
