//
//  MyJourneyViewController.swift
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
import BridgeSDK
import BridgeAppSDK
import ResearchUXFactory

fileprivate let taskGroupViewControllerSegue = "taskGroupSegue"
fileprivate let addActivitySegue = "addActivitySegue"

fileprivate enum MyJourneyCellIdentifier: String {
    case todayHeader = "TodayHeaderCell"
    case scheduleSection = "ScheduleSectionCell"
    case separator = "SeparatorCell"
    case date = "DateCell"
}

class MyJourneyViewController: UIViewController, SBALoadingViewPresenter, UITableViewDelegate, UITableViewDataSource, SBAScheduledActivityManagerDelegate {
    
    @IBOutlet var preferredSizeView: UIView!
    @IBOutlet var firstDayHeaderView: UIView!
    @IBOutlet var tableView: UITableView!
    @IBOutlet var footerView: MyJourneyFooterView!
    
    lazy var scheduledActivityManager : MasterScheduledActivityManager = {
        return MasterScheduledActivityManager(delegate: self)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Hide the views on first load
        self.firstDayHeaderView.isHidden = true
        self.tableView.isHidden = true
    }
    
    
    // MARK: Load and reload - view refresh
    
    var isVisible = false
    var shouldScrollToToday = false
    var shouldAnimateCompletion = false
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        debugPrint("-- MyJourneyViewController.viewWillAppear")
        
        // Set self as the delegate for the schedule manager to listen for changes
        scheduledActivityManager.delegate = self
        
        // Reload on view will appear
        self.reloadFinished(nil)
        
        // Fire request to update the schedules (this will be ignored if already running)
        scheduledActivityManager.reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        isVisible = true
        if shouldScrollToToday {
            scrollToTodayIfNeeded()
        }
        
        // TODO emm 2017-11-11 decide if we need this
//        if let deepLinkTaskGroup = scheduledActivityManager.deepLinkTaskGroup,
//            let deepLinkTaskId = deepLinkTaskGroup.taskIdentifiers.first {
//            // We should show a loading dialog to convey to the user that we are
//            // automatically sending them somewhere after everything has loaded
//            self.showLoadingView()
//            scheduledActivityManager.notifyWhenTaskIsAvailable(taskId: deepLinkTaskId.rawValue, callback: { [weak self] (taskId) in
//                self?.hideLoadingView()
//                self?.sendUserToDeepLinkTasGroup()
//            })
//        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isVisible = false
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let headerView = self.tableView.tableHeaderView!
        headerView.frame = self.firstDayHeaderView.bounds
        self.tableView.tableHeaderView = headerView
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func getLatestSchedules() -> [ScheduleSection] {
        return scheduledActivityManager.scheduleSections.reversed()
    }
    
    func reloadFinished(_ sender: Any?) {
        let newSchedules = getLatestSchedules()
        guard newSchedules.count > 0,
            newSchedules != scheduleSections,
            let dayOne = scheduledActivityManager.dayOne
        else {
            debugPrint("-- reloadFinished(\(String(describing:sender)). Exit early with \(newSchedules.count) schedules and scheduledActivityManager.dayOne is \(String(describing:scheduledActivityManager.dayOne)).")
            return
        }
        
        // Reset stored values (that are expensive to calculate) if the day has changed
        if !Calendar.gregorian.isDateInToday(today) {
            today = Date()
            scheduleSections = []
        }
        
        // Check if this is the first load before setting the schedule
        let isFirstLoad = (scheduleSections.count == 0)
        
        // Set up the schedule management
        scheduleSections = newSchedules
        isFirstDay = Calendar.gregorian.isDateInToday(dayOne)
        todaySectionIndex = {
            if let inTodayIdx = scheduleSections.index(where: { Calendar.gregorian.isDateInToday($0.date) }) {
                // If there is an activity scheduled for today then include it as the today schedule.
                return inTodayIdx
            }
            else if let inYesterdayIdx = scheduleSections.index(where: { Calendar.gregorian.isDateInToday($0.date.addingNumberOfDays(1)) })
            {
                // If there was a survey scheduled for yesterday, then look to see if the day is the overlap day
                // such that the last clinic visit could be run *before* 14 days out.
                if inYesterdayIdx == 1, scheduleSections[inYesterdayIdx].isCompleted {
                    return 0
                } else {
                    return inYesterdayIdx
                }
            }
            else {
                // return day 14 (or first day if the other schedules aren't loaded)
                return 0
            }
        }()
        
        // set up values associated with first load
        if isFirstLoad {
            
            // Setup today detail and header visibility
            buildTodayDetailText()
        }
        self.firstDayHeaderView.isHidden = !shouldShowFirstDayOnly
        
        // Set up state for completion animation
        if scheduleSections[todaySectionIndex].isCompleted {
            if isFirstLoad {
                // This is a reload with a completed day. Start with completed
                isTodayFullSize = false
                shouldAnimateCompletion = false
                self.firstDayHeaderView.isHidden = true
            }
            else {
                // otherwise, set a flag to animate the completion
                shouldAnimateCompletion = true
            }
        }
        else {
            isTodayFullSize = true
        }
        
        // load the table
        self.tableView.reloadData()
        scrollToTodayIfNeeded(isFirstLoad && !self.tableView.isHidden)
        
        // Update footer text
        let dateText = DateFormatter.localizedString(from: dayOne, dateStyle: .medium, timeStyle: .none)
        self.footerView.textLabel.text = Localization.localizedStringWithFormatKey("You started the study on %@", dateText)
        
        let version = Bundle.main.versionString
        let build = Bundle.main.appVersion()
        let externalID = self.scheduledActivityManager.user.externalId ?? "Unknown"
        self.footerView.versionLabel.text = Localization.localizedStringWithFormatKey("CRF %@ (%@), Participant %@", version, build, externalID)
    }
    

    // MARK: DataSource
    
    var today: Date = Date()
    var scheduleSections: [ScheduleSection] = []
    var isFirstDay: Bool = false
    var todayDetailText: String?
    var isTodayFullSize: Bool = true
    var todaySectionIndex: Int = 0
    
    var shouldShowFirstDayOnly: Bool {
        return isTodayFullSize && isFirstDay
    }
    
    func scrollToTodayIfNeeded(_ animated: Bool = false) {
        
        // If not yet visible then set a flag and exit early
        guard isVisible && scheduleSections.count > 0 else {
            self.shouldScrollToToday = true
            return
        }
        
        // scroll to today
        let row = rows(for: todaySectionIndex).index(of: .scheduleSection)!
        tableView.scrollToRow(at: IndexPath(row: row, section: todaySectionIndex), at: .bottom, animated: animated)
        
        // If this is the first day then lock the view and do not allow scrolling
        tableView.isScrollEnabled = !shouldShowFirstDayOnly
        
        // use a fade-in animation to show the view on first load
        if self.tableView.isHidden {
            self.tableView.alpha = 0
            self.tableView.isHidden = false
            UIView.animate(withDuration: 0.3) {
                self.firstDayHeaderView.alpha = 1
                self.tableView.alpha = 1
            }
        }
        
        // If there is a completion animation then change state with animations
        if shouldAnimateCompletion {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: { 
                self.animateTodayCompletion()
            })
        }
    }
    
    func animateTodayCompletion() {
        
        // If the request is to animate the completion but this view isn't visible
        // then just reload.
        guard isVisible && shouldAnimateCompletion && UIApplication.shared.applicationState == .active && isTodayFullSize
        else {
            self.isTodayFullSize = self.scheduleSections.count > todaySectionIndex && self.scheduleSections[todaySectionIndex].isCompleted
            self.firstDayHeaderView.isHidden = !self.shouldShowFirstDayOnly
            self.tableView.reloadData()
            return
        }
        shouldAnimateCompletion = false
        
        // Use a two-stage animation b/c trying to animate the table updates concurrently looks really weird.
        let row = rows(for: todaySectionIndex).index(of: .scheduleSection)!
        let sectionCell = tableView.cellForRow(at: IndexPath(row: row, section: todaySectionIndex)) as! MyJourneySectionTableViewCell
        
        UIView.animate(withDuration: 1.0, delay: 0.0, options: .curveEaseInOut, animations: {
            
            // Animate the section cell shrink
            sectionCell.isFullSize = false
            sectionCell.setNeedsLayout()
            sectionCell.layoutIfNeeded()
            
            // fade out the first day header
            self.firstDayHeaderView.alpha = 0
            
        }) { (_) in
            self.animateTodayCompletedTableUpdates()
        }
    }
    
    func animateTodayCompletedTableUpdates() {
        
        // update the table
        self.tableView.beginUpdates()

        if let rowToRemove = self.rows(for: self.todaySectionIndex).index(of: .todayHeader) {
            self.tableView.deleteRows(at: [IndexPath(row: rowToRemove, section: self.todaySectionIndex)], with: .fade)
        }
        
        self.isTodayFullSize = false
        
        if let rowToAdd = self.rows(for: self.todaySectionIndex).index(of: .date) {
            self.tableView.insertRows(at: [IndexPath(row: rowToAdd, section: self.todaySectionIndex)], with: .fade)
        }
        
        self.tableView.endUpdates()
        
        // turn on scrolling for the tableview
        self.tableView.isScrollEnabled = true
    }
    
    func usesFullSize(for section: Int) -> Bool {
        return isTodayFullSize && (todaySectionIndex == section)
    }
    
    func buildTodayDetailText() {
        let scheduleSection = scheduleSections[todaySectionIndex]
        
        // TODO: syoung 06/15/2017 Localize
        
        if scheduleSection.contains(taskGroup: TaskGroup.clinicDay0) {
            todayDetailText = "Complete the surveys and the\nclinic cardiovascular stress test."
        }
        else if scheduleSection.contains(taskGroup: TaskGroup.clinicDay0alt) {
            todayDetailText = "Complete the surveys and the\nclinic cardiovascular fitness tests."
        }
        else if scheduleSection.contains(taskGroup: TaskGroup.clinicDay14) || scheduleSection.contains(taskGroup: TaskGroup.clinicDay14alt) {
            todayDetailText = "Complete your last clinic visit."
        }
        else if scheduleSection.contains(taskGroup: TaskGroup.cardio12MT) {
            if scheduledActivityManager.completedCount(for: TaskGroup.cardio12MT) == 0 {
                todayDetailText = "Complete your first run/walk."
            }
            else {
                todayDetailText = "It's time for your run/walk."
            }
        }
        else if scheduleSection.contains(taskGroup: TaskGroup.cardioStairStep) {
            if scheduledActivityManager.completedCount(for: TaskGroup.cardioStairStep) == 0 {
                todayDetailText = "Complete your first stair step."
            }
            else {
                todayDetailText = "It's time for your stair step."
            }
        }
        else {
            todayDetailText = "Please try and complete the Daily Check-in every day."
        }
    }
    
    func scheduleSection(at indexPath: IndexPath) -> ScheduleSection? {
        guard indexPath.section < scheduleSections.count else { return nil }
        return scheduleSections[indexPath.section]
    }
    
    fileprivate let rowIdentifiers: [MyJourneyCellIdentifier] = [.todayHeader, .date, .scheduleSection, .separator]
    
    fileprivate func rows(for section: Int) -> [MyJourneyCellIdentifier] {
    
        return rowIdentifiers.filter { (cellIdentifier) -> Bool in
            switch(cellIdentifier) {
            case .todayHeader:
                return usesFullSize(for: section)
                
            case .scheduleSection:
                return true
                
            case .date:
                return !usesFullSize(for: section)
                
            case .separator:
                return true
            }
        }
    }
    
    fileprivate func cellIdentifier(at indexPath: IndexPath) -> MyJourneyCellIdentifier {
        return rows(for: indexPath.section)[indexPath.row]
    }
    
    
    // MARK: UITableViewDelegate and UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return scheduleSections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows(for: section).count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let reuseIdentifier = cellIdentifier(at: indexPath).rawValue
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        
        if let sectionCell = cell as? MyJourneySectionTableViewCell, let scheduleSection = self.scheduleSection(at: indexPath) {
            sectionCell.configureCell(with: scheduleSection,
                                      isFullSize: usesFullSize(for: indexPath.section),
                                      isPast: indexPath.section > self.todaySectionIndex)
            sectionCell.adjustInsets()
        }
        else if let headerCell = cell as? MyJourneyTodayHeaderView {
            headerCell.configureHeader(with: todayDetailText ?? "")
            let overallWidth = self.preferredSizeView.bounds.size.width
            headerCell.detailWidth.constant = min(overallWidth - 48, 290)
            headerCell.titleToDetail.constant = self.view.bounds.size.width < 375 ? 12 : 24
        }
        else if let dateCell = cell as? MyJourneyDateCell, let scheduleSection = self.scheduleSection(at: indexPath) {
            if scheduleSection.contains(taskGroup: .clinicDay14) || scheduleSection.contains(taskGroup: .clinicDay14alt) {
                // Do not show date for the final clinc visit.
                dateCell.dateLabel.text = ""
            }
            else if indexPath.section == self.todaySectionIndex &&
                Calendar.gregorian.isDateInToday(scheduleSection.date) {
                dateCell.dateLabel.text = Localization.localizedString("Today")
            }
            else {
                let dateFormatter = DateFormatter()
                dateFormatter.setLocalizedDateFormatFromTemplate("MMMMd")
                dateCell.dateLabel.text = dateFormatter.string(from: scheduleSection.date)
            }
            dateCell.adjustInsets()
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        switch(cellIdentifier(at: indexPath)) {
        case .todayHeader:
            return UITableViewAutomaticDimension
        
        case .date:
            return 36
            
        case .scheduleSection:
            return MyJourneyActivityViewCell.preferredSize(isFullSize: usesFullSize(for: indexPath.section)).height
            
        case .separator:
            if shouldShowFirstDayOnly && usesFullSize(for: indexPath.section + 1) {
                return self.preferredSizeView.bounds.size.height - tableView.tableHeaderView!.bounds.size.height - 160
            }
            else if usesFullSize(for: indexPath.section) ||
                usesFullSize(for: indexPath.section + 1) ||
                (indexPath.section == scheduleSections.count - 1) {
                return 42   // last section and surrounding today section are bigger
            }
            else {
                return 24
            }
        }
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 160
    }
    
    
    // MARK: show the schedule item
    
    func taskGroupForSegue(withIdentifier identifier: String, sender: Any?) -> (TaskGroup, Date)? {
        
        // Is this the add Activity segue?
        if identifier == addActivitySegue {
            return (TaskGroup.addActivities, Date())
        }
        
        // Is this a task group segue?
        if identifier.hasPrefix(taskGroupViewControllerSegue),
            let button = sender as? UIButton {
            
            let adjustSectionIndex = todaySectionIndex
            
            if let scheduleSection = self.scheduleSection(at: IndexPath(item: 0, section: adjustSectionIndex)),
                button.tag < scheduleSection.items.count {
                return (scheduleSection.items[button.tag].taskGroup, scheduleSection.date)
            }
        }
        
        return nil
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if let (taskGroup, date) = taskGroupForSegue(withIdentifier: identifier, sender: sender),
            taskGroup.taskIdentifiers.count == 1 {
            if Calendar.gregorian.isDateInToday(date) {
                // If there is only one task and its today then show that and cancel the segue
                self.presentTaskViewController(for: taskGroup.taskIdentifiers[0], sender: sender)
                return false
            }
        }
        
        // Use a fall-through that defaults to performing the segue
        return true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        if let segueIdentifier = segue.identifier,
            let (taskGroup, date) = taskGroupForSegue(withIdentifier: segueIdentifier, sender: sender),
            let vc = segue.destination as? BaseTaskGroupTableViewController {
            // If this is a valid task group then set up the schedule
            vc.scheduledActivityManager.taskGroup = taskGroup
            vc.scheduledActivityManager.date = date
            vc.scheduledActivityManager.activities = scheduledActivityManager.activities
            
            vc.clinicDay0Schedule = scheduledActivityManager.clinicDay0Schedule
        }
    }
    
    func presentTaskViewController(for taskIdentifier: TaskIdentifier, sender: Any?) {
        guard let taskVC = scheduledActivityManager.createTaskViewController(for: taskIdentifier)
        else {
            showAlertWithOk(title: "Activity not available",
                            message: "Please check your network connection.",
                            actionHandler: nil)
            return
        }
        
        taskVC.modalTransitionStyle = .crossDissolve
        present(taskVC, animated: true, completion: nil)
    }
    
    func presentTaskViewController(for scheduledActivity: SBBScheduledActivity, sender: Any?) {
        guard let taskVC = scheduledActivityManager.createTaskViewController(for: scheduledActivity)
            else {
                return
        }
        
        taskVC.modalTransitionStyle = .crossDissolve
        present(taskVC, animated: true, completion: nil)
    }
}

class MyJourneyTodayHeaderView: UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    
    @IBOutlet var titleToTop: NSLayoutConstraint!
    @IBOutlet var titleToDetail: NSLayoutConstraint!
    @IBOutlet var detailWidth: NSLayoutConstraint!
    
    func configureHeader(with detailText: String) {
        
        self.titleLabel.textColor = UIColor(named: "darkGrayText")
        self.detailLabel.textColor = UIColor(named: "darkGrayText")
        
        self.detailLabel.text = detailText
        
        self.setNeedsLayout()
    }
}

class MyJourneyDateCell: UITableViewCell {
    
    @IBOutlet weak var dateLabel: UILabel!

    override func layoutSubviews() {
        super.layoutSubviews()
        self.dateLabel.textColor = UIColor(named: "blueyGrey")
    }
    
    func adjustInsets() {
        self.layoutMargins = UIEdgeInsets.zero
        self.contentView.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 4, right: 0)
        self.separatorInset = UIEdgeInsets.zero
    }
}

class MyJourneySeparatorCell: UITableViewCell {
    
    @IBOutlet weak var separatorLine: UIView!
    
    override func layoutSubviews() {
        super.layoutSubviews()
        separatorLine.backgroundColor = UIColor(named: "blueyGrey")
    }
}

class MyJourneySectionTableViewCell: UITableViewCell {
    
    @IBOutlet var todayCells: [MyJourneyActivityViewCell]!
    @IBOutlet var cellCenters: [NSLayoutConstraint]!
    
    var isFullSize: Bool = false
    var section: ScheduleSection!
    
    override func layoutSubviews() {
        updateDisplay()
        super.layoutSubviews()
    }
    
    func updateDisplay() {
        guard section != nil else { return }
        
        let displayCount = isFullSize ? min(section.items.count, todayCells.count) : 1

        for (index, cell) in todayCells.enumerated() {
            cell.isFullSize = isFullSize
            if !cell.isHidden {
                cell.updateDisplay()
                cell.alpha = isFullSize || (index == section.items.count - 1) ? 1 : 0
                cell.layoutIfNeeded()
            }
        }
        
        // Setup the position of the cell
        let cellWidth = (self.bounds.size.width - 2*self.layoutMargins.left) / CGFloat(displayCount)
        var cellCenter = cellWidth / 2.0
        for constraint in cellCenters {
            constraint.constant = cellCenter
            if isFullSize {
                cellCenter = cellCenter + cellWidth
            }
        }
    }
    
    func configureCell(with section: ScheduleSection, isFullSize: Bool, isPast: Bool) {
        guard (self.section != section) || (self.isFullSize != isFullSize) else { return }
        
        // Only flag layout change if isFullSize has changed
        if (self.isFullSize != isFullSize) {
            self.setNeedsLayout()
        }
        
        self.section = section
        self.isFullSize = isFullSize
        
        for (index, cell) in todayCells.enumerated() {
            cell.isHidden = index >= section.items.count
            if !cell.isHidden {
                let item = section.items[index]
                cell.isComplete = item.isCompleted
                cell.imageView.image = item.taskGroup.iconImage
                cell.titleLabel.text = item.taskGroup.journeyTitle
                cell.detailLabel.text = item.isCompleted ?
                    Localization.localizedString("Completed") :
                    item.taskGroup.activityMinutesLabel()
            }
        }
    }
    
    func adjustInsets() {
        self.layoutMargins = UIEdgeInsets.zero
        self.contentView.layoutMargins = sectionInsets
        self.separatorInset = UIEdgeInsets.zero
    }
}

private let imageSizeSmall: CGFloat = 40.0
private let imageSizeFull: CGFloat = 72.0
private let sectionInsets = UIEdgeInsets(top: 2, left: 0, bottom: 8, right: 0)

class MyJourneyActivityViewCell: UIView {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var checkmark: UIImageView!
    @IBOutlet weak var borderView: UIView!
    @IBOutlet weak var button: UIButton!
    
    @IBOutlet weak var imageSizeConstraint: NSLayoutConstraint!
    @IBOutlet weak var checkmarkSizeConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    
    var isPast: Bool = false
    var isComplete: Bool = false
    var isFullSize: Bool = false
    
    func updateDisplay() {
        
        self.backgroundColor = UIColor.clear
        
        self.button.isHidden = !isFullSize
        
        self.titleLabel.textColor = UIColor(named: "darkGrayText")
        self.detailLabel.textColor = UIColor(named: "blueyGrey")
        
        self.checkmark.isHidden = !self.isComplete
        self.titleLabel.alpha = self.isFullSize ? 1 : 0
        self.detailLabel.alpha = self.isFullSize ? 1 : 0
        self.checkmarkSizeConstraint.constant = self.isFullSize ? 18.0 : 12.0
        self.imageSizeConstraint.constant = self.isFullSize ? imageSizeFull : imageSizeSmall
        
        self.imageView.alpha = isFullSize || isComplete ? 1.0 : 0.5
        
        self.borderView.isHidden = isFullSize || isComplete
        self.borderView.layer.cornerRadius = self.imageSizeConstraint.constant / 2.0
        self.borderView.layer.borderWidth = 2
        self.borderView.layer.borderColor = isPast ? UIColor(named: "blueyGrey")?.cgColor : UIColor(named: "salmon")?.cgColor
        
        let renderingMode: UIImageRenderingMode = isComplete || !isPast ? .alwaysOriginal : .alwaysTemplate
        if let currentImage = imageView.image, currentImage.renderingMode != renderingMode {
            let newImage = (renderingMode == .alwaysTemplate) ? currentImage.imageWithWhiteTransparency() : currentImage
            imageView.image = newImage.withRenderingMode(renderingMode)
            imageView.tintColor = UIColor(named: "blueyGrey")
        }
        
        self.setNeedsLayout()
        self.setNeedsUpdateConstraints()
        self.setNeedsDisplay()
    }
    
    class func preferredSize(isFullSize: Bool) -> CGSize {
        let insets = sectionInsets.top + sectionInsets.bottom
        return isFullSize ? CGSize(width: 110, height: 152 + insets) : CGSize(width: 110, height: imageSizeSmall + insets)
    }
}

class MyJourneyFooterView: UIView {
    
    @IBOutlet weak var textLabel: UILabel!
    @IBOutlet weak var versionLabel: UILabel!
}

extension UIImage {
    
    func imageWithWhiteTransparency() -> UIImage {
        guard let jpeg = UIImageJPEGRepresentation(self, 1.0),
            let image = UIImage(data: jpeg),
            let rawImageRef = image.cgImage
        else {
            return self.copy() as! UIImage
        }

        UIGraphicsBeginImageContext(image.size)
        
        var result: UIImage?
        
        let colorMasking: [CGFloat] = [222, 255, 222, 255, 222, 255]
        if  let maskedImageRef = rawImageRef.copy(maskingColorComponents: colorMasking),
            let context = UIGraphicsGetCurrentContext() {
        
            context.translateBy(x: 0.0, y: image.size.height)
            context.scaleBy(x: 1.0, y: -1.0)
            context.draw(maskedImageRef, in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
            result = UIGraphicsGetImageFromCurrentImageContext()
        }
        
        UIGraphicsEndImageContext()
        
        return result ?? self.copy() as! UIImage
    }
    
}

extension Bundle {
    
    var versionString: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    }
}
