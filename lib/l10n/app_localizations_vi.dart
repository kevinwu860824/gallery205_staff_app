// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get homeTitle => 'Gallery 20.5';

  @override
  String get loading => 'Đang tải...';

  @override
  String get homeOrder => 'Đặt món';

  @override
  String get homeCalendar => 'Lịch';

  @override
  String get homeShift => 'Ca làm việc';

  @override
  String get homePrep => 'Chuẩn bị';

  @override
  String get homeStock => 'Kho';

  @override
  String get homeClockIn => 'Chấm công';

  @override
  String get homeWorkReport => 'Báo cáo';

  @override
  String get homeBackhouse => 'Quản trị';

  @override
  String get homeDailyCost => 'Chi phí ngày';

  @override
  String get homeCashFlow => 'Dòng tiền';

  @override
  String get homeMonthlyCost => 'Chi phí tháng';

  @override
  String get homeSetting => 'Cài đặt';

  @override
  String get settingsTitle => 'Cài đặt';

  @override
  String get defaultUser => 'Người dùng';

  @override
  String get settingPrepInfo => 'Thông tin chuẩn bị';

  @override
  String get settingStock => 'Kho';

  @override
  String get settingStockLog => 'Nhật ký kho';

  @override
  String get settingTable => 'Bàn';

  @override
  String get settingTableMap => 'Sơ đồ bàn';

  @override
  String get settingMenu => 'Menu';

  @override
  String get settingPrinter => 'Máy in';

  @override
  String get settingClockInInfo => 'Thông tin chấm công';

  @override
  String get settingPayment => 'Thanh toán';

  @override
  String get settingCashbox => 'Két tiền';

  @override
  String get settingShift => 'Ca kíp';

  @override
  String get settingUserManagement => 'Quản lý người dùng';

  @override
  String get settingCostCategories => 'Danh mục chi phí';

  @override
  String get settingLanguage => 'Ngôn ngữ';

  @override
  String get settingChangePassword => 'Đổi mật khẩu';

  @override
  String get settingLogout => 'Đăng xuất';

  @override
  String get settingRoleManagement => 'Quản lý vai trò';

  @override
  String get loginTitle => 'Đăng nhập';

  @override
  String get loginShopIdHint => 'Chọn mã cửa hàng';

  @override
  String get loginEmailHint => 'Email';

  @override
  String get loginPasswordHint => 'Mật khẩu';

  @override
  String get loginButton => 'Đăng nhập';

  @override
  String get loginAddShopOption => '+ Thêm cửa hàng';

  @override
  String get loginAddShopDialogTitle => 'Thêm cửa hàng';

  @override
  String get loginAddShopDialogHint => 'Nhập mã mới';

  @override
  String get commonCancel => 'Hủy';

  @override
  String get commonAdd => 'Thêm';

  @override
  String get loginMsgFillAll => 'Vui lòng điền đầy đủ';

  @override
  String get loginMsgFaceIdFirst => 'Vui lòng đăng nhập bằng Email trước';

  @override
  String get loginMsgFaceIdReason => 'Vui lòng sử dụng Face ID';

  @override
  String get loginMsgNoSavedData => 'Không có dữ liệu lưu';

  @override
  String get loginMsgNoFaceIdData => 'Không tìm thấy dữ liệu Face ID';

  @override
  String get loginMsgShopNotFound => 'Không tìm thấy cửa hàng';

  @override
  String get loginMsgNoPermission => 'Bạn không có quyền truy cập';

  @override
  String get loginMsgFailed => 'Đăng nhập thất bại';

  @override
  String loginMsgFailedReason(Object error) {
    return 'Lỗi: $error';
  }

  @override
  String get scheduleTitle => 'Lịch làm việc';

  @override
  String get scheduleTabMy => 'Của tôi';

  @override
  String get scheduleTabAll => 'Tất cả';

  @override
  String get scheduleTabCustom => 'Tùy chỉnh';

  @override
  String get scheduleFilterTooltip => 'Lọc nhóm';

  @override
  String get scheduleSelectGroups => 'Chọn nhóm';

  @override
  String get scheduleSelectAll => 'Chọn tất cả';

  @override
  String get scheduleDeselectAll => 'Bỏ chọn tất cả';

  @override
  String get commonDone => 'Xong';

  @override
  String get schedulePersonalMe => 'Cá nhân';

  @override
  String get scheduleUntitled => 'Không tiêu đề';

  @override
  String get scheduleNoEvents => 'Không có sự kiện';

  @override
  String get scheduleAllDay => 'Cả ngày';

  @override
  String get scheduleDayLabel => 'Ngày';

  @override
  String get commonNoTitle => 'Không tiêu đề';

  @override
  String scheduleMoreEvents(Object count) {
    return '+$count thêm...';
  }

  @override
  String get commonToday => 'Hôm nay';

  @override
  String get calendarGroupsTitle => 'Nhóm lịch';

  @override
  String get calendarGroupPersonal => 'Cá nhân';

  @override
  String get calendarGroupUntitled => 'Không tiêu đề';

  @override
  String get calendarGroupPrivateDesc => 'Sự kiện riêng tư';

  @override
  String calendarGroupVisibleToMembers(Object count) {
    return 'Hiển thị cho $count thành viên';
  }

  @override
  String get calendarGroupNew => 'Nhóm mới';

  @override
  String get calendarGroupEdit => 'Sửa nhóm';

  @override
  String get calendarGroupName => 'TÊN NHÓM';

  @override
  String get calendarGroupNameHint => 'VD: Công việc, Họp';

  @override
  String get calendarGroupColor => 'MÀU NHÓM';

  @override
  String get calendarGroupEventColors => 'MÀU SỰ KIỆN';

  @override
  String get calendarGroupSaveFirstHint => 'Lưu nhóm trước để chỉnh màu.';

  @override
  String get calendarGroupVisibleTo => 'HIỂN THỊ VỚI';

  @override
  String get calendarGroupDelete => 'Xóa nhóm';

  @override
  String get calendarGroupDeleteConfirm => 'Xóa nhóm sẽ mất hết sự kiện. Bạn chắc chứ?';

  @override
  String get calendarColorNew => 'Màu mới';

  @override
  String get calendarColorEdit => 'Sửa màu';

  @override
  String get calendarColorName => 'TÊN MÀU';

  @override
  String get calendarColorNameHint => 'VD: Khẩn cấp';

  @override
  String get calendarColorPick => 'CHỌN MÀU';

  @override
  String get calendarColorDelete => 'Xóa màu';

  @override
  String get calendarColorDeleteConfirm => 'Xóa cài đặt màu này?';

  @override
  String get commonSave => 'Lưu';

  @override
  String get commonDelete => 'Xóa';

  @override
  String get notificationGroupInviteTitle => 'Lời mời nhóm';

  @override
  String notificationGroupInviteBody(Object groupName) {
    return 'Bạn đã được thêm vào nhóm: $groupName';
  }

  @override
  String get eventDetailTitleEdit => 'Sửa sự kiện';

  @override
  String get eventDetailTitleNew => 'Sự kiện mới';

  @override
  String get eventDetailLabelTitle => 'Tiêu đề';

  @override
  String get eventDetailLabelGroup => 'Nhóm';

  @override
  String get eventDetailLabelColor => 'Màu';

  @override
  String get eventDetailLabelAllDay => 'Cả ngày';

  @override
  String get eventDetailLabelStarts => 'Bắt đầu';

  @override
  String get eventDetailLabelEnds => 'Kết thúc';

  @override
  String get eventDetailLabelRepeat => 'Lặp lại';

  @override
  String get eventDetailLabelRelatedPeople => 'Người liên quan';

  @override
  String get eventDetailLabelNotes => 'Ghi chú';

  @override
  String get eventDetailDelete => 'Xóa sự kiện';

  @override
  String get eventDetailDeleteConfirm => 'Bạn có chắc muốn xóa?';

  @override
  String get eventDetailSelectGroup => 'Chọn nhóm';

  @override
  String get eventDetailSelectColor => 'Chọn màu';

  @override
  String get eventDetailGroupDefault => 'Mặc định';

  @override
  String get eventDetailCustomColor => 'Màu tùy chỉnh';

  @override
  String get eventDetailNoCustomColors => 'Chưa có màu tùy chỉnh.';

  @override
  String get eventDetailSelectPeople => 'Chọn người';

  @override
  String eventDetailPeopleCount(Object count) {
    return '$count người';
  }

  @override
  String get eventDetailNone => 'Không';

  @override
  String get eventDetailRepeatNone => 'Không lặp';

  @override
  String get eventDetailRepeatDaily => 'Hàng ngày';

  @override
  String get eventDetailRepeatWeekly => 'Hàng tuần';

  @override
  String get eventDetailRepeatMonthly => 'Hàng tháng';

  @override
  String get eventDetailErrorTitleRequired => 'Cần nhập tiêu đề';

  @override
  String get eventDetailErrorGroupRequired => 'Cần chọn nhóm';

  @override
  String get eventDetailErrorEndTime => 'Thời gian kết thúc không hợp lệ';

  @override
  String get eventDetailErrorSave => 'Lưu thất bại';

  @override
  String get eventDetailErrorDelete => 'Xóa thất bại';

  @override
  String notificationNewEventTitle(Object groupName) {
    return '[$groupName] Sự kiện mới';
  }

  @override
  String notificationNewEventBody(Object time, Object title, Object userName) {
    return '$userName đã thêm: $title ($time)';
  }

  @override
  String get notificationTimeChangeTitle => '⏰ [Cập nhật] Thay đổi giờ';

  @override
  String notificationTimeChangeBody(Object title, Object userName) {
    return '$userName đổi giờ của \"$title\".';
  }

  @override
  String get notificationContentChangeTitle => '✏️ [Cập nhật] Thay đổi nội dung';

  @override
  String notificationContentChangeBody(Object title, Object userName) {
    return '$userName cập nhật \"$title\".';
  }

  @override
  String get notificationDeleteTitle => '🗑️ [Hủy] Sự kiện bị xóa';

  @override
  String notificationDeleteBody(Object title, Object userName) {
    return '$userName hủy sự kiện: $title';
  }

  @override
  String get localNotificationTitle => '🔔 Nhắc nhở';

  @override
  String localNotificationBody(Object title) {
    return 'Trong 10 phút: $title';
  }

  @override
  String get commonSelect => 'Chọn...';

  @override
  String get commonUnknown => 'Không rõ';

  @override
  String get commonPersonalMe => 'Cá nhân';

  @override
  String get scheduleViewTitle => 'Lịch làm việc';

  @override
  String get scheduleViewModeMy => 'Ca của tôi';

  @override
  String get scheduleViewModeAll => 'Tất cả';

  @override
  String scheduleViewErrorInit(Object error) {
    return 'Lỗi tải dữ liệu: $error';
  }

  @override
  String scheduleViewErrorFetch(Object error) {
    return 'Lỗi tải lịch: $error';
  }

  @override
  String get scheduleViewUnknown => 'Không rõ';

  @override
  String get scheduleUploadTitle => 'Phân ca';

  @override
  String get scheduleUploadSelectEmployee => 'Chọn nhân viên';

  @override
  String get scheduleUploadSelectShiftFirst => 'Vui lòng chọn loại ca trước.';

  @override
  String get scheduleUploadUnsavedChanges => 'Chưa lưu thay đổi';

  @override
  String get scheduleUploadDiscardChangesMessage => 'Thay đổi chưa lưu sẽ bị mất. Tiếp tục?';

  @override
  String get scheduleUploadNoChanges => 'Không có thay đổi.';

  @override
  String get scheduleUploadSaveSuccess => 'Đã lưu lịch!';

  @override
  String scheduleUploadSaveError(Object error) {
    return 'Lỗi lưu: $error';
  }

  @override
  String scheduleUploadLoadError(Object error) {
    return 'Lỗi tải dữ liệu: $error';
  }

  @override
  String scheduleUploadLoadScheduleError(Object name) {
    return 'Lỗi tải lịch của $name';
  }

  @override
  String scheduleUploadRole(Object role) {
    return 'Vai trò: $role';
  }

  @override
  String get commonConfirm => 'Xác nhận';

  @override
  String get commonSaveChanges => 'Lưu thay đổi';

  @override
  String get prepViewTitle => 'Danh mục chuẩn bị';

  @override
  String get prepViewItemTitle => 'Mục chuẩn bị';

  @override
  String get prepViewItemUntitled => 'Không tên';

  @override
  String get prepViewMainIngredients => 'Nguyên liệu chính';

  @override
  String prepViewNote(Object note) {
    return 'Ghi chú: $note';
  }

  @override
  String get prepViewDetailLabel => 'Chi tiết';

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
  String get inventoryViewTitle => 'Tổng quan kho';

  @override
  String get inventorySearchHint => 'Tìm kiếm';

  @override
  String get inventoryNoItems => 'Không tìm thấy';

  @override
  String inventorySafetyQuantity(Object quantity) {
    return 'Mức an toàn: $quantity';
  }

  @override
  String get inventoryConfirmUpdateTitle => 'Xác nhận cập nhật';

  @override
  String inventoryConfirmUpdateOriginal(Object unit, Object value) {
    return 'Ban đầu: $value $unit';
  }

  @override
  String inventoryConfirmUpdateNew(Object unit, Object value) {
    return 'Mới: $value $unit';
  }

  @override
  String inventoryConfirmUpdateChange(Object value) {
    return 'Thay đổi: $value';
  }

  @override
  String get inventoryUnsavedTitle => 'Chưa lưu';

  @override
  String get inventoryUnsavedContent => 'Có thay đổi tồn kho chưa lưu. Lưu và thoát?';

  @override
  String get inventoryUnsavedDiscard => 'Hủy & Thoát';

  @override
  String inventoryUpdateSuccess(Object name) {
    return '✅ Đã cập nhật kho $name!';
  }

  @override
  String get inventoryUpdateFailedTitle => 'Cập nhật thất bại';

  @override
  String get inventoryUpdateFailedMsg => 'Lỗi cơ sở dữ liệu.';

  @override
  String get inventoryBatchSaveFailedTitle => 'Lỗi lưu hàng loạt';

  @override
  String inventoryBatchSaveFailedMsg(Object name) {
    return 'Mục $name lưu thất bại.';
  }

  @override
  String get inventoryReasonStockIn => 'Nhập kho';

  @override
  String get inventoryReasonAudit => 'Kiểm kê';

  @override
  String get inventoryErrorTitle => 'Lỗi';

  @override
  String get inventoryErrorInvalidNumber => 'Nhập số hợp lệ';

  @override
  String get commonOk => 'OK';

  @override
  String get punchTitle => 'Chấm công';

  @override
  String get punchInButton => 'Vào ca';

  @override
  String get punchOutButton => 'Ra ca';

  @override
  String get punchMakeUpButton => 'Bổ sung\nChấm công';

  @override
  String get punchLocDisabled => 'Định vị bị tắt.';

  @override
  String get punchLocDenied => 'Từ chối quyền định vị';

  @override
  String get punchLocDeniedForever => 'Quyền định vị bị chặn vĩnh viễn.';

  @override
  String get punchErrorSettingsNotFound => 'Chưa cài đặt chấm công.';

  @override
  String punchErrorWifi(Object wifi) {
    return 'Sai Wi-Fi.\nVui lòng kết nối: $wifi';
  }

  @override
  String get punchErrorDistance => 'Bạn ở quá xa cửa hàng.';

  @override
  String get punchErrorAlreadyIn => 'Bạn đã vào ca rồi.';

  @override
  String get punchSuccessInTitle => 'Vào ca thành công';

  @override
  String get punchSuccessInMsg => 'Chúc một ngày làm việc vui vẻ : )';

  @override
  String get punchErrorInTitle => 'Vào ca thất bại';

  @override
  String get punchErrorNoSession => 'Không tìm thấy phiên làm việc.';

  @override
  String get punchErrorOverTime => 'Quá 12 giờ. Vui lòng dùng \'Bổ sung\'.';

  @override
  String get punchSuccessOutTitle => 'Ra ca thành công';

  @override
  String get punchSuccessOutMsg => 'Vất vả rồi ❤️';

  @override
  String get punchErrorOutTitle => 'Ra ca thất bại';

  @override
  String punchErrorGeneric(Object error) {
    return 'Lỗi: $error';
  }

  @override
  String get punchMakeUpTitle => 'Bổ sung Chấm công';

  @override
  String get punchMakeUpTypeIn => 'Bổ sung Vào ca';

  @override
  String get punchMakeUpTypeOut => 'Bổ sung Ra ca';

  @override
  String get punchMakeUpReasonHint => 'Lý do (Bắt buộc)';

  @override
  String get punchMakeUpErrorReason => 'Vui lòng nhập lý do';

  @override
  String get punchMakeUpErrorFuture => 'Không thể chọn giờ tương lai';

  @override
  String get punchMakeUpError72h => 'Quá hạn 72h. Liên hệ quản lý.';

  @override
  String punchMakeUpErrorOverlap(Object time) {
    return 'Trùng giờ làm việc. Vui lòng ra ca trước.';
  }

  @override
  String get punchMakeUpErrorNoRecord => 'Không tìm thấy dữ liệu khớp.';

  @override
  String get punchMakeUpErrorOver12h => 'Ca làm việc quá 12h.';

  @override
  String get punchMakeUpSuccessTitle => 'Thành công';

  @override
  String get punchMakeUpSuccessMsg => 'Đã bổ sung chấm công';

  @override
  String get punchMakeUpCheckInfo => 'Kiểm tra thông tin';

  @override
  String punchMakeUpLabelType(Object type) {
    return 'Loại: $type';
  }

  @override
  String punchMakeUpLabelTime(Object time) {
    return 'Giờ: $time';
  }

  @override
  String punchMakeUpLabelReason(Object reason) {
    return 'Lý do: $reason';
  }

  @override
  String get commonDate => 'Ngày';

  @override
  String get commonTime => 'Giờ';

  @override
  String get workReportTitle => 'Báo cáo công việc';

  @override
  String get workReportSelectDate => 'Chọn ngày';

  @override
  String get workReportJobSubject => 'Chủ đề (Bắt buộc)';

  @override
  String get workReportJobDescription => 'Mô tả (Bắt buộc)';

  @override
  String get workReportOverTime => 'Giờ làm thêm (Tùy chọn)';

  @override
  String get workReportHourUnit => 'giờ';

  @override
  String get workReportErrorRequiredTitle => 'Thiếu thông tin';

  @override
  String get workReportErrorRequiredMsg => 'Cần nhập Chủ đề và Mô tả!';

  @override
  String get workReportConfirmOverwriteTitle => 'Báo cáo đã tồn tại';

  @override
  String get workReportConfirmOverwriteMsg => 'Bạn muốn ghi đè báo cáo cũ?';

  @override
  String get workReportOverwriteYes => 'Có';

  @override
  String get workReportSuccessTitle => 'Thành công';

  @override
  String get workReportSuccessMsg => 'Báo cáo đã gửi!';

  @override
  String get workReportSubmitFailed => 'Gửi thất bại';

  @override
  String get todoScreenTitle => 'Việc cần làm';

  @override
  String get todoTabIncomplete => 'Chưa xong';

  @override
  String get todoTabPending => 'Chờ duyệt';

  @override
  String get todoTabCompleted => 'Đã xong';

  @override
  String get todoFilterMyTasks => 'Việc của tôi';

  @override
  String todoCountSuffix(Object count) {
    return '$count mục';
  }

  @override
  String get todoEmptyPending => 'Không có việc chờ duyệt';

  @override
  String get todoEmptyIncomplete => 'Không có việc chưa xong';

  @override
  String get todoEmptyCompleted => 'Chưa có việc hoàn thành';

  @override
  String get todoSubmitReviewTitle => 'Gửi duyệt';

  @override
  String get todoSubmitReviewContent => 'Bạn đã xong việc và muốn gửi duyệt?';

  @override
  String get todoSubmitButton => 'Gửi';

  @override
  String get todoApproveTitle => 'Duyệt';

  @override
  String get todoApproveContent => 'Xác nhận hoàn thành?';

  @override
  String get todoApproveButton => 'Duyệt';

  @override
  String get todoRejectTitle => 'Từ chối';

  @override
  String get todoRejectContent => 'Trả lại việc để làm lại?';

  @override
  String get todoRejectButton => 'Trả lại';

  @override
  String get todoDeleteTitle => 'Xóa việc';

  @override
  String get todoDeleteContent => 'Hành động này không thể hoàn tác.';

  @override
  String get todoErrorNoPermissionSubmit => 'Bạn không có quyền gửi.';

  @override
  String get todoErrorNoPermissionApprove => 'Chỉ người giao việc mới được duyệt.';

  @override
  String get todoErrorNoPermissionReject => 'Chỉ người giao việc mới được từ chối.';

  @override
  String get todoErrorNoPermissionEdit => 'Chỉ người giao việc mới được sửa.';

  @override
  String get todoErrorNoPermissionDelete => 'Chỉ người giao việc mới được xóa.';

  @override
  String get notificationTodoReviewTitle => '👀 Việc cần duyệt';

  @override
  String notificationTodoReviewBody(Object name, Object task) {
    return '$name đã gửi: $task';
  }

  @override
  String get notificationTodoApprovedTitle => '✅ Việc được duyệt';

  @override
  String notificationTodoApprovedBody(Object task) {
    return 'Đã duyệt: $task';
  }

  @override
  String get notificationTodoRejectedTitle => '↩️ Việc bị trả lại';

  @override
  String notificationTodoRejectedBody(Object task) {
    return 'Cần làm lại: $task';
  }

  @override
  String get notificationTodoDeletedTitle => '🗑️ Việc bị xóa';

  @override
  String notificationTodoDeletedBody(Object task) {
    return 'Đã xóa: $task';
  }

  @override
  String todoActionSheetTitle(Object title) {
    return 'Hành động: $title';
  }

  @override
  String get todoActionCompleteAndSubmit => 'Hoàn thành & Gửi';

  @override
  String todoReviewSheetTitle(Object title) {
    return 'Duyệt: $title';
  }

  @override
  String get todoReviewSheetMessageAssigner => 'Vui lòng xác nhận kết quả.';

  @override
  String get todoReviewSheetMessageAssignee => 'Đang chờ duyệt.';

  @override
  String get todoActionApprove => '✅ Duyệt';

  @override
  String get todoActionReject => '↩️ Trả lại';

  @override
  String get todoActionViewDetails => 'Xem chi tiết';

  @override
  String get todoLabelTo => 'Đến: ';

  @override
  String get todoLabelFrom => 'Từ: ';

  @override
  String get todoUnassigned => 'Chưa giao';

  @override
  String get todoLabelCompletedAt => 'Xong lúc: ';

  @override
  String get todoLabelWaitingReview => 'Chờ duyệt';

  @override
  String get commonEdit => 'Sửa';

  @override
  String get todoAddTaskTitleNew => 'Việc mới';

  @override
  String get todoAddTaskTitleEdit => 'Sửa việc';

  @override
  String get todoAddTaskLabelTitle => 'Tiêu đề';

  @override
  String get todoAddTaskLabelDesc => 'Mô tả (Tùy chọn)';

  @override
  String get todoAddTaskLabelAssign => 'Giao cho:';

  @override
  String get todoAddTaskSelectStaff => 'Chọn nhân viên';

  @override
  String todoAddTaskSelectedStaff(Object count) {
    return 'Đã chọn $count';
  }

  @override
  String get todoAddTaskSetDueDate => 'Hạn ngày';

  @override
  String get todoAddTaskSelectDate => 'Chọn ngày';

  @override
  String get todoAddTaskSetDueTime => 'Hạn giờ';

  @override
  String get todoAddTaskSelectTime => 'Chọn giờ';

  @override
  String get notificationTodoEditTitle => '✏️ Cập nhật việc';

  @override
  String notificationTodoEditBody(Object task) {
    return 'Cập nhật: $task';
  }

  @override
  String get notificationTodoUrgentUpdate => '🔥 Cập nhật khẩn';

  @override
  String get notificationTodoNewTitle => '📝 Việc mới';

  @override
  String notificationTodoNewBody(Object task) {
    return '$task';
  }

  @override
  String get notificationTodoUrgentNew => '🔥 Việc khẩn cấp';

  @override
  String get costInputTitle => 'Chi phí hàng ngày';

  @override
  String get costInputTotalToday => 'Tổng chi hôm nay';

  @override
  String get costInputLabelName => 'Tên';

  @override
  String get costInputLabelPrice => 'Giá';

  @override
  String get costInputTabNotOpenTitle => 'Chưa mở sổ';

  @override
  String get costInputTabNotOpenMsg => 'Vui lòng mở sổ hôm nay trước.';

  @override
  String get costInputTabNotOpenPageTitle => 'Vui lòng mở sổ hôm nay';

  @override
  String get costInputTabNotOpenPageDesc => 'Bạn cần mở sổ trước khi nhập chi phí.';

  @override
  String get costInputButtonOpenTab => 'Đi mở sổ';

  @override
  String get costInputErrorInputTitle => 'Lỗi nhập liệu';

  @override
  String get costInputErrorInputMsg => 'Kiểm tra tên và giá.';

  @override
  String get costInputSuccess => '✅ Đã lưu chi phí';

  @override
  String get costInputSaveFailed => 'Lưu thất bại';

  @override
  String get costInputLoadingCategories => 'Đang tải...';

  @override
  String get costDetailTitle => 'Chi tiết chi phí';

  @override
  String get costDetailNoRecords => 'Không có dữ liệu.';

  @override
  String get costDetailItemUntitled => 'Khoản không tên';

  @override
  String get costDetailCategoryNA => 'N/A';

  @override
  String get costDetailBuyerNA => 'N/A';

  @override
  String costDetailLabelCategory(Object category) {
    return 'Mục: $category';
  }

  @override
  String costDetailLabelBuyer(Object buyer) {
    return 'Người mua: $buyer';
  }

  @override
  String get costDetailEditTitle => 'Sửa chi phí';

  @override
  String get costDetailDeleteTitle => 'Xóa chi phí';

  @override
  String costDetailDeleteContent(Object name) {
    return 'Xóa khoan chi này?\n($name)';
  }

  @override
  String get costDetailErrorUpdate => 'Cập nhật lỗi';

  @override
  String get costDetailErrorDelete => 'Xóa lỗi';

  @override
  String get cashSettlementDeposits => 'Tiền gửi';

  @override
  String get cashSettlementExpectedCash => 'Tiền dự kiến';

  @override
  String get cashSettlementDifference => 'Chênh lệch';

  @override
  String get cashSettlementConfirmTitle => 'Xác nhận chốt';

  @override
  String get commonSubmit => 'Gửi';

  @override
  String get cashSettlementDepositSheetTitle => 'Phiếu tiền gửi';

  @override
  String get cashSettlementDepositNew => 'Khoản gửi mới';

  @override
  String get cashSettlementNewDepositTitle => 'Khoản gửi mới';

  @override
  String get commonName => 'Tên';

  @override
  String get commonPhone => 'SĐT';

  @override
  String get commonAmount => 'Số tiền';

  @override
  String get commonNotes => 'Ghi chú';

  @override
  String get cashSettlementDepositAddSuccess => 'Thêm thành công';

  @override
  String get cashSettlementSelectRedeemedDeposit => 'Chọn tiền cọc đã dùng';

  @override
  String get commonNoData => 'Không dữ liệu';

  @override
  String get cashSettlementTitleOpen => 'Mở đầu ca';

  @override
  String get cashSettlementTitleClose => 'Chốt cuối ca';

  @override
  String get cashSettlementTitleLoading => 'Đang tải...';

  @override
  String get cashSettlementOpenDesc => 'Vui lòng kiểm tra số lượng tiền và tổng tiền khớp với dự kiến.';

  @override
  String get cashSettlementTargetAmount => 'Mục tiêu:';

  @override
  String get cashSettlementTotal => 'Tổng:';

  @override
  String get cashSettlementRevenueAndPayment => 'Doanh thu & Thanh toán';

  @override
  String get cashSettlementRevenueHint => 'Tổng doanh thu';

  @override
  String cashSettlementDepositButton(Object amount) {
    return 'Tiền cọc hôm nay (Chọn: \$$amount)';
  }

  @override
  String get cashSettlementReceivableCash => 'Tiền mặt phải thu:';

  @override
  String get cashSettlementCashCountingTitle => 'Đếm tiền\n(Nhập số tờ thực tế)';

  @override
  String get cashSettlementTotalCashCounted => 'Tổng đếm:';

  @override
  String get cashSettlementReviewTitle => 'Kiểm tra lại';

  @override
  String get cashSettlementOpeningCash => 'Tiền đầu ca';

  @override
  String get cashSettlementDailyCosts => 'Chi phí ngày';

  @override
  String get cashSettlementRedeemedDeposit => 'Cọc đã dùng';

  @override
  String get cashSettlementTotalExpectedCash => 'Tổng tiền dự kiến';

  @override
  String get cashSettlementTodaysCashCount => 'Tiền đếm được';

  @override
  String get cashSettlementSummary => 'Tổng kết:';

  @override
  String get cashSettlementErrorCountMismatch => 'Số tiền không khớp mục tiêu!';

  @override
  String get cashSettlementOpenSuccessTitle => 'Mở thành công';

  @override
  String cashSettlementOpenSuccessMsg(Object count) {
    return 'Đã mở ca $count!';
  }

  @override
  String get cashSettlementOpenFailedTitle => 'Mở thất bại';

  @override
  String get cashSettlementCloseSuccessTitle => 'Đã chốt ca & Lưu';

  @override
  String get cashSettlementCloseSuccessMsg => 'Sếp yêu bạn ❤️';

  @override
  String get cashSettlementCloseFailedTitle => 'Chốt thất bại';

  @override
  String get cashSettlementErrorInputRevenue => 'Vui lòng nhập doanh thu.';

  @override
  String get cashSettlementDepositTitle => 'Quản lý cọc';

  @override
  String get cashSettlementDepositAdd => 'Thêm cọc';

  @override
  String get cashSettlementDepositEdit => 'Sửa cọc';

  @override
  String get cashSettlementDepositRedeemTitle => 'Dùng cọc hôm nay';

  @override
  String get cashSettlementDepositNoUnredeemed => 'Không có cọc chưa dùng';

  @override
  String cashSettlementDepositTotalRedeemed(Object amount) {
    return 'Đã dùng: \$$amount';
  }

  @override
  String get cashSettlementDepositAddTitle => 'Thêm cọc';

  @override
  String get cashSettlementDepositEditTitle => 'Sửa cọc';

  @override
  String get cashSettlementDepositPaymentDate => 'Ngày thanh toán';

  @override
  String get cashSettlementDepositReservationDate => 'Ngày đặt';

  @override
  String get cashSettlementDepositReservationTime => 'Giờ đặt';

  @override
  String get cashSettlementDepositName => 'Tên';

  @override
  String get cashSettlementDepositPax => 'Số khách';

  @override
  String get cashSettlementDepositAmount => 'Số tiền';

  @override
  String get cashSettlementErrorInputDates => 'Chọn ngày giờ đầy đủ.';

  @override
  String get cashSettlementErrorInputAmount => 'Nhập tên và số tiền.';

  @override
  String get cashSettlementErrorTimePast => 'Không thể chọn giờ quá khứ';

  @override
  String get cashSettlementSaveFailed => 'Lưu thất bại';

  @override
  String get depositScreenTitle => 'Quản lý đặt cọc';

  @override
  String get depositScreenNoRecords => 'Không có cọc';

  @override
  String depositScreenLabelName(Object name) {
    return 'Tên: $name';
  }

  @override
  String depositScreenLabelReservationDate(Object date) {
    return 'Ngày đặt: $date';
  }

  @override
  String depositScreenLabelReservationTime(Object time) {
    return 'Giờ đặt: $time';
  }

  @override
  String depositScreenLabelGroupSize(Object size) {
    return 'Khách: $size';
  }

  @override
  String get depositScreenDeleteConfirm => 'Xóa cọc';

  @override
  String get depositScreenDeleteContent => 'Bạn muốn xóa khoản cọc này?';

  @override
  String get depositScreenDeleteSuccess => 'Đã xóa';

  @override
  String depositScreenDeleteFailed(Object error) {
    return 'Xóa lỗi: $error';
  }

  @override
  String depositScreenSaveFailed(Object error) {
    return 'Lưu lỗi: $error';
  }

  @override
  String get depositScreenInputError => 'Thiếu thông tin.';

  @override
  String get depositScreenTimeError => 'Giờ không hợp lệ.';

  @override
  String get depositDialogTitleAdd => 'Thêm cọc';

  @override
  String get depositDialogTitleEdit => 'Sửa cọc';

  @override
  String get depositDialogHintPaymentDate => 'Ngày thanh toán';

  @override
  String get depositDialogHintReservationDate => 'Ngày đặt';

  @override
  String get depositDialogHintReservationTime => 'Giờ đặt';

  @override
  String get depositDialogHintName => 'Tên';

  @override
  String get depositDialogHintGroupSize => 'Số khách';

  @override
  String get depositDialogHintAmount => 'Số tiền';

  @override
  String get monthlyCostTitle => 'Chi phí tháng';

  @override
  String get monthlyCostTotal => 'Tổng chi tháng này';

  @override
  String get monthlyCostLabelName => 'Tên';

  @override
  String get monthlyCostLabelPrice => 'Giá';

  @override
  String get monthlyCostLabelNote => 'Ghi chú';

  @override
  String get monthlyCostErrorInputTitle => 'Lỗi';

  @override
  String get monthlyCostErrorInputMsg => 'Cần Tên và Giá.';

  @override
  String get monthlyCostErrorSaveFailed => 'Lưu thất bại';

  @override
  String get monthlyCostSuccess => 'Đã lưu';

  @override
  String get monthlyCostDetailTitle => 'Chi tiết tháng';

  @override
  String get monthlyCostDetailNoRecords => 'Không có dữ liệu.';

  @override
  String get monthlyCostDetailItemUntitled => 'Không tên';

  @override
  String get monthlyCostDetailCategoryNA => 'N/A';

  @override
  String get monthlyCostDetailBuyerNA => 'N/A';

  @override
  String monthlyCostDetailLabelCategory(Object category) {
    return 'Mục: $category';
  }

  @override
  String monthlyCostDetailLabelDate(Object date) {
    return 'Ngày: $date';
  }

  @override
  String monthlyCostDetailLabelBuyer(Object buyer) {
    return 'Người mua: $buyer';
  }

  @override
  String get monthlyCostDetailEditTitle => 'Sửa chi phí';

  @override
  String get monthlyCostDetailDeleteTitle => 'Xóa chi phí';

  @override
  String monthlyCostDetailDeleteContent(Object name) {
    return 'Xóa mục này?\n($name)';
  }

  @override
  String monthlyCostDetailErrorFetch(Object error) {
    return 'Lỗi tải: $error';
  }

  @override
  String get monthlyCostDetailErrorUpdate => 'Cập nhật lỗi';

  @override
  String get monthlyCostDetailErrorDelete => 'Xóa lỗi';

  @override
  String get cashFlowTitle => 'Báo cáo dòng tiền';

  @override
  String get cashFlowMonthlyRevenue => 'Doanh thu tháng';

  @override
  String get cashFlowMonthlyDifference => 'Chênh lệch tiền';

  @override
  String cashFlowLabelShift(Object count) {
    return 'Ca $count';
  }

  @override
  String get cashFlowLabelRevenue => 'Doanh thu:';

  @override
  String get cashFlowLabelCost => 'Chi phí:';

  @override
  String get cashFlowLabelDifference => 'Chênh lệch:';

  @override
  String get cashFlowNoRecords => 'Không dữ liệu.';

  @override
  String get costReportTitle => 'Tổng hợp chi phí';

  @override
  String get costReportMonthlyTotal => 'Tổng chi tháng';

  @override
  String get costReportNoRecords => 'Không dữ liệu.';

  @override
  String get costReportNoRecordsShift => 'Ca này không có chi phí.';

  @override
  String get costReportLabelTotalCost => 'Tổng chi:';

  @override
  String get dashboardTitle => 'Bảng điều khiển';

  @override
  String get dashboardTotalRevenue => 'Tổng doanh thu';

  @override
  String get dashboardCogs => 'Giá vốn';

  @override
  String get dashboardGrossProfit => 'Lợi nhuận gộp';

  @override
  String get dashboardGrossMargin => 'Biên LN gộp';

  @override
  String get dashboardOpex => 'Chi phí vận hành';

  @override
  String get dashboardOpIncome => 'Thu nhập vận hành';

  @override
  String get dashboardNetIncome => 'Thu nhập ròng';

  @override
  String get dashboardNetProfitMargin => 'Biên LN ròng';

  @override
  String get dashboardNoCostData => 'Thiếu dữ liệu chi phí';

  @override
  String dashboardErrorLoad(Object error) {
    return 'Lỗi: $error';
  }

  @override
  String get reportingTitle => 'Hậu cần';

  @override
  String get reportingCashFlow => 'Dòng tiền';

  @override
  String get reportingCostSum => 'Tổng chi phí';

  @override
  String get reportingDashboard => 'Dashboard';

  @override
  String get reportingCashVault => 'Két sắt';

  @override
  String get reportingClockIn => 'Chấm công';

  @override
  String get reportingWorkReport => 'Báo cáo';

  @override
  String get reportingNoAccess => 'Không có quyền truy cập';

  @override
  String get vaultTitle => 'Dòng tiền';

  @override
  String get vaultTotalCash => 'Tổng tiền';

  @override
  String get vaultTitleVault => 'Két sắt';

  @override
  String get vaultTitleCashbox => 'Két thu ngân';

  @override
  String get vaultCashDetail => 'Chi tiết tiền';

  @override
  String vaultDetailDenom(Object cashboxCount, Object totalCount, Object vaultCount) {
    return '\$ $cashboxCount X $totalCount (Két $cashboxCount + Thu ngân $vaultCount)';
  }

  @override
  String get vaultActivityHistory => 'Lịch sử';

  @override
  String get vaultTableDate => 'Ngày';

  @override
  String get vaultTableStaff => 'Nhân viên';

  @override
  String get vaultNoRecords => 'Không có lịch sử.';

  @override
  String get vaultManagementSheetTitle => 'Quản lý két';

  @override
  String get vaultAdjustCounts => 'Điều chỉnh số lượng';

  @override
  String get vaultSaveMoney => 'Cất tiền (Gửi)';

  @override
  String get vaultChangeMoney => 'Đổi tiền';

  @override
  String get vaultPromptAdjust => 'Nhập TỔNG số tờ (Két + Thu ngân).';

  @override
  String get vaultPromptDeposit => 'Nhập số tiền gửi';

  @override
  String get vaultPromptChangeOut => 'Lấy tiền LỚN ra';

  @override
  String get vaultPromptChangeIn => 'Bỏ tiền NHỎ vào';

  @override
  String get vaultErrorMismatch => 'Số tiền không khớp!';

  @override
  String vaultDialogTotal(Object amount) {
    return 'Tổng: $amount';
  }

  @override
  String get clockInReportTitle => 'Báo cáo chấm công';

  @override
  String get clockInReportTotalHours => 'Tổng giờ';

  @override
  String get clockInReportStaffCount => 'Nhân sự';

  @override
  String get clockInReportWorkDays => 'Ngày làm';

  @override
  String get clockInReportUnitPpl => 'người';

  @override
  String get clockInReportUnitDays => 'ngày';

  @override
  String get clockInReportUnitHr => 'giờ';

  @override
  String get clockInReportNoRecords => 'Không dữ liệu.';

  @override
  String get clockInReportLabelManual => 'Thủ công';

  @override
  String get clockInReportLabelIn => 'Vào';

  @override
  String get clockInReportLabelOut => 'Ra';

  @override
  String get clockInReportStatusWorking => 'Đang làm';

  @override
  String get clockInReportStatusCompleted => 'Hoàn thành';

  @override
  String get clockInReportStatusIncomplete => 'Chưa xong';

  @override
  String get clockInReportAllStaff => 'Tất cả';

  @override
  String get clockInReportSelectStaff => 'Chọn nhân viên';

  @override
  String get clockInDetailTitleIn => 'Vào ca';

  @override
  String get clockInDetailTitleOut => 'Ra ca';

  @override
  String get clockInDetailMissing => 'Thiếu dữ liệu';

  @override
  String get clockInDetailFixButton => 'Sửa giờ ra';

  @override
  String get clockInDetailCloseButton => 'Đóng';

  @override
  String clockInDetailLabelWifi(Object wifi) {
    return 'WiFi: $wifi';
  }

  @override
  String clockInDetailLabelReason(Object reason) {
    return 'Lý do: $reason';
  }

  @override
  String get clockInDetailReasonSupervisorFix => 'Quản lý sửa';

  @override
  String get clockInDetailErrorInLaterThanOut => 'Giờ Vào không thể sau giờ Ra.';

  @override
  String get clockInDetailErrorOutEarlierThanIn => 'Giờ Ra không thể trước giờ Vào.';

  @override
  String get clockInDetailErrorDateCheck => 'Lỗi ngày tháng.';

  @override
  String get clockInDetailSuccessUpdate => 'Cập nhật thành công.';

  @override
  String get clockInDetailSelectDate => 'Chọn ngày Ra';

  @override
  String get commonNone => 'Không';

  @override
  String get workReportOverviewTitle => 'Báo cáo công việc';

  @override
  String get workReportOverviewNoRecords => 'Không có báo cáo.';

  @override
  String get workReportOverviewSelectStaff => 'Chọn nhân viên';

  @override
  String get workReportOverviewAllStaff => 'Tất cả';

  @override
  String get workReportOverviewNoSubject => 'Không chủ đề';

  @override
  String get workReportOverviewNoContent => 'Không nội dung';

  @override
  String workReportOverviewOvertimeTag(Object hours) {
    return 'OT: ${hours}h';
  }

  @override
  String workReportDetailOvertimeLabel(Object hours) {
    return 'Làm thêm: $hours giờ';
  }

  @override
  String get commonClose => 'Đóng';

  @override
  String get userMgmtTitle => 'Quản lý người dùng';

  @override
  String get userMgmtInviteNewUser => 'Mời người mới';

  @override
  String get userMgmtStatusInvited => 'Đã mời';

  @override
  String get userMgmtStatusWaiting => 'Đang chờ...';

  @override
  String userMgmtLabelRole(Object roleName) {
    return 'Vai trò: $roleName';
  }

  @override
  String get userMgmtNameHint => 'Tên';

  @override
  String get userMgmtInviteNote => 'Người dùng sẽ nhận email mời.';

  @override
  String get userMgmtInviteButton => 'Gửi lời mời';

  @override
  String get userMgmtEditTitle => 'Sửa người dùng';

  @override
  String get userMgmtDeleteTitle => 'Xóa người dùng';

  @override
  String userMgmtDeleteContent(Object userName) {
    return 'Xóa tài khoản $userName?';
  }

  @override
  String userMgmtErrorLoad(Object error) {
    return 'Lỗi tải: $error';
  }

  @override
  String get userMgmtInviteSuccess => 'Đã gửi lời mời!';

  @override
  String userMgmtInviteFailed(Object error) {
    return 'Mời thất bại: $error';
  }

  @override
  String userMgmtErrorConnection(Object error) {
    return 'Lỗi kết nối: $error';
  }

  @override
  String userMgmtDeleteFailed(Object error) {
    return 'Xóa thất bại: $error';
  }

  @override
  String get userMgmtLabelEmail => 'Email';

  @override
  String get userMgmtLabelRolePicker => 'Vai trò';

  @override
  String get userMgmtButtonDone => 'Xong';

  @override
  String get userMgmtLabelRoleSelect => 'Chọn';

  @override
  String get roleMgmtTitle => 'Quản lý vai trò';

  @override
  String get roleMgmtSystemDefault => 'Mặc định hệ thống';

  @override
  String roleMgmtPermissionGroupTitle(Object groupName) {
    return 'Quyền - $groupName';
  }

  @override
  String get roleMgmtRoleNameHint => 'Tên vai trò';

  @override
  String get roleMgmtSaveButton => 'Lưu';

  @override
  String get roleMgmtDeleteRole => 'Xóa vai trò';

  @override
  String get roleMgmtAddNewRole => 'Thêm vai trò mới';

  @override
  String get roleMgmtEnterRoleName => 'Nhập tên vai trò (VD: Phục vụ)';

  @override
  String get roleMgmtCreateButton => 'Tạo';

  @override
  String get roleMgmtDeleteConfirmTitle => 'Xóa vai trò';

  @override
  String get roleMgmtDeleteConfirmContent => 'Bạn chắc muốn xóa vai trò này?';

  @override
  String get roleMgmtCannotDeleteTitle => 'Không thể xóa';

  @override
  String roleMgmtCannotDeleteContent(Object count, Object roleName) {
    return 'Vẫn còn $count người dùng thuộc vai trò \"$roleName\".\n\nHãy chuyển họ sang vai trò khác trước.';
  }

  @override
  String get roleMgmtUnderstandButton => 'Đã hiểu';

  @override
  String roleMgmtErrorLoad(Object error) {
    return 'Lỗi tải: $error';
  }

  @override
  String roleMgmtErrorSave(Object error) {
    return 'Lỗi lưu: $error';
  }

  @override
  String roleMgmtErrorAdd(Object error) {
    return 'Lỗi thêm: $error';
  }

  @override
  String get commonNotificationTitle => 'Thông báo';

  @override
  String get permGroupMainScreen => 'Màn hình chính';

  @override
  String get permGroupSchedule => 'Lịch làm việc';

  @override
  String get permGroupBackstageDashboard => 'Dashboard Hậu cần';

  @override
  String get permGroupSettings => 'Cài đặt';

  @override
  String get permHomeOrder => 'Nhận đơn';

  @override
  String get permHomePrep => 'Chuẩn bị';

  @override
  String get permHomeStock => 'Kho';

  @override
  String get permHomeBackDashboard => 'Dashboard Hậu cần';

  @override
  String get permHomeDailyCost => 'Nhập chi phí ngày';

  @override
  String get permHomeCashFlow => 'Báo cáo dòng tiền';

  @override
  String get permHomeMonthlyCost => 'Nhập chi phí tháng';

  @override
  String get permHomeScan => 'Quét thông minh';

  @override
  String get permScheduleEdit => 'Sửa lịch nhân viên';

  @override
  String get permBackCashFlow => 'Báo cáo dòng tiền';

  @override
  String get permBackCostSum => 'Tổng hợp chi phí';

  @override
  String get permBackDashboard => 'Bảng điều khiển';

  @override
  String get permBackCashVault => 'Quản lý két sắt';

  @override
  String get permBackClockIn => 'Báo cáo chấm công';

  @override
  String get permBackViewAllClockIn => 'Xem tất cả chấm công';

  @override
  String get permBackWorkReport => 'Tổng quan báo cáo';

  @override
  String get permSetStaff => 'Quản lý nhân sự';

  @override
  String get permSetRole => 'Quản lý vai trò';

  @override
  String get permSetPrinter => 'Cài đặt máy in';

  @override
  String get permSetTableMap => 'Quản lý sơ đồ bàn';

  @override
  String get permSetTableList => 'Danh sách bàn';

  @override
  String get permSetMenu => 'Sửa Menu';

  @override
  String get permSetShift => 'Cài đặt ca';

  @override
  String get permSetPunch => 'Cài đặt chấm công';

  @override
  String get permSetPay => 'Phương thức thanh toán';

  @override
  String get permSetCostCat => 'Danh mục chi phí';

  @override
  String get permSetInv => 'Kho & Sản phẩm';

  @override
  String get permSetCashReg => 'Cài đặt két tiền';

  @override
  String get stockCategoryTitle => 'Chi tiết chuẩn bị';

  @override
  String get stockCategoryAddButton => '＋ Thêm danh mục';

  @override
  String get stockCategoryAddDialogTitle => 'Thêm danh mục';

  @override
  String get stockCategoryEditDialogTitle => 'Sửa danh mục';

  @override
  String get stockCategoryHintName => 'Tên danh mục';

  @override
  String get stockCategoryDeleteTitle => 'Xóa danh mục';

  @override
  String stockCategoryDeleteContent(Object categoryName) {
    return 'Xóa danh mục: $categoryName?';
  }

  @override
  String get inventoryCategoryTitle => 'Chỉnh sửa kho';

  @override
  String get inventoryManagementTitle => 'Quản lý kho';

  @override
  String get inventoryCategoryDetailTitle => 'Danh sách sản phẩm';

  @override
  String get inventoryCategoryAddButton => '＋ Thêm danh mục';

  @override
  String get inventoryCategoryAddDialogTitle => 'Thêm danh mục';

  @override
  String get inventoryCategoryEditDialogTitle => 'Sửa danh mục';

  @override
  String get inventoryCategoryHintName => 'Tên danh mục';

  @override
  String get inventoryCategoryDeleteTitle => 'Xóa danh mục';

  @override
  String inventoryCategoryDeleteContent(Object categoryName) {
    return 'Xóa danh mục: $categoryName?';
  }

  @override
  String get inventoryItemAddButton => '＋ Thêm sản phẩm';

  @override
  String get inventoryItemAddDialogTitle => 'Thêm sản phẩm';

  @override
  String get inventoryItemEditDialogTitle => 'Sửa sản phẩm';

  @override
  String get inventoryItemDeleteTitle => 'Xóa sản phẩm';

  @override
  String inventoryItemDeleteContent(Object itemName) {
    return 'Xóa $itemName?';
  }

  @override
  String get inventoryItemHintName => 'Tên sản phẩm';

  @override
  String get inventoryItemHintUnit => 'Đơn vị';

  @override
  String get inventoryItemHintStock => 'Tồn kho hiện tại';

  @override
  String get inventoryItemHintPar => 'Tồn an toàn';

  @override
  String get stockItemTitle => 'Thông tin sản phẩm';

  @override
  String get stockItemLabelName => 'Tên sản phẩm';

  @override
  String get stockItemLabelMainIngredients => 'Nguyên liệu chính';

  @override
  String get stockItemLabelSubsidiaryIngredients => 'Nguyên liệu phụ';

  @override
  String stockItemLabelDetails(Object index) {
    return 'Chi tiết $index';
  }

  @override
  String get stockItemHintIngredient => 'Nguyên liệu';

  @override
  String get stockItemHintQty => 'Số lượng';

  @override
  String get stockItemHintUnit => 'Đơn vị';

  @override
  String get stockItemHintInstructionsSub => 'Hướng dẫn phụ';

  @override
  String get stockItemHintInstructionsNote => 'Ghi chú sản phẩm';

  @override
  String get stockItemAddSubDialogTitle => 'Thêm nguyên liệu phụ';

  @override
  String get stockItemEditSubDialogTitle => 'Edit Subsidiary Category';

  @override
  String get stockItemAddSubHintGroupName => 'Tên nhóm (VD: Trang trí)';

  @override
  String get stockItemAddOptionTitle => 'Thêm Tùy chọn';

  @override
  String get stockItemAddOptionSub => 'Thêm nguyên liệu phụ';

  @override
  String get stockItemAddOptionDetail => 'Thêm chi tiết';

  @override
  String get stockItemDeleteSubTitle => 'Xóa nguyên liệu phụ';

  @override
  String get stockItemDeleteSubContent => 'Bạn muốn xóa nguyên liệu này?';

  @override
  String get stockItemDeleteNoteTitle => 'Xóa ghi chú';

  @override
  String get stockItemDeleteNoteContent => 'Bạn muốn xóa ghi chú này?';

  @override
  String get stockCategoryDetailItemTitle => 'Danh sách';

  @override
  String get stockCategoryDetailAddItemButton => '＋ Thêm sản phẩm';

  @override
  String get stockItemDetailDeleteTitle => 'Xóa sản phẩm';

  @override
  String stockItemDetailDeleteContent(Object productName) {
    return 'Xóa $productName?';
  }

  @override
  String get inventoryLogTitle => 'Nhật ký kho';

  @override
  String get inventoryLogSearchHint => 'Tìm sản phẩm';

  @override
  String get inventoryLogAllDates => 'Tất cả ngày';

  @override
  String get inventoryLogDatePickerConfirm => 'Chọn';

  @override
  String get inventoryLogReasonAll => 'Tất cả';

  @override
  String get inventoryLogReasonAdd => 'Thêm';

  @override
  String get inventoryLogReasonAdjustment => 'Điều chỉnh';

  @override
  String get inventoryLogReasonWaste => 'Hủy';

  @override
  String get inventoryLogNoRecords => 'Không có nhật ký.';

  @override
  String get inventoryLogCardUnknownItem => 'Sản phẩm lạ';

  @override
  String get inventoryLogCardUnknownUser => 'Người lạ';

  @override
  String inventoryLogCardLabelName(Object userName) {
    return 'Tên: $userName';
  }

  @override
  String inventoryLogCardLabelChange(Object adjustment, Object unit) {
    return 'Thay đổi: $adjustment $unit';
  }

  @override
  String inventoryLogCardLabelStock(Object newStock, Object oldStock) {
    return 'Số lượng $oldStock→$newStock';
  }

  @override
  String get printerSettingsTitle => 'Cài đặt phần cứng';

  @override
  String get printerSettingsListTitle => 'Danh sách máy in';

  @override
  String get printerSettingsNoPrinters => 'Chưa có máy in';

  @override
  String printerSettingsLabelIP(Object ip) {
    return 'IP: $ip';
  }

  @override
  String get printerDialogAddTitle => 'Thêm máy in';

  @override
  String get printerDialogEditTitle => 'Sửa máy in';

  @override
  String get printerDialogHintName => 'Tên máy in';

  @override
  String get printerDialogHintIP => 'Địa chỉ IP';

  @override
  String get printerTestConnectionFailed => '❌ Kết nối thất bại';

  @override
  String get printerTestTicketSuccess => '✅ Đã in thử';

  @override
  String get printerCashDrawerOpenSuccess => '✅ Đã mở ngăn kéo';

  @override
  String get printerDeleteTitle => 'Xóa máy in';

  @override
  String printerDeleteContent(Object printerName) {
    return 'Xóa máy in $printerName?';
  }

  @override
  String get printerTestPrintTitle => '【IN THỬ NGHIỆM】';

  @override
  String get printerTestPrintSubtitle => 'Kiểm tra kết nối';

  @override
  String get printerTestPrintContent1 => 'Đây là phiếu in thử,';

  @override
  String get printerTestPrintContent2 => 'Nếu bạn thấy dòng này,';

  @override
  String get printerTestPrintContent3 => 'Nghĩa là in văn bản và ảnh bình thường.';

  @override
  String get printerTestPrintContent4 => 'Nghĩa là in văn bản và ảnh bình thường.';

  @override
  String get printerTestPrintContent5 => 'Cảm ơn bạn đã dùng Gallery 20.5';

  @override
  String get tableMapAreaSuffix => ' Khu';

  @override
  String get tableMapRemoveTitle => 'Xóa bàn';

  @override
  String tableMapRemoveContent(Object tableName) {
    return 'Xóa bàn \"$tableName\"?';
  }

  @override
  String get tableMapRemoveConfirm => 'Xóa';

  @override
  String get tableMapAddDialogTitle => 'Thêm bàn';

  @override
  String get tableMapShapeCircle => 'Tròn';

  @override
  String get tableMapShapeSquare => 'Vuông';

  @override
  String get tableMapShapeRect => 'Chữ nhật';

  @override
  String get tableMapAddDialogHint => 'Chọn số bàn';

  @override
  String get tableMapNoAvailableTables => 'Không có bàn trống.';

  @override
  String get tableMgmtTitle => 'Quản lý bàn';

  @override
  String get tableMgmtAreaListAddButton => '＋ Thêm khu vực';

  @override
  String get tableMgmtAreaListAddTitle => 'Thêm khu vực';

  @override
  String get tableMgmtAreaListEditTitle => 'Sửa khu vực';

  @override
  String get tableMgmtAreaListHintName => 'Tên khu vực';

  @override
  String get tableMgmtAreaListDeleteTitle => 'Xóa khu vực';

  @override
  String tableMgmtAreaListDeleteContent(Object areaName) {
    return 'Xóa khu vực $areaName?';
  }

  @override
  String tableMgmtAreaAddSuccess(Object name) {
    return '✅ Đã thêm khu \"$name\"';
  }

  @override
  String get tableMgmtAreaAddFailure => 'Thêm thất bại';

  @override
  String get tableMgmtTableListAddButton => '＋ Thêm bàn';

  @override
  String get tableMgmtTableListAddTitle => 'Thêm bàn mới';

  @override
  String get tableMgmtTableListEditTitle => 'Sửa bàn';

  @override
  String get tableMgmtTableListHintName => 'Tên bàn';

  @override
  String get tableMgmtTableListDeleteTitle => 'Xóa bàn';

  @override
  String tableMgmtTableListDeleteContent(Object tableName) {
    return 'Xóa bàn $tableName?';
  }

  @override
  String get tableMgmtTableAddFailure => 'Thêm thất bại';

  @override
  String get tableMgmtTableDeleteFailure => 'Xóa thất bại';

  @override
  String get commonSaveFailure => 'Lưu thất bại.';

  @override
  String get commonDeleteFailure => 'Xóa thất bại.';

  @override
  String get commonNameExists => 'Tên đã tồn tại.';

  @override
  String get menuEditTitle => 'Sửa Menu';

  @override
  String get menuCategoryAddButton => '＋ Thêm danh mục';

  @override
  String get menuDetailAddItemButton => '＋ Thêm món';

  @override
  String get menuDeleteCategoryTitle => 'Xóa danh mục';

  @override
  String menuDeleteCategoryContent(Object categoryName) {
    return 'Xóa danh mục $categoryName?';
  }

  @override
  String get menuCategoryAddDialogTitle => 'Thêm danh mục';

  @override
  String get menuCategoryEditDialogTitle => 'Sửa tên danh mục';

  @override
  String get menuCategoryHintName => 'Tên danh mục';

  @override
  String get menuItemAddDialogTitle => 'Thêm món mới';

  @override
  String get menuItemEditDialogTitle => 'Sửa món';

  @override
  String get menuItemPriceLabel => 'Giá hiện tại';

  @override
  String get menuItemMarketPrice => 'Giá thị trường';

  @override
  String get menuItemHintPrice => 'Giá món';

  @override
  String get menuItemLabelMarketPrice => 'Giá thị trường';

  @override
  String menuItemLabelPrice(Object price) {
    return 'Giá: $price';
  }

  @override
  String get shiftSetupTitle => 'Cài đặt ca';

  @override
  String get shiftSetupSectionTitle => 'Loại ca đã định nghĩa';

  @override
  String get shiftSetupListAddButton => '+ Thêm loại ca';

  @override
  String get shiftSetupSaveButton => 'Lưu';

  @override
  String shiftListStartTime(Object endTime, Object startTime) {
    return '$startTime - $endTime';
  }

  @override
  String get shiftDialogAddTitle => 'Thêm loại ca';

  @override
  String get shiftDialogEditTitle => 'Sửa loại ca';

  @override
  String get shiftDialogHintName => 'Tên ca';

  @override
  String get shiftDialogLabelStartTime => 'Bắt đầu:';

  @override
  String get shiftDialogLabelEndTime => 'Kết thúc:';

  @override
  String get shiftDialogLabelColor => 'Màu:';

  @override
  String get shiftDialogErrorNameEmpty => 'Vui lòng nhập tên ca.';

  @override
  String get shiftDeleteConfirmTitle => 'Xác nhận xóa';

  @override
  String shiftDeleteConfirmContent(Object shiftName) {
    return 'Bạn muốn xóa loại ca \"$shiftName\"?';
  }

  @override
  String shiftDeleteLocalSuccess(Object shiftName) {
    return 'Đã xóa loại ca \"$shiftName\".';
  }

  @override
  String get shiftSaveSuccess => 'Đã lưu cài đặt!';

  @override
  String shiftSaveError(Object error) {
    return 'Lỗi lưu: $error';
  }

  @override
  String shiftLoadError(Object error) {
    return 'Lỗi tải: $error';
  }

  @override
  String get commonSuccess => 'Thành công';

  @override
  String get commonError => 'Lỗi';

  @override
  String get punchInSetupTitle => 'Thông tin chấm công';

  @override
  String get punchInWifiSection => 'Tên Wi-Fi hiện tại';

  @override
  String get punchInLocationSection => 'Vị trí hiện tại';

  @override
  String get punchInLoading => 'Đang tải...';

  @override
  String get punchInErrorPermissionTitle => 'Lỗi quyền';

  @override
  String get punchInErrorPermissionContent => 'Vui lòng bật quyền vị trí.';

  @override
  String get punchInErrorFetchTitle => 'Lỗi lấy thông tin';

  @override
  String get punchInErrorFetchContent => 'Không lấy được Wi-Fi hoặc GPS.';

  @override
  String get punchInSaveFailureTitle => 'Lỗi';

  @override
  String get punchInSaveFailureContent => 'Không lấy được thông tin cần thiết.';

  @override
  String get punchInSaveSuccessTitle => 'Thành công';

  @override
  String get punchInSaveSuccessContent => 'Đã lưu thông tin chấm công.';

  @override
  String get punchInRegainButton => 'Lấy lại Wi-Fi & Vị trí';

  @override
  String get punchInSaveButton => 'Lưu thông tin';

  @override
  String get punchInConfirmOverwriteTitle => 'Xác nhận ghi đè';

  @override
  String get punchInConfirmOverwriteContent => 'Dữ liệu đã tồn tại. Bạn muốn ghi đè?';

  @override
  String get commonOverwrite => 'Ghi đè';

  @override
  String get commonOK => 'OK';

  @override
  String get paymentSetupTitle => 'Cài đặt thanh toán';

  @override
  String get paymentSetupMethodsSection => 'Phương thức đã bật';

  @override
  String get paymentSetupFunctionModule => 'Chức năng';

  @override
  String get paymentSetupFunctionDeposit => 'Tiền cọc';

  @override
  String get paymentSetupSaveButton => 'Lưu';

  @override
  String paymentSetupLoadError(Object error) {
    return 'Lỗi tải: $error';
  }

  @override
  String get paymentSetupSaveSuccess => '✅ Đã lưu';

  @override
  String paymentSetupSaveFailure(Object error) {
    return 'Lưu lỗi: $error';
  }

  @override
  String get paymentAddDialogTitle => '＋Thêm phương thức';

  @override
  String get paymentAddDialogHintName => 'Tên phương thức';

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
  String get cashRegSetupTitle => 'Cài đặt két tiền';

  @override
  String get cashRegSetupSubtitle => 'Nhập số lượng mặc định cho mỗi mệnh giá\nkhi mở ca làm việc.';

  @override
  String cashRegSetupTotalLabel(Object totalAmount) {
    return 'Tổng: $totalAmount';
  }

  @override
  String get cashRegSetupInputHint => '0';

  @override
  String get cashRegNoticeSaveSuccess => 'Đã lưu cài đặt két tiền!';

  @override
  String cashRegNoticeSaveFailure(Object error) {
    return 'Lưu thất bại: $error';
  }

  @override
  String cashRegNoticeLoadError(Object error) {
    return 'Lỗi tải: $error';
  }

  @override
  String get languageEnglish => 'English';

  @override
  String get languageTraditionalChinese => '繁體中文 (Traditional Chinese)';

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
  String get languageSimplifiedChinese => '简体中文 (Simplified Chinese)';

  @override
  String get languageItalian => 'Italiano';

  @override
  String get languageVietnamese => 'Tiếng Việt';

  @override
  String get settingAppearance => 'System Color';

  @override
  String get themeSystem => 'Màu hệ thống';

  @override
  String get themeSage => 'Mặc định';

  @override
  String get themeLight => 'Chế độ sáng';

  @override
  String get themeDark => 'Chế độ tối';
}
