//
//  TaskGroupTableViewController.swift
//  JourneyPRO
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

class BaseTaskGroupTableViewController: UITableViewController, SBAScheduledActivityManagerDelegate {
    
    static let storyboardName = "Main"
    static let cellIdentifier = "ChallengeTableViewCell"
    
    var scheduledActivityDataSource: SBAScheduledActivityDataSource {
        return scheduledActivityManager
    }
    
    lazy var scheduledActivityManager : GroupedScheduledActivityManager = {
        return GroupedScheduledActivityManager(delegate: self)
    }()
    
    func reloadFinished(_ sender: Any?) {
        // reload table
        self.refreshControl?.endRefreshing()
        self.tableView.reloadData()
    }
    
    func dequeueReusableCell(in tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: BaseTaskGroupTableViewController.cellIdentifier, for: indexPath)
    }
    
    func configure(groupedCell: ChallengeTableViewCell, for schedule:SBBScheduledActivity) {
        
        groupedCell.titleLabel.text = schedule.activity.label
        
        if let taskReference = scheduledActivityManager.bridgeInfo.taskReferenceForSchedule(schedule) {
            groupedCell.iconImageView.image = taskReference.activityIcon
        } else {
            groupedCell.iconImageView.isHidden = true
        }
        
        // The default text on the subtitle label will be complete: [date], so override it
        if (schedule.isCompleted) {
            groupedCell.subtitleLabel?.text = Localization.localizedString("JP_COMPLETED_TITLE")
            groupedCell.subtitleLabel?.textColor = UIColor(named: "darkPastelGreen")!
            groupedCell.checkmarkImageView?.isHidden = false
        } else {
            groupedCell.subtitleLabel?.text = schedule.activity.labelDetail
            groupedCell.subtitleLabel?.textColor = UIColor(named: "black54")
            groupedCell.checkmarkImageView?.isHidden = true
        }
    }
    
    // Mark: UITableViewController overrides
    
    override open func numberOfSections(in tableView: UITableView) -> Int {
        return scheduledActivityDataSource.numberOfSections()
    }
    
    override open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return scheduledActivityDataSource.numberOfRows(for: section)
    }
    
    override open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = dequeueReusableCell(in: tableView, at: indexPath)
        
        guard let groupedCell = cell as? ChallengeTableViewCell,
            let schedule = scheduledActivityDataSource.scheduledActivity(at: indexPath) else {
                return cell
        }
        
        configure(groupedCell: groupedCell, for: schedule)
        
        return cell
    }
}

//class AddActivityTableViewController: BaseTaskGroupTableViewController {
//    
//    static let storyboardIdentifier = "AddActivityTableViewController"
//    
//    var activitiesNotAvailable: Bool {
//        return super.tableView(self.tableView, numberOfRowsInSection: 0) == 0
//    }
//    
//    override func viewDidLayoutSubviews() {
//        super.viewDidLayoutSubviews()
//        
//        // Adjust the height of the headerView to full size.
//        // This will be faded in and then the table view will animate
//        // up from the bottom.
//        if self.tableView.tableHeaderView!.bounds.size.height != self.view.bounds.size.height {
//            let headerView = self.tableView.tableHeaderView
//            headerView?.frame = self.view.bounds
//            self.tableView.tableHeaderView = headerView
//        }
//    }
//    
//    override func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//        
//        self.tableView.backgroundColor = UIColor.clear
//        self.tableView.superview?.backgroundColor = UIColor.clear
//    }
//    
//    override func viewDidAppear(_ animated: Bool) {
//        super.viewDidAppear(animated)
//        
//        // Adjust cell height if needed
//        let count = scheduledActivityManager.taskGroup.taskIdentifiers.count
//        let maxCellHeight = (self.view.bounds.size.height - 20) / CGFloat(count + 1)
//        if maxCellHeight < 70 {
//            self.tableView.rowHeight = maxCellHeight
//        }
//        
//        // scroll to bottom
//        let numRows = self.tableView(self.tableView, numberOfRowsInSection: 0)
//        guard numRows > 0 else { return }
//        let lastRow = numRows - 1
//        self.tableView.scrollToRow(at: IndexPath(row: lastRow, section: 0), at: .bottom, animated: true)
//        self.tableView.isScrollEnabled = false
//    }
//    
//    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//        if self.activitiesNotAvailable {
//            return 1
//        } else {
//            return super.tableView(tableView, numberOfRowsInSection: section)
//        }
//    }
//    
//    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//        if self.activitiesNotAvailable {
//            let cell = self.tableView.dequeueReusableCell(withIdentifier: "ActivitiesNotAvailable", for: indexPath)
//            cell.textLabel?.font = UIFont.appTextStyleFont()
//            cell.textLabel?.textColor = UIColor.red
//            return cell
//        } else {
//            return super.tableView(tableView, cellForRowAt: indexPath)
//        }
//    }
//    
//    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
//        if self.activitiesNotAvailable {
//            return false
//        }
//        return true
//    }
//
//    override func configure(groupedCell: ChallengeTableViewCell, for schedule: SBBScheduledActivity) {
//        super.configure(groupedCell: groupedCell, for: schedule)
//        guard let taskId = schedule.taskId else { return }
//        
//        // Custom strings for the titles
//        // NOTE: Do not add the word "Start" on the activities. This does not fit on an iPhone SE.
//        switch taskId {
//        case .labDetails:
//            groupedCell.titleLabel.text = Localization.localizedString("JP_ADD_LAB_DETAILS")
//            
//        case .transfusionDetails:
//            groupedCell.titleLabel.text = Localization.localizedString("JP_ADD_TRANSFUSION_DETAILS")
//                
//        case .anemiaPrescription:
//            groupedCell.titleLabel.text = Localization.localizedString("JP_ADD_PRESCRIPTION_CHANGES")
//            
//        default:
//            break
//        }
//    }
//    
//    @IBAction func headerTapped(_ sender: Any) {
//        dismiss(animated: true, completion: nil)
//    }
//    
//    override open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        if  let schedule = scheduledActivityDataSource.scheduledActivity(at: indexPath),
//            let vc = MasterScheduledActivityManager.shared.createTaskViewController(for: schedule),
//            let parentVC = self.presentingViewController
//        {
//            dismiss(animated: true, completion: {
//                vc.modalTransitionStyle = .crossDissolve
//                parentVC.present(vc, animated: true, completion: nil)
//            })
//        }
//        
//        tableView.deselectRow(at: indexPath, animated: true)
//    }
//}

class TaskGroupTableViewController: BaseTaskGroupTableViewController {

    @IBOutlet weak var tableHeaderView: UIView!
    @IBOutlet weak var headerIconView: UIImageView!
    @IBOutlet weak var headerTitleLabel: UILabel!
    @IBOutlet weak var headerDetailLabel: UILabel!
    @IBOutlet weak var headerDescriptionLabel: UILabel!
    @IBOutlet weak var tableFooterView: UIView!
    @IBOutlet weak var tableFooterButton: SBAUnderlinedButton?
    @IBOutlet weak var doneButton: SBARoundedButton!
    
    var isFirstAppearance: Bool = true
    var isCompletedOnFirstLoad = false
    var isVisible: Bool = false
    var hasFiredTimingSchedule: Bool = false
    
    static let className = String(describing: TaskGroupTableViewController.self)
    
    class func instantiate(taskGroup: TaskGroup, date: Date, activities: [SBBScheduledActivity]) -> TaskGroupTableViewController? {
        guard let taskGroupVc = UIStoryboard(name: SBAMainStoryboardName, bundle: nil).instantiateViewController(withIdentifier: TaskGroupTableViewController.className) as? TaskGroupTableViewController else {
            return nil
        }
        taskGroupVc.scheduledActivityManager.date = date
        taskGroupVc.scheduledActivityManager.taskGroup = taskGroup
        taskGroupVc.scheduledActivityManager.activities = activities
        
        return taskGroupVc
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.white
        tableView.separatorStyle = .none
        
        setupHeaderAndFooter()
    }
    
    func setupHeaderAndFooter() {
        tableHeaderView.backgroundColor = UIColor.white
        
        headerTitleLabel.textColor = UIColor.black
        headerTitleLabel.text = scheduledActivityManager.taskGroup.title
        
        headerDetailLabel.textColor = UIColor.black
        headerDetailLabel.text = ""  // set this when we load the data
        
        headerDescriptionLabel.textColor = UIColor(named: "black54")
        headerDescriptionLabel.text = scheduledActivityManager.taskGroup.groupDescription ?? ""
        
        headerIconView.image = scheduledActivityManager.taskGroup.iconImage
        
        tableFooterButton?.setTitle(Localization.localizedString("JP_REMIND_ME_LATER_TITLE"), for: .normal)
        tableFooterButton?.addTarget(self, action: #selector(remindMeLaterTapped(sender:)), for: .touchUpInside)
        tableFooterButton?.textColor = UIColor(named: "blueyGrey") ?? UIColor.darkText
        tableFooterButton?.isHidden = true
        
        doneButton.shadowColor = UIColor.roundedButtonBackgroundDark
        doneButton.shadowColor = UIColor.roundedButtonShadowDark
        doneButton.titleColor = UIColor.roundedButtonTextLight
    }
    
    @IBAction func remindMeLaterTapped(sender: UIButton!) {
        // Instead of an action sheet, just show the scheduling task to allow setting day of week as well as time of day
        _exitOnDidAppear = true
        guard let vc =  self.scheduledActivityManager.createTimingTaskViewController()
        else {
            self.dismiss(animated: true, completion: nil)
            return
        }
        present(vc, animated: true, completion: nil)
    }

    
    @IBAction func doneTapped(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    private var _exitOnDidAppear = false
    private var _popDismissCompletion: (() -> Void)?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard !_exitOnDidAppear else { return }
        
        title = scheduledActivityManager.taskGroup.title
        updateHeaderAndFooter()
        
        isCompletedOnFirstLoad = isFirstAppearance && self.scheduledActivityManager.allActivitiesCompleted
        isFirstAppearance = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isVisible = true
        
        if _exitOnDidAppear {
            self.dismiss(animated: false, completion: nil)
        }
        else {
            showReminderScheduleIfNeeded()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isVisible = false
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        _popDismissCompletion?()
        _popDismissCompletion = nil
    }
    
    override open func reloadFinished(_ sender: Any?) {
        super.reloadFinished(sender)
        updateHeaderAndFooter()
        showReminderScheduleIfNeeded()
    }
    
    func showReminderScheduleIfNeeded() {
        if !isCompletedOnFirstLoad && self.scheduledActivityManager.allActivitiesCompleted && isVisible,
            self.scheduledActivityManager.shouldFireTimingSchedule,
            let vc =  self.scheduledActivityManager.createTimingTaskViewController() {
            present(vc, animated: true, completion: nil)
        }
    }
    
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        if self.presentedViewController == nil && self.presentingViewController == nil {
            self.navigationController?.popViewController(animated: flag)
            _popDismissCompletion = completion
        }
        else {
            super.dismiss(animated: flag, completion: completion)
        }
    }
    
    func updateHeaderAndFooter() {
        
        let isFinished = self.scheduledActivityManager.allActivitiesCompleted
        if isFinished {
            tableFooterButton?.removeFromSuperview()
        }
        doneButton.isEnabled = self.scheduledActivityManager.allActivitiesCompleted
        
        let numberOfActivities = scheduledActivityDataSource.numberOfRows(for: 0)
        // Loop through all the activities displayed and grab their labels,
        // as their labels contains the estimated time it takes to complete each one
        var minutesTotal = 0
        for i in 0 ..< numberOfActivities {
            let indexPath = IndexPath(item: i, section: 0)
            if  let schedule = scheduledActivityDataSource.scheduledActivity(at: indexPath),
                let taskReference = scheduledActivityManager.bridgeInfo.taskReferenceForSchedule(schedule)
            {
                minutesTotal += taskReference.activityMinutes
            }
        }
        
        let minutesFormatter = DateComponentsFormatter()
        minutesFormatter.unitsStyle = .full
        minutesFormatter.allowedUnits = [.minute]
        let minutesStr = minutesFormatter.string(from: TimeInterval(minutesTotal * 60))!.lowercased()
        
        let subtitle = String.localizedStringWithFormat("%@", minutesStr)
        headerDetailLabel.text = subtitle
    }
    
    override open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if  let schedule = scheduledActivityDataSource.scheduledActivity(at: indexPath),
            let vc = scheduledActivityManager.createRSDTaskViewController(for: schedule)
        {
            // The transition delegate should execute off the center of the cell in the view
            // Get the cell rect and adjust it to consider scroll offset
            var cellRect = self.tableView.rectForRow(at: indexPath)
            cellRect = cellRect.offsetBy(dx: -tableView.contentOffset.x, dy: -tableView.contentOffset.y)
            
            vc.modalTransitionStyle = .crossDissolve
            
            present(vc, animated: true, completion: nil)
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
