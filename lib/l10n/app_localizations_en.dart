// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get homeTitle => 'Gallery 20.5';

  @override
  String get loading => 'Loading...';

  @override
  String get homeOrder => 'Order';

  @override
  String get homeCalendar => 'Calendar';

  @override
  String get homeShift => 'Shift';

  @override
  String get homePrep => 'Prep';

  @override
  String get homeStock => 'Stock';

  @override
  String get homeClockIn => 'Clock-in';

  @override
  String get homeWorkReport => 'Work Report';

  @override
  String get homeBackhouse => 'Backhouse';

  @override
  String get homeDailyCost => 'Daily Cost';

  @override
  String get homeCashFlow => 'Cash Flow';

  @override
  String get homeMonthlyCost => 'Monthly Cost';

  @override
  String get homeSetting => 'Setting';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get defaultUser => 'User';

  @override
  String get settingPrepInfo => 'Prep Info';

  @override
  String get settingStock => 'Stock';

  @override
  String get settingStockLog => 'Stock Log';

  @override
  String get settingTable => 'Table';

  @override
  String get settingTableMap => 'Table Map';

  @override
  String get settingMenu => 'Menu';

  @override
  String get settingPrinter => 'Printer';

  @override
  String get settingClockInInfo => 'Clock-in Info';

  @override
  String get settingPayment => 'Payment';

  @override
  String get settingCashbox => 'Cashbox';

  @override
  String get settingShift => 'Shift';

  @override
  String get settingUserManagement => 'User Management';

  @override
  String get settingCostCategories => 'Cost Categories';

  @override
  String get settingLanguage => 'Language';

  @override
  String get settingChangePassword => 'Change Password';

  @override
  String get settingLogout => 'Logout';

  @override
  String get settingRoleManagement => 'Role Management';

  @override
  String get loginTitle => 'Login';

  @override
  String get loginShopIdHint => 'Select Shop ID';

  @override
  String get loginEmailHint => 'Email';

  @override
  String get loginPasswordHint => 'Password';

  @override
  String get loginButton => 'Login';

  @override
  String get loginAddShopOption => '+ Add Shop';

  @override
  String get loginAddShopDialogTitle => 'Add Shop';

  @override
  String get loginAddShopDialogHint => 'Enter new shop code';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonAdd => 'Add';

  @override
  String get loginMsgFillAll => 'Please fill in all fields';

  @override
  String get loginMsgFaceIdFirst => 'Please login with Email first';

  @override
  String get loginMsgFaceIdReason => 'Please use Face ID to login';

  @override
  String get loginMsgNoSavedData => 'No saved login data';

  @override
  String get loginMsgNoFaceIdData => 'No Face ID data found for this account';

  @override
  String get loginMsgShopNotFound => 'Shop not found';

  @override
  String get loginMsgNoPermission => 'You do not have permission for this shop';

  @override
  String get loginMsgFailed => 'Login failed';

  @override
  String loginMsgFailedReason(Object error) {
    return 'Login failed: $error';
  }

  @override
  String get scheduleTitle => 'Schedule';

  @override
  String get scheduleTabMy => 'My';

  @override
  String get scheduleTabAll => 'All';

  @override
  String get scheduleTabCustom => 'Custom';

  @override
  String get scheduleFilterTooltip => 'Filter Groups';

  @override
  String get scheduleSelectGroups => 'Select Groups';

  @override
  String get commonDone => 'Done';

  @override
  String get schedulePersonalMe => 'Personal (Me)';

  @override
  String get scheduleUntitled => 'Untitled';

  @override
  String get scheduleNoEvents => 'No events';

  @override
  String get scheduleAllDay => 'All Day';

  @override
  String get scheduleDayLabel => 'Day';

  @override
  String get commonNoTitle => 'No Title';

  @override
  String scheduleMoreEvents(Object count) {
    return '+$count more...';
  }

  @override
  String get commonToday => 'Today';

  @override
  String get calendarGroupsTitle => 'Calendar Groups';

  @override
  String get calendarGroupPersonal => 'Personal (Me)';

  @override
  String get calendarGroupUntitled => 'Untitled';

  @override
  String get calendarGroupPrivateDesc => 'Private events only visible to you';

  @override
  String calendarGroupVisibleToMembers(Object count) {
    return 'Visible to $count members';
  }

  @override
  String get calendarGroupNew => 'New Group';

  @override
  String get calendarGroupEdit => 'Edit Group';

  @override
  String get calendarGroupName => 'GROUP NAME';

  @override
  String get calendarGroupNameHint => 'e.g. Work, Meeting';

  @override
  String get calendarGroupColor => 'GROUP COLOR';

  @override
  String get calendarGroupEventColors => 'EVENT COLORS';

  @override
  String get calendarGroupSaveFirstHint => 'Save this group first to setup custom event colors.';

  @override
  String get calendarGroupVisibleTo => 'VISIBLE TO MEMBERS';

  @override
  String get calendarGroupDelete => 'Delete Group';

  @override
  String get calendarGroupDeleteConfirm => 'Deleting this group will remove all associated events. Are you sure?';

  @override
  String get calendarColorNew => 'New Color';

  @override
  String get calendarColorEdit => 'Edit Color';

  @override
  String get calendarColorName => 'COLOR NAME';

  @override
  String get calendarColorNameHint => 'e.g. Urgent, Meeting';

  @override
  String get calendarColorPick => 'PICK COLOR';

  @override
  String get calendarColorDelete => 'Delete Color';

  @override
  String get calendarColorDeleteConfirm => 'Delete this color setting?';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get notificationGroupInviteTitle => 'Group Invite';

  @override
  String notificationGroupInviteBody(Object groupName) {
    return 'You have been added to calendar group: $groupName';
  }

  @override
  String get eventDetailTitleEdit => 'Edit Event';

  @override
  String get eventDetailTitleNew => 'New Event';

  @override
  String get eventDetailLabelTitle => 'Title';

  @override
  String get eventDetailLabelGroup => 'Group';

  @override
  String get eventDetailLabelColor => 'Color';

  @override
  String get eventDetailLabelAllDay => 'All-day';

  @override
  String get eventDetailLabelStarts => 'Starts';

  @override
  String get eventDetailLabelEnds => 'Ends';

  @override
  String get eventDetailLabelRepeat => 'Repeat';

  @override
  String get eventDetailLabelRelatedPeople => 'Related People';

  @override
  String get eventDetailLabelNotes => 'Notes';

  @override
  String get eventDetailDelete => 'Delete Event';

  @override
  String get eventDetailDeleteConfirm => 'Are you sure you want to delete this event?';

  @override
  String get eventDetailSelectGroup => 'Select Group';

  @override
  String get eventDetailSelectColor => 'Select Color';

  @override
  String get eventDetailGroupDefault => 'Group Default';

  @override
  String get eventDetailCustomColor => 'Custom Color';

  @override
  String get eventDetailNoCustomColors => 'No custom colors set for this group.';

  @override
  String get eventDetailSelectPeople => 'Select People';

  @override
  String eventDetailPeopleCount(Object count) {
    return '$count people';
  }

  @override
  String get eventDetailNone => 'None';

  @override
  String get eventDetailRepeatNone => 'None';

  @override
  String get eventDetailRepeatDaily => 'Daily';

  @override
  String get eventDetailRepeatWeekly => 'Weekly';

  @override
  String get eventDetailRepeatMonthly => 'Monthly';

  @override
  String get eventDetailErrorTitleRequired => 'Title is required';

  @override
  String get eventDetailErrorGroupRequired => 'Group is required';

  @override
  String get eventDetailErrorEndTime => 'End time cannot be before start time';

  @override
  String get eventDetailErrorSave => 'Failed to save event';

  @override
  String get eventDetailErrorDelete => 'Failed to delete';

  @override
  String notificationNewEventTitle(Object groupName) {
    return '[$groupName] New Event';
  }

  @override
  String notificationNewEventBody(Object time, Object title, Object userName) {
    return '$userName added: $title ($time)';
  }

  @override
  String get notificationTimeChangeTitle => '⏰ [Update] Time Changed';

  @override
  String notificationTimeChangeBody(Object title, Object userName) {
    return '$userName changed the time of \"$title\", please check.';
  }

  @override
  String get notificationContentChangeTitle => '✏️ [Update] Content Changed';

  @override
  String notificationContentChangeBody(Object title, Object userName) {
    return '$userName updated details of \"$title\".';
  }

  @override
  String get notificationDeleteTitle => '🗑️ [Cancel] Event Removed';

  @override
  String notificationDeleteBody(Object title, Object userName) {
    return '$userName canceled event: $title';
  }

  @override
  String get localNotificationTitle => '🔔 Reminder';

  @override
  String localNotificationBody(Object title) {
    return 'In 10 mins: $title';
  }

  @override
  String get commonSelect => 'Select...';

  @override
  String get commonUnknown => 'Unknown';

  @override
  String get commonPersonalMe => 'Personal (Me)';

  @override
  String get scheduleViewTitle => 'Work Schedule';

  @override
  String get scheduleViewModeMy => 'My Shifts';

  @override
  String get scheduleViewModeAll => 'All Shifts';

  @override
  String scheduleViewErrorInit(Object error) {
    return 'Failed to load initial data: $error';
  }

  @override
  String scheduleViewErrorFetch(Object error) {
    return 'Failed to fetch schedule: $error';
  }

  @override
  String get scheduleViewUnknown => 'Unknown';

  @override
  String get scheduleUploadTitle => 'Shift Assigning';

  @override
  String get scheduleUploadSelectEmployee => 'Select Employee';

  @override
  String get scheduleUploadSelectShiftFirst => 'Please select a shift type from above first.';

  @override
  String get scheduleUploadUnsavedChanges => 'Unsaved Changes';

  @override
  String get scheduleUploadDiscardChangesMessage => 'You have unsaved changes. Switching employees or leaving will discard them. Continue?';

  @override
  String get scheduleUploadNoChanges => 'No changes to save.';

  @override
  String get scheduleUploadSaveSuccess => 'Schedule saved!';

  @override
  String scheduleUploadSaveError(Object error) {
    return 'Save failed: $error';
  }

  @override
  String scheduleUploadLoadError(Object error) {
    return 'Failed to load initial data: $error';
  }

  @override
  String scheduleUploadLoadScheduleError(Object name) {
    return 'Failed to load schedule for $name';
  }

  @override
  String scheduleUploadRole(Object role) {
    return 'Role: $role';
  }

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonSaveChanges => 'Save Changes';

  @override
  String get prepViewTitle => 'View Prep Category';

  @override
  String get prepViewItemTitle => 'View Prep Item';

  @override
  String get prepViewItemUntitled => 'Untitled Item';

  @override
  String get prepViewMainIngredients => 'Main Ingredients';

  @override
  String prepViewNote(Object note) {
    return 'Note: $note';
  }

  @override
  String get prepViewDetailLabel => 'Detail';

  @override
  String get settingCategoryPersonnel => 'Personnel & Permissions';

  @override
  String get settingCategoryMenuInv => 'Menu & Inventory';

  @override
  String get settingCategoryEquipTable => 'Equipment & Tables';

  @override
  String get settingCategorySystem => 'System';

  @override
  String get settingPayroll => 'Payroll Report';

  @override
  String get permBackPayroll => 'Payroll Report';

  @override
  String get permBackLoginWeb => 'Allow Backend Login';

  @override
  String get settingModifiers => 'Modifiers Setup';

  @override
  String get settingTax => 'Tax Settings';

  @override
  String get inventoryViewTitle => 'Stock Overview';

  @override
  String get inventorySearchHint => 'Search Item';

  @override
  String get inventoryNoItems => 'No items found';

  @override
  String inventorySafetyQuantity(Object quantity) {
    return 'Safety Quantity: $quantity';
  }

  @override
  String get inventoryConfirmUpdateTitle => 'Confirm Update';

  @override
  String inventoryConfirmUpdateOriginal(Object unit, Object value) {
    return 'Original Number: $value $unit';
  }

  @override
  String inventoryConfirmUpdateNew(Object unit, Object value) {
    return 'New Number: $value $unit';
  }

  @override
  String inventoryConfirmUpdateChange(Object value) {
    return 'Change: $value';
  }

  @override
  String get inventoryUnsavedTitle => 'Unsaved Change';

  @override
  String get inventoryUnsavedContent => 'You have unsaved inventory adjustments. Would you like to save and exit?';

  @override
  String get inventoryUnsavedDiscard => 'Cancel & Exit';

  @override
  String inventoryUpdateSuccess(Object name) {
    return '✅ $name stock updated successfully!';
  }

  @override
  String get inventoryUpdateFailedTitle => 'Update Failed';

  @override
  String get inventoryUpdateFailedMsg => 'Database error, please contact administrator.';

  @override
  String get inventoryBatchSaveFailedTitle => 'Batch Save Failed';

  @override
  String inventoryBatchSaveFailedMsg(Object name) {
    return 'Item $name failed to save.';
  }

  @override
  String get inventoryReasonStockIn => 'Stock In';

  @override
  String get inventoryReasonAudit => 'Audit Adjustment';

  @override
  String get inventoryErrorTitle => 'Error';

  @override
  String get inventoryErrorInvalidNumber => 'Please enter a valid number';

  @override
  String get commonOk => 'OK';

  @override
  String get punchTitle => 'Clock-in';

  @override
  String get punchInButton => 'Clock-in';

  @override
  String get punchOutButton => 'Clock-out';

  @override
  String get punchMakeUpButton => 'Make Up For\nClock-in/out';

  @override
  String get punchLocDisabled => 'Location services are disabled. Please enable them in Settings.';

  @override
  String get punchLocDenied => 'Location permissions are denied';

  @override
  String get punchLocDeniedForever => 'Location permissions are permanently denied, we cannot request permissions.';

  @override
  String get punchErrorSettingsNotFound => 'Shop punch-in settings not found. Please contact manager.';

  @override
  String punchErrorWifi(Object wifi) {
    return 'Wi-Fi incorrect.\nPlease connect to: $wifi';
  }

  @override
  String get punchErrorDistance => 'You are too far from the shop.';

  @override
  String get punchErrorAlreadyIn => 'You are already clocked in.';

  @override
  String get punchSuccessInTitle => 'Clock-in Succeeded';

  @override
  String get punchSuccessInMsg => 'Have a nice shift : )';

  @override
  String get punchErrorInTitle => 'Clock-in Failed';

  @override
  String get punchErrorNoSession => 'No active session found within 24 hours. Please contact manager.';

  @override
  String get punchErrorOverTime => 'Over 12 hours. Please use \"Make Up\" function.';

  @override
  String get punchSuccessOutTitle => 'Clock-out Succeeded';

  @override
  String get punchSuccessOutMsg => 'Boss love you ❤️';

  @override
  String get punchErrorOutTitle => 'Clock-out Failed';

  @override
  String punchErrorGeneric(Object error) {
    return 'An error occurred: $error';
  }

  @override
  String get punchMakeUpTitle => 'Make up for clock-in/out';

  @override
  String get punchMakeUpTypeIn => 'Make Up For Clock-in';

  @override
  String get punchMakeUpTypeOut => 'Make Up For Clock-out';

  @override
  String get punchMakeUpReasonHint => 'Reason (Required)';

  @override
  String get punchMakeUpErrorReason => 'Please fill up the reason';

  @override
  String get punchMakeUpErrorFuture => 'Cannot make up for a future time';

  @override
  String get punchMakeUpError72h => 'Cannot make up beyond 72 hours. Please contact manager.';

  @override
  String punchMakeUpErrorOverlap(Object time) {
    return 'Active session found at $time. Please clock out first.';
  }

  @override
  String get punchMakeUpErrorNoRecord => 'No matching record found within 72 hours. Please contact manager.';

  @override
  String get punchMakeUpErrorOver12h => 'Shift duration exceeds 12 hours. Please contact manager.';

  @override
  String get punchMakeUpSuccessTitle => 'Succeeded';

  @override
  String get punchMakeUpSuccessMsg => 'Your make up clock-in/out succeeded';

  @override
  String get punchMakeUpCheckInfo => 'Please Check The Info';

  @override
  String punchMakeUpLabelType(Object type) {
    return 'Type: $type';
  }

  @override
  String punchMakeUpLabelTime(Object time) {
    return 'Time: $time';
  }

  @override
  String punchMakeUpLabelReason(Object reason) {
    return 'Reason: $reason';
  }

  @override
  String get commonDate => 'Date';

  @override
  String get commonTime => 'Time';

  @override
  String get workReportTitle => 'Work Report';

  @override
  String get workReportSelectDate => 'Select Date';

  @override
  String get workReportJobSubject => 'Job Subject (Required)';

  @override
  String get workReportJobDescription => 'Job Description (Required)';

  @override
  String get workReportOverTime => 'Over time hour (Optional)';

  @override
  String get workReportHourUnit => 'hr';

  @override
  String get workReportErrorRequiredTitle => 'Please Fill In The\nRequired Fields';

  @override
  String get workReportErrorRequiredMsg => 'Subject and Description\nare required!';

  @override
  String get workReportConfirmOverwriteTitle => 'Report Exists';

  @override
  String get workReportConfirmOverwriteMsg => 'You already submitted\na report for this date.\nDo you want to overwrite?';

  @override
  String get workReportOverwriteYes => 'Yes';

  @override
  String get workReportSuccessTitle => 'Successfully';

  @override
  String get workReportSuccessMsg => 'Your work report is successfully been summited!';

  @override
  String get workReportSubmitFailed => 'Submit Failed';

  @override
  String get todoScreenTitle => '待辦事項';

  @override
  String get todoTabIncomplete => 'Incomplete';

  @override
  String get todoTabPending => 'Pending';

  @override
  String get todoTabCompleted => 'Completed';

  @override
  String get todoFilterMyTasks => 'My Tasks Only';

  @override
  String todoCountSuffix(Object count) {
    return '$count items';
  }

  @override
  String get todoEmptyPending => 'No pending tasks';

  @override
  String get todoEmptyIncomplete => 'No incomplete tasks';

  @override
  String get todoEmptyCompleted => 'No completed tasks this month';

  @override
  String get todoSubmitReviewTitle => 'Submit for Review';

  @override
  String get todoSubmitReviewContent => 'Are you sure you have completed this task and want to submit it for review?';

  @override
  String get todoSubmitButton => 'Submit';

  @override
  String get todoApproveTitle => 'Approve Task';

  @override
  String get todoApproveContent => 'Are you sure this task is completed?';

  @override
  String get todoApproveButton => 'Approve';

  @override
  String get todoRejectTitle => 'Reject Task';

  @override
  String get todoRejectContent => 'Return this task to the employee for rework?';

  @override
  String get todoRejectButton => 'Return';

  @override
  String get todoDeleteTitle => 'Delete Task';

  @override
  String get todoDeleteContent => 'Are you sure? This action cannot be undone.';

  @override
  String get todoErrorNoPermissionSubmit => 'You do not have permission to submit this task.';

  @override
  String get todoErrorNoPermissionApprove => 'Only the assigner can approve this task.';

  @override
  String get todoErrorNoPermissionReject => 'Only the assigner can reject this task.';

  @override
  String get todoErrorNoPermissionEdit => 'Only the assigner can edit this task.';

  @override
  String get todoErrorNoPermissionDelete => 'Only the assigner can delete this task.';

  @override
  String get notificationTodoReviewTitle => '👀 Task for Review';

  @override
  String notificationTodoReviewBody(Object name, Object task) {
    return '$name submitted: $task, please check.';
  }

  @override
  String get notificationTodoApprovedTitle => '✅ Task Approved';

  @override
  String notificationTodoApprovedBody(Object task) {
    return 'Assigner approved: $task';
  }

  @override
  String get notificationTodoRejectedTitle => '↩️ Task Returned';

  @override
  String notificationTodoRejectedBody(Object task) {
    return 'Please revise and resubmit: $task';
  }

  @override
  String get notificationTodoDeletedTitle => '🗑️ Task Deleted';

  @override
  String notificationTodoDeletedBody(Object task) {
    return 'Assigner deleted: $task';
  }

  @override
  String todoActionSheetTitle(Object title) {
    return 'Action: $title';
  }

  @override
  String get todoActionCompleteAndSubmit => 'Complete & Submit';

  @override
  String todoReviewSheetTitle(Object title) {
    return 'Review: $title';
  }

  @override
  String get todoReviewSheetMessageAssigner => 'Please confirm if the task is qualified.';

  @override
  String get todoReviewSheetMessageAssignee => 'Waiting for assigner review.';

  @override
  String get todoActionApprove => '✅ Approve';

  @override
  String get todoActionReject => '↩️ Return';

  @override
  String get todoActionViewDetails => 'View Details';

  @override
  String get todoLabelTo => 'To: ';

  @override
  String get todoLabelFrom => 'From: ';

  @override
  String get todoUnassigned => 'Unassigned';

  @override
  String get todoLabelCompletedAt => 'Completed: ';

  @override
  String get todoLabelWaitingReview => 'Waiting for Review';

  @override
  String get commonEdit => 'Edit';

  @override
  String get todoAddTaskTitleNew => 'New Task';

  @override
  String get todoAddTaskTitleEdit => 'Edit Task';

  @override
  String get todoAddTaskLabelTitle => 'Task Title';

  @override
  String get todoAddTaskLabelDesc => 'Description (Optional)';

  @override
  String get todoAddTaskLabelAssign => 'Assign To:';

  @override
  String get todoAddTaskSelectStaff => 'Select Staff';

  @override
  String todoAddTaskSelectedStaff(Object count) {
    return '$count Staff Selected';
  }

  @override
  String get todoAddTaskSetDueDate => 'Set Due Date';

  @override
  String get todoAddTaskSelectDate => 'Select Date';

  @override
  String get todoAddTaskSetDueTime => 'Set Due Time';

  @override
  String get todoAddTaskSelectTime => 'Select Time';

  @override
  String get notificationTodoEditTitle => '✏️ Task Updated';

  @override
  String notificationTodoEditBody(Object task) {
    return 'Content updated: $task';
  }

  @override
  String get notificationTodoUrgentUpdate => '🔥 Urgent Update';

  @override
  String get notificationTodoNewTitle => '📝 New Task';

  @override
  String notificationTodoNewBody(Object task) {
    return '$task';
  }

  @override
  String get notificationTodoUrgentNew => '🔥 Urgent Task';

  @override
  String get costInputTitle => 'Daily Cost';

  @override
  String get costInputTotalToday => 'Total cost of today';

  @override
  String get costInputLabelName => 'Name';

  @override
  String get costInputLabelPrice => 'Price';

  @override
  String get costInputTabNotOpenTitle => 'Tab is not open';

  @override
  String get costInputTabNotOpenMsg => 'Please open today\'s tab first.';

  @override
  String get costInputTabNotOpenPageTitle => 'Please Open Today’s Tab';

  @override
  String get costInputTabNotOpenPageDesc => 'You must open the tab first before\nyou can start filling in the daily costs.';

  @override
  String get costInputButtonOpenTab => 'Go For Open Today’s Tab';

  @override
  String get costInputErrorInputTitle => 'Input Error';

  @override
  String get costInputErrorInputMsg => 'Please ensure item and price are filled correctly.';

  @override
  String get costInputSuccess => '✅ Cost saved successfully';

  @override
  String get costInputSaveFailed => 'Save Failed';

  @override
  String get costInputLoadingCategories => 'Loading...';

  @override
  String get costDetailTitle => 'Daily Cost Detail';

  @override
  String get costDetailNoRecords => 'No cost records for this period.';

  @override
  String get costDetailItemUntitled => 'No Item Name';

  @override
  String get costDetailCategoryNA => 'N/A';

  @override
  String get costDetailBuyerNA => 'N/A';

  @override
  String costDetailLabelCategory(Object category) {
    return 'Category: $category';
  }

  @override
  String costDetailLabelBuyer(Object buyer) {
    return 'Buyer: $buyer';
  }

  @override
  String get costDetailEditTitle => 'Edit Daily Cost Detail';

  @override
  String get costDetailDeleteTitle => 'Delete Cost';

  @override
  String costDetailDeleteContent(Object name) {
    return 'Are you sure to delete this cost?\n($name)';
  }

  @override
  String get costDetailErrorUpdate => 'Update Failed';

  @override
  String get costDetailErrorDelete => 'Delete Failed';

  @override
  String get cashSettlementDeposits => 'Deposits';

  @override
  String get cashSettlementExpectedCash => 'Expected Cash';

  @override
  String get cashSettlementDifference => 'Difference';

  @override
  String get cashSettlementConfirmTitle => 'Confirm Settlement';

  @override
  String get commonSubmit => 'Submit';

  @override
  String get cashSettlementDepositSheetTitle => 'Deposit Sheet';

  @override
  String get cashSettlementDepositNew => 'New Deposit';

  @override
  String get cashSettlementNewDepositTitle => 'New Deposit';

  @override
  String get commonName => 'Name';

  @override
  String get commonPhone => 'Phone';

  @override
  String get commonAmount => 'Amount';

  @override
  String get commonNotes => 'Notes';

  @override
  String get cashSettlementDepositAddSuccess => 'Deposit Added Successfully';

  @override
  String get cashSettlementSelectRedeemedDeposit => 'Select Redeemed Deposit';

  @override
  String get commonNoData => 'No Data';

  @override
  String get cashSettlementTitleOpen => 'Opening Check';

  @override
  String get cashSettlementTitleClose => 'Closing Check';

  @override
  String get cashSettlementTitleLoading => 'Loading...';

  @override
  String get cashSettlementOpenDesc => 'Please check and confirm that the number of bills and the total amount are consistent with the expected values.';

  @override
  String get cashSettlementTargetAmount => 'Target amount:';

  @override
  String get cashSettlementTotal => 'Total:';

  @override
  String get cashSettlementRevenueAndPayment => 'Daily Revenue and Payment Methods';

  @override
  String get cashSettlementRevenueHint => 'Total Revenue';

  @override
  String cashSettlementDepositButton(Object amount) {
    return 'Today\'s Deposit (Selected: \$$amount)';
  }

  @override
  String get cashSettlementReceivableCash => 'Receivable Cash:';

  @override
  String get cashSettlementCashCountingTitle => 'Cash Counting\n(Please Enter Actual Number of Bills)';

  @override
  String get cashSettlementTotalCashCounted => 'Total Cash Counted:';

  @override
  String get cashSettlementReviewTitle => 'Review';

  @override
  String get cashSettlementOpeningCash => 'Opening Cash';

  @override
  String get cashSettlementDailyCosts => 'Daily Costs';

  @override
  String get cashSettlementRedeemedDeposit => 'Redeemed Deposit';

  @override
  String get cashSettlementTotalExpectedCash => 'Total Expected Cash';

  @override
  String get cashSettlementTodaysCashCount => 'Today’s Cash Count';

  @override
  String get cashSettlementSummary => 'Summary:';

  @override
  String get cashSettlementErrorCountMismatch => 'Counted total does not match target amount!';

  @override
  String get cashSettlementOpenSuccessTitle => 'Successfully Opened';

  @override
  String cashSettlementOpenSuccessMsg(Object count) {
    return 'Shift $count opened successfully!';
  }

  @override
  String get cashSettlementOpenFailedTitle => 'Open Failed';

  @override
  String get cashSettlementCloseSuccessTitle => 'Successfully Closed & Save';

  @override
  String get cashSettlementCloseSuccessMsg => 'Bosses ❤️ U!';

  @override
  String get cashSettlementCloseFailedTitle => 'Close Failed';

  @override
  String get cashSettlementErrorInputRevenue => 'Please enter total revenue.';

  @override
  String get cashSettlementDepositTitle => 'Deposite Management';

  @override
  String get cashSettlementDepositAdd => 'Add New Deposite';

  @override
  String get cashSettlementDepositEdit => 'Edit All Deposite';

  @override
  String get cashSettlementDepositRedeemTitle => 'Redeem Today\'s Deposit';

  @override
  String get cashSettlementDepositNoUnredeemed => 'No unredeemed deposits';

  @override
  String cashSettlementDepositTotalRedeemed(Object amount) {
    return 'Total Redeemed: \$$amount';
  }

  @override
  String get cashSettlementDepositAddTitle => 'Add Deposit';

  @override
  String get cashSettlementDepositEditTitle => 'Edit Deposit';

  @override
  String get cashSettlementDepositPaymentDate => 'Payment Date';

  @override
  String get cashSettlementDepositReservationDate => 'Reservation Date';

  @override
  String get cashSettlementDepositReservationTime => 'Reservation Time';

  @override
  String get cashSettlementDepositName => 'Name';

  @override
  String get cashSettlementDepositPax => 'Party Size';

  @override
  String get cashSettlementDepositAmount => 'Deposit Amount';

  @override
  String get cashSettlementErrorInputDates => 'Please select all dates and times.';

  @override
  String get cashSettlementErrorInputAmount => 'Please fill in name and valid amount';

  @override
  String get cashSettlementErrorTimePast => 'Booking time cannot be in the past';

  @override
  String get cashSettlementSaveFailed => 'Save Failed';

  @override
  String get depositScreenTitle => 'Deposit Management';

  @override
  String get depositScreenNoRecords => 'No unredeemed deposits';

  @override
  String depositScreenLabelName(Object name) {
    return 'Name: $name';
  }

  @override
  String depositScreenLabelReservationDate(Object date) {
    return 'Reservation Date: $date';
  }

  @override
  String depositScreenLabelReservationTime(Object time) {
    return 'Reservation Time: $time';
  }

  @override
  String depositScreenLabelGroupSize(Object size) {
    return 'Group Size: $size';
  }

  @override
  String get depositScreenDeleteConfirm => 'Delete Deposit';

  @override
  String get depositScreenDeleteContent => 'Are you sure to delete this deposit?';

  @override
  String get depositScreenDeleteSuccess => 'Deposit deleted';

  @override
  String depositScreenDeleteFailed(Object error) {
    return 'Delete failed: $error';
  }

  @override
  String depositScreenSaveFailed(Object error) {
    return 'Save failed: $error';
  }

  @override
  String get depositScreenInputError => 'Please fill in all required fields (Name, Amount, Date/Time).';

  @override
  String get depositScreenTimeError => 'Booking time cannot be in the past.';

  @override
  String get depositDialogTitleAdd => 'Add Deposit';

  @override
  String get depositDialogTitleEdit => 'Edit Deposit';

  @override
  String get depositDialogHintPaymentDate => 'Payment Date';

  @override
  String get depositDialogHintReservationDate => 'Reservation Date';

  @override
  String get depositDialogHintReservationTime => 'Reservation Time';

  @override
  String get depositDialogHintName => 'Name';

  @override
  String get depositDialogHintGroupSize => 'Group Size';

  @override
  String get depositDialogHintAmount => 'Deposit Amount';

  @override
  String get monthlyCostTitle => 'Monthly Cost';

  @override
  String get monthlyCostTotal => 'Total cost of this month';

  @override
  String get monthlyCostLabelName => 'Name';

  @override
  String get monthlyCostLabelPrice => 'Price';

  @override
  String get monthlyCostLabelNote => 'Note';

  @override
  String get monthlyCostErrorInputTitle => 'Error';

  @override
  String get monthlyCostErrorInputMsg => 'Name and Price are required.';

  @override
  String get monthlyCostErrorSaveFailed => 'Save Failed';

  @override
  String get monthlyCostSuccess => 'Cost saved successfully';

  @override
  String get monthlyCostDetailTitle => 'Monthly Cost Detail';

  @override
  String get monthlyCostDetailNoRecords => 'No cost records for this month.';

  @override
  String get monthlyCostDetailItemUntitled => 'No Item Name';

  @override
  String get monthlyCostDetailCategoryNA => 'N/A';

  @override
  String get monthlyCostDetailBuyerNA => 'N/A';

  @override
  String monthlyCostDetailLabelCategory(Object category) {
    return 'Category: $category';
  }

  @override
  String monthlyCostDetailLabelDate(Object date) {
    return 'Date: $date';
  }

  @override
  String monthlyCostDetailLabelBuyer(Object buyer) {
    return 'Buyer: $buyer';
  }

  @override
  String get monthlyCostDetailEditTitle => 'Edit Monthly Cost Detail';

  @override
  String get monthlyCostDetailDeleteTitle => 'Delete Cost';

  @override
  String monthlyCostDetailDeleteContent(Object name) {
    return 'Are you sure to delete this cost?\n($name)';
  }

  @override
  String monthlyCostDetailErrorFetch(Object error) {
    return 'Failed to fetch expenses: $error';
  }

  @override
  String get monthlyCostDetailErrorUpdate => 'Update Failed';

  @override
  String get monthlyCostDetailErrorDelete => 'Delete Failed';

  @override
  String get cashFlowTitle => 'Cash Flow Report';

  @override
  String get cashFlowMonthlyRevenue => 'Monthly Revenue';

  @override
  String get cashFlowMonthlyDifference => 'Monthly Difference';

  @override
  String cashFlowLabelShift(Object count) {
    return 'Shift $count';
  }

  @override
  String get cashFlowLabelRevenue => 'Total Revenue:';

  @override
  String get cashFlowLabelCost => 'Total Cost:';

  @override
  String get cashFlowLabelDifference => 'Cash Difference:';

  @override
  String get cashFlowNoRecords => 'No records found.';

  @override
  String get costReportTitle => 'Cost Summary';

  @override
  String get costReportMonthlyTotal => 'Monthly Cost Total';

  @override
  String get costReportNoRecords => 'No cost records.';

  @override
  String get costReportNoRecordsShift => 'No cost records for this shift.';

  @override
  String get costReportLabelTotalCost => 'Total Cost:';

  @override
  String get dashboardTitle => 'Operation Dashboard';

  @override
  String get dashboardTotalRevenue => 'Total Revenue';

  @override
  String get dashboardCogs => 'Cost of Revenue';

  @override
  String get dashboardGrossProfit => 'Gross Profit';

  @override
  String get dashboardGrossMargin => 'Gross Margin';

  @override
  String get dashboardOpex => 'Operation Expense';

  @override
  String get dashboardOpIncome => 'Operation Income';

  @override
  String get dashboardNetIncome => 'Net Income';

  @override
  String get dashboardNetProfitMargin => 'Net Profit Margin';

  @override
  String get dashboardNoCostData => 'No cost data available';

  @override
  String dashboardErrorLoad(Object error) {
    return 'Data load error: $error';
  }

  @override
  String get reportingTitle => 'Backstage';

  @override
  String get reportingCashFlow => 'Cash Flow';

  @override
  String get reportingCostSum => 'Cost Sum';

  @override
  String get reportingDashboard => 'Dashboard';

  @override
  String get reportingCashVault => 'Cash Vault';

  @override
  String get reportingClockIn => 'Clock-in';

  @override
  String get reportingWorkReport => 'Work Report';

  @override
  String get reportingNoAccess => 'No accessible features';

  @override
  String get vaultTitle => 'Cash Flow';

  @override
  String get vaultTotalCash => 'Total Cash';

  @override
  String get vaultTitleVault => 'Vault';

  @override
  String get vaultTitleCashbox => 'Cashbox';

  @override
  String get vaultCashDetail => 'Cash Detail';

  @override
  String vaultDetailDenom(Object cashboxCount, Object totalCount, Object vaultCount) {
    return '\$ $cashboxCount X $totalCount (Vault $cashboxCount + Cashbox $vaultCount)';
  }

  @override
  String get vaultActivityHistory => 'Activity History';

  @override
  String get vaultTableDate => 'Date';

  @override
  String get vaultTableStaff => 'Staff';

  @override
  String get vaultNoRecords => 'No activity records.';

  @override
  String get vaultManagementSheetTitle => 'Vault Management';

  @override
  String get vaultAdjustCounts => 'Adjust Vault Counts';

  @override
  String get vaultSaveMoney => 'Save Money (Deposit)';

  @override
  String get vaultChangeMoney => 'Change Money';

  @override
  String get vaultPromptAdjust => 'Enter the TOTAL counts (Vault + Cashbox).';

  @override
  String get vaultPromptDeposit => 'Enter amount to deposit to bank';

  @override
  String get vaultPromptChangeOut => 'Take OUT large bills from Vault';

  @override
  String get vaultPromptChangeIn => 'Put IN small bills to Vault';

  @override
  String get vaultErrorMismatch => 'Amount mismatch! Exchange cancelled.';

  @override
  String vaultDialogTotal(Object amount) {
    return 'Total: $amount';
  }

  @override
  String get clockInReportTitle => 'Clock-in Report';

  @override
  String get clockInReportTotalHours => 'Total Hours';

  @override
  String get clockInReportStaffCount => 'Staff Count';

  @override
  String get clockInReportWorkDays => 'Work Days';

  @override
  String get clockInReportUnitPpl => 'ppl';

  @override
  String get clockInReportUnitDays => 'days';

  @override
  String get clockInReportUnitHr => 'hr';

  @override
  String get clockInReportNoRecords => 'No records found.';

  @override
  String get clockInReportLabelManual => 'Manual';

  @override
  String get clockInReportLabelIn => 'In';

  @override
  String get clockInReportLabelOut => 'Out';

  @override
  String get clockInReportStatusWorking => 'Working';

  @override
  String get clockInReportStatusCompleted => 'Completed';

  @override
  String get clockInReportStatusIncomplete => 'Incomplete';

  @override
  String get clockInReportAllStaff => 'All Staff';

  @override
  String get clockInReportSelectStaff => 'Select Staff';

  @override
  String get clockInDetailTitleIn => 'Clock In';

  @override
  String get clockInDetailTitleOut => 'Clock Out';

  @override
  String get clockInDetailMissing => 'Missing Record';

  @override
  String get clockInDetailFixButton => 'Fix Clock-out';

  @override
  String get clockInDetailCloseButton => 'Close';

  @override
  String clockInDetailLabelWifi(Object wifi) {
    return 'WiFi: $wifi';
  }

  @override
  String clockInDetailLabelReason(Object reason) {
    return 'Reason: $reason';
  }

  @override
  String get clockInDetailReasonSupervisorFix => 'Supervisor Fix';

  @override
  String get clockInDetailErrorInLaterThanOut => 'Clock-in cannot be later than Clock-out.';

  @override
  String get clockInDetailErrorOutEarlierThanIn => 'Clock-out cannot be earlier than Clock-in.';

  @override
  String get clockInDetailErrorDateCheck => 'Date Error: Please check if you selected the correct date (e.g., next day).';

  @override
  String get clockInDetailSuccessUpdate => 'Time updated successfully.';

  @override
  String get clockInDetailSelectDate => 'Select Clock-out Date';

  @override
  String get commonNone => 'None';

  @override
  String get workReportOverviewTitle => 'Work Reports';

  @override
  String get workReportOverviewNoRecords => 'No reports found.';

  @override
  String get workReportOverviewSelectStaff => 'Select Staff';

  @override
  String get workReportOverviewAllStaff => 'All Staff';

  @override
  String get workReportOverviewNoSubject => 'No Subject';

  @override
  String get workReportOverviewNoContent => 'No Content';

  @override
  String workReportOverviewOvertimeTag(Object hours) {
    return 'OT: ${hours}h';
  }

  @override
  String workReportDetailOvertimeLabel(Object hours) {
    return 'Overtime: $hours hr';
  }

  @override
  String get commonClose => 'Close';

  @override
  String get userMgmtTitle => 'User Management';

  @override
  String get userMgmtInviteNewUser => 'Invite New User';

  @override
  String get userMgmtStatusInvited => 'Invited';

  @override
  String get userMgmtStatusWaiting => 'Waiting...';

  @override
  String userMgmtLabelRole(Object roleName) {
    return 'Role: $roleName';
  }

  @override
  String get userMgmtNameHint => 'Name';

  @override
  String get userMgmtInviteNote => 'User will receive an email invitation.';

  @override
  String get userMgmtInviteButton => 'Invite';

  @override
  String get userMgmtEditTitle => 'Edit User Info';

  @override
  String get userMgmtDeleteTitle => 'Delete User';

  @override
  String userMgmtDeleteContent(Object userName) {
    return 'Are you sure to delete $userName?';
  }

  @override
  String userMgmtErrorLoad(Object error) {
    return 'Failed to load: $error';
  }

  @override
  String get userMgmtInviteSuccess => 'Invitation sent! The user will receive an email to join.';

  @override
  String userMgmtInviteFailed(Object error) {
    return 'Invitation failed: $error';
  }

  @override
  String userMgmtErrorConnection(Object error) {
    return 'Connection error: $error';
  }

  @override
  String userMgmtDeleteFailed(Object error) {
    return 'Deletion failed: $error';
  }

  @override
  String get userMgmtLabelEmail => 'Email';

  @override
  String get userMgmtLabelRolePicker => 'Role';

  @override
  String get userMgmtButtonDone => 'Done';

  @override
  String get userMgmtLabelRoleSelect => 'Select';

  @override
  String get roleMgmtTitle => 'Role Management';

  @override
  String get roleMgmtSystemDefault => 'System Default';

  @override
  String roleMgmtPermissionGroupTitle(Object groupName) {
    return 'Permissions - $groupName';
  }

  @override
  String get roleMgmtRoleNameHint => 'Role Name';

  @override
  String get roleMgmtSaveButton => 'Save';

  @override
  String get roleMgmtDeleteRole => 'Delete Role';

  @override
  String get roleMgmtAddNewRole => 'Add New Role';

  @override
  String get roleMgmtEnterRoleName => 'Enter role name (e.g. Server)';

  @override
  String get roleMgmtCreateButton => 'Create';

  @override
  String get roleMgmtDeleteConfirmTitle => 'Delete Role';

  @override
  String get roleMgmtDeleteConfirmContent => 'Are you sure you want to delete this role? This action cannot be undone.';

  @override
  String get roleMgmtCannotDeleteTitle => 'Cannot Delete Role';

  @override
  String roleMgmtCannotDeleteContent(Object count, Object roleName) {
    return 'There are still $count users assigned to the role \"$roleName\".\n\nPlease assign them to a different role before deleting.';
  }

  @override
  String get roleMgmtUnderstandButton => 'I Understand';

  @override
  String roleMgmtErrorLoad(Object error) {
    return 'Failed to load roles: $error';
  }

  @override
  String roleMgmtErrorSave(Object error) {
    return 'Error saving permissions: $error';
  }

  @override
  String roleMgmtErrorAdd(Object error) {
    return 'Error adding role: $error';
  }

  @override
  String get commonNotificationTitle => 'Notification';

  @override
  String get permGroupMainScreen => 'Main Screen';

  @override
  String get permGroupSchedule => 'Schedule';

  @override
  String get permGroupBackstageDashboard => 'Backstage Dashboard';

  @override
  String get permGroupSettings => 'Settings';

  @override
  String get permHomeOrder => 'Take Orders';

  @override
  String get permHomePrep => 'Prep List';

  @override
  String get permHomeStock => 'Stock/Inventory';

  @override
  String get permHomeBackDashboard => 'Backstage Dashboard';

  @override
  String get permHomeDailyCost => 'Daily Cost Input';

  @override
  String get permHomeCashFlow => 'Cash Flow Report';

  @override
  String get permHomeMonthlyCost => 'Monthly Cost Input';

  @override
  String get permHomeScan => 'Smart Scan';

  @override
  String get permScheduleEdit => 'Edit Staff Schedule';

  @override
  String get permBackCashFlow => 'Cash Flow Report';

  @override
  String get permBackCostSum => 'Cost Sum Report';

  @override
  String get permBackDashboard => 'Operation Dashboard';

  @override
  String get permBackCashVault => 'Cash Vault Management';

  @override
  String get permBackClockIn => 'Clock-in Report';

  @override
  String get permBackViewAllClockIn => 'View All Staff Clock-ins';

  @override
  String get permBackWorkReport => 'Work Report Overview';

  @override
  String get permSetStaff => 'Manage Users';

  @override
  String get permSetRole => 'Role Management';

  @override
  String get permSetPrinter => 'Printer Settings';

  @override
  String get permSetTableMap => 'Table Map Management';

  @override
  String get permSetTableList => 'Table Status List';

  @override
  String get permSetMenu => 'Edit Menu';

  @override
  String get permSetShift => 'Shift Settings';

  @override
  String get permSetPunch => 'Punch Settings';

  @override
  String get permSetPay => 'Payment Methods';

  @override
  String get permSetCostCat => 'Cost Category Settings';

  @override
  String get permSetInv => 'Inventory & Items';

  @override
  String get permSetCashReg => 'Cash Register Settings';

  @override
  String get stockCategoryTitle => 'Edit Prep Details';

  @override
  String get stockCategoryAddButton => '＋ Add New Category';

  @override
  String get stockCategoryAddDialogTitle => 'Add New Category';

  @override
  String get stockCategoryEditDialogTitle => 'Edit Category';

  @override
  String get stockCategoryHintName => 'Category Name';

  @override
  String get stockCategoryDeleteTitle => 'Delete Category';

  @override
  String stockCategoryDeleteContent(Object categoryName) {
    return 'Are you sure to delete Category: $categoryName?';
  }

  @override
  String get inventoryCategoryTitle => 'Edit Stock List';

  @override
  String get inventoryManagementTitle => 'Inventory Management';

  @override
  String get inventoryCategoryDetailTitle => 'Product List';

  @override
  String get inventoryCategoryAddButton => '＋ Add New Category';

  @override
  String get inventoryCategoryAddDialogTitle => 'Add New Category';

  @override
  String get inventoryCategoryEditDialogTitle => 'Edit Category';

  @override
  String get inventoryCategoryHintName => 'Category Name';

  @override
  String get inventoryCategoryDeleteTitle => 'Delete Category';

  @override
  String inventoryCategoryDeleteContent(Object categoryName) {
    return 'Are you sure to delete Category: $categoryName?';
  }

  @override
  String get inventoryItemAddButton => '＋ Add New Product';

  @override
  String get inventoryItemAddDialogTitle => 'Add New Product';

  @override
  String get inventoryItemEditDialogTitle => 'Edit Product';

  @override
  String get inventoryItemDeleteTitle => 'Delete Product';

  @override
  String inventoryItemDeleteContent(Object itemName) {
    return 'Are you sure to delete $itemName?';
  }

  @override
  String get inventoryItemHintName => 'Product Name';

  @override
  String get inventoryItemHintUnit => 'Product Unit';

  @override
  String get inventoryItemHintStock => 'Current Inventory Number';

  @override
  String get inventoryItemHintPar => 'Safety Inventory Quantity';

  @override
  String get stockItemTitle => 'Product Info';

  @override
  String get stockItemLabelName => 'Product Name';

  @override
  String get stockItemLabelMainIngredients => 'Main Ingredients';

  @override
  String get stockItemLabelSubsidiaryIngredients => 'Subsidiary Ingredient';

  @override
  String stockItemLabelDetails(Object index) {
    return 'Details $index';
  }

  @override
  String get stockItemHintIngredient => 'Ingredient';

  @override
  String get stockItemHintQty => 'Qty';

  @override
  String get stockItemHintUnit => 'Unit';

  @override
  String get stockItemHintInstructionsSub => 'Instructions Details of Subsidiary';

  @override
  String get stockItemHintInstructionsNote => 'Instructions Details of Product';

  @override
  String get stockItemAddSubDialogTitle => 'Add Subsidiary Ingredient';

  @override
  String get stockItemEditSubDialogTitle => 'Edit Subsidiary Category';

  @override
  String get stockItemAddSubHintGroupName => 'Group Name (e.g., Garnish)';

  @override
  String get stockItemAddOptionTitle => 'Add Subsidiary Ingredient or Detail';

  @override
  String get stockItemAddOptionSub => 'Add Subsidiary Ingredient';

  @override
  String get stockItemAddOptionDetail => 'Add Detail';

  @override
  String get stockItemDeleteSubTitle => 'Delete Subsidiary Ingredient';

  @override
  String get stockItemDeleteSubContent => 'Are you sure to delete this subsidiary ingredient and its notes?';

  @override
  String get stockItemDeleteNoteTitle => 'Delete Note';

  @override
  String get stockItemDeleteNoteContent => 'Are you sure to delete this note?';

  @override
  String get stockCategoryDetailItemTitle => 'Product List';

  @override
  String get stockCategoryDetailAddItemButton => '＋ Add New Product';

  @override
  String get stockItemDetailDeleteTitle => 'Delete Product';

  @override
  String stockItemDetailDeleteContent(Object productName) {
    return 'Are you sure to delete $productName?';
  }

  @override
  String get inventoryLogTitle => 'Stock Logs';

  @override
  String get inventoryLogSearchHint => 'Search Stock Item';

  @override
  String get inventoryLogAllDates => 'All Dates';

  @override
  String get inventoryLogDatePickerConfirm => 'Confirm';

  @override
  String get inventoryLogReasonAll => 'ALL';

  @override
  String get inventoryLogReasonAdd => 'Add';

  @override
  String get inventoryLogReasonAdjustment => 'Inventory Adjustment';

  @override
  String get inventoryLogReasonWaste => 'Waste';

  @override
  String get inventoryLogNoRecords => 'No logs found.';

  @override
  String get inventoryLogCardUnknownItem => 'Unknown Item';

  @override
  String get inventoryLogCardUnknownUser => 'Unknown Operator';

  @override
  String inventoryLogCardLabelName(Object userName) {
    return 'Name: $userName';
  }

  @override
  String inventoryLogCardLabelChange(Object adjustment, Object unit) {
    return 'Change: $adjustment $unit';
  }

  @override
  String inventoryLogCardLabelStock(Object newStock, Object oldStock) {
    return 'Number $oldStock→$newStock';
  }

  @override
  String get printerSettingsTitle => 'Hardware Setting';

  @override
  String get printerSettingsListTitle => 'Printer List';

  @override
  String get printerSettingsNoPrinters => 'No printers currently configured';

  @override
  String printerSettingsLabelIP(Object ip) {
    return 'IP: $ip';
  }

  @override
  String get printerDialogAddTitle => 'Add New Printer';

  @override
  String get printerDialogEditTitle => 'Edit Printer Info';

  @override
  String get printerDialogHintName => 'Printer Name';

  @override
  String get printerDialogHintIP => 'Printer IP Address';

  @override
  String get printerTestConnectionFailed => '❌ Printer connection failed';

  @override
  String get printerTestTicketSuccess => '✅ Test ticket printed';

  @override
  String get printerCashDrawerOpenSuccess => '✅ Cash drawer opened';

  @override
  String get printerDeleteTitle => 'Delete Printer';

  @override
  String printerDeleteContent(Object printerName) {
    return 'Are you sure to delete $printerName?';
  }

  @override
  String get printerTestPrintTitle => '【TICKET TEST】';

  @override
  String get printerTestPrintSubtitle => 'Testing printer connection';

  @override
  String get printerTestPrintContent1 => 'This is a test ticket,';

  @override
  String get printerTestPrintContent2 => 'If you see this text,';

  @override
  String get printerTestPrintContent3 => 'It means text and image printing are normal.';

  @override
  String get printerTestPrintContent4 => 'It means text and image printing are normal.';

  @override
  String get printerTestPrintContent5 => 'Thank you for using Gallery 20.5';

  @override
  String get tableMapAreaSuffix => ' Zone';

  @override
  String get tableMapRemoveTitle => 'Remove Table';

  @override
  String tableMapRemoveContent(Object tableName) {
    return 'Remove \"$tableName\" from map?';
  }

  @override
  String get tableMapRemoveConfirm => 'Remove';

  @override
  String get tableMapAddDialogTitle => 'Add Table';

  @override
  String get tableMapShapeCircle => 'Circle';

  @override
  String get tableMapShapeSquare => 'Square';

  @override
  String get tableMapShapeRect => 'Rect';

  @override
  String get tableMapAddDialogHint => 'Select Table No.';

  @override
  String get tableMapNoAvailableTables => 'No available tables in this zone.';

  @override
  String get tableMgmtTitle => 'Table Management';

  @override
  String get tableMgmtAreaListAddButton => '＋ Add New Area';

  @override
  String get tableMgmtAreaListAddTitle => 'Add New Zone';

  @override
  String get tableMgmtAreaListEditTitle => 'Edit Zone';

  @override
  String get tableMgmtAreaListHintName => 'Zone Name';

  @override
  String get tableMgmtAreaListDeleteTitle => 'Delete Zone';

  @override
  String tableMgmtAreaListDeleteContent(Object areaName) {
    return 'Are you sure to delete Zone $areaName?';
  }

  @override
  String tableMgmtAreaAddSuccess(Object name) {
    return '✅ Zone \"$name\" added successfully';
  }

  @override
  String get tableMgmtAreaAddFailure => 'Failed to add zone';

  @override
  String get tableMgmtTableListAddButton => '＋ Add New Table';

  @override
  String get tableMgmtTableListAddTitle => 'Add New Table';

  @override
  String get tableMgmtTableListEditTitle => 'Edit Table';

  @override
  String get tableMgmtTableListHintName => 'Table Name';

  @override
  String get tableMgmtTableListDeleteTitle => 'Delete Table';

  @override
  String tableMgmtTableListDeleteContent(Object tableName) {
    return 'Are you sure to delete Table $tableName?';
  }

  @override
  String get tableMgmtTableAddFailure => 'Failed to add table';

  @override
  String get tableMgmtTableDeleteFailure => 'Failed to delete table';

  @override
  String get commonSaveFailure => 'Failed to save data.';

  @override
  String get commonDeleteFailure => 'Failed to delete item.';

  @override
  String get commonNameExists => 'Name already exists.';

  @override
  String get menuEditTitle => 'Edit Menu';

  @override
  String get menuCategoryAddButton => '＋ Add New Category';

  @override
  String get menuDetailAddItemButton => '＋ Add New Product';

  @override
  String get menuDeleteCategoryTitle => 'Delete Category';

  @override
  String menuDeleteCategoryContent(Object categoryName) {
    return 'Are you sure to delete $categoryName?';
  }

  @override
  String get menuCategoryAddDialogTitle => 'Add New Category';

  @override
  String get menuCategoryEditDialogTitle => 'Edit Category Name';

  @override
  String get menuCategoryHintName => 'Category Name';

  @override
  String get menuItemAddDialogTitle => 'Add New Product';

  @override
  String get menuItemEditDialogTitle => 'Edit Product';

  @override
  String get menuItemPriceLabel => 'Current Price';

  @override
  String get menuItemMarketPrice => 'Market Price';

  @override
  String get menuItemHintPrice => 'Product Price';

  @override
  String get menuItemLabelMarketPrice => 'Market Price';

  @override
  String menuItemLabelPrice(Object price) {
    return 'Price: $price';
  }

  @override
  String get shiftSetupTitle => 'Shift Setup';

  @override
  String get shiftSetupSectionTitle => 'Defined Shift Types';

  @override
  String get shiftSetupListAddButton => '+ Add Shift Type';

  @override
  String get shiftSetupSaveButton => 'Save';

  @override
  String shiftListStartTime(Object endTime, Object startTime) {
    return '$startTime - $endTime';
  }

  @override
  String get shiftDialogAddTitle => 'Add Shift Type';

  @override
  String get shiftDialogEditTitle => 'Edit Shift Type';

  @override
  String get shiftDialogHintName => 'Shift Name';

  @override
  String get shiftDialogLabelStartTime => 'Start Time:';

  @override
  String get shiftDialogLabelEndTime => 'End Time:';

  @override
  String get shiftDialogLabelColor => 'Color Tag:';

  @override
  String get shiftDialogErrorNameEmpty => 'Please enter a shift name.';

  @override
  String get shiftDeleteConfirmTitle => 'Confirm Delete';

  @override
  String shiftDeleteConfirmContent(Object shiftName) {
    return 'Are you sure you want to delete the shift type \"$shiftName\"? This change must be saved.';
  }

  @override
  String shiftDeleteLocalSuccess(Object shiftName) {
    return 'Shift type \"$shiftName\" deleted locally.';
  }

  @override
  String get shiftSaveSuccess => 'Shift settings saved successfully!';

  @override
  String shiftSaveError(Object error) {
    return 'Failed to save settings: $error';
  }

  @override
  String shiftLoadError(Object error) {
    return 'Error loading shifts: $error';
  }

  @override
  String get commonSuccess => 'Success';

  @override
  String get commonError => 'Error';

  @override
  String get punchInSetupTitle => 'Clock-in Info';

  @override
  String get punchInWifiSection => 'Current Wi-Fi Name';

  @override
  String get punchInLocationSection => 'Current Location';

  @override
  String get punchInLoading => 'Loading...';

  @override
  String get punchInErrorPermissionTitle => 'Permission Error';

  @override
  String get punchInErrorPermissionContent => 'Please enable location permission to use this feature.';

  @override
  String get punchInErrorFetchTitle => 'Failed to Get Info';

  @override
  String get punchInErrorFetchContent => 'Failed to get Wi-Fi or GPS information. Please check permissions and network connection.';

  @override
  String get punchInSaveFailureTitle => 'Error';

  @override
  String get punchInSaveFailureContent => 'Failed to get necessary information.';

  @override
  String get punchInSaveSuccessTitle => 'Success';

  @override
  String get punchInSaveSuccessContent => 'Clock-in information saved.';

  @override
  String get punchInRegainButton => 'Regain Wi-Fi & Location';

  @override
  String get punchInSaveButton => 'Save Clock-in Info';

  @override
  String get punchInConfirmOverwriteTitle => 'Confirm Overwrite';

  @override
  String get punchInConfirmOverwriteContent => 'Clock-in information already exists for this shop. Do you want to overwrite the existing data?';

  @override
  String get commonOverwrite => 'Overwrite';

  @override
  String get commonOK => 'OK';

  @override
  String get paymentSetupTitle => 'Payment Setup';

  @override
  String get paymentSetupMethodsSection => 'Enabled Payment Methods';

  @override
  String get paymentSetupFunctionModule => 'Function Module';

  @override
  String get paymentSetupFunctionDeposit => 'Deposit';

  @override
  String get paymentSetupSaveButton => 'Save';

  @override
  String paymentSetupLoadError(Object error) {
    return 'Error loading shifts: $error';
  }

  @override
  String get paymentSetupSaveSuccess => '✅ Settings saved';

  @override
  String paymentSetupSaveFailure(Object error) {
    return 'Saving failed: $error';
  }

  @override
  String get paymentAddDialogTitle => '＋Add Payment Method';

  @override
  String get paymentAddDialogHintName => 'Method Name';

  @override
  String get settlementDetailDailyRevenueSummary => 'Daily Revenue Summary';

  @override
  String get settlementDetailPaymentDetails => 'Payment Details';

  @override
  String get settlementDetailCashCount => 'Cash Count';

  @override
  String get settlementDetailValue => 'Value';

  @override
  String get settlementDetailSummary => 'Summary';

  @override
  String get settlementDetailTotalRevenue => 'Total Revenue:';

  @override
  String get settlementDetailTotalCost => 'Total Cost:';

  @override
  String get settlementDetailCash => 'Cash:';

  @override
  String get settlementDetailTodayDeposit => 'Today\'s Deposit:';

  @override
  String get vaultChangeMoneyStep1 => 'Change Money (Step 1/2)';

  @override
  String get vaultChangeMoneyStep2 => 'Change Money (Step 2/2)';

  @override
  String vaultSaveFailed(Object error) {
    return 'Save failed: $error';
  }

  @override
  String get paymentAddDialogSave => 'Save';

  @override
  String get costCategoryTitle => 'Cost Category';

  @override
  String get costCategoryAddButton => 'Add New Category';

  @override
  String get costCategoryTypeCOGS => 'COGS';

  @override
  String get costCategoryTypeOPEX => 'OPEX';

  @override
  String get costCategoryAddTitle => 'Add Category';

  @override
  String get costCategoryEditTitle => 'Edit Category';

  @override
  String get costCategoryHintName => 'Category Name';

  @override
  String costCategoryDeleteTitle(Object categoryName) {
    return 'Delete $categoryName';
  }

  @override
  String get costCategoryDeleteContent => 'Are you sure to delete this category?';

  @override
  String get costCategoryNoticeErrorTitle => 'Error';

  @override
  String get costCategoryNoticeErrorLoad => 'Failed to load categories.';

  @override
  String get costCategoryNoticeErrorAdd => 'Failed to add category.';

  @override
  String get costCategoryNoticeErrorUpdate => 'Failed to update category.';

  @override
  String get costCategoryNoticeErrorDelete => 'Failed to delete category.';

  @override
  String get cashRegSetupTitle => 'Cashbox Setup';

  @override
  String get cashRegSetupSubtitle => 'Please enter the default quantity of\neach denomination in the cash drawer.';

  @override
  String cashRegSetupTotalLabel(Object totalAmount) {
    return 'Total: $totalAmount';
  }

  @override
  String get cashRegSetupInputHint => '0';

  @override
  String get cashRegNoticeSaveSuccess => 'Cash float settings saved successfully!';

  @override
  String cashRegNoticeSaveFailure(Object error) {
    return 'Saving failed: $error';
  }

  @override
  String cashRegNoticeLoadError(Object error) {
    return 'Error loading cashbox settings: $error';
  }

  @override
  String get languageEnglish => 'English';

  @override
  String get languageTraditionalChinese => '繁體中文';

  @override
  String get changePasswordTitle => 'Change Password';

  @override
  String get changePasswordOldHint => 'Old Password';

  @override
  String get changePasswordNewHint => 'New Password';

  @override
  String get changePasswordConfirmHint => 'Confirm New Password';

  @override
  String get changePasswordButton => 'Change Password';

  @override
  String get passwordValidatorEmptyOld => 'Please enter the old password';

  @override
  String get passwordValidatorLength => 'Password must be at least 6 digits';

  @override
  String get passwordValidatorMismatch => 'Passwords do not match';

  @override
  String get passwordErrorReLogin => 'Please log in again';

  @override
  String get passwordErrorOldPassword => 'Incorrect old password';

  @override
  String get passwordErrorUpdateFailed => 'Password update failed';

  @override
  String get passwordSuccess => '✅ Password updated';

  @override
  String passwordFailure(Object error) {
    return '❌ Password update failed: $error';
  }

  @override
  String get languageSimplifiedChinese => '简体中文';

  @override
  String get languageItalian => 'Italiano';

  @override
  String get languageVietnamese => 'Tiếng Việt';

  @override
  String get settingAppearance => 'System Color';

  @override
  String get themeSystem => 'System Color';

  @override
  String get themeSage => 'Gallery 20.5 Default';

  @override
  String get themeLight => 'Light Mode';

  @override
  String get themeDark => 'Dark Mode';
}
