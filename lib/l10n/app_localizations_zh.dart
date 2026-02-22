// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get homeTitle => 'Gallery 20.5';

  @override
  String get loading => '載入中...';

  @override
  String get homeOrder => '點餐';

  @override
  String get homeCalendar => '行事曆';

  @override
  String get homeShift => '排班';

  @override
  String get homePrep => '備料';

  @override
  String get homeStock => '庫存';

  @override
  String get homeClockIn => '打卡';

  @override
  String get homeWorkReport => '工作日報';

  @override
  String get homeBackhouse => '後台';

  @override
  String get homeDailyCost => '每日成本';

  @override
  String get homeCashFlow => '關帳';

  @override
  String get homeMonthlyCost => '月度成本';

  @override
  String get homeSetting => '設定';

  @override
  String get settingsTitle => '設定';

  @override
  String get defaultUser => '使用者';

  @override
  String get settingPrepInfo => '備料資訊';

  @override
  String get settingStock => '庫存管理';

  @override
  String get settingStockLog => '庫存紀錄';

  @override
  String get settingTable => '桌位管理';

  @override
  String get settingTableMap => '桌位圖';

  @override
  String get settingMenu => '菜單管理';

  @override
  String get settingPrinter => '出單機設定';

  @override
  String get settingClockInInfo => '打卡資訊';

  @override
  String get settingPayment => '付款方式';

  @override
  String get settingCashbox => '零錢櫃管理';

  @override
  String get settingShift => '排班管理';

  @override
  String get settingUserManagement => '人員管理';

  @override
  String get settingCostCategories => '成本類別';

  @override
  String get settingLanguage => '語言設定';

  @override
  String get settingChangePassword => '修改密碼';

  @override
  String get settingLogout => '登出';

  @override
  String get settingRoleManagement => '角色權限管理';

  @override
  String get loginTitle => '登入';

  @override
  String get loginShopIdHint => '選擇店號';

  @override
  String get loginEmailHint => '電子信箱';

  @override
  String get loginPasswordHint => '密碼';

  @override
  String get loginButton => '登入';

  @override
  String get loginAddShopOption => '+ 新增店號';

  @override
  String get loginAddShopDialogTitle => '新增店號';

  @override
  String get loginAddShopDialogHint => '輸入新店號';

  @override
  String get commonCancel => '取消';

  @override
  String get commonAdd => '新增';

  @override
  String get loginMsgFillAll => '請填寫所有欄位';

  @override
  String get loginMsgFaceIdFirst => '請先用 Email 登入一次';

  @override
  String get loginMsgFaceIdReason => '請使用 Face ID 登入';

  @override
  String get loginMsgNoSavedData => '尚未儲存任何登入資料';

  @override
  String get loginMsgNoFaceIdData => '找不到這組帳號的 Face ID 登入資料';

  @override
  String get loginMsgShopNotFound => '找不到該店號';

  @override
  String get loginMsgNoPermission => '您沒有這間店的使用權限';

  @override
  String get loginMsgFailed => '登入失敗';

  @override
  String loginMsgFailedReason(Object error) {
    return '登入失敗：$error';
  }

  @override
  String get scheduleTitle => '行事曆';

  @override
  String get scheduleTabMy => '個人';

  @override
  String get scheduleTabAll => '全部';

  @override
  String get scheduleTabCustom => '自訂';

  @override
  String get scheduleFilterTooltip => '篩選群組';

  @override
  String get scheduleSelectGroups => '選擇群組';

  @override
  String get commonDone => '完成';

  @override
  String get schedulePersonalMe => '個人 (我)';

  @override
  String get scheduleUntitled => '未命名';

  @override
  String get scheduleNoEvents => '無行程';

  @override
  String get scheduleAllDay => '整天';

  @override
  String get scheduleDayLabel => '全天';

  @override
  String get commonNoTitle => '無標題';

  @override
  String scheduleMoreEvents(Object count) {
    return '還有 $count 個...';
  }

  @override
  String get commonToday => '今天';

  @override
  String get calendarGroupsTitle => '行事曆群組';

  @override
  String get calendarGroupPersonal => '個人 (我)';

  @override
  String get calendarGroupUntitled => '未命名';

  @override
  String get calendarGroupPrivateDesc => '私人行程僅您可見';

  @override
  String calendarGroupVisibleToMembers(Object count) {
    return '對 $count 位成員可見';
  }

  @override
  String get calendarGroupNew => '建立群組';

  @override
  String get calendarGroupEdit => '編輯群組';

  @override
  String get calendarGroupName => '群組名稱';

  @override
  String get calendarGroupNameHint => '例如：工作、會議';

  @override
  String get calendarGroupColor => '群組代表色';

  @override
  String get calendarGroupEventColors => '事件標籤顏色';

  @override
  String get calendarGroupSaveFirstHint => '請先儲存群組以設定自訂事件顏色。';

  @override
  String get calendarGroupVisibleTo => '群組成員';

  @override
  String get calendarGroupDelete => '刪除群組';

  @override
  String get calendarGroupDeleteConfirm => '刪除此群組將一併移除所有關聯事件，確定要刪除嗎？';

  @override
  String get calendarColorNew => '新增顏色';

  @override
  String get calendarColorEdit => '編輯顏色';

  @override
  String get calendarColorName => '顏色名稱';

  @override
  String get calendarColorNameHint => '例如：緊急、會議';

  @override
  String get calendarColorPick => '選擇顏色';

  @override
  String get calendarColorDelete => '刪除顏色';

  @override
  String get calendarColorDeleteConfirm => '確定要刪除此顏色設定？';

  @override
  String get commonSave => '儲存';

  @override
  String get commonDelete => '刪除';

  @override
  String get notificationGroupInviteTitle => '群組邀請';

  @override
  String notificationGroupInviteBody(Object groupName) {
    return '您已被加入行事曆群組：「$groupName」';
  }

  @override
  String get eventDetailTitleEdit => '編輯事件';

  @override
  String get eventDetailTitleNew => '新增事件';

  @override
  String get eventDetailLabelTitle => '標題';

  @override
  String get eventDetailLabelGroup => '群組';

  @override
  String get eventDetailLabelColor => '顏色';

  @override
  String get eventDetailLabelAllDay => '整天';

  @override
  String get eventDetailLabelStarts => '開始';

  @override
  String get eventDetailLabelEnds => '結束';

  @override
  String get eventDetailLabelRepeat => '重複';

  @override
  String get eventDetailLabelRelatedPeople => '相關人員';

  @override
  String get eventDetailLabelNotes => '備註';

  @override
  String get eventDetailDelete => '刪除事件';

  @override
  String get eventDetailDeleteConfirm => '確定要刪除此事件嗎？';

  @override
  String get eventDetailSelectGroup => '選擇群組';

  @override
  String get eventDetailSelectColor => '選擇顏色';

  @override
  String get eventDetailGroupDefault => '群組預設';

  @override
  String get eventDetailCustomColor => '自訂顏色';

  @override
  String get eventDetailNoCustomColors => '此群組尚未設定自訂顏色。';

  @override
  String get eventDetailSelectPeople => '選擇人員';

  @override
  String eventDetailPeopleCount(Object count) {
    return '$count 人';
  }

  @override
  String get eventDetailNone => '無';

  @override
  String get eventDetailRepeatNone => '無';

  @override
  String get eventDetailRepeatDaily => '每天';

  @override
  String get eventDetailRepeatWeekly => '每週';

  @override
  String get eventDetailRepeatMonthly => '每月';

  @override
  String get eventDetailErrorTitleRequired => '標題為必填';

  @override
  String get eventDetailErrorGroupRequired => '群組為必選';

  @override
  String get eventDetailErrorEndTime => '結束時間不能早於開始時間';

  @override
  String get eventDetailErrorSave => '儲存失敗';

  @override
  String get eventDetailErrorDelete => '刪除失敗';

  @override
  String notificationNewEventTitle(Object groupName) {
    return '[$groupName] 新增事件';
  }

  @override
  String notificationNewEventBody(Object time, Object title, Object userName) {
    return '$userName 新增了：$title ($time)';
  }

  @override
  String get notificationTimeChangeTitle => '⏰ [變更] 時間異動';

  @override
  String notificationTimeChangeBody(Object title, Object userName) {
    return '$userName 修改了「$title」的時間，請確認。';
  }

  @override
  String get notificationContentChangeTitle => '✏️ [更新] 內容變更';

  @override
  String notificationContentChangeBody(Object title, Object userName) {
    return '$userName 更新了「$title」的詳細資訊。';
  }

  @override
  String get notificationDeleteTitle => '🗑️ [取消] 事件移除';

  @override
  String notificationDeleteBody(Object title, Object userName) {
    return '$userName 取消了事件：$title';
  }

  @override
  String get localNotificationTitle => '🔔 待辦事項提醒';

  @override
  String localNotificationBody(Object title) {
    return '10分鐘後：$title';
  }

  @override
  String get commonSelect => '請選擇...';

  @override
  String get commonUnknown => '未知';

  @override
  String get commonPersonalMe => '個人 (我)';

  @override
  String get scheduleViewTitle => '排班表';

  @override
  String get scheduleViewModeMy => '我的班表';

  @override
  String get scheduleViewModeAll => '全店班表';

  @override
  String scheduleViewErrorInit(Object error) {
    return '初始數據載入失敗：$error';
  }

  @override
  String scheduleViewErrorFetch(Object error) {
    return '獲取班表失敗：$error';
  }

  @override
  String get scheduleViewUnknown => '未知';

  @override
  String get scheduleUploadTitle => '排班管理';

  @override
  String get scheduleUploadSelectEmployee => '選擇員工';

  @override
  String get scheduleUploadSelectShiftFirst => '請先從上方選擇一個班型';

  @override
  String get scheduleUploadUnsavedChanges => '未儲存的變更';

  @override
  String get scheduleUploadDiscardChangesMessage => '您有未儲存的變更，切換或離開頁面將會遺失這些變更。是否繼續？';

  @override
  String get scheduleUploadNoChanges => '沒有需要儲存的變更。';

  @override
  String get scheduleUploadSaveSuccess => '✅ 班表已儲存！';

  @override
  String scheduleUploadSaveError(Object error) {
    return '❌ 儲存失敗：$error';
  }

  @override
  String scheduleUploadLoadError(Object error) {
    return '❌ 初始數據載入失敗：$error';
  }

  @override
  String scheduleUploadLoadScheduleError(Object name) {
    return '❌ 載入 $name 的班表失敗';
  }

  @override
  String scheduleUploadRole(Object role) {
    return '職位：$role';
  }

  @override
  String get commonConfirm => '確認';

  @override
  String get commonSaveChanges => '儲存變更';

  @override
  String get prepViewTitle => '檢視備料類別';

  @override
  String get prepViewItemTitle => '檢視備料品項';

  @override
  String get prepViewItemUntitled => '未命名品項';

  @override
  String get prepViewMainIngredients => '主要材料';

  @override
  String prepViewNote(Object note) {
    return '備註：$note';
  }

  @override
  String get prepViewDetailLabel => '詳細資訊';

  @override
  String get settingCategoryPersonnel => '人員與權限管理';

  @override
  String get settingCategoryMenuInv => '菜單與庫存設定';

  @override
  String get settingCategoryEquipTable => '設備與桌位配置';

  @override
  String get settingCategorySystem => '系統設定';

  @override
  String get settingPayroll => '薪資報表';

  @override
  String get permBackPayroll => '薪資報表 (Payroll Report)';

  @override
  String get permBackLoginWeb => '允許登入控制台 (Backend Login)';

  @override
  String get settingModifiers => '配料設定';

  @override
  String get settingTax => '稅務設定';

  @override
  String get inventoryViewTitle => '庫存盤點';

  @override
  String get inventorySearchHint => '搜尋品項';

  @override
  String get inventoryNoItems => '查無項目';

  @override
  String inventorySafetyQuantity(Object quantity) {
    return '安全存量：$quantity';
  }

  @override
  String get inventoryConfirmUpdateTitle => '確認更新';

  @override
  String inventoryConfirmUpdateOriginal(Object unit, Object value) {
    return '原始數量：$value $unit';
  }

  @override
  String inventoryConfirmUpdateNew(Object unit, Object value) {
    return '新數量：$value $unit';
  }

  @override
  String inventoryConfirmUpdateChange(Object value) {
    return '變更量：$value';
  }

  @override
  String get inventoryUnsavedTitle => '未儲存的變更';

  @override
  String get inventoryUnsavedContent => '您有未儲存的庫存調整，是否要儲存並離開？';

  @override
  String get inventoryUnsavedDiscard => '放棄並離開';

  @override
  String inventoryUpdateSuccess(Object name) {
    return '✅ $name 庫存更新成功！';
  }

  @override
  String get inventoryUpdateFailedTitle => '更新失敗';

  @override
  String get inventoryUpdateFailedMsg => '資料庫錯誤，請聯繫管理員。';

  @override
  String get inventoryBatchSaveFailedTitle => '批量儲存失敗';

  @override
  String inventoryBatchSaveFailedMsg(Object name) {
    return '品項 $name 儲存失敗。';
  }

  @override
  String get inventoryReasonStockIn => '入庫';

  @override
  String get inventoryReasonAudit => '盤點調整';

  @override
  String get inventoryErrorTitle => '錯誤';

  @override
  String get inventoryErrorInvalidNumber => '請輸入有效的數字';

  @override
  String get commonOk => '確定';

  @override
  String get punchTitle => '打卡';

  @override
  String get punchInButton => '上班打卡';

  @override
  String get punchOutButton => '下班打卡';

  @override
  String get punchMakeUpButton => '補打卡\n(上班/下班)';

  @override
  String get punchLocDisabled => '定位服務已關閉，請至設定中開啟。';

  @override
  String get punchLocDenied => '定位權限被拒絕';

  @override
  String get punchLocDeniedForever => '定位權限被永久拒絕，無法請求權限。';

  @override
  String get punchErrorSettingsNotFound => '找不到打卡設定，請聯繫管理員。';

  @override
  String punchErrorWifi(Object wifi) {
    return 'Wi-Fi 不正確。\n請連接至：$wifi';
  }

  @override
  String get punchErrorDistance => '您距離店鋪太遠。';

  @override
  String get punchErrorAlreadyIn => '您已經打過上班卡了。';

  @override
  String get punchSuccessInTitle => '打卡成功';

  @override
  String get punchSuccessInMsg => '祝您上班愉快 : )';

  @override
  String get punchErrorInTitle => '上班打卡失敗';

  @override
  String get punchErrorNoSession => '找不到 24 小時內的上班紀錄，請聯繫管理員。';

  @override
  String get punchErrorOverTime => '工時超過 12 小時，請使用「補打卡」功能。';

  @override
  String get punchSuccessOutTitle => '打卡成功';

  @override
  String get punchSuccessOutMsg => '老闆愛你 ❤️';

  @override
  String get punchErrorOutTitle => '下班打卡失敗';

  @override
  String punchErrorGeneric(Object error) {
    return '發生錯誤：$error';
  }

  @override
  String get punchMakeUpTitle => '補打卡 (上班/下班)';

  @override
  String get punchMakeUpTypeIn => '補上班卡';

  @override
  String get punchMakeUpTypeOut => '補下班卡';

  @override
  String get punchMakeUpReasonHint => '原因 (必填)';

  @override
  String get punchMakeUpErrorReason => '請填寫補打卡原因';

  @override
  String get punchMakeUpErrorFuture => '不能補打未來的時間';

  @override
  String get punchMakeUpError72h => '補打卡不能超過 72 小時，請聯繫管理員。';

  @override
  String punchMakeUpErrorOverlap(Object time) {
    return '發現未下班紀錄 ($time)，請先補下班卡。';
  }

  @override
  String get punchMakeUpErrorNoRecord => '找不到 72 小時內的對應上班紀錄，請聯繫管理員。';

  @override
  String get punchMakeUpErrorOver12h => '工時超過 12 小時，請聯繫管理員。';

  @override
  String get punchMakeUpSuccessTitle => '成功';

  @override
  String get punchMakeUpSuccessMsg => '補打卡成功';

  @override
  String get punchMakeUpCheckInfo => '請確認資訊';

  @override
  String punchMakeUpLabelType(Object type) {
    return '類型：$type';
  }

  @override
  String punchMakeUpLabelTime(Object time) {
    return '時間：$time';
  }

  @override
  String punchMakeUpLabelReason(Object reason) {
    return '原因：$reason';
  }

  @override
  String get commonDate => '日期';

  @override
  String get commonTime => '時間';

  @override
  String get workReportTitle => '工作日報';

  @override
  String get workReportSelectDate => '選擇日期';

  @override
  String get workReportJobSubject => '工作主旨 (必填)';

  @override
  String get workReportJobDescription => '工作內容 (必填)';

  @override
  String get workReportOverTime => '加班時數 (選填)';

  @override
  String get workReportHourUnit => '小時';

  @override
  String get workReportErrorRequiredTitle => '請填寫必填欄位';

  @override
  String get workReportErrorRequiredMsg => '主旨與內容為必填項目！';

  @override
  String get workReportConfirmOverwriteTitle => '報告已存在';

  @override
  String get workReportConfirmOverwriteMsg => '您已提交過此日期的報告。\n是否要覆蓋？';

  @override
  String get workReportOverwriteYes => '覆蓋';

  @override
  String get workReportSuccessTitle => '提交成功';

  @override
  String get workReportSuccessMsg => '您的工作日報已成功提交！';

  @override
  String get workReportSubmitFailed => '提交失敗';

  @override
  String get todoScreenTitle => '待辦事項';

  @override
  String get todoTabIncomplete => '未完成';

  @override
  String get todoTabPending => '待確認';

  @override
  String get todoTabCompleted => '已完成';

  @override
  String get todoFilterMyTasks => '只看與我有關';

  @override
  String todoCountSuffix(Object count) {
    return '$count 筆';
  }

  @override
  String get todoEmptyPending => '沒有待確認事項';

  @override
  String get todoEmptyIncomplete => '沒有待辦事項';

  @override
  String get todoEmptyCompleted => '本月無完成紀錄';

  @override
  String get todoSubmitReviewTitle => '提交驗收';

  @override
  String get todoSubmitReviewContent => '確定已完成並提交給指派人檢查嗎？';

  @override
  String get todoSubmitButton => '提交';

  @override
  String get todoApproveTitle => '通過驗收';

  @override
  String get todoApproveContent => '確定此任務已完成嗎？';

  @override
  String get todoApproveButton => '通過';

  @override
  String get todoRejectTitle => '退回任務';

  @override
  String get todoRejectContent => '將任務退回給員工重新處理？';

  @override
  String get todoRejectButton => '退回';

  @override
  String get todoDeleteTitle => '刪除事項';

  @override
  String get todoDeleteContent => '確定要刪除嗎？此動作無法復原。';

  @override
  String get todoErrorNoPermissionSubmit => '您沒有權限提交此事項';

  @override
  String get todoErrorNoPermissionApprove => '只有指派人可以驗收此事項';

  @override
  String get todoErrorNoPermissionReject => '只有指派人可以退回事項';

  @override
  String get todoErrorNoPermissionEdit => '只有指派人可以編輯內容';

  @override
  String get todoErrorNoPermissionDelete => '只有指派人可以刪除事項';

  @override
  String get notificationTodoReviewTitle => '👀 任務待驗收';

  @override
  String notificationTodoReviewBody(Object name, Object task) {
    return '$name 已提交：$task，請確認。';
  }

  @override
  String get notificationTodoApprovedTitle => '✅ 任務驗收通過';

  @override
  String notificationTodoApprovedBody(Object task) {
    return '指派人已確認完成：$task';
  }

  @override
  String get notificationTodoRejectedTitle => '↩️ 任務被退回';

  @override
  String notificationTodoRejectedBody(Object task) {
    return '請修正並重新提交：$task';
  }

  @override
  String get notificationTodoDeletedTitle => '🗑️ 事項已刪除';

  @override
  String notificationTodoDeletedBody(Object task) {
    return '指派人刪除了：$task';
  }

  @override
  String todoActionSheetTitle(Object title) {
    return '操作：$title';
  }

  @override
  String get todoActionCompleteAndSubmit => '完成並提交驗收';

  @override
  String todoReviewSheetTitle(Object title) {
    return '驗收：$title';
  }

  @override
  String get todoReviewSheetMessageAssigner => '請確認任務是否合格';

  @override
  String get todoReviewSheetMessageAssignee => '等待指派人驗收中';

  @override
  String get todoActionApprove => '✅ 通過驗收';

  @override
  String get todoActionReject => '↩️ 退回重做';

  @override
  String get todoActionViewDetails => '查看詳情';

  @override
  String get todoLabelTo => '給：';

  @override
  String get todoLabelFrom => '來自：';

  @override
  String get todoUnassigned => '未指派';

  @override
  String get todoLabelCompletedAt => '完成於：';

  @override
  String get todoLabelWaitingReview => '等待驗收中';

  @override
  String get commonEdit => '編輯';

  @override
  String get todoAddTaskTitleNew => '新增任務';

  @override
  String get todoAddTaskTitleEdit => '編輯任務';

  @override
  String get todoAddTaskLabelTitle => '任務標題';

  @override
  String get todoAddTaskLabelDesc => '內容描述 (選填)';

  @override
  String get todoAddTaskLabelAssign => '指派給：';

  @override
  String get todoAddTaskSelectStaff => '選擇員工';

  @override
  String todoAddTaskSelectedStaff(Object count) {
    return '已選擇 $count 位員工';
  }

  @override
  String get todoAddTaskSetDueDate => '設定截止日期';

  @override
  String get todoAddTaskSelectDate => '選擇日期';

  @override
  String get todoAddTaskSetDueTime => '設定截止時間';

  @override
  String get todoAddTaskSelectTime => '選擇時間';

  @override
  String get notificationTodoEditTitle => '✏️ 事項已更新';

  @override
  String notificationTodoEditBody(Object task) {
    return '內容已有變動：$task';
  }

  @override
  String get notificationTodoUrgentUpdate => '🔥 急件更新';

  @override
  String get notificationTodoNewTitle => '📝 新待辦事項';

  @override
  String notificationTodoNewBody(Object task) {
    return '$task';
  }

  @override
  String get notificationTodoUrgentNew => '🔥 急件指派';

  @override
  String get costInputTitle => '每日成本';

  @override
  String get costInputTotalToday => '今日總成本';

  @override
  String get costInputLabelName => '項目名稱';

  @override
  String get costInputLabelPrice => '金額';

  @override
  String get costInputTabNotOpenTitle => '尚未開帳';

  @override
  String get costInputTabNotOpenMsg => '請先開啟今日帳務。';

  @override
  String get costInputTabNotOpenPageTitle => '請先開啟今日帳務';

  @override
  String get costInputTabNotOpenPageDesc => '您必須先完成開帳，\n才能開始輸入每日成本。';

  @override
  String get costInputButtonOpenTab => '前往開帳';

  @override
  String get costInputErrorInputTitle => '輸入錯誤';

  @override
  String get costInputErrorInputMsg => '請確認項目名稱與金額填寫正確。';

  @override
  String get costInputSuccess => '✅ 成本儲存成功';

  @override
  String get costInputSaveFailed => '儲存失敗';

  @override
  String get costInputLoadingCategories => '載入中...';

  @override
  String get costDetailTitle => '每日成本明細';

  @override
  String get costDetailNoRecords => '此期間無成本紀錄。';

  @override
  String get costDetailItemUntitled => '未命名項目';

  @override
  String get costDetailCategoryNA => '未知';

  @override
  String get costDetailBuyerNA => '未知';

  @override
  String costDetailLabelCategory(Object category) {
    return '類別：$category';
  }

  @override
  String costDetailLabelBuyer(Object buyer) {
    return '採購人：$buyer';
  }

  @override
  String get costDetailEditTitle => '編輯每日成本';

  @override
  String get costDetailDeleteTitle => '刪除成本';

  @override
  String costDetailDeleteContent(Object name) {
    return '確定要刪除這筆成本嗎？\n($name)';
  }

  @override
  String get costDetailErrorUpdate => '更新失敗';

  @override
  String get costDetailErrorDelete => '刪除失敗';

  @override
  String get cashSettlementDeposits => '訂金';

  @override
  String get cashSettlementExpectedCash => '預期現金';

  @override
  String get cashSettlementDifference => '差異';

  @override
  String get cashSettlementConfirmTitle => '確認結算';

  @override
  String get commonSubmit => '提交';

  @override
  String get cashSettlementDepositSheetTitle => '訂金表';

  @override
  String get cashSettlementDepositNew => '新訂金';

  @override
  String get cashSettlementNewDepositTitle => '新訂金';

  @override
  String get commonName => '姓名';

  @override
  String get commonPhone => '電話';

  @override
  String get commonAmount => '金額';

  @override
  String get commonNotes => '備註';

  @override
  String get cashSettlementDepositAddSuccess => '訂金新增成功';

  @override
  String get cashSettlementSelectRedeemedDeposit => '選擇已核銷訂金';

  @override
  String get commonNoData => '無資料';

  @override
  String get cashSettlementTitleOpen => '開班點鈔';

  @override
  String get cashSettlementTitleClose => '結帳點鈔';

  @override
  String get cashSettlementTitleLoading => '載入中...';

  @override
  String get cashSettlementOpenDesc => '請檢查並確認鈔票數量與總金額是否與預期一致。';

  @override
  String get cashSettlementTargetAmount => '目標金額：';

  @override
  String get cashSettlementTotal => '總計：';

  @override
  String get cashSettlementRevenueAndPayment => '今日營收與支付方式';

  @override
  String get cashSettlementRevenueHint => '總營收';

  @override
  String cashSettlementDepositButton(Object amount) {
    return '今日訂金 (已選：\$$amount)';
  }

  @override
  String get cashSettlementReceivableCash => '應收現金：';

  @override
  String get cashSettlementCashCountingTitle => '點鈔確認\n(請輸入實際鈔票數量)';

  @override
  String get cashSettlementTotalCashCounted => '點鈔總計：';

  @override
  String get cashSettlementReviewTitle => '總結';

  @override
  String get cashSettlementOpeningCash => '開班現金';

  @override
  String get cashSettlementDailyCosts => '今日成本';

  @override
  String get cashSettlementRedeemedDeposit => '抵扣訂金';

  @override
  String get cashSettlementTotalExpectedCash => '預期現金總額';

  @override
  String get cashSettlementTodaysCashCount => '今日點鈔總額';

  @override
  String get cashSettlementSummary => '差異：';

  @override
  String get cashSettlementErrorCountMismatch => '點鈔金額與目標金額不符！';

  @override
  String get cashSettlementOpenSuccessTitle => '開班成功';

  @override
  String cashSettlementOpenSuccessMsg(Object count) {
    return '第 $count 班次已成功開啟！';
  }

  @override
  String get cashSettlementOpenFailedTitle => '開班失敗';

  @override
  String get cashSettlementCloseSuccessTitle => '結帳成功';

  @override
  String get cashSettlementCloseSuccessMsg => '老闆愛你 ❤️';

  @override
  String get cashSettlementCloseFailedTitle => '結帳失敗';

  @override
  String get cashSettlementErrorInputRevenue => '請輸入總營收。';

  @override
  String get cashSettlementDepositTitle => '訂金管理';

  @override
  String get cashSettlementDepositAdd => '新增訂金';

  @override
  String get cashSettlementDepositEdit => '編輯所有訂金';

  @override
  String get cashSettlementDepositRedeemTitle => '核銷今日訂金';

  @override
  String get cashSettlementDepositNoUnredeemed => '無未核銷訂金';

  @override
  String cashSettlementDepositTotalRedeemed(Object amount) {
    return '核銷總額：\$$amount';
  }

  @override
  String get cashSettlementDepositAddTitle => '新增訂金';

  @override
  String get cashSettlementDepositEditTitle => '編輯訂金';

  @override
  String get cashSettlementDepositPaymentDate => '付款日期';

  @override
  String get cashSettlementDepositReservationDate => '預約日期';

  @override
  String get cashSettlementDepositReservationTime => '預約時間';

  @override
  String get cashSettlementDepositName => '姓名';

  @override
  String get cashSettlementDepositPax => '人數';

  @override
  String get cashSettlementDepositAmount => '訂金金額';

  @override
  String get cashSettlementErrorInputDates => '請選擇所有日期與時間。';

  @override
  String get cashSettlementErrorInputAmount => '請填寫姓名與有效金額。';

  @override
  String get cashSettlementErrorTimePast => '預約時間不能是過去的時間。';

  @override
  String get cashSettlementSaveFailed => '儲存失敗';

  @override
  String get depositScreenTitle => '訂金管理';

  @override
  String get depositScreenNoRecords => '無未核銷訂金';

  @override
  String depositScreenLabelName(Object name) {
    return '姓名：$name';
  }

  @override
  String depositScreenLabelReservationDate(Object date) {
    return '預約日期：$date';
  }

  @override
  String depositScreenLabelReservationTime(Object time) {
    return '預約時間：$time';
  }

  @override
  String depositScreenLabelGroupSize(Object size) {
    return '人數：$size';
  }

  @override
  String get depositScreenDeleteConfirm => '刪除訂金';

  @override
  String get depositScreenDeleteContent => '確定要刪除這筆訂金嗎？';

  @override
  String get depositScreenDeleteSuccess => '訂金刪除成功';

  @override
  String depositScreenDeleteFailed(Object error) {
    return '刪除失敗：$error';
  }

  @override
  String depositScreenSaveFailed(Object error) {
    return '儲存失敗：$error';
  }

  @override
  String get depositScreenInputError => '請填寫所有必填欄位 (姓名、金額、日期/時間)。';

  @override
  String get depositScreenTimeError => '預約時間不能是過去的時間。';

  @override
  String get depositDialogTitleAdd => '新增訂金';

  @override
  String get depositDialogTitleEdit => '編輯訂金';

  @override
  String get depositDialogHintPaymentDate => '付款日期';

  @override
  String get depositDialogHintReservationDate => '預約日期';

  @override
  String get depositDialogHintReservationTime => '預約時間';

  @override
  String get depositDialogHintName => '姓名';

  @override
  String get depositDialogHintGroupSize => '人數';

  @override
  String get depositDialogHintAmount => '訂金金額';

  @override
  String get monthlyCostTitle => '月度成本';

  @override
  String get monthlyCostTotal => '本月總成本';

  @override
  String get monthlyCostLabelName => '項目名稱';

  @override
  String get monthlyCostLabelPrice => '金額';

  @override
  String get monthlyCostLabelNote => '備註';

  @override
  String get monthlyCostErrorInputTitle => '錯誤';

  @override
  String get monthlyCostErrorInputMsg => '項目名稱與金額為必填。';

  @override
  String get monthlyCostErrorSaveFailed => '儲存失敗';

  @override
  String get monthlyCostSuccess => '成本儲存成功';

  @override
  String get monthlyCostDetailTitle => '月度成本明細';

  @override
  String get monthlyCostDetailNoRecords => '本月無成本紀錄。';

  @override
  String get monthlyCostDetailItemUntitled => '未命名項目';

  @override
  String get monthlyCostDetailCategoryNA => '未知';

  @override
  String get monthlyCostDetailBuyerNA => '未知';

  @override
  String monthlyCostDetailLabelCategory(Object category) {
    return '類別：$category';
  }

  @override
  String monthlyCostDetailLabelDate(Object date) {
    return '日期：$date';
  }

  @override
  String monthlyCostDetailLabelBuyer(Object buyer) {
    return '採購人：$buyer';
  }

  @override
  String get monthlyCostDetailEditTitle => '編輯月度成本';

  @override
  String get monthlyCostDetailDeleteTitle => '刪除成本';

  @override
  String monthlyCostDetailDeleteContent(Object name) {
    return '確定要刪除這筆成本嗎？\n($name)';
  }

  @override
  String monthlyCostDetailErrorFetch(Object error) {
    return '獲取成本失敗：$error';
  }

  @override
  String get monthlyCostDetailErrorUpdate => '更新失敗';

  @override
  String get monthlyCostDetailErrorDelete => '刪除失敗';

  @override
  String get cashFlowTitle => '關帳報表';

  @override
  String get cashFlowMonthlyRevenue => '本月營收';

  @override
  String get cashFlowMonthlyDifference => '本月每日成本';

  @override
  String cashFlowLabelShift(Object count) {
    return '第 $count 班';
  }

  @override
  String get cashFlowLabelRevenue => '總營收：';

  @override
  String get cashFlowLabelCost => '總成本：';

  @override
  String get cashFlowLabelDifference => '現金短溢：';

  @override
  String get cashFlowNoRecords => '無紀錄。';

  @override
  String get costReportTitle => '成本總結';

  @override
  String get costReportMonthlyTotal => '本月總成本';

  @override
  String get costReportNoRecords => '無成本紀錄。';

  @override
  String get costReportNoRecordsShift => '此班次無成本紀錄。';

  @override
  String get costReportLabelTotalCost => '總成本：';

  @override
  String get dashboardTitle => '營運儀表板';

  @override
  String get dashboardTotalRevenue => '總營收';

  @override
  String get dashboardCogs => '營收成本';

  @override
  String get dashboardGrossProfit => '毛利';

  @override
  String get dashboardGrossMargin => '毛利率';

  @override
  String get dashboardOpex => '營業費用';

  @override
  String get dashboardOpIncome => '營業利益';

  @override
  String get dashboardNetIncome => '淨利';

  @override
  String get dashboardNetProfitMargin => '淨利率';

  @override
  String get dashboardNoCostData => '無成本數據';

  @override
  String dashboardErrorLoad(Object error) {
    return '資料載入錯誤：$error';
  }

  @override
  String get reportingTitle => '後台管理';

  @override
  String get reportingCashFlow => '關帳報表';

  @override
  String get reportingCostSum => '成本總結';

  @override
  String get reportingDashboard => '營運儀表板';

  @override
  String get reportingCashVault => '金庫管理';

  @override
  String get reportingClockIn => '打卡紀錄';

  @override
  String get reportingWorkReport => '工作日報';

  @override
  String get reportingNoAccess => '無可使用的功能';

  @override
  String get vaultTitle => '關帳概況';

  @override
  String get vaultTotalCash => '現金總額';

  @override
  String get vaultTitleVault => '金庫';

  @override
  String get vaultTitleCashbox => '找零櫃';

  @override
  String get vaultCashDetail => '現金明細';

  @override
  String vaultDetailDenom(Object cashboxCount, Object totalCount, Object vaultCount) {
    return '\$ $cashboxCount X $totalCount (金庫 $cashboxCount + 找零櫃 $vaultCount)';
  }

  @override
  String get vaultActivityHistory => '活動紀錄';

  @override
  String get vaultTableDate => '日期';

  @override
  String get vaultTableStaff => '點帳人';

  @override
  String get vaultNoRecords => '無活動紀錄。';

  @override
  String get vaultManagementSheetTitle => '金庫管理';

  @override
  String get vaultAdjustCounts => '調整庫存';

  @override
  String get vaultSaveMoney => '存錢 (入銀行)';

  @override
  String get vaultChangeMoney => '兌換零錢';

  @override
  String get vaultPromptAdjust => '請輸入總數 (金庫 + 找零櫃)。';

  @override
  String get vaultPromptDeposit => '請輸入要存入銀行的金額';

  @override
  String get vaultPromptChangeOut => '取出大鈔 (兌換)';

  @override
  String get vaultPromptChangeIn => '存入零鈔 (兌換)';

  @override
  String get vaultErrorMismatch => '金額不符！已取消兌換。';

  @override
  String vaultDialogTotal(Object amount) {
    return '總計：$amount';
  }

  @override
  String get clockInReportTitle => '打卡紀錄';

  @override
  String get clockInReportTotalHours => '總工時';

  @override
  String get clockInReportStaffCount => '員工人數';

  @override
  String get clockInReportWorkDays => '出勤日數';

  @override
  String get clockInReportUnitPpl => '人';

  @override
  String get clockInReportUnitDays => '天';

  @override
  String get clockInReportUnitHr => '小時';

  @override
  String get clockInReportNoRecords => '無紀錄。';

  @override
  String get clockInReportLabelManual => '補打卡';

  @override
  String get clockInReportLabelIn => '上班';

  @override
  String get clockInReportLabelOut => '下班';

  @override
  String get clockInReportStatusWorking => '上班中';

  @override
  String get clockInReportStatusCompleted => '已完成';

  @override
  String get clockInReportStatusIncomplete => '未完成';

  @override
  String get clockInReportAllStaff => '所有員工';

  @override
  String get clockInReportSelectStaff => '選擇員工';

  @override
  String get clockInDetailTitleIn => '上班打卡';

  @override
  String get clockInDetailTitleOut => '下班打卡';

  @override
  String get clockInDetailMissing => '紀錄遺失';

  @override
  String get clockInDetailFixButton => '修正下班時間';

  @override
  String get clockInDetailCloseButton => '關閉';

  @override
  String clockInDetailLabelWifi(Object wifi) {
    return 'WiFi：$wifi';
  }

  @override
  String clockInDetailLabelReason(Object reason) {
    return '原因：$reason';
  }

  @override
  String get clockInDetailReasonSupervisorFix => '主管修正';

  @override
  String get clockInDetailErrorInLaterThanOut => '上班時間不能晚於下班時間。';

  @override
  String get clockInDetailErrorOutEarlierThanIn => '下班時間不能早於上班時間。';

  @override
  String get clockInDetailErrorDateCheck => '日期錯誤：請檢查是否選到正確日期 (例如：隔天)。';

  @override
  String get clockInDetailSuccessUpdate => '時間更新成功。';

  @override
  String get clockInDetailSelectDate => '選擇下班日期';

  @override
  String get commonNone => '無';

  @override
  String get workReportOverviewTitle => '工作日報';

  @override
  String get workReportOverviewNoRecords => '無日報紀錄。';

  @override
  String get workReportOverviewSelectStaff => '選擇員工';

  @override
  String get workReportOverviewAllStaff => '所有員工';

  @override
  String get workReportOverviewNoSubject => '無主旨';

  @override
  String get workReportOverviewNoContent => '無內容';

  @override
  String workReportOverviewOvertimeTag(Object hours) {
    return 'OT: $hours小時';
  }

  @override
  String workReportDetailOvertimeLabel(Object hours) {
    return '加班：$hours 小時';
  }

  @override
  String get commonClose => '關閉';

  @override
  String get userMgmtTitle => '人員管理';

  @override
  String get userMgmtInviteNewUser => '邀請新使用者';

  @override
  String get userMgmtStatusInvited => '已邀請';

  @override
  String get userMgmtStatusWaiting => '等待中...';

  @override
  String userMgmtLabelRole(Object roleName) {
    return '職位：$roleName';
  }

  @override
  String get userMgmtNameHint => '姓名';

  @override
  String get userMgmtInviteNote => '使用者將收到 Email 邀請信。';

  @override
  String get userMgmtInviteButton => '邀請';

  @override
  String get userMgmtEditTitle => '編輯使用者資訊';

  @override
  String get userMgmtDeleteTitle => '刪除使用者';

  @override
  String userMgmtDeleteContent(Object userName) {
    return '確定要刪除 $userName 嗎？';
  }

  @override
  String userMgmtErrorLoad(Object error) {
    return '載入失敗：$error';
  }

  @override
  String get userMgmtInviteSuccess => '邀請已發送！對方收到 Email 後即可加入。';

  @override
  String userMgmtInviteFailed(Object error) {
    return '邀請失敗：$error';
  }

  @override
  String userMgmtErrorConnection(Object error) {
    return '連線錯誤：$error';
  }

  @override
  String userMgmtDeleteFailed(Object error) {
    return '刪除失敗：$error';
  }

  @override
  String get userMgmtLabelEmail => '電子信箱';

  @override
  String get userMgmtLabelRolePicker => '職位';

  @override
  String get userMgmtButtonDone => '完成';

  @override
  String get userMgmtLabelRoleSelect => '選擇';

  @override
  String get roleMgmtTitle => '職位權限管理';

  @override
  String get roleMgmtSystemDefault => '系統預設';

  @override
  String roleMgmtPermissionGroupTitle(Object groupName) {
    return '權限 - $groupName';
  }

  @override
  String get roleMgmtRoleNameHint => '職位名稱';

  @override
  String get roleMgmtSaveButton => '儲存';

  @override
  String get roleMgmtDeleteRole => '刪除職位';

  @override
  String get roleMgmtAddNewRole => '新增職位';

  @override
  String get roleMgmtEnterRoleName => '輸入職位名稱 (例如：服務生)';

  @override
  String get roleMgmtCreateButton => '建立';

  @override
  String get roleMgmtDeleteConfirmTitle => '刪除職位';

  @override
  String get roleMgmtDeleteConfirmContent => '確定要刪除此職位嗎？此操作無法復原。';

  @override
  String get roleMgmtCannotDeleteTitle => '無法刪除職位';

  @override
  String roleMgmtCannotDeleteContent(Object count, Object roleName) {
    return '仍有 $count 位使用者被指派給「$roleName」職位。\n\n請先將他們指派給其他職位後再刪除。';
  }

  @override
  String get roleMgmtUnderstandButton => '我知道了';

  @override
  String roleMgmtErrorLoad(Object error) {
    return '載入職位失敗：$error';
  }

  @override
  String roleMgmtErrorSave(Object error) {
    return '儲存權限失敗：$error';
  }

  @override
  String roleMgmtErrorAdd(Object error) {
    return '新增職位失敗：$error';
  }

  @override
  String get commonNotificationTitle => '通知';

  @override
  String get permGroupMainScreen => '主畫面功能';

  @override
  String get permGroupSchedule => '班表';

  @override
  String get permGroupBackstageDashboard => '後台儀表板';

  @override
  String get permGroupSettings => '設定頁面功能';

  @override
  String get permHomeOrder => '點餐';

  @override
  String get permHomePrep => '備料清單';

  @override
  String get permHomeStock => '庫存盤點';

  @override
  String get permHomeBackDashboard => '後台儀表板';

  @override
  String get permHomeDailyCost => '每日成本輸入';

  @override
  String get permHomeCashFlow => '關帳報表';

  @override
  String get permHomeMonthlyCost => '月度成本輸入';

  @override
  String get permHomeScan => '智慧掃描';

  @override
  String get permScheduleEdit => '更動員工班表';

  @override
  String get permBackCashFlow => '關帳報表';

  @override
  String get permBackCostSum => '成本總結報表';

  @override
  String get permBackDashboard => '營運儀表板';

  @override
  String get permBackCashVault => '金庫管理';

  @override
  String get permBackClockIn => '打卡紀錄報表';

  @override
  String get permBackViewAllClockIn => '查看所有員工打卡紀錄';

  @override
  String get permBackWorkReport => '工作日報總覽';

  @override
  String get permSetStaff => '人員管理';

  @override
  String get permSetRole => '職位權限管理';

  @override
  String get permSetPrinter => '印表機設定';

  @override
  String get permSetTableMap => '桌位圖管理';

  @override
  String get permSetTableList => '桌況列表';

  @override
  String get permSetMenu => '編輯菜單';

  @override
  String get permSetShift => '班別設定';

  @override
  String get permSetPunch => '打卡設定';

  @override
  String get permSetPay => '付款方式設定';

  @override
  String get permSetCostCat => '成本類別設定';

  @override
  String get permSetInv => '庫存與品項管理';

  @override
  String get permSetCashReg => '收銀機設定';

  @override
  String get stockCategoryTitle => '編輯備料細節';

  @override
  String get stockCategoryAddButton => '＋ 新增類別';

  @override
  String get stockCategoryAddDialogTitle => '新增備料類別';

  @override
  String get stockCategoryEditDialogTitle => '編輯類別';

  @override
  String get stockCategoryHintName => '類別名稱';

  @override
  String get stockCategoryDeleteTitle => '刪除類別';

  @override
  String stockCategoryDeleteContent(Object categoryName) {
    return '確定要刪除類別：$categoryName 嗎？';
  }

  @override
  String get inventoryCategoryTitle => '編輯庫存列表';

  @override
  String get inventoryManagementTitle => 'Inventory Management';

  @override
  String get inventoryCategoryDetailTitle => '品項列表';

  @override
  String get inventoryCategoryAddButton => '＋ 新增類別';

  @override
  String get inventoryCategoryAddDialogTitle => '新增庫存類別';

  @override
  String get inventoryCategoryEditDialogTitle => '編輯類別';

  @override
  String get inventoryCategoryHintName => '類別名稱';

  @override
  String get inventoryCategoryDeleteTitle => '刪除類別';

  @override
  String inventoryCategoryDeleteContent(Object categoryName) {
    return '確定要刪除類別：$categoryName 嗎？';
  }

  @override
  String get inventoryItemAddButton => '＋ 新增品項';

  @override
  String get inventoryItemAddDialogTitle => '新增品項';

  @override
  String get inventoryItemEditDialogTitle => '編輯品項';

  @override
  String get inventoryItemDeleteTitle => '刪除品項';

  @override
  String inventoryItemDeleteContent(Object itemName) {
    return '確定要刪除 $itemName 嗎？';
  }

  @override
  String get inventoryItemHintName => '品項名稱';

  @override
  String get inventoryItemHintUnit => '品項單位';

  @override
  String get inventoryItemHintStock => '目前庫存數量';

  @override
  String get inventoryItemHintPar => '安全庫存量';

  @override
  String get stockItemTitle => '品項資訊';

  @override
  String get stockItemLabelName => '品項名稱';

  @override
  String get stockItemLabelMainIngredients => '主材料';

  @override
  String get stockItemLabelSubsidiaryIngredients => '副材料';

  @override
  String stockItemLabelDetails(Object index) {
    return '詳細說明 $index';
  }

  @override
  String get stockItemHintIngredient => '品名';

  @override
  String get stockItemHintQty => '數量';

  @override
  String get stockItemHintUnit => '單位';

  @override
  String get stockItemHintInstructionsSub => '副材料操作說明';

  @override
  String get stockItemHintInstructionsNote => '品項操作說明';

  @override
  String get stockItemAddSubDialogTitle => '新增副材料';

  @override
  String get stockItemEditSubDialogTitle => '編輯副材料類別';

  @override
  String get stockItemAddSubHintGroupName => '群組名稱 (例如：裝飾)';

  @override
  String get stockItemAddOptionTitle => '新增副材料或說明';

  @override
  String get stockItemAddOptionSub => '新增副材料';

  @override
  String get stockItemAddOptionDetail => '新增說明';

  @override
  String get stockItemDeleteSubTitle => '刪除副材料';

  @override
  String get stockItemDeleteSubContent => '確定要刪除此副材料及其備註嗎？';

  @override
  String get stockItemDeleteNoteTitle => '刪除說明';

  @override
  String get stockItemDeleteNoteContent => '確定要刪除此說明嗎？';

  @override
  String get stockCategoryDetailItemTitle => '品項列表';

  @override
  String get stockCategoryDetailAddItemButton => '＋ 新增品項';

  @override
  String get stockItemDetailDeleteTitle => '刪除品項';

  @override
  String stockItemDetailDeleteContent(Object productName) {
    return '確定要刪除 $productName 嗎？';
  }

  @override
  String get inventoryLogTitle => '庫存日誌';

  @override
  String get inventoryLogSearchHint => '搜尋庫存品項';

  @override
  String get inventoryLogAllDates => '所有日期';

  @override
  String get inventoryLogDatePickerConfirm => '確定';

  @override
  String get inventoryLogReasonAll => '全部';

  @override
  String get inventoryLogReasonAdd => '入庫';

  @override
  String get inventoryLogReasonAdjustment => '盤點調整';

  @override
  String get inventoryLogReasonWaste => '報廢';

  @override
  String get inventoryLogNoRecords => '無日誌紀錄。';

  @override
  String get inventoryLogCardUnknownItem => '未知原料';

  @override
  String get inventoryLogCardUnknownUser => '未知操作者';

  @override
  String inventoryLogCardLabelName(Object userName) {
    return '操作者：$userName';
  }

  @override
  String inventoryLogCardLabelChange(Object adjustment, Object unit) {
    return '變更：$adjustment $unit';
  }

  @override
  String inventoryLogCardLabelStock(Object newStock, Object oldStock) {
    return '數量 $oldStock→$newStock';
  }

  @override
  String get printerSettingsTitle => '硬體設定';

  @override
  String get printerSettingsListTitle => '出單機列表';

  @override
  String get printerSettingsNoPrinters => '目前沒有設定出單機';

  @override
  String printerSettingsLabelIP(Object ip) {
    return 'IP：$ip';
  }

  @override
  String get printerDialogAddTitle => '新增出單機';

  @override
  String get printerDialogEditTitle => '編輯出單機資訊';

  @override
  String get printerDialogHintName => '出單機名稱';

  @override
  String get printerDialogHintIP => '出單機 IP 位址';

  @override
  String get printerTestConnectionFailed => '❌ 印表機連線失敗';

  @override
  String get printerTestTicketSuccess => '✅ 測試單已列印';

  @override
  String get printerCashDrawerOpenSuccess => '✅ 錢櫃已開啟';

  @override
  String get printerDeleteTitle => '刪除出單機';

  @override
  String printerDeleteContent(Object printerName) {
    return '確定要刪除 $printerName 嗎？';
  }

  @override
  String get printerTestPrintTitle => '【出單測試】';

  @override
  String get printerTestPrintSubtitle => '測試印表機是否正常列印';

  @override
  String get printerTestPrintContent1 => '這是一張測試單，';

  @override
  String get printerTestPrintContent2 => '如果您看到這段文字，';

  @override
  String get printerTestPrintContent3 => '代表中文與圖片列印皆正常。';

  @override
  String get printerTestPrintContent4 => '代表中文與圖片列印皆正常。';

  @override
  String get printerTestPrintContent5 => '感謝使用 Gallery 20.5';

  @override
  String get tableMapAreaSuffix => '區';

  @override
  String get tableMapRemoveTitle => '移除桌位';

  @override
  String tableMapRemoveContent(Object tableName) {
    return '確定要將「$tableName」從地圖上移除嗎？';
  }

  @override
  String get tableMapRemoveConfirm => '移除';

  @override
  String get tableMapAddDialogTitle => '新增桌位';

  @override
  String get tableMapShapeCircle => '圓形';

  @override
  String get tableMapShapeSquare => '方形';

  @override
  String get tableMapShapeRect => '矩形';

  @override
  String get tableMapAddDialogHint => '選擇桌號';

  @override
  String get tableMapNoAvailableTables => '此區域沒有可用的桌位。';

  @override
  String get tableMgmtTitle => '桌位管理';

  @override
  String get tableMgmtAreaListAddButton => '＋ 新增區域';

  @override
  String get tableMgmtAreaListAddTitle => '新增區域';

  @override
  String get tableMgmtAreaListEditTitle => '編輯區域';

  @override
  String get tableMgmtAreaListHintName => '區域名稱';

  @override
  String get tableMgmtAreaListDeleteTitle => '刪除區域';

  @override
  String tableMgmtAreaListDeleteContent(Object areaName) {
    return '確定要刪除區域 $areaName 嗎？';
  }

  @override
  String tableMgmtAreaAddSuccess(Object name) {
    return '✅ 區域「$name」新增成功';
  }

  @override
  String get tableMgmtAreaAddFailure => '新增區域失敗';

  @override
  String get tableMgmtTableListAddButton => '＋ 新增桌位';

  @override
  String get tableMgmtTableListAddTitle => '新增桌位';

  @override
  String get tableMgmtTableListEditTitle => '編輯桌位';

  @override
  String get tableMgmtTableListHintName => '桌位名稱';

  @override
  String get tableMgmtTableListDeleteTitle => '刪除桌位';

  @override
  String tableMgmtTableListDeleteContent(Object tableName) {
    return '確定要刪除桌位 $tableName 嗎？';
  }

  @override
  String get tableMgmtTableAddFailure => '新增桌位失敗';

  @override
  String get tableMgmtTableDeleteFailure => '刪除桌位失敗';

  @override
  String get commonSaveFailure => '儲存資料失敗。';

  @override
  String get commonDeleteFailure => '刪除失敗，請稍後再試。';

  @override
  String get commonNameExists => '名稱已存在。';

  @override
  String get menuEditTitle => '菜單編輯';

  @override
  String get menuCategoryAddButton => '＋ 新增類別';

  @override
  String get menuDetailAddItemButton => '＋ 新增品項';

  @override
  String get menuDeleteCategoryTitle => '刪除類別';

  @override
  String menuDeleteCategoryContent(Object categoryName) {
    return '確定要刪除 $categoryName 嗎？';
  }

  @override
  String get menuCategoryAddDialogTitle => '新增菜單類別';

  @override
  String get menuCategoryEditDialogTitle => '編輯類別名稱';

  @override
  String get menuCategoryHintName => '類別名稱';

  @override
  String get menuItemAddDialogTitle => '新增品項';

  @override
  String get menuItemEditDialogTitle => '編輯品項';

  @override
  String get menuItemPriceLabel => '目前價格';

  @override
  String get menuItemMarketPrice => '時價';

  @override
  String get menuItemHintPrice => '品項價格';

  @override
  String get menuItemLabelMarketPrice => '時價';

  @override
  String menuItemLabelPrice(Object price) {
    return '價格：$price';
  }

  @override
  String get shiftSetupTitle => '班次設定';

  @override
  String get shiftSetupSectionTitle => '已定義的班次類型';

  @override
  String get shiftSetupListAddButton => '+ 新增班次類型';

  @override
  String get shiftSetupSaveButton => '儲存';

  @override
  String shiftListStartTime(Object endTime, Object startTime) {
    return '$startTime - $endTime';
  }

  @override
  String get shiftDialogAddTitle => '新增班次類型';

  @override
  String get shiftDialogEditTitle => '編輯班次類型';

  @override
  String get shiftDialogHintName => '班次名稱';

  @override
  String get shiftDialogLabelStartTime => '開始時間：';

  @override
  String get shiftDialogLabelEndTime => '結束時間：';

  @override
  String get shiftDialogLabelColor => '顏色標籤：';

  @override
  String get shiftDialogErrorNameEmpty => '請輸入班次名稱。';

  @override
  String get shiftDeleteConfirmTitle => '確認刪除';

  @override
  String shiftDeleteConfirmContent(Object shiftName) {
    return '確定要刪除班次類型「$shiftName」嗎？此變更必須儲存。';
  }

  @override
  String shiftDeleteLocalSuccess(Object shiftName) {
    return '班次類型「$shiftName」已在本地刪除。';
  }

  @override
  String get shiftSaveSuccess => '班次設定儲存成功！';

  @override
  String shiftSaveError(Object error) {
    return '儲存設定失敗：$error';
  }

  @override
  String shiftLoadError(Object error) {
    return '載入班次失敗：$error';
  }

  @override
  String get commonSuccess => '成功';

  @override
  String get commonError => '錯誤';

  @override
  String get punchInSetupTitle => '打卡資訊設定';

  @override
  String get punchInWifiSection => '當前 Wi-Fi 名稱';

  @override
  String get punchInLocationSection => '當前位置';

  @override
  String get punchInLoading => '讀取中...';

  @override
  String get punchInErrorPermissionTitle => '權限錯誤';

  @override
  String get punchInErrorPermissionContent => '請開啟位置權限才能使用此功能。';

  @override
  String get punchInErrorFetchTitle => '取得資訊失敗';

  @override
  String get punchInErrorFetchContent => '無法取得 Wi-Fi 或 GPS 資訊，請檢查權限及網路連線。';

  @override
  String get punchInSaveFailureTitle => '錯誤';

  @override
  String get punchInSaveFailureContent => '無法取得必要資訊。';

  @override
  String get punchInSaveSuccessTitle => '成功';

  @override
  String get punchInSaveSuccessContent => '打卡資訊已儲存。';

  @override
  String get punchInRegainButton => '重新讀取 Wi-Fi 與位置';

  @override
  String get punchInSaveButton => '儲存打卡資訊';

  @override
  String get punchInConfirmOverwriteTitle => '確認覆蓋';

  @override
  String get punchInConfirmOverwriteContent => '此商店已存在打卡資訊，是否要覆蓋原有資料？';

  @override
  String get commonOverwrite => '覆蓋';

  @override
  String get commonOK => '確定';

  @override
  String get paymentSetupTitle => '支付設定';

  @override
  String get paymentSetupMethodsSection => '啟用支付方式';

  @override
  String get paymentSetupFunctionModule => '功能模組';

  @override
  String get paymentSetupFunctionDeposit => '訂金功能';

  @override
  String get paymentSetupSaveButton => '儲存';

  @override
  String paymentSetupLoadError(Object error) {
    return '載入設定失敗：$error';
  }

  @override
  String get paymentSetupSaveSuccess => '✅ 設定已儲存';

  @override
  String paymentSetupSaveFailure(Object error) {
    return '儲存失敗：$error';
  }

  @override
  String get paymentAddDialogTitle => '＋新增支付方式';

  @override
  String get paymentAddDialogHintName => '方式名稱';

  @override
  String get settlementDetailDailyRevenueSummary => '今日營收摘要';

  @override
  String get settlementDetailPaymentDetails => '支付明細';

  @override
  String get settlementDetailCashCount => '點鈔明細';

  @override
  String get settlementDetailValue => '面額';

  @override
  String get settlementDetailSummary => '小計';

  @override
  String get settlementDetailTotalRevenue => '總營收：';

  @override
  String get settlementDetailTotalCost => '總成本：';

  @override
  String get settlementDetailCash => '現金：';

  @override
  String get settlementDetailTodayDeposit => '今日訂金：';

  @override
  String get vaultChangeMoneyStep1 => '換錢 (步驟 1/2)';

  @override
  String get vaultChangeMoneyStep2 => '換錢 (步驟 2/2)';

  @override
  String vaultSaveFailed(Object error) {
    return '儲存失敗：$error';
  }

  @override
  String get paymentAddDialogSave => '儲存';

  @override
  String get costCategoryTitle => '支出類別';

  @override
  String get costCategoryAddButton => '新增支出類別';

  @override
  String get costCategoryTypeCOGS => '銷貨成本';

  @override
  String get costCategoryTypeOPEX => '營運成本';

  @override
  String get costCategoryAddTitle => '新增類別';

  @override
  String get costCategoryEditTitle => '編輯類別';

  @override
  String get costCategoryHintName => '類別名稱';

  @override
  String costCategoryDeleteTitle(Object categoryName) {
    return '刪除 $categoryName';
  }

  @override
  String get costCategoryDeleteContent => '確定要刪除此類別嗎？';

  @override
  String get costCategoryNoticeErrorTitle => '錯誤';

  @override
  String get costCategoryNoticeErrorLoad => '載入類別失敗。';

  @override
  String get costCategoryNoticeErrorAdd => '新增類別失敗。';

  @override
  String get costCategoryNoticeErrorUpdate => '更新類別失敗。';

  @override
  String get costCategoryNoticeErrorDelete => '刪除類別失敗。';

  @override
  String get cashRegSetupTitle => '錢櫃設定';

  @override
  String get cashRegSetupSubtitle => '請輸入錢櫃中每個面額的預設數量。';

  @override
  String cashRegSetupTotalLabel(Object totalAmount) {
    return '總計：$totalAmount';
  }

  @override
  String get cashRegSetupInputHint => '0';

  @override
  String get cashRegNoticeSaveSuccess => '錢櫃零用金設定已儲存！';

  @override
  String cashRegNoticeSaveFailure(Object error) {
    return '儲存失敗：$error';
  }

  @override
  String cashRegNoticeLoadError(Object error) {
    return '載入錢櫃設定失敗：$error';
  }

  @override
  String get languageEnglish => 'English';

  @override
  String get languageTraditionalChinese => '繁體中文';

  @override
  String get changePasswordTitle => '變更密碼';

  @override
  String get changePasswordOldHint => '舊密碼';

  @override
  String get changePasswordNewHint => '新密碼';

  @override
  String get changePasswordConfirmHint => '確認新密碼';

  @override
  String get changePasswordButton => '變更密碼';

  @override
  String get passwordValidatorEmptyOld => '請輸入舊密碼';

  @override
  String get passwordValidatorLength => '密碼至少 6 位數';

  @override
  String get passwordValidatorMismatch => '密碼不一致';

  @override
  String get passwordErrorReLogin => '請重新登入';

  @override
  String get passwordErrorOldPassword => '舊密碼錯誤';

  @override
  String get passwordErrorUpdateFailed => '密碼更新失敗';

  @override
  String get passwordSuccess => '✅ 密碼已更新';

  @override
  String passwordFailure(Object error) {
    return '❌ 密碼修改失敗: $error';
  }

  @override
  String get languageSimplifiedChinese => '简体中文';

  @override
  String get languageItalian => 'Italiano';

  @override
  String get languageVietnamese => '越南文 (Vietnamese)';

  @override
  String get settingAppearance => '系統顏色';

  @override
  String get themeSystem => '系統顏色';

  @override
  String get themeSage => 'Gallery 20.5 預設';

  @override
  String get themeLight => '淺色模式';

  @override
  String get themeDark => '深色 (舊版)';
}

/// The translations for Chinese, using the Han script (`zh_Hans`).
class AppLocalizationsZhHans extends AppLocalizationsZh {
  AppLocalizationsZhHans(): super('zh_Hans');

  @override
  String get homeTitle => 'Gallery 20.5';

  @override
  String get loading => '加载中...';

  @override
  String get homeOrder => '点餐';

  @override
  String get homeCalendar => '日程表';

  @override
  String get homeShift => '排班';

  @override
  String get homePrep => '备料';

  @override
  String get homeStock => '库存';

  @override
  String get homeClockIn => '打卡';

  @override
  String get homeWorkReport => '工作日报';

  @override
  String get homeBackhouse => '后台';

  @override
  String get homeDailyCost => '每日成本';

  @override
  String get homeCashFlow => '關帳';

  @override
  String get homeMonthlyCost => '月度成本';

  @override
  String get homeSetting => '设置';

  @override
  String get settingsTitle => '设置';

  @override
  String get defaultUser => '用户';

  @override
  String get settingPrepInfo => '备料信息';

  @override
  String get settingStock => '库存管理';

  @override
  String get settingStockLog => '库存记录';

  @override
  String get settingTable => '桌位管理';

  @override
  String get settingTableMap => '桌位图';

  @override
  String get settingMenu => '菜单管理';

  @override
  String get settingPrinter => '出单机设置';

  @override
  String get settingClockInInfo => '打卡信息';

  @override
  String get settingPayment => '付款方式';

  @override
  String get settingCashbox => '零钱柜管理';

  @override
  String get settingShift => '排班管理';

  @override
  String get settingUserManagement => '人员管理';

  @override
  String get settingCostCategories => '成本类别';

  @override
  String get settingLanguage => '语言设置';

  @override
  String get settingChangePassword => '修改密码';

  @override
  String get settingLogout => '登出';

  @override
  String get settingRoleManagement => '角色权限管理';

  @override
  String get loginTitle => '登录';

  @override
  String get loginShopIdHint => '选择店号';

  @override
  String get loginEmailHint => '电子邮箱';

  @override
  String get loginPasswordHint => '密码';

  @override
  String get loginButton => '登录';

  @override
  String get loginAddShopOption => '+ 新增店号';

  @override
  String get loginAddShopDialogTitle => '新增店号';

  @override
  String get loginAddShopDialogHint => '输入新店号';

  @override
  String get commonCancel => '取消';

  @override
  String get commonAdd => '新增';

  @override
  String get loginMsgFillAll => '请填写所有字段';

  @override
  String get loginMsgFaceIdFirst => '请先用 Email 登录一次';

  @override
  String get loginMsgFaceIdReason => '请使用 Face ID 登录';

  @override
  String get loginMsgNoSavedData => '尚未保存任何登录数据';

  @override
  String get loginMsgNoFaceIdData => '找不到这组账号的 Face ID 登录数据';

  @override
  String get loginMsgShopNotFound => '找不到该店号';

  @override
  String get loginMsgNoPermission => '您没有这间店的使用权限';

  @override
  String get loginMsgFailed => '登录失败';

  @override
  String loginMsgFailedReason(Object error) {
    return '登录失败：$error';
  }

  @override
  String get scheduleTitle => '日程表';

  @override
  String get scheduleTabMy => '个人';

  @override
  String get scheduleTabAll => '全部';

  @override
  String get scheduleTabCustom => '自定义';

  @override
  String get scheduleFilterTooltip => '筛选群组';

  @override
  String get scheduleSelectGroups => '选择群组';

  @override
  String get commonDone => '完成';

  @override
  String get schedulePersonalMe => '个人 (我)';

  @override
  String get scheduleUntitled => '未命名';

  @override
  String get scheduleNoEvents => '无行程';

  @override
  String get scheduleAllDay => '全天';

  @override
  String get scheduleDayLabel => '全天';

  @override
  String get commonNoTitle => '无标题';

  @override
  String scheduleMoreEvents(Object count) {
    return '还有 $count 个...';
  }

  @override
  String get commonToday => '今天';

  @override
  String get calendarGroupsTitle => '日程表群组';

  @override
  String get calendarGroupPersonal => '个人 (我)';

  @override
  String get calendarGroupUntitled => '未命名';

  @override
  String get calendarGroupPrivateDesc => '私人行程仅您可见';

  @override
  String calendarGroupVisibleToMembers(Object count) {
    return '对 $count 位成员可见';
  }

  @override
  String get calendarGroupNew => '创建群组';

  @override
  String get calendarGroupEdit => '编辑群组';

  @override
  String get calendarGroupName => '群组名称';

  @override
  String get calendarGroupNameHint => '例如：工作、会议';

  @override
  String get calendarGroupColor => '群组代表色';

  @override
  String get calendarGroupEventColors => '事件标签颜色';

  @override
  String get calendarGroupSaveFirstHint => '请先保存群组以设置自定义事件颜色。';

  @override
  String get calendarGroupVisibleTo => '群组员';

  @override
  String get calendarGroupDelete => '删除群组';

  @override
  String get calendarGroupDeleteConfirm => '删除此群组将一并移除所有关联事件，确定要删除吗？';

  @override
  String get calendarColorNew => '新增颜色';

  @override
  String get calendarColorEdit => '编辑颜色';

  @override
  String get calendarColorName => '颜色名称';

  @override
  String get calendarColorNameHint => '例如：紧急、会议';

  @override
  String get calendarColorPick => '选择颜色';

  @override
  String get calendarColorDelete => '删除颜色';

  @override
  String get calendarColorDeleteConfirm => '确定要删除此颜色设置？';

  @override
  String get commonSave => '保存';

  @override
  String get commonDelete => '删除';

  @override
  String get notificationGroupInviteTitle => '群组邀请';

  @override
  String notificationGroupInviteBody(Object groupName) {
    return '您已被加入日程表群组：「$groupName」';
  }

  @override
  String get eventDetailTitleEdit => '编辑事件';

  @override
  String get eventDetailTitleNew => '新增事件';

  @override
  String get eventDetailLabelTitle => '标题';

  @override
  String get eventDetailLabelGroup => '群组';

  @override
  String get eventDetailLabelColor => '颜色';

  @override
  String get eventDetailLabelAllDay => '全天';

  @override
  String get eventDetailLabelStarts => '开始';

  @override
  String get eventDetailLabelEnds => '结束';

  @override
  String get eventDetailLabelRepeat => '重复';

  @override
  String get eventDetailLabelRelatedPeople => '相关人员';

  @override
  String get eventDetailLabelNotes => '备注';

  @override
  String get eventDetailDelete => '删除事件';

  @override
  String get eventDetailDeleteConfirm => '确定要删除此事件吗？';

  @override
  String get eventDetailSelectGroup => '选择群组';

  @override
  String get eventDetailSelectColor => '选择颜色';

  @override
  String get eventDetailGroupDefault => '群组默认';

  @override
  String get eventDetailCustomColor => '自定义颜色';

  @override
  String get eventDetailNoCustomColors => '此群组尚未设置自定义颜色。';

  @override
  String get eventDetailSelectPeople => '选择人员';

  @override
  String eventDetailPeopleCount(Object count) {
    return '$count 人';
  }

  @override
  String get eventDetailNone => '无';

  @override
  String get eventDetailRepeatNone => '无';

  @override
  String get eventDetailRepeatDaily => '每天';

  @override
  String get eventDetailRepeatWeekly => '每周';

  @override
  String get eventDetailRepeatMonthly => '每月';

  @override
  String get eventDetailErrorTitleRequired => '标题为必填';

  @override
  String get eventDetailErrorGroupRequired => '群组为必选';

  @override
  String get eventDetailErrorEndTime => '结束时间不能早于开始时间';

  @override
  String get eventDetailErrorSave => '保存失败';

  @override
  String get eventDetailErrorDelete => '删除失败';

  @override
  String notificationNewEventTitle(Object groupName) {
    return '[$groupName] 新增事件';
  }

  @override
  String notificationNewEventBody(Object time, Object title, Object userName) {
    return '$userName 新增了：$title ($time)';
  }

  @override
  String get notificationTimeChangeTitle => '⏰ [变更] 时间异动';

  @override
  String notificationTimeChangeBody(Object title, Object userName) {
    return '$userName 修改了「$title」的时间，请确认。';
  }

  @override
  String get notificationContentChangeTitle => '✏️ [更新] 内容变更';

  @override
  String notificationContentChangeBody(Object title, Object userName) {
    return '$userName 更新了「$title」的详细信息。';
  }

  @override
  String get notificationDeleteTitle => '🗑️ [取消] 事件移除';

  @override
  String notificationDeleteBody(Object title, Object userName) {
    return '$userName 取消了事件：$title';
  }

  @override
  String get localNotificationTitle => '🔔 待办事项提醒';

  @override
  String localNotificationBody(Object title) {
    return '10分钟后：$title';
  }

  @override
  String get commonSelect => '请选择...';

  @override
  String get commonUnknown => '未知';

  @override
  String get commonPersonalMe => '个人 (我)';

  @override
  String get scheduleViewTitle => '排班表';

  @override
  String get scheduleViewModeMy => '我的班表';

  @override
  String get scheduleViewModeAll => '全店班表';

  @override
  String scheduleViewErrorInit(Object error) {
    return '初始数据加载失败：$error';
  }

  @override
  String scheduleViewErrorFetch(Object error) {
    return '获取班表失败：$error';
  }

  @override
  String get scheduleViewUnknown => '未知';

  @override
  String get scheduleUploadTitle => '排班管理';

  @override
  String get scheduleUploadSelectEmployee => '选择员工';

  @override
  String get scheduleUploadSelectShiftFirst => '请先从上方选择一个班型';

  @override
  String get scheduleUploadUnsavedChanges => '未保存的变更';

  @override
  String get scheduleUploadDiscardChangesMessage => '您有未保存的变更，切换或离开页面将会丢失这些变更。是否继续？';

  @override
  String get scheduleUploadNoChanges => '没有需要保存的变更。';

  @override
  String get scheduleUploadSaveSuccess => '✅ 班表已保存！';

  @override
  String scheduleUploadSaveError(Object error) {
    return '❌ 保存失败：$error';
  }

  @override
  String scheduleUploadLoadError(Object error) {
    return '❌ 初始数据加载失败：$error';
  }

  @override
  String scheduleUploadLoadScheduleError(Object name) {
    return '❌ 加载 $name 的班表失败';
  }

  @override
  String scheduleUploadRole(Object role) {
    return '职位：$role';
  }

  @override
  String get commonConfirm => '确认';

  @override
  String get commonSaveChanges => '保存变更';

  @override
  String get prepViewTitle => '查看备料类别';

  @override
  String get prepViewItemTitle => '查看备料品项';

  @override
  String get prepViewItemUntitled => '未命名品项';

  @override
  String get prepViewMainIngredients => '主要材料';

  @override
  String prepViewNote(Object note) {
    return '备注：$note';
  }

  @override
  String get prepViewDetailLabel => '详细信息';

  @override
  String get inventoryViewTitle => '库存总览';

  @override
  String get inventorySearchHint => '搜索品项';

  @override
  String get inventoryNoItems => '查无项目';

  @override
  String inventorySafetyQuantity(Object quantity) {
    return '安全存量：$quantity';
  }

  @override
  String get inventoryConfirmUpdateTitle => '确认更新';

  @override
  String inventoryConfirmUpdateOriginal(Object unit, Object value) {
    return '原始数量：$value $unit';
  }

  @override
  String inventoryConfirmUpdateNew(Object unit, Object value) {
    return '新数量：$value $unit';
  }

  @override
  String inventoryConfirmUpdateChange(Object value) {
    return '变动量：$value';
  }

  @override
  String get inventoryUnsavedTitle => '未保存的变更';

  @override
  String get inventoryUnsavedContent => '您有未保存的库存调整，是否要保存并离开？';

  @override
  String get inventoryUnsavedDiscard => '放弃并离开';

  @override
  String inventoryUpdateSuccess(Object name) {
    return '✅ $name 库存更新成功！';
  }

  @override
  String get inventoryUpdateFailedTitle => '更新失败';

  @override
  String get inventoryUpdateFailedMsg => '数据库错误，请联系管理员。';

  @override
  String get inventoryBatchSaveFailedTitle => '批量保存失败';

  @override
  String inventoryBatchSaveFailedMsg(Object name) {
    return '品项 $name 保存失败。';
  }

  @override
  String get inventoryReasonStockIn => '入库';

  @override
  String get inventoryReasonAudit => '盘点调整';

  @override
  String get inventoryErrorTitle => '错误';

  @override
  String get inventoryErrorInvalidNumber => '请输入有效的数字';

  @override
  String get commonOk => '确定';

  @override
  String get punchTitle => '打卡';

  @override
  String get punchInButton => '上班打卡';

  @override
  String get punchOutButton => '下班打卡';

  @override
  String get punchMakeUpButton => '补打卡\n(上班/下班)';

  @override
  String get punchLocDisabled => '定位服务已关闭，请至设置中开启。';

  @override
  String get punchLocDenied => '定位权限被拒绝';

  @override
  String get punchLocDeniedForever => '定位权限被永久拒绝，无法请求权限。';

  @override
  String get punchErrorSettingsNotFound => '找不到打卡设置，请联系管理员。';

  @override
  String punchErrorWifi(Object wifi) {
    return 'Wi-Fi 不正确。\n请连接至：$wifi';
  }

  @override
  String get punchErrorDistance => '您距离店铺太远。';

  @override
  String get punchErrorAlreadyIn => '您已经打过上班卡了。';

  @override
  String get punchSuccessInTitle => '打卡成功';

  @override
  String get punchSuccessInMsg => '祝您上班愉快 : )';

  @override
  String get punchErrorInTitle => '上班打卡失败';

  @override
  String get punchErrorNoSession => '找不到 24 小时内的上班记录，请联系管理员。';

  @override
  String get punchErrorOverTime => '工时超过 12 小时，请使用「补打卡」功能。';

  @override
  String get punchSuccessOutTitle => '打卡成功';

  @override
  String get punchSuccessOutMsg => '老板爱你 ❤️';

  @override
  String get punchErrorOutTitle => '下班打卡失败';

  @override
  String punchErrorGeneric(Object error) {
    return '发生错误：$error';
  }

  @override
  String get punchMakeUpTitle => '补打卡 (上班/下班)';

  @override
  String get punchMakeUpTypeIn => '补上班卡';

  @override
  String get punchMakeUpTypeOut => '补下班卡';

  @override
  String get punchMakeUpReasonHint => '原因 (必填)';

  @override
  String get punchMakeUpErrorReason => '请填写补打卡原因';

  @override
  String get punchMakeUpErrorFuture => '不能补打未来的时间';

  @override
  String get punchMakeUpError72h => '补打卡不能超过 72 小时，请联系管理员。';

  @override
  String punchMakeUpErrorOverlap(Object time) {
    return '发现未下班记录 ($time)，请先补下班卡。';
  }

  @override
  String get punchMakeUpErrorNoRecord => '找不到 72 小时内的对应上班记录，请联系管理员。';

  @override
  String get punchMakeUpErrorOver12h => '工时超过 12 小时，请联系管理员。';

  @override
  String get punchMakeUpSuccessTitle => '成功';

  @override
  String get punchMakeUpSuccessMsg => '补打卡成功';

  @override
  String get punchMakeUpCheckInfo => '请确认信息';

  @override
  String punchMakeUpLabelType(Object type) {
    return '类型：$type';
  }

  @override
  String punchMakeUpLabelTime(Object time) {
    return '时间：$time';
  }

  @override
  String punchMakeUpLabelReason(Object reason) {
    return '原因：$reason';
  }

  @override
  String get commonDate => '日期';

  @override
  String get commonTime => '时间';

  @override
  String get workReportTitle => '工作日报';

  @override
  String get workReportSelectDate => '选择日期';

  @override
  String get workReportJobSubject => '工作主旨 (必填)';

  @override
  String get workReportJobDescription => '工作内容 (必填)';

  @override
  String get workReportOverTime => '加班时数 (选填)';

  @override
  String get workReportHourUnit => '小时';

  @override
  String get workReportErrorRequiredTitle => '请填写必填字段';

  @override
  String get workReportErrorRequiredMsg => '主旨与内容为必填项！';

  @override
  String get workReportConfirmOverwriteTitle => '报告已存在';

  @override
  String get workReportConfirmOverwriteMsg => '您已提交过此日期的报告。\n是否要覆盖？';

  @override
  String get workReportOverwriteYes => '覆盖';

  @override
  String get workReportSuccessTitle => '提交成功';

  @override
  String get workReportSuccessMsg => '您的工作日报已成功提交！';

  @override
  String get workReportSubmitFailed => '提交失败';

  @override
  String get todoScreenTitle => '待办事项';

  @override
  String get todoTabIncomplete => '未完成';

  @override
  String get todoTabPending => '待确认';

  @override
  String get todoTabCompleted => '已完成';

  @override
  String get todoFilterMyTasks => '只看与我有关';

  @override
  String todoCountSuffix(Object count) {
    return '$count 笔';
  }

  @override
  String get todoEmptyPending => '没有待确认事项';

  @override
  String get todoEmptyIncomplete => '没有待办事项';

  @override
  String get todoEmptyCompleted => '本月无完成记录';

  @override
  String get todoSubmitReviewTitle => '提交验收';

  @override
  String get todoSubmitReviewContent => '确定已完成并提交给指派人检查吗？';

  @override
  String get todoSubmitButton => '提交';

  @override
  String get todoApproveTitle => '通过验收';

  @override
  String get todoApproveContent => '确定此任务已完成吗？';

  @override
  String get todoApproveButton => '通过';

  @override
  String get todoRejectTitle => '退回任务';

  @override
  String get todoRejectContent => '将任务退回给员工重新处理？';

  @override
  String get todoRejectButton => '退回';

  @override
  String get todoDeleteTitle => '删除事项';

  @override
  String get todoDeleteContent => '确定要删除吗？此操作无法复原。';

  @override
  String get todoErrorNoPermissionSubmit => '您没有权限提交此事项';

  @override
  String get todoErrorNoPermissionApprove => '只有指派人可以验收此事项';

  @override
  String get todoErrorNoPermissionReject => '只有指派人可以退回事项';

  @override
  String get todoErrorNoPermissionEdit => '只有指派人可以编辑内容';

  @override
  String get todoErrorNoPermissionDelete => '只有指派人可以删除事项';

  @override
  String get notificationTodoReviewTitle => '👀 任务待验收';

  @override
  String notificationTodoReviewBody(Object name, Object task) {
    return '$name 已提交：$task，请确认。';
  }

  @override
  String get notificationTodoApprovedTitle => '✅ 任务验收通过';

  @override
  String notificationTodoApprovedBody(Object task) {
    return '指派人已确认完成：$task';
  }

  @override
  String get notificationTodoRejectedTitle => '↩️ 任务被退回';

  @override
  String notificationTodoRejectedBody(Object task) {
    return '请修正并重新提交：$task';
  }

  @override
  String get notificationTodoDeletedTitle => '🗑️ 事项已删除';

  @override
  String notificationTodoDeletedBody(Object task) {
    return '指派人删除了：$task';
  }

  @override
  String todoActionSheetTitle(Object title) {
    return '操作：$title';
  }

  @override
  String get todoActionCompleteAndSubmit => '完成并提交验收';

  @override
  String todoReviewSheetTitle(Object title) {
    return '验收：$title';
  }

  @override
  String get todoReviewSheetMessageAssigner => '请确认任务是否合格';

  @override
  String get todoReviewSheetMessageAssignee => '等待指派人验收中';

  @override
  String get todoActionApprove => '✅ 通过验收';

  @override
  String get todoActionReject => '↩️ 退回重做';

  @override
  String get todoActionViewDetails => '查看详情';

  @override
  String get todoLabelTo => '给：';

  @override
  String get todoLabelFrom => '来自：';

  @override
  String get todoUnassigned => '未指派';

  @override
  String get todoLabelCompletedAt => '完成于：';

  @override
  String get todoLabelWaitingReview => '等待验收中';

  @override
  String get commonEdit => '编辑';

  @override
  String get todoAddTaskTitleNew => '新增任务';

  @override
  String get todoAddTaskTitleEdit => '编辑任务';

  @override
  String get todoAddTaskLabelTitle => '任务标题';

  @override
  String get todoAddTaskLabelDesc => '内容描述 (选填)';

  @override
  String get todoAddTaskLabelAssign => '指派给：';

  @override
  String get todoAddTaskSelectStaff => '选择员工';

  @override
  String todoAddTaskSelectedStaff(Object count) {
    return '已选择 $count 位员工';
  }

  @override
  String get todoAddTaskSetDueDate => '设置截止日期';

  @override
  String get todoAddTaskSelectDate => '选择日期';

  @override
  String get todoAddTaskSetDueTime => '设置截止时间';

  @override
  String get todoAddTaskSelectTime => '选择时间';

  @override
  String get notificationTodoEditTitle => '✏️ 事项已更新';

  @override
  String notificationTodoEditBody(Object task) {
    return '内容已有变动：$task';
  }

  @override
  String get notificationTodoUrgentUpdate => '🔥 急件更新';

  @override
  String get notificationTodoNewTitle => '📝 新待办事项';

  @override
  String notificationTodoNewBody(Object task) {
    return '$task';
  }

  @override
  String get notificationTodoUrgentNew => '🔥 急件指派';

  @override
  String get costInputTitle => '每日成本';

  @override
  String get costInputTotalToday => '今日总成本';

  @override
  String get costInputLabelName => '项目名称';

  @override
  String get costInputLabelPrice => '金额';

  @override
  String get costInputTabNotOpenTitle => '尚未开账';

  @override
  String get costInputTabNotOpenMsg => '请先开启今日账务。';

  @override
  String get costInputTabNotOpenPageTitle => '请先开启今日账务';

  @override
  String get costInputTabNotOpenPageDesc => '您必须先完成开账，\n才能开始输入每日成本。';

  @override
  String get costInputButtonOpenTab => '前往开账';

  @override
  String get costInputErrorInputTitle => '输入错误';

  @override
  String get costInputErrorInputMsg => '请确认项目名称与金额填写正确。';

  @override
  String get costInputSuccess => '✅ 成本保存成功';

  @override
  String get costInputSaveFailed => '保存失败';

  @override
  String get costInputLoadingCategories => '加载中...';

  @override
  String get costDetailTitle => '每日成本明细';

  @override
  String get costDetailNoRecords => '此期间无成本记录。';

  @override
  String get costDetailItemUntitled => '未命名项目';

  @override
  String get costDetailCategoryNA => '未知';

  @override
  String get costDetailBuyerNA => '未知';

  @override
  String costDetailLabelCategory(Object category) {
    return '类别：$category';
  }

  @override
  String costDetailLabelBuyer(Object buyer) {
    return '采购人：$buyer';
  }

  @override
  String get costDetailEditTitle => '编辑每日成本';

  @override
  String get costDetailDeleteTitle => '删除成本';

  @override
  String costDetailDeleteContent(Object name) {
    return '确定要删除这笔成本吗？\n($name)';
  }

  @override
  String get costDetailErrorUpdate => '更新失败';

  @override
  String get costDetailErrorDelete => '删除失败';

  @override
  String get cashSettlementTitleOpen => '开班点钞';

  @override
  String get cashSettlementTitleClose => '结账点钞';

  @override
  String get cashSettlementTitleLoading => '加载中...';

  @override
  String get cashSettlementOpenDesc => '请检查并确认钞票数量与总金额是否与预期一致。';

  @override
  String get cashSettlementTargetAmount => '目标金额：';

  @override
  String get cashSettlementTotal => '总计：';

  @override
  String get cashSettlementRevenueAndPayment => '今日营收与支付方式';

  @override
  String get cashSettlementRevenueHint => '总营收';

  @override
  String cashSettlementDepositButton(Object amount) {
    return '今日定金 (已选：\$$amount)';
  }

  @override
  String get cashSettlementReceivableCash => '应收现金：';

  @override
  String get cashSettlementCashCountingTitle => '点钞确认\n(请输入实际钞票数量)';

  @override
  String get cashSettlementTotalCashCounted => '点钞总计：';

  @override
  String get cashSettlementReviewTitle => '总结';

  @override
  String get cashSettlementOpeningCash => '开班现金';

  @override
  String get cashSettlementDailyCosts => '今日成本';

  @override
  String get cashSettlementRedeemedDeposit => '抵扣定金';

  @override
  String get cashSettlementTotalExpectedCash => '预期现金总额';

  @override
  String get cashSettlementTodaysCashCount => '今日点钞总额';

  @override
  String get cashSettlementSummary => '差异：';

  @override
  String get cashSettlementErrorCountMismatch => '点钞金额与目标金额不符！';

  @override
  String get cashSettlementOpenSuccessTitle => '开班成功';

  @override
  String cashSettlementOpenSuccessMsg(Object count) {
    return '第 $count 班次已成功开启！';
  }

  @override
  String get cashSettlementOpenFailedTitle => '开班失败';

  @override
  String get cashSettlementCloseSuccessTitle => '结账成功';

  @override
  String get cashSettlementCloseSuccessMsg => '老板爱你 ❤️';

  @override
  String get cashSettlementCloseFailedTitle => '结账失败';

  @override
  String get cashSettlementErrorInputRevenue => '请输入总营收。';

  @override
  String get cashSettlementDepositTitle => '定金管理';

  @override
  String get cashSettlementDepositAdd => '新增定金';

  @override
  String get cashSettlementDepositEdit => '编辑所有定金';

  @override
  String get cashSettlementDepositRedeemTitle => '核销今日定金';

  @override
  String get cashSettlementDepositNoUnredeemed => '无未核销定金';

  @override
  String cashSettlementDepositTotalRedeemed(Object amount) {
    return '核销总额：\$$amount';
  }

  @override
  String get cashSettlementDepositAddTitle => '新增定金';

  @override
  String get cashSettlementDepositEditTitle => '编辑定金';

  @override
  String get cashSettlementDepositPaymentDate => '付款日期';

  @override
  String get cashSettlementDepositReservationDate => '预约日期';

  @override
  String get cashSettlementDepositReservationTime => '预约时间';

  @override
  String get cashSettlementDepositName => '姓名';

  @override
  String get cashSettlementDepositPax => '人数';

  @override
  String get cashSettlementDepositAmount => '定金金额';

  @override
  String get cashSettlementErrorInputDates => '请选择所有日期与时间。';

  @override
  String get cashSettlementErrorInputAmount => '请填写姓名与有效金额。';

  @override
  String get cashSettlementErrorTimePast => '预约时间不能是过去的时间。';

  @override
  String get cashSettlementSaveFailed => '保存失败';

  @override
  String get depositScreenTitle => '定金管理';

  @override
  String get depositScreenNoRecords => '无未核销定金';

  @override
  String depositScreenLabelName(Object name) {
    return '姓名：$name';
  }

  @override
  String depositScreenLabelReservationDate(Object date) {
    return '预约日期：$date';
  }

  @override
  String depositScreenLabelReservationTime(Object time) {
    return '预约时间：$time';
  }

  @override
  String depositScreenLabelGroupSize(Object size) {
    return '人数：$size';
  }

  @override
  String get depositScreenDeleteConfirm => '删除定金';

  @override
  String get depositScreenDeleteContent => '确定要删除这笔定金吗？';

  @override
  String get depositScreenDeleteSuccess => '定金删除成功';

  @override
  String depositScreenDeleteFailed(Object error) {
    return '删除失败：$error';
  }

  @override
  String depositScreenSaveFailed(Object error) {
    return '保存失败：$error';
  }

  @override
  String get depositScreenInputError => '请填写所有必填字段 (姓名、金额、日期/时间)。';

  @override
  String get depositScreenTimeError => '预约时间不能是过去的时间。';

  @override
  String get depositDialogTitleAdd => '新增定金';

  @override
  String get depositDialogTitleEdit => '编辑定金';

  @override
  String get depositDialogHintPaymentDate => '付款日期';

  @override
  String get depositDialogHintReservationDate => '预约日期';

  @override
  String get depositDialogHintReservationTime => '预约时间';

  @override
  String get depositDialogHintName => '姓名';

  @override
  String get depositDialogHintGroupSize => '人数';

  @override
  String get depositDialogHintAmount => '定金金额';

  @override
  String get monthlyCostTitle => '月度成本';

  @override
  String get monthlyCostTotal => '本月总成本';

  @override
  String get monthlyCostLabelName => '项目名称';

  @override
  String get monthlyCostLabelPrice => '金额';

  @override
  String get monthlyCostLabelNote => '备注';

  @override
  String get monthlyCostErrorInputTitle => '错误';

  @override
  String get monthlyCostErrorInputMsg => '项目名称与金额为必填。';

  @override
  String get monthlyCostErrorSaveFailed => '保存失败';

  @override
  String get monthlyCostSuccess => '成本保存成功';

  @override
  String get monthlyCostDetailTitle => '月度成本明细';

  @override
  String get monthlyCostDetailNoRecords => '本月无成本记录。';

  @override
  String get monthlyCostDetailItemUntitled => '未命名项目';

  @override
  String get monthlyCostDetailCategoryNA => '未知';

  @override
  String get monthlyCostDetailBuyerNA => '未知';

  @override
  String monthlyCostDetailLabelCategory(Object category) {
    return '类别：$category';
  }

  @override
  String monthlyCostDetailLabelDate(Object date) {
    return '日期：$date';
  }

  @override
  String monthlyCostDetailLabelBuyer(Object buyer) {
    return '采购人：$buyer';
  }

  @override
  String get monthlyCostDetailEditTitle => '编辑月度成本';

  @override
  String get monthlyCostDetailDeleteTitle => '删除成本';

  @override
  String monthlyCostDetailDeleteContent(Object name) {
    return '确定要删除这笔成本吗？\n($name)';
  }

  @override
  String monthlyCostDetailErrorFetch(Object error) {
    return '获取成本失败：$error';
  }

  @override
  String get monthlyCostDetailErrorUpdate => '更新失败';

  @override
  String get monthlyCostDetailErrorDelete => '删除失败';

  @override
  String get cashFlowTitle => '關帳報表';

  @override
  String get cashFlowMonthlyRevenue => '本月营收';

  @override
  String get cashFlowMonthlyDifference => '本月每日成本';

  @override
  String cashFlowLabelShift(Object count) {
    return '第 $count 班';
  }

  @override
  String get cashFlowLabelRevenue => '总营收：';

  @override
  String get cashFlowLabelCost => '总成本：';

  @override
  String get cashFlowLabelDifference => '现金短溢：';

  @override
  String get cashFlowNoRecords => '无记录。';

  @override
  String get costReportTitle => '成本总结';

  @override
  String get costReportMonthlyTotal => '本月总成本';

  @override
  String get costReportNoRecords => '无成本记录。';

  @override
  String get costReportNoRecordsShift => '此班次无成本记录。';

  @override
  String get costReportLabelTotalCost => '总成本：';

  @override
  String get dashboardTitle => '运营仪表板';

  @override
  String get dashboardTotalRevenue => '总营收';

  @override
  String get dashboardCogs => '营收成本';

  @override
  String get dashboardGrossProfit => '毛利';

  @override
  String get dashboardGrossMargin => '毛利率';

  @override
  String get dashboardOpex => '营业费用';

  @override
  String get dashboardOpIncome => '营业利益';

  @override
  String get dashboardNetIncome => '净利';

  @override
  String get dashboardNetProfitMargin => '净利率';

  @override
  String get dashboardNoCostData => '无成本数据';

  @override
  String dashboardErrorLoad(Object error) {
    return '数据加载错误：$error';
  }

  @override
  String get reportingTitle => '后台管理';

  @override
  String get reportingCashFlow => '關帳報表';

  @override
  String get reportingCostSum => '成本总结';

  @override
  String get reportingDashboard => '运营仪表板';

  @override
  String get reportingCashVault => '金库管理';

  @override
  String get reportingClockIn => '打卡记录';

  @override
  String get reportingWorkReport => '工作日报';

  @override
  String get reportingNoAccess => '无可使用的功能';

  @override
  String get vaultTitle => '资金概况';

  @override
  String get vaultTotalCash => '现金总额';

  @override
  String get vaultTitleVault => '金库';

  @override
  String get vaultTitleCashbox => '找零柜';

  @override
  String get vaultCashDetail => '现金明细';

  @override
  String vaultDetailDenom(Object cashboxCount, Object totalCount, Object vaultCount) {
    return '\$ $cashboxCount X $totalCount (金库 $cashboxCount + 找零柜 $vaultCount)';
  }

  @override
  String get vaultActivityHistory => '活动记录';

  @override
  String get vaultTableDate => '日期';

  @override
  String get vaultTableStaff => '点账人';

  @override
  String get vaultNoRecords => '无活动记录。';

  @override
  String get vaultManagementSheetTitle => '金库管理';

  @override
  String get vaultAdjustCounts => '调整库存';

  @override
  String get vaultSaveMoney => '存钱 (入银行)';

  @override
  String get vaultChangeMoney => '兑换零钱';

  @override
  String get vaultPromptAdjust => '请输入总数 (金库 + 找零柜)。';

  @override
  String get vaultPromptDeposit => '请输入要存入银行的金额';

  @override
  String get vaultPromptChangeOut => '取出大钞 (兑换)';

  @override
  String get vaultPromptChangeIn => '存入零钞 (兑换)';

  @override
  String get vaultErrorMismatch => '金额不符！已取消兑换。';

  @override
  String vaultDialogTotal(Object amount) {
    return '总计：$amount';
  }

  @override
  String get clockInReportTitle => '打卡记录';

  @override
  String get clockInReportTotalHours => '总工时';

  @override
  String get clockInReportStaffCount => '员人数';

  @override
  String get clockInReportWorkDays => '出勤日数';

  @override
  String get clockInReportUnitPpl => '人';

  @override
  String get clockInReportUnitDays => '天';

  @override
  String get clockInReportUnitHr => '小时';

  @override
  String get clockInReportNoRecords => '无记录。';

  @override
  String get clockInReportLabelManual => '补打卡';

  @override
  String get clockInReportLabelIn => '上班';

  @override
  String get clockInReportLabelOut => '下班';

  @override
  String get clockInReportStatusWorking => '上班中';

  @override
  String get clockInReportStatusCompleted => '已完成';

  @override
  String get clockInReportStatusIncomplete => '未完成';

  @override
  String get clockInReportAllStaff => '所有员工';

  @override
  String get clockInReportSelectStaff => '选择员工';

  @override
  String get clockInDetailTitleIn => '上班打卡';

  @override
  String get clockInDetailTitleOut => '下班打卡';

  @override
  String get clockInDetailMissing => '记录遗失';

  @override
  String get clockInDetailFixButton => '修正下班时间';

  @override
  String get clockInDetailCloseButton => '关闭';

  @override
  String clockInDetailLabelWifi(Object wifi) {
    return 'WiFi：$wifi';
  }

  @override
  String clockInDetailLabelReason(Object reason) {
    return '原因：$reason';
  }

  @override
  String get clockInDetailReasonSupervisorFix => '主管修正';

  @override
  String get clockInDetailErrorInLaterThanOut => '上班时间不能晚于下班时间。';

  @override
  String get clockInDetailErrorOutEarlierThanIn => '下班时间不能早于上班时间。';

  @override
  String get clockInDetailErrorDateCheck => '日期错误：请检查是否选到正确日期 (例如：隔天)。';

  @override
  String get clockInDetailSuccessUpdate => '时间更新成功。';

  @override
  String get clockInDetailSelectDate => '选择下班日期';

  @override
  String get commonNone => '无';

  @override
  String get workReportOverviewTitle => '工作日报';

  @override
  String get workReportOverviewNoRecords => '无日报记录。';

  @override
  String get workReportOverviewSelectStaff => '选择员工';

  @override
  String get workReportOverviewAllStaff => '所有员工';

  @override
  String get workReportOverviewNoSubject => '无主旨';

  @override
  String get workReportOverviewNoContent => '无内容';

  @override
  String workReportOverviewOvertimeTag(Object hours) {
    return 'OT: $hours小时';
  }

  @override
  String workReportDetailOvertimeLabel(Object hours) {
    return '加班：$hours 小时';
  }

  @override
  String get commonClose => '关闭';

  @override
  String get userMgmtTitle => '人员管理';

  @override
  String get userMgmtInviteNewUser => '邀请新用户';

  @override
  String get userMgmtStatusInvited => '已邀请';

  @override
  String get userMgmtStatusWaiting => '等待中...';

  @override
  String userMgmtLabelRole(Object roleName) {
    return '职位：$roleName';
  }

  @override
  String get userMgmtNameHint => '姓名';

  @override
  String get userMgmtInviteNote => '用户将收到 Email 邀请信。';

  @override
  String get userMgmtInviteButton => '邀请';

  @override
  String get userMgmtEditTitle => '编辑用户信息';

  @override
  String get userMgmtDeleteTitle => '删除用户';

  @override
  String userMgmtDeleteContent(Object userName) {
    return '确定要删除 $userName 吗？';
  }

  @override
  String userMgmtErrorLoad(Object error) {
    return '加载失败：$error';
  }

  @override
  String get userMgmtInviteSuccess => '邀请已发送！对方收到 Email 后即可加入。';

  @override
  String userMgmtInviteFailed(Object error) {
    return '邀请失败：$error';
  }

  @override
  String userMgmtErrorConnection(Object error) {
    return '连接错误：$error';
  }

  @override
  String userMgmtDeleteFailed(Object error) {
    return '删除失败：$error';
  }

  @override
  String get userMgmtLabelEmail => '电子邮箱';

  @override
  String get userMgmtLabelRolePicker => '职位';

  @override
  String get userMgmtButtonDone => '完成';

  @override
  String get userMgmtLabelRoleSelect => '选择';

  @override
  String get roleMgmtTitle => '职位权限管理';

  @override
  String get roleMgmtSystemDefault => '系统默认';

  @override
  String roleMgmtPermissionGroupTitle(Object groupName) {
    return '权限 - $groupName';
  }

  @override
  String get roleMgmtRoleNameHint => '职位名称';

  @override
  String get roleMgmtSaveButton => '保存';

  @override
  String get roleMgmtDeleteRole => '删除职位';

  @override
  String get roleMgmtAddNewRole => '新增职位';

  @override
  String get roleMgmtEnterRoleName => '输入职位名称 (例如：服务员)';

  @override
  String get roleMgmtCreateButton => '创建';

  @override
  String get roleMgmtDeleteConfirmTitle => '删除职位';

  @override
  String get roleMgmtDeleteConfirmContent => '确定要删除此职位吗？此操作无法复原。';

  @override
  String get roleMgmtCannotDeleteTitle => '无法删除职位';

  @override
  String roleMgmtCannotDeleteContent(Object count, Object roleName) {
    return '仍有 $count 位用户被指派给「$roleName」职位。\n\n请先将他们指派给其他职位后再删除。';
  }

  @override
  String get roleMgmtUnderstandButton => '我知道了';

  @override
  String roleMgmtErrorLoad(Object error) {
    return '加载职位失败：$error';
  }

  @override
  String roleMgmtErrorSave(Object error) {
    return '保存权限失败：$error';
  }

  @override
  String roleMgmtErrorAdd(Object error) {
    return '新增职位失败：$error';
  }

  @override
  String get commonNotificationTitle => '通知';

  @override
  String get permGroupMainScreen => '主画面功能';

  @override
  String get permGroupSchedule => '排班表';

  @override
  String get permGroupBackstageDashboard => '后台仪表板';

  @override
  String get permGroupSettings => '设置页面功能';

  @override
  String get permHomeOrder => '点餐';

  @override
  String get permHomePrep => '备料清单';

  @override
  String get permHomeStock => '库存盘点';

  @override
  String get permHomeBackDashboard => '后台仪表板';

  @override
  String get permHomeDailyCost => '每日成本输入';

  @override
  String get permHomeCashFlow => '關帳報表';

  @override
  String get permHomeMonthlyCost => '月度成本输入';

  @override
  String get permHomeScan => '智慧扫描';

  @override
  String get permScheduleEdit => '更改员工班表';

  @override
  String get permBackCashFlow => '關帳報表';

  @override
  String get permBackCostSum => '成本总结报表';

  @override
  String get permBackDashboard => '运营仪表板';

  @override
  String get permBackCashVault => '金库管理';

  @override
  String get permBackClockIn => '打卡记录报表';

  @override
  String get permBackViewAllClockIn => '查看所有员工打卡记录';

  @override
  String get permBackWorkReport => '工作日报总览';

  @override
  String get permSetStaff => '人员管理';

  @override
  String get permSetRole => '职位权限管理';

  @override
  String get permSetPrinter => '印表机设置';

  @override
  String get permSetTableMap => '桌位图管理';

  @override
  String get permSetTableList => '桌况列表';

  @override
  String get permSetMenu => '编辑菜单';

  @override
  String get permSetShift => '班别设置';

  @override
  String get permSetPunch => '打卡设置';

  @override
  String get permSetPay => '付款方式设置';

  @override
  String get permSetCostCat => '成本类别设置';

  @override
  String get permSetInv => '库存与品项管理';

  @override
  String get permSetCashReg => '收银机设置';

  @override
  String get stockCategoryTitle => '编辑备料细节';

  @override
  String get stockCategoryAddButton => '＋ 新增类别';

  @override
  String get stockCategoryAddDialogTitle => '新增备料类别';

  @override
  String get stockCategoryEditDialogTitle => '编辑类别';

  @override
  String get stockCategoryHintName => '类别名称';

  @override
  String get stockCategoryDeleteTitle => '删除类别';

  @override
  String stockCategoryDeleteContent(Object categoryName) {
    return '确定要删除类别：$categoryName 吗？';
  }

  @override
  String get inventoryCategoryTitle => '编辑库存列表';

  @override
  String get inventoryCategoryDetailTitle => '品项列表';

  @override
  String get inventoryCategoryAddButton => '＋ 新增类别';

  @override
  String get inventoryCategoryAddDialogTitle => '新增库存类别';

  @override
  String get inventoryCategoryEditDialogTitle => '编辑类别';

  @override
  String get inventoryCategoryHintName => '类别名称';

  @override
  String get inventoryCategoryDeleteTitle => '删除类别';

  @override
  String inventoryCategoryDeleteContent(Object categoryName) {
    return '确定要删除类别：$categoryName 吗？';
  }

  @override
  String get inventoryItemAddButton => '＋ 新增品项';

  @override
  String get inventoryItemAddDialogTitle => '新增品项';

  @override
  String get inventoryItemEditDialogTitle => '编辑品项';

  @override
  String get inventoryItemDeleteTitle => '删除品项';

  @override
  String inventoryItemDeleteContent(Object itemName) {
    return '确定要删除 $itemName 吗？';
  }

  @override
  String get inventoryItemHintName => '品项名称';

  @override
  String get inventoryItemHintUnit => '品项单位';

  @override
  String get inventoryItemHintStock => '目前库存数量';

  @override
  String get inventoryItemHintPar => '安全库存量';

  @override
  String get stockItemTitle => '品项信息';

  @override
  String get stockItemLabelName => '品项名称';

  @override
  String get stockItemLabelMainIngredients => '主材料';

  @override
  String get stockItemLabelSubsidiaryIngredients => '副材料';

  @override
  String stockItemLabelDetails(Object index) {
    return '详细说明 $index';
  }

  @override
  String get stockItemHintIngredient => '品名';

  @override
  String get stockItemHintQty => '数量';

  @override
  String get stockItemHintUnit => '单位';

  @override
  String get stockItemHintInstructionsSub => '副材料操作说明';

  @override
  String get stockItemHintInstructionsNote => '品项操作说明';

  @override
  String get stockItemAddSubDialogTitle => '新增副材料';

  @override
  String get stockItemAddSubHintGroupName => '群组名称 (例如：装饰)';

  @override
  String get stockItemAddOptionTitle => '新增副材料或说明';

  @override
  String get stockItemAddOptionSub => '新增副材料';

  @override
  String get stockItemAddOptionDetail => '新增说明';

  @override
  String get stockItemDeleteSubTitle => '删除副材料';

  @override
  String get stockItemDeleteSubContent => '确定要删除此副材料及其备注吗？';

  @override
  String get stockItemDeleteNoteTitle => '删除说明';

  @override
  String get stockItemDeleteNoteContent => '确定要删除此说明吗？';

  @override
  String get stockCategoryDetailItemTitle => '品项列表';

  @override
  String get stockCategoryDetailAddItemButton => '＋ 新增品项';

  @override
  String get stockItemDetailDeleteTitle => '删除品项';

  @override
  String stockItemDetailDeleteContent(Object productName) {
    return '确定要删除 $productName 吗？';
  }

  @override
  String get inventoryLogTitle => '库存日志';

  @override
  String get inventoryLogSearchHint => '搜索库存品项';

  @override
  String get inventoryLogAllDates => '所有日期';

  @override
  String get inventoryLogDatePickerConfirm => '确定';

  @override
  String get inventoryLogReasonAll => '全部';

  @override
  String get inventoryLogReasonAdd => '入库';

  @override
  String get inventoryLogReasonAdjustment => '盘点调整';

  @override
  String get inventoryLogReasonWaste => '报废';

  @override
  String get inventoryLogNoRecords => '无日志记录。';

  @override
  String get inventoryLogCardUnknownItem => '未知原料';

  @override
  String get inventoryLogCardUnknownUser => '未知操作者';

  @override
  String inventoryLogCardLabelName(Object userName) {
    return '操作者：$userName';
  }

  @override
  String inventoryLogCardLabelChange(Object adjustment, Object unit) {
    return '变更：$adjustment $unit';
  }

  @override
  String inventoryLogCardLabelStock(Object newStock, Object oldStock) {
    return '数量 $oldStock→$newStock';
  }

  @override
  String get printerSettingsTitle => '硬件设置';

  @override
  String get printerSettingsListTitle => '出单机列表';

  @override
  String get printerSettingsNoPrinters => '目前没有设置出单机';

  @override
  String printerSettingsLabelIP(Object ip) {
    return 'IP：$ip';
  }

  @override
  String get printerDialogAddTitle => '新增出单机';

  @override
  String get printerDialogEditTitle => '编辑出单机信息';

  @override
  String get printerDialogHintName => '出单机名称';

  @override
  String get printerDialogHintIP => '出单机 IP 地址';

  @override
  String get printerTestConnectionFailed => '❌ 打印机连接失败';

  @override
  String get printerTestTicketSuccess => '✅ 测试单已打印';

  @override
  String get printerCashDrawerOpenSuccess => '✅ 钱柜已开启';

  @override
  String get printerDeleteTitle => '删除出单机';

  @override
  String printerDeleteContent(Object printerName) {
    return '确定要删除 $printerName 吗？';
  }

  @override
  String get printerTestPrintTitle => '【出单测试】';

  @override
  String get printerTestPrintSubtitle => '测试打印机是否正常打印';

  @override
  String get printerTestPrintContent1 => '这是一张测试单，';

  @override
  String get printerTestPrintContent2 => '如果您看到这段文字，';

  @override
  String get printerTestPrintContent3 => '代表中文与图片打印皆正常。';

  @override
  String get printerTestPrintContent4 => '代表中文与图片打印皆正常。';

  @override
  String get printerTestPrintContent5 => '感谢使用 Gallery 20.5';

  @override
  String get tableMapAreaSuffix => '区';

  @override
  String get tableMapRemoveTitle => '移除桌位';

  @override
  String tableMapRemoveContent(Object tableName) {
    return '确定要将「$tableName」从地图上移除吗？';
  }

  @override
  String get tableMapRemoveConfirm => '移除';

  @override
  String get tableMapAddDialogTitle => '新增桌位';

  @override
  String get tableMapShapeCircle => '圆形';

  @override
  String get tableMapShapeSquare => '方形';

  @override
  String get tableMapShapeRect => '矩形';

  @override
  String get tableMapAddDialogHint => '选择桌号';

  @override
  String get tableMapNoAvailableTables => '此区域没有可用的桌位。';

  @override
  String get tableMgmtTitle => '桌位管理';

  @override
  String get tableMgmtAreaListAddButton => '＋ 新增区域';

  @override
  String get tableMgmtAreaListAddTitle => '新增区域';

  @override
  String get tableMgmtAreaListEditTitle => '编辑区域';

  @override
  String get tableMgmtAreaListHintName => '区域名称';

  @override
  String get tableMgmtAreaListDeleteTitle => '删除区域';

  @override
  String tableMgmtAreaListDeleteContent(Object areaName) {
    return '确定要删除区域 $areaName 吗？';
  }

  @override
  String tableMgmtAreaAddSuccess(Object name) {
    return '✅ 区域「$name」新增成功';
  }

  @override
  String get tableMgmtAreaAddFailure => '新增区域失败';

  @override
  String get tableMgmtTableListAddButton => '＋ 新增桌位';

  @override
  String get tableMgmtTableListAddTitle => '新增桌位';

  @override
  String get tableMgmtTableListEditTitle => '编辑桌位';

  @override
  String get tableMgmtTableListHintName => '桌位名称';

  @override
  String get tableMgmtTableListDeleteTitle => '删除桌位';

  @override
  String tableMgmtTableListDeleteContent(Object tableName) {
    return '确定要删除桌位 $tableName 吗？';
  }

  @override
  String get tableMgmtTableAddFailure => '新增桌位失败';

  @override
  String get tableMgmtTableDeleteFailure => '删除桌位失败';

  @override
  String get commonSaveFailure => '保存数据失败。';

  @override
  String get commonDeleteFailure => '删除失败，请稍后重试。';

  @override
  String get commonNameExists => '名称已存在。';

  @override
  String get menuEditTitle => '菜单编辑';

  @override
  String get menuCategoryAddButton => '＋ 新增类别';

  @override
  String get menuDetailAddItemButton => '＋ 新增品项';

  @override
  String get menuDeleteCategoryTitle => '删除类别';

  @override
  String menuDeleteCategoryContent(Object categoryName) {
    return '确定要删除 $categoryName 吗？';
  }

  @override
  String get menuCategoryAddDialogTitle => '新增菜单类别';

  @override
  String get menuCategoryEditDialogTitle => '编辑类别名称';

  @override
  String get menuCategoryHintName => '类别名称';

  @override
  String get menuItemAddDialogTitle => '新增品项';

  @override
  String get menuItemEditDialogTitle => '编辑品项';

  @override
  String get menuItemPriceLabel => '目前价格';

  @override
  String get menuItemMarketPrice => '时价';

  @override
  String get menuItemHintPrice => '品项价格';

  @override
  String get menuItemLabelMarketPrice => '时价';

  @override
  String menuItemLabelPrice(Object price) {
    return '价格：$price';
  }

  @override
  String get shiftSetupTitle => '班次设置';

  @override
  String get shiftSetupSectionTitle => '已定义的班次类型';

  @override
  String get shiftSetupListAddButton => '+ 新增班次类型';

  @override
  String get shiftSetupSaveButton => '保存';

  @override
  String shiftListStartTime(Object endTime, Object startTime) {
    return '$startTime - $endTime';
  }

  @override
  String get shiftDialogAddTitle => '新增班次类型';

  @override
  String get shiftDialogEditTitle => '编辑班次类型';

  @override
  String get shiftDialogHintName => '班次名称';

  @override
  String get shiftDialogLabelStartTime => '开始时间：';

  @override
  String get shiftDialogLabelEndTime => '结束时间：';

  @override
  String get shiftDialogLabelColor => '颜色标签：';

  @override
  String get shiftDialogErrorNameEmpty => '请输入班次名称。';

  @override
  String get shiftDeleteConfirmTitle => '确认删除';

  @override
  String shiftDeleteConfirmContent(Object shiftName) {
    return '确定要删除班次类型「$shiftName」吗？此变更必须保存。';
  }

  @override
  String shiftDeleteLocalSuccess(Object shiftName) {
    return '班次类型「$shiftName」已在本地删除。';
  }

  @override
  String get shiftSaveSuccess => '班次设置保存成功！';

  @override
  String shiftSaveError(Object error) {
    return '保存设置失败：$error';
  }

  @override
  String shiftLoadError(Object error) {
    return '加载班次失败：$error';
  }

  @override
  String get commonSuccess => '成功';

  @override
  String get commonError => '错误';

  @override
  String get punchInSetupTitle => '打卡信息设置';

  @override
  String get punchInWifiSection => '当前 Wi-Fi 名称';

  @override
  String get punchInLocationSection => '当前位置';

  @override
  String get punchInLoading => '加载中...';

  @override
  String get punchInErrorPermissionTitle => '权限错误';

  @override
  String get punchInErrorPermissionContent => '请开启位置权限才能使用此功能。';

  @override
  String get punchInErrorFetchTitle => '获取信息失败';

  @override
  String get punchInErrorFetchContent => '无法获取 Wi-Fi 或 GPS 信息，请检查权限及网络连接。';

  @override
  String get punchInSaveFailureTitle => '错误';

  @override
  String get punchInSaveFailureContent => '无法获取必要信息。';

  @override
  String get punchInSaveSuccessTitle => '成功';

  @override
  String get punchInSaveSuccessContent => '打卡信息已保存。';

  @override
  String get punchInRegainButton => '重新读取 Wi-Fi 与位置';

  @override
  String get punchInSaveButton => '保存打卡信息';

  @override
  String get punchInConfirmOverwriteTitle => '确认覆盖';

  @override
  String get punchInConfirmOverwriteContent => '此商店已存在打卡信息，是否要覆盖原有数据？';

  @override
  String get commonOverwrite => '覆盖';

  @override
  String get commonOK => '确定';

  @override
  String get paymentSetupTitle => '支付设置';

  @override
  String get paymentSetupMethodsSection => '启用支付方式';

  @override
  String get paymentSetupFunctionModule => '功能模块';

  @override
  String get paymentSetupFunctionDeposit => '定金功能';

  @override
  String get paymentSetupSaveButton => '保存';

  @override
  String paymentSetupLoadError(Object error) {
    return '加载设置失败：$error';
  }

  @override
  String get paymentSetupSaveSuccess => '✅ 设置已保存';

  @override
  String paymentSetupSaveFailure(Object error) {
    return '保存失败：$error';
  }

  @override
  String get paymentAddDialogTitle => '＋新增支付方式';

  @override
  String get paymentAddDialogHintName => '方式名称';

  @override
  String get paymentAddDialogSave => '保存';

  @override
  String get costCategoryTitle => '支出类别';

  @override
  String get costCategoryAddButton => '新增支出类别';

  @override
  String get costCategoryTypeCOGS => '销货成本';

  @override
  String get costCategoryTypeOPEX => '运营成本';

  @override
  String get costCategoryAddTitle => '新增类别';

  @override
  String get costCategoryEditTitle => '编辑类别';

  @override
  String get costCategoryHintName => '类别名称';

  @override
  String costCategoryDeleteTitle(Object categoryName) {
    return '删除 $categoryName';
  }

  @override
  String get costCategoryDeleteContent => '确定要删除此类别吗？';

  @override
  String get costCategoryNoticeErrorTitle => '错误';

  @override
  String get costCategoryNoticeErrorLoad => '加载类别失败。';

  @override
  String get costCategoryNoticeErrorAdd => '新增类别失败。';

  @override
  String get costCategoryNoticeErrorUpdate => '更新类别失败。';

  @override
  String get costCategoryNoticeErrorDelete => '删除类别失败。';

  @override
  String get cashRegSetupTitle => '钱柜设置';

  @override
  String get cashRegSetupSubtitle => '请输入钱柜中每个面额的默认数量。';

  @override
  String cashRegSetupTotalLabel(Object totalAmount) {
    return '总计：$totalAmount';
  }

  @override
  String get cashRegSetupInputHint => '0';

  @override
  String get cashRegNoticeSaveSuccess => '钱柜零用金设置已保存！';

  @override
  String cashRegNoticeSaveFailure(Object error) {
    return '保存失败：$error';
  }

  @override
  String cashRegNoticeLoadError(Object error) {
    return '加载钱柜设置失败：$error';
  }

  @override
  String get languageEnglish => 'English';

  @override
  String get languageTraditionalChinese => '繁体中文';

  @override
  String get changePasswordTitle => '变更密码';

  @override
  String get changePasswordOldHint => '旧密码';

  @override
  String get changePasswordNewHint => '新密码';

  @override
  String get changePasswordConfirmHint => '确认新密码';

  @override
  String get changePasswordButton => '变更密码';

  @override
  String get passwordValidatorEmptyOld => '请输入旧密码';

  @override
  String get passwordValidatorLength => '密码至少 6 位数';

  @override
  String get passwordValidatorMismatch => '密码不一致';

  @override
  String get passwordErrorReLogin => '请重新登录';

  @override
  String get passwordErrorOldPassword => '旧密码错误';

  @override
  String get passwordErrorUpdateFailed => '密码更新失败';

  @override
  String get passwordSuccess => '✅ 密码已更新';

  @override
  String passwordFailure(Object error) {
    return '❌ 密码修改失败: $error';
  }

  @override
  String get languageSimplifiedChinese => '简体中文';

  @override
  String get languageItalian => 'Italiano';

  @override
  String get languageVietnamese => '越南文 (Vietnamese)';

  @override
  String get themeSystem => '系统颜色';

  @override
  String get themeSage => '默认';

  @override
  String get themeLight => '浅色模式';

  @override
  String get themeDark => '深色模式';
}
