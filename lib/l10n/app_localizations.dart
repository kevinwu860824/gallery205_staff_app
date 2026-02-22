import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('it'),
    Locale('vi'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    Locale('zh')
  ];

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Gallery 20.5'**
  String get homeTitle;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @homeOrder.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get homeOrder;

  /// No description provided for @homeCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get homeCalendar;

  /// No description provided for @homeShift.
  ///
  /// In en, this message translates to:
  /// **'Shift'**
  String get homeShift;

  /// No description provided for @homePrep.
  ///
  /// In en, this message translates to:
  /// **'Prep'**
  String get homePrep;

  /// No description provided for @homeStock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get homeStock;

  /// No description provided for @homeClockIn.
  ///
  /// In en, this message translates to:
  /// **'Clock-in'**
  String get homeClockIn;

  /// No description provided for @homeWorkReport.
  ///
  /// In en, this message translates to:
  /// **'Work Report'**
  String get homeWorkReport;

  /// No description provided for @homeBackhouse.
  ///
  /// In en, this message translates to:
  /// **'Backhouse'**
  String get homeBackhouse;

  /// No description provided for @homeDailyCost.
  ///
  /// In en, this message translates to:
  /// **'Daily Cost'**
  String get homeDailyCost;

  /// No description provided for @homeCashFlow.
  ///
  /// In en, this message translates to:
  /// **'Cash Flow'**
  String get homeCashFlow;

  /// No description provided for @homeMonthlyCost.
  ///
  /// In en, this message translates to:
  /// **'Monthly Cost'**
  String get homeMonthlyCost;

  /// No description provided for @homeSetting.
  ///
  /// In en, this message translates to:
  /// **'Setting'**
  String get homeSetting;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @defaultUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get defaultUser;

  /// No description provided for @settingPrepInfo.
  ///
  /// In en, this message translates to:
  /// **'Prep Info'**
  String get settingPrepInfo;

  /// No description provided for @settingStock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get settingStock;

  /// No description provided for @settingStockLog.
  ///
  /// In en, this message translates to:
  /// **'Stock Log'**
  String get settingStockLog;

  /// No description provided for @settingTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get settingTable;

  /// No description provided for @settingTableMap.
  ///
  /// In en, this message translates to:
  /// **'Table Map'**
  String get settingTableMap;

  /// No description provided for @settingMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get settingMenu;

  /// No description provided for @settingPrinter.
  ///
  /// In en, this message translates to:
  /// **'Printer'**
  String get settingPrinter;

  /// No description provided for @settingClockInInfo.
  ///
  /// In en, this message translates to:
  /// **'Clock-in Info'**
  String get settingClockInInfo;

  /// No description provided for @settingPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get settingPayment;

  /// No description provided for @settingCashbox.
  ///
  /// In en, this message translates to:
  /// **'Cashbox'**
  String get settingCashbox;

  /// No description provided for @settingShift.
  ///
  /// In en, this message translates to:
  /// **'Shift'**
  String get settingShift;

  /// No description provided for @settingUserManagement.
  ///
  /// In en, this message translates to:
  /// **'User Management'**
  String get settingUserManagement;

  /// No description provided for @settingCostCategories.
  ///
  /// In en, this message translates to:
  /// **'Cost Categories'**
  String get settingCostCategories;

  /// No description provided for @settingLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingLanguage;

  /// No description provided for @settingChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get settingChangePassword;

  /// No description provided for @settingLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get settingLogout;

  /// No description provided for @settingRoleManagement.
  ///
  /// In en, this message translates to:
  /// **'Role Management'**
  String get settingRoleManagement;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginTitle;

  /// No description provided for @loginShopIdHint.
  ///
  /// In en, this message translates to:
  /// **'Select Shop ID'**
  String get loginShopIdHint;

  /// No description provided for @loginEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get loginEmailHint;

  /// No description provided for @loginPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPasswordHint;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginButton;

  /// No description provided for @loginAddShopOption.
  ///
  /// In en, this message translates to:
  /// **'+ Add Shop'**
  String get loginAddShopOption;

  /// No description provided for @loginAddShopDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Shop'**
  String get loginAddShopDialogTitle;

  /// No description provided for @loginAddShopDialogHint.
  ///
  /// In en, this message translates to:
  /// **'Enter new shop code'**
  String get loginAddShopDialogHint;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @loginMsgFillAll.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all fields'**
  String get loginMsgFillAll;

  /// No description provided for @loginMsgFaceIdFirst.
  ///
  /// In en, this message translates to:
  /// **'Please login with Email first'**
  String get loginMsgFaceIdFirst;

  /// No description provided for @loginMsgFaceIdReason.
  ///
  /// In en, this message translates to:
  /// **'Please use Face ID to login'**
  String get loginMsgFaceIdReason;

  /// No description provided for @loginMsgNoSavedData.
  ///
  /// In en, this message translates to:
  /// **'No saved login data'**
  String get loginMsgNoSavedData;

  /// No description provided for @loginMsgNoFaceIdData.
  ///
  /// In en, this message translates to:
  /// **'No Face ID data found for this account'**
  String get loginMsgNoFaceIdData;

  /// No description provided for @loginMsgShopNotFound.
  ///
  /// In en, this message translates to:
  /// **'Shop not found'**
  String get loginMsgShopNotFound;

  /// No description provided for @loginMsgNoPermission.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission for this shop'**
  String get loginMsgNoPermission;

  /// No description provided for @loginMsgFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get loginMsgFailed;

  /// No description provided for @loginMsgFailedReason.
  ///
  /// In en, this message translates to:
  /// **'Login failed: {error}'**
  String loginMsgFailedReason(Object error);

  /// No description provided for @scheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get scheduleTitle;

  /// No description provided for @scheduleTabMy.
  ///
  /// In en, this message translates to:
  /// **'My'**
  String get scheduleTabMy;

  /// No description provided for @scheduleTabAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get scheduleTabAll;

  /// No description provided for @scheduleTabCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get scheduleTabCustom;

  /// No description provided for @scheduleFilterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter Groups'**
  String get scheduleFilterTooltip;

  /// No description provided for @scheduleSelectGroups.
  ///
  /// In en, this message translates to:
  /// **'Select Groups'**
  String get scheduleSelectGroups;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @schedulePersonalMe.
  ///
  /// In en, this message translates to:
  /// **'Personal (Me)'**
  String get schedulePersonalMe;

  /// No description provided for @scheduleUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get scheduleUntitled;

  /// No description provided for @scheduleNoEvents.
  ///
  /// In en, this message translates to:
  /// **'No events'**
  String get scheduleNoEvents;

  /// No description provided for @scheduleAllDay.
  ///
  /// In en, this message translates to:
  /// **'All Day'**
  String get scheduleAllDay;

  /// No description provided for @scheduleDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get scheduleDayLabel;

  /// No description provided for @commonNoTitle.
  ///
  /// In en, this message translates to:
  /// **'No Title'**
  String get commonNoTitle;

  /// No description provided for @scheduleMoreEvents.
  ///
  /// In en, this message translates to:
  /// **'+{count} more...'**
  String scheduleMoreEvents(Object count);

  /// No description provided for @commonToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get commonToday;

  /// No description provided for @calendarGroupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar Groups'**
  String get calendarGroupsTitle;

  /// No description provided for @calendarGroupPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal (Me)'**
  String get calendarGroupPersonal;

  /// No description provided for @calendarGroupUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get calendarGroupUntitled;

  /// No description provided for @calendarGroupPrivateDesc.
  ///
  /// In en, this message translates to:
  /// **'Private events only visible to you'**
  String get calendarGroupPrivateDesc;

  /// No description provided for @calendarGroupVisibleToMembers.
  ///
  /// In en, this message translates to:
  /// **'Visible to {count} members'**
  String calendarGroupVisibleToMembers(Object count);

  /// No description provided for @calendarGroupNew.
  ///
  /// In en, this message translates to:
  /// **'New Group'**
  String get calendarGroupNew;

  /// No description provided for @calendarGroupEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Group'**
  String get calendarGroupEdit;

  /// No description provided for @calendarGroupName.
  ///
  /// In en, this message translates to:
  /// **'GROUP NAME'**
  String get calendarGroupName;

  /// No description provided for @calendarGroupNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Work, Meeting'**
  String get calendarGroupNameHint;

  /// No description provided for @calendarGroupColor.
  ///
  /// In en, this message translates to:
  /// **'GROUP COLOR'**
  String get calendarGroupColor;

  /// No description provided for @calendarGroupEventColors.
  ///
  /// In en, this message translates to:
  /// **'EVENT COLORS'**
  String get calendarGroupEventColors;

  /// No description provided for @calendarGroupSaveFirstHint.
  ///
  /// In en, this message translates to:
  /// **'Save this group first to setup custom event colors.'**
  String get calendarGroupSaveFirstHint;

  /// No description provided for @calendarGroupVisibleTo.
  ///
  /// In en, this message translates to:
  /// **'VISIBLE TO MEMBERS'**
  String get calendarGroupVisibleTo;

  /// No description provided for @calendarGroupDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Group'**
  String get calendarGroupDelete;

  /// No description provided for @calendarGroupDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Deleting this group will remove all associated events. Are you sure?'**
  String get calendarGroupDeleteConfirm;

  /// No description provided for @calendarColorNew.
  ///
  /// In en, this message translates to:
  /// **'New Color'**
  String get calendarColorNew;

  /// No description provided for @calendarColorEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Color'**
  String get calendarColorEdit;

  /// No description provided for @calendarColorName.
  ///
  /// In en, this message translates to:
  /// **'COLOR NAME'**
  String get calendarColorName;

  /// No description provided for @calendarColorNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Urgent, Meeting'**
  String get calendarColorNameHint;

  /// No description provided for @calendarColorPick.
  ///
  /// In en, this message translates to:
  /// **'PICK COLOR'**
  String get calendarColorPick;

  /// No description provided for @calendarColorDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Color'**
  String get calendarColorDelete;

  /// No description provided for @calendarColorDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this color setting?'**
  String get calendarColorDeleteConfirm;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @notificationGroupInviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Group Invite'**
  String get notificationGroupInviteTitle;

  /// No description provided for @notificationGroupInviteBody.
  ///
  /// In en, this message translates to:
  /// **'You have been added to calendar group: {groupName}'**
  String notificationGroupInviteBody(Object groupName);

  /// No description provided for @eventDetailTitleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Event'**
  String get eventDetailTitleEdit;

  /// No description provided for @eventDetailTitleNew.
  ///
  /// In en, this message translates to:
  /// **'New Event'**
  String get eventDetailTitleNew;

  /// No description provided for @eventDetailLabelTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get eventDetailLabelTitle;

  /// No description provided for @eventDetailLabelGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get eventDetailLabelGroup;

  /// No description provided for @eventDetailLabelColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get eventDetailLabelColor;

  /// No description provided for @eventDetailLabelAllDay.
  ///
  /// In en, this message translates to:
  /// **'All-day'**
  String get eventDetailLabelAllDay;

  /// No description provided for @eventDetailLabelStarts.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get eventDetailLabelStarts;

  /// No description provided for @eventDetailLabelEnds.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get eventDetailLabelEnds;

  /// No description provided for @eventDetailLabelRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get eventDetailLabelRepeat;

  /// No description provided for @eventDetailLabelRelatedPeople.
  ///
  /// In en, this message translates to:
  /// **'Related People'**
  String get eventDetailLabelRelatedPeople;

  /// No description provided for @eventDetailLabelNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get eventDetailLabelNotes;

  /// No description provided for @eventDetailDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Event'**
  String get eventDetailDelete;

  /// No description provided for @eventDetailDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this event?'**
  String get eventDetailDeleteConfirm;

  /// No description provided for @eventDetailSelectGroup.
  ///
  /// In en, this message translates to:
  /// **'Select Group'**
  String get eventDetailSelectGroup;

  /// No description provided for @eventDetailSelectColor.
  ///
  /// In en, this message translates to:
  /// **'Select Color'**
  String get eventDetailSelectColor;

  /// No description provided for @eventDetailGroupDefault.
  ///
  /// In en, this message translates to:
  /// **'Group Default'**
  String get eventDetailGroupDefault;

  /// No description provided for @eventDetailCustomColor.
  ///
  /// In en, this message translates to:
  /// **'Custom Color'**
  String get eventDetailCustomColor;

  /// No description provided for @eventDetailNoCustomColors.
  ///
  /// In en, this message translates to:
  /// **'No custom colors set for this group.'**
  String get eventDetailNoCustomColors;

  /// No description provided for @eventDetailSelectPeople.
  ///
  /// In en, this message translates to:
  /// **'Select People'**
  String get eventDetailSelectPeople;

  /// No description provided for @eventDetailPeopleCount.
  ///
  /// In en, this message translates to:
  /// **'{count} people'**
  String eventDetailPeopleCount(Object count);

  /// No description provided for @eventDetailNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get eventDetailNone;

  /// No description provided for @eventDetailRepeatNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get eventDetailRepeatNone;

  /// No description provided for @eventDetailRepeatDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get eventDetailRepeatDaily;

  /// No description provided for @eventDetailRepeatWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get eventDetailRepeatWeekly;

  /// No description provided for @eventDetailRepeatMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get eventDetailRepeatMonthly;

  /// No description provided for @eventDetailErrorTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Title is required'**
  String get eventDetailErrorTitleRequired;

  /// No description provided for @eventDetailErrorGroupRequired.
  ///
  /// In en, this message translates to:
  /// **'Group is required'**
  String get eventDetailErrorGroupRequired;

  /// No description provided for @eventDetailErrorEndTime.
  ///
  /// In en, this message translates to:
  /// **'End time cannot be before start time'**
  String get eventDetailErrorEndTime;

  /// No description provided for @eventDetailErrorSave.
  ///
  /// In en, this message translates to:
  /// **'Failed to save event'**
  String get eventDetailErrorSave;

  /// No description provided for @eventDetailErrorDelete.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete'**
  String get eventDetailErrorDelete;

  /// No description provided for @notificationNewEventTitle.
  ///
  /// In en, this message translates to:
  /// **'[{groupName}] New Event'**
  String notificationNewEventTitle(Object groupName);

  /// No description provided for @notificationNewEventBody.
  ///
  /// In en, this message translates to:
  /// **'{userName} added: {title} ({time})'**
  String notificationNewEventBody(Object time, Object title, Object userName);

  /// No description provided for @notificationTimeChangeTitle.
  ///
  /// In en, this message translates to:
  /// **'⏰ [Update] Time Changed'**
  String get notificationTimeChangeTitle;

  /// No description provided for @notificationTimeChangeBody.
  ///
  /// In en, this message translates to:
  /// **'{userName} changed the time of \"{title}\", please check.'**
  String notificationTimeChangeBody(Object title, Object userName);

  /// No description provided for @notificationContentChangeTitle.
  ///
  /// In en, this message translates to:
  /// **'✏️ [Update] Content Changed'**
  String get notificationContentChangeTitle;

  /// No description provided for @notificationContentChangeBody.
  ///
  /// In en, this message translates to:
  /// **'{userName} updated details of \"{title}\".'**
  String notificationContentChangeBody(Object title, Object userName);

  /// No description provided for @notificationDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'🗑️ [Cancel] Event Removed'**
  String get notificationDeleteTitle;

  /// No description provided for @notificationDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'{userName} canceled event: {title}'**
  String notificationDeleteBody(Object title, Object userName);

  /// No description provided for @localNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'🔔 Reminder'**
  String get localNotificationTitle;

  /// No description provided for @localNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'In 10 mins: {title}'**
  String localNotificationBody(Object title);

  /// No description provided for @commonSelect.
  ///
  /// In en, this message translates to:
  /// **'Select...'**
  String get commonSelect;

  /// No description provided for @commonUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get commonUnknown;

  /// No description provided for @commonPersonalMe.
  ///
  /// In en, this message translates to:
  /// **'Personal (Me)'**
  String get commonPersonalMe;

  /// No description provided for @scheduleViewTitle.
  ///
  /// In en, this message translates to:
  /// **'Work Schedule'**
  String get scheduleViewTitle;

  /// No description provided for @scheduleViewModeMy.
  ///
  /// In en, this message translates to:
  /// **'My Shifts'**
  String get scheduleViewModeMy;

  /// No description provided for @scheduleViewModeAll.
  ///
  /// In en, this message translates to:
  /// **'All Shifts'**
  String get scheduleViewModeAll;

  /// No description provided for @scheduleViewErrorInit.
  ///
  /// In en, this message translates to:
  /// **'Failed to load initial data: {error}'**
  String scheduleViewErrorInit(Object error);

  /// No description provided for @scheduleViewErrorFetch.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch schedule: {error}'**
  String scheduleViewErrorFetch(Object error);

  /// No description provided for @scheduleViewUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get scheduleViewUnknown;

  /// No description provided for @scheduleUploadTitle.
  ///
  /// In en, this message translates to:
  /// **'Shift Assigning'**
  String get scheduleUploadTitle;

  /// No description provided for @scheduleUploadSelectEmployee.
  ///
  /// In en, this message translates to:
  /// **'Select Employee'**
  String get scheduleUploadSelectEmployee;

  /// No description provided for @scheduleUploadSelectShiftFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select a shift type from above first.'**
  String get scheduleUploadSelectShiftFirst;

  /// No description provided for @scheduleUploadUnsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'Unsaved Changes'**
  String get scheduleUploadUnsavedChanges;

  /// No description provided for @scheduleUploadDiscardChangesMessage.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Switching employees or leaving will discard them. Continue?'**
  String get scheduleUploadDiscardChangesMessage;

  /// No description provided for @scheduleUploadNoChanges.
  ///
  /// In en, this message translates to:
  /// **'No changes to save.'**
  String get scheduleUploadNoChanges;

  /// No description provided for @scheduleUploadSaveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Schedule saved!'**
  String get scheduleUploadSaveSuccess;

  /// No description provided for @scheduleUploadSaveError.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String scheduleUploadSaveError(Object error);

  /// No description provided for @scheduleUploadLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load initial data: {error}'**
  String scheduleUploadLoadError(Object error);

  /// No description provided for @scheduleUploadLoadScheduleError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load schedule for {name}'**
  String scheduleUploadLoadScheduleError(Object name);

  /// No description provided for @scheduleUploadRole.
  ///
  /// In en, this message translates to:
  /// **'Role: {role}'**
  String scheduleUploadRole(Object role);

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get commonSaveChanges;

  /// No description provided for @prepViewTitle.
  ///
  /// In en, this message translates to:
  /// **'View Prep Category'**
  String get prepViewTitle;

  /// No description provided for @prepViewItemTitle.
  ///
  /// In en, this message translates to:
  /// **'View Prep Item'**
  String get prepViewItemTitle;

  /// No description provided for @prepViewItemUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled Item'**
  String get prepViewItemUntitled;

  /// No description provided for @prepViewMainIngredients.
  ///
  /// In en, this message translates to:
  /// **'Main Ingredients'**
  String get prepViewMainIngredients;

  /// No description provided for @prepViewNote.
  ///
  /// In en, this message translates to:
  /// **'Note: {note}'**
  String prepViewNote(Object note);

  /// No description provided for @prepViewDetailLabel.
  ///
  /// In en, this message translates to:
  /// **'Detail'**
  String get prepViewDetailLabel;

  /// No description provided for @settingCategoryPersonnel.
  ///
  /// In en, this message translates to:
  /// **'Personnel & Permissions'**
  String get settingCategoryPersonnel;

  /// No description provided for @settingCategoryMenuInv.
  ///
  /// In en, this message translates to:
  /// **'Menu & Inventory'**
  String get settingCategoryMenuInv;

  /// No description provided for @settingCategoryEquipTable.
  ///
  /// In en, this message translates to:
  /// **'Equipment & Tables'**
  String get settingCategoryEquipTable;

  /// No description provided for @settingCategorySystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingCategorySystem;

  /// No description provided for @settingPayroll.
  ///
  /// In en, this message translates to:
  /// **'Payroll Report'**
  String get settingPayroll;

  /// No description provided for @permBackPayroll.
  ///
  /// In en, this message translates to:
  /// **'Payroll Report'**
  String get permBackPayroll;

  /// No description provided for @permBackLoginWeb.
  ///
  /// In en, this message translates to:
  /// **'Allow Backend Login'**
  String get permBackLoginWeb;

  /// No description provided for @settingModifiers.
  ///
  /// In en, this message translates to:
  /// **'Modifiers Setup'**
  String get settingModifiers;

  /// No description provided for @settingTax.
  ///
  /// In en, this message translates to:
  /// **'Tax Settings'**
  String get settingTax;

  /// No description provided for @inventoryViewTitle.
  ///
  /// In en, this message translates to:
  /// **'Stock Overview'**
  String get inventoryViewTitle;

  /// No description provided for @inventorySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search Item'**
  String get inventorySearchHint;

  /// No description provided for @inventoryNoItems.
  ///
  /// In en, this message translates to:
  /// **'No items found'**
  String get inventoryNoItems;

  /// No description provided for @inventorySafetyQuantity.
  ///
  /// In en, this message translates to:
  /// **'Safety Quantity: {quantity}'**
  String inventorySafetyQuantity(Object quantity);

  /// No description provided for @inventoryConfirmUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Update'**
  String get inventoryConfirmUpdateTitle;

  /// No description provided for @inventoryConfirmUpdateOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original Number: {value} {unit}'**
  String inventoryConfirmUpdateOriginal(Object unit, Object value);

  /// No description provided for @inventoryConfirmUpdateNew.
  ///
  /// In en, this message translates to:
  /// **'New Number: {value} {unit}'**
  String inventoryConfirmUpdateNew(Object unit, Object value);

  /// No description provided for @inventoryConfirmUpdateChange.
  ///
  /// In en, this message translates to:
  /// **'Change: {value}'**
  String inventoryConfirmUpdateChange(Object value);

  /// No description provided for @inventoryUnsavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsaved Change'**
  String get inventoryUnsavedTitle;

  /// No description provided for @inventoryUnsavedContent.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved inventory adjustments. Would you like to save and exit?'**
  String get inventoryUnsavedContent;

  /// No description provided for @inventoryUnsavedDiscard.
  ///
  /// In en, this message translates to:
  /// **'Cancel & Exit'**
  String get inventoryUnsavedDiscard;

  /// No description provided for @inventoryUpdateSuccess.
  ///
  /// In en, this message translates to:
  /// **'✅ {name} stock updated successfully!'**
  String inventoryUpdateSuccess(Object name);

  /// No description provided for @inventoryUpdateFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Update Failed'**
  String get inventoryUpdateFailedTitle;

  /// No description provided for @inventoryUpdateFailedMsg.
  ///
  /// In en, this message translates to:
  /// **'Database error, please contact administrator.'**
  String get inventoryUpdateFailedMsg;

  /// No description provided for @inventoryBatchSaveFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Batch Save Failed'**
  String get inventoryBatchSaveFailedTitle;

  /// No description provided for @inventoryBatchSaveFailedMsg.
  ///
  /// In en, this message translates to:
  /// **'Item {name} failed to save.'**
  String inventoryBatchSaveFailedMsg(Object name);

  /// No description provided for @inventoryReasonStockIn.
  ///
  /// In en, this message translates to:
  /// **'Stock In'**
  String get inventoryReasonStockIn;

  /// No description provided for @inventoryReasonAudit.
  ///
  /// In en, this message translates to:
  /// **'Audit Adjustment'**
  String get inventoryReasonAudit;

  /// No description provided for @inventoryErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get inventoryErrorTitle;

  /// No description provided for @inventoryErrorInvalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid number'**
  String get inventoryErrorInvalidNumber;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @punchTitle.
  ///
  /// In en, this message translates to:
  /// **'Clock-in'**
  String get punchTitle;

  /// No description provided for @punchInButton.
  ///
  /// In en, this message translates to:
  /// **'Clock-in'**
  String get punchInButton;

  /// No description provided for @punchOutButton.
  ///
  /// In en, this message translates to:
  /// **'Clock-out'**
  String get punchOutButton;

  /// No description provided for @punchMakeUpButton.
  ///
  /// In en, this message translates to:
  /// **'Make Up For\nClock-in/out'**
  String get punchMakeUpButton;

  /// No description provided for @punchLocDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location services are disabled. Please enable them in Settings.'**
  String get punchLocDisabled;

  /// No description provided for @punchLocDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permissions are denied'**
  String get punchLocDenied;

  /// No description provided for @punchLocDeniedForever.
  ///
  /// In en, this message translates to:
  /// **'Location permissions are permanently denied, we cannot request permissions.'**
  String get punchLocDeniedForever;

  /// No description provided for @punchErrorSettingsNotFound.
  ///
  /// In en, this message translates to:
  /// **'Shop punch-in settings not found. Please contact manager.'**
  String get punchErrorSettingsNotFound;

  /// No description provided for @punchErrorWifi.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi incorrect.\nPlease connect to: {wifi}'**
  String punchErrorWifi(Object wifi);

  /// No description provided for @punchErrorDistance.
  ///
  /// In en, this message translates to:
  /// **'You are too far from the shop.'**
  String get punchErrorDistance;

  /// No description provided for @punchErrorAlreadyIn.
  ///
  /// In en, this message translates to:
  /// **'You are already clocked in.'**
  String get punchErrorAlreadyIn;

  /// No description provided for @punchSuccessInTitle.
  ///
  /// In en, this message translates to:
  /// **'Clock-in Succeeded'**
  String get punchSuccessInTitle;

  /// No description provided for @punchSuccessInMsg.
  ///
  /// In en, this message translates to:
  /// **'Have a nice shift : )'**
  String get punchSuccessInMsg;

  /// No description provided for @punchErrorInTitle.
  ///
  /// In en, this message translates to:
  /// **'Clock-in Failed'**
  String get punchErrorInTitle;

  /// No description provided for @punchErrorNoSession.
  ///
  /// In en, this message translates to:
  /// **'No active session found within 24 hours. Please contact manager.'**
  String get punchErrorNoSession;

  /// No description provided for @punchErrorOverTime.
  ///
  /// In en, this message translates to:
  /// **'Over 12 hours. Please use \"Make Up\" function.'**
  String get punchErrorOverTime;

  /// No description provided for @punchSuccessOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Clock-out Succeeded'**
  String get punchSuccessOutTitle;

  /// No description provided for @punchSuccessOutMsg.
  ///
  /// In en, this message translates to:
  /// **'Boss love you ❤️'**
  String get punchSuccessOutMsg;

  /// No description provided for @punchErrorOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Clock-out Failed'**
  String get punchErrorOutTitle;

  /// No description provided for @punchErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'An error occurred: {error}'**
  String punchErrorGeneric(Object error);

  /// No description provided for @punchMakeUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Make up for clock-in/out'**
  String get punchMakeUpTitle;

  /// No description provided for @punchMakeUpTypeIn.
  ///
  /// In en, this message translates to:
  /// **'Make Up For Clock-in'**
  String get punchMakeUpTypeIn;

  /// No description provided for @punchMakeUpTypeOut.
  ///
  /// In en, this message translates to:
  /// **'Make Up For Clock-out'**
  String get punchMakeUpTypeOut;

  /// No description provided for @punchMakeUpReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Reason (Required)'**
  String get punchMakeUpReasonHint;

  /// No description provided for @punchMakeUpErrorReason.
  ///
  /// In en, this message translates to:
  /// **'Please fill up the reason'**
  String get punchMakeUpErrorReason;

  /// No description provided for @punchMakeUpErrorFuture.
  ///
  /// In en, this message translates to:
  /// **'Cannot make up for a future time'**
  String get punchMakeUpErrorFuture;

  /// No description provided for @punchMakeUpError72h.
  ///
  /// In en, this message translates to:
  /// **'Cannot make up beyond 72 hours. Please contact manager.'**
  String get punchMakeUpError72h;

  /// No description provided for @punchMakeUpErrorOverlap.
  ///
  /// In en, this message translates to:
  /// **'Active session found at {time}. Please clock out first.'**
  String punchMakeUpErrorOverlap(Object time);

  /// No description provided for @punchMakeUpErrorNoRecord.
  ///
  /// In en, this message translates to:
  /// **'No matching record found within 72 hours. Please contact manager.'**
  String get punchMakeUpErrorNoRecord;

  /// No description provided for @punchMakeUpErrorOver12h.
  ///
  /// In en, this message translates to:
  /// **'Shift duration exceeds 12 hours. Please contact manager.'**
  String get punchMakeUpErrorOver12h;

  /// No description provided for @punchMakeUpSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Succeeded'**
  String get punchMakeUpSuccessTitle;

  /// No description provided for @punchMakeUpSuccessMsg.
  ///
  /// In en, this message translates to:
  /// **'Your make up clock-in/out succeeded'**
  String get punchMakeUpSuccessMsg;

  /// No description provided for @punchMakeUpCheckInfo.
  ///
  /// In en, this message translates to:
  /// **'Please Check The Info'**
  String get punchMakeUpCheckInfo;

  /// No description provided for @punchMakeUpLabelType.
  ///
  /// In en, this message translates to:
  /// **'Type: {type}'**
  String punchMakeUpLabelType(Object type);

  /// No description provided for @punchMakeUpLabelTime.
  ///
  /// In en, this message translates to:
  /// **'Time: {time}'**
  String punchMakeUpLabelTime(Object time);

  /// No description provided for @punchMakeUpLabelReason.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String punchMakeUpLabelReason(Object reason);

  /// No description provided for @commonDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get commonDate;

  /// No description provided for @commonTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get commonTime;

  /// No description provided for @workReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Work Report'**
  String get workReportTitle;

  /// No description provided for @workReportSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get workReportSelectDate;

  /// No description provided for @workReportJobSubject.
  ///
  /// In en, this message translates to:
  /// **'Job Subject (Required)'**
  String get workReportJobSubject;

  /// No description provided for @workReportJobDescription.
  ///
  /// In en, this message translates to:
  /// **'Job Description (Required)'**
  String get workReportJobDescription;

  /// No description provided for @workReportOverTime.
  ///
  /// In en, this message translates to:
  /// **'Over time hour (Optional)'**
  String get workReportOverTime;

  /// No description provided for @workReportHourUnit.
  ///
  /// In en, this message translates to:
  /// **'hr'**
  String get workReportHourUnit;

  /// No description provided for @workReportErrorRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Please Fill In The\nRequired Fields'**
  String get workReportErrorRequiredTitle;

  /// No description provided for @workReportErrorRequiredMsg.
  ///
  /// In en, this message translates to:
  /// **'Subject and Description\nare required!'**
  String get workReportErrorRequiredMsg;

  /// No description provided for @workReportConfirmOverwriteTitle.
  ///
  /// In en, this message translates to:
  /// **'Report Exists'**
  String get workReportConfirmOverwriteTitle;

  /// No description provided for @workReportConfirmOverwriteMsg.
  ///
  /// In en, this message translates to:
  /// **'You already submitted\na report for this date.\nDo you want to overwrite?'**
  String get workReportConfirmOverwriteMsg;

  /// No description provided for @workReportOverwriteYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get workReportOverwriteYes;

  /// No description provided for @workReportSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Successfully'**
  String get workReportSuccessTitle;

  /// No description provided for @workReportSuccessMsg.
  ///
  /// In en, this message translates to:
  /// **'Your work report is successfully been summited!'**
  String get workReportSuccessMsg;

  /// No description provided for @workReportSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Submit Failed'**
  String get workReportSubmitFailed;

  /// No description provided for @todoScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'待辦事項'**
  String get todoScreenTitle;

  /// No description provided for @todoTabIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Incomplete'**
  String get todoTabIncomplete;

  /// No description provided for @todoTabPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get todoTabPending;

  /// No description provided for @todoTabCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get todoTabCompleted;

  /// No description provided for @todoFilterMyTasks.
  ///
  /// In en, this message translates to:
  /// **'My Tasks Only'**
  String get todoFilterMyTasks;

  /// No description provided for @todoCountSuffix.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String todoCountSuffix(Object count);

  /// No description provided for @todoEmptyPending.
  ///
  /// In en, this message translates to:
  /// **'No pending tasks'**
  String get todoEmptyPending;

  /// No description provided for @todoEmptyIncomplete.
  ///
  /// In en, this message translates to:
  /// **'No incomplete tasks'**
  String get todoEmptyIncomplete;

  /// No description provided for @todoEmptyCompleted.
  ///
  /// In en, this message translates to:
  /// **'No completed tasks this month'**
  String get todoEmptyCompleted;

  /// No description provided for @todoSubmitReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Submit for Review'**
  String get todoSubmitReviewTitle;

  /// No description provided for @todoSubmitReviewContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you have completed this task and want to submit it for review?'**
  String get todoSubmitReviewContent;

  /// No description provided for @todoSubmitButton.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get todoSubmitButton;

  /// No description provided for @todoApproveTitle.
  ///
  /// In en, this message translates to:
  /// **'Approve Task'**
  String get todoApproveTitle;

  /// No description provided for @todoApproveContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure this task is completed?'**
  String get todoApproveContent;

  /// No description provided for @todoApproveButton.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get todoApproveButton;

  /// No description provided for @todoRejectTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject Task'**
  String get todoRejectTitle;

  /// No description provided for @todoRejectContent.
  ///
  /// In en, this message translates to:
  /// **'Return this task to the employee for rework?'**
  String get todoRejectContent;

  /// No description provided for @todoRejectButton.
  ///
  /// In en, this message translates to:
  /// **'Return'**
  String get todoRejectButton;

  /// No description provided for @todoDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Task'**
  String get todoDeleteTitle;

  /// No description provided for @todoDeleteContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure? This action cannot be undone.'**
  String get todoDeleteContent;

  /// No description provided for @todoErrorNoPermissionSubmit.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to submit this task.'**
  String get todoErrorNoPermissionSubmit;

  /// No description provided for @todoErrorNoPermissionApprove.
  ///
  /// In en, this message translates to:
  /// **'Only the assigner can approve this task.'**
  String get todoErrorNoPermissionApprove;

  /// No description provided for @todoErrorNoPermissionReject.
  ///
  /// In en, this message translates to:
  /// **'Only the assigner can reject this task.'**
  String get todoErrorNoPermissionReject;

  /// No description provided for @todoErrorNoPermissionEdit.
  ///
  /// In en, this message translates to:
  /// **'Only the assigner can edit this task.'**
  String get todoErrorNoPermissionEdit;

  /// No description provided for @todoErrorNoPermissionDelete.
  ///
  /// In en, this message translates to:
  /// **'Only the assigner can delete this task.'**
  String get todoErrorNoPermissionDelete;

  /// No description provided for @notificationTodoReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'👀 Task for Review'**
  String get notificationTodoReviewTitle;

  /// No description provided for @notificationTodoReviewBody.
  ///
  /// In en, this message translates to:
  /// **'{name} submitted: {task}, please check.'**
  String notificationTodoReviewBody(Object name, Object task);

  /// No description provided for @notificationTodoApprovedTitle.
  ///
  /// In en, this message translates to:
  /// **'✅ Task Approved'**
  String get notificationTodoApprovedTitle;

  /// No description provided for @notificationTodoApprovedBody.
  ///
  /// In en, this message translates to:
  /// **'Assigner approved: {task}'**
  String notificationTodoApprovedBody(Object task);

  /// No description provided for @notificationTodoRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'↩️ Task Returned'**
  String get notificationTodoRejectedTitle;

  /// No description provided for @notificationTodoRejectedBody.
  ///
  /// In en, this message translates to:
  /// **'Please revise and resubmit: {task}'**
  String notificationTodoRejectedBody(Object task);

  /// No description provided for @notificationTodoDeletedTitle.
  ///
  /// In en, this message translates to:
  /// **'🗑️ Task Deleted'**
  String get notificationTodoDeletedTitle;

  /// No description provided for @notificationTodoDeletedBody.
  ///
  /// In en, this message translates to:
  /// **'Assigner deleted: {task}'**
  String notificationTodoDeletedBody(Object task);

  /// No description provided for @todoActionSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Action: {title}'**
  String todoActionSheetTitle(Object title);

  /// No description provided for @todoActionCompleteAndSubmit.
  ///
  /// In en, this message translates to:
  /// **'Complete & Submit'**
  String get todoActionCompleteAndSubmit;

  /// No description provided for @todoReviewSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Review: {title}'**
  String todoReviewSheetTitle(Object title);

  /// No description provided for @todoReviewSheetMessageAssigner.
  ///
  /// In en, this message translates to:
  /// **'Please confirm if the task is qualified.'**
  String get todoReviewSheetMessageAssigner;

  /// No description provided for @todoReviewSheetMessageAssignee.
  ///
  /// In en, this message translates to:
  /// **'Waiting for assigner review.'**
  String get todoReviewSheetMessageAssignee;

  /// No description provided for @todoActionApprove.
  ///
  /// In en, this message translates to:
  /// **'✅ Approve'**
  String get todoActionApprove;

  /// No description provided for @todoActionReject.
  ///
  /// In en, this message translates to:
  /// **'↩️ Return'**
  String get todoActionReject;

  /// No description provided for @todoActionViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get todoActionViewDetails;

  /// No description provided for @todoLabelTo.
  ///
  /// In en, this message translates to:
  /// **'To: '**
  String get todoLabelTo;

  /// No description provided for @todoLabelFrom.
  ///
  /// In en, this message translates to:
  /// **'From: '**
  String get todoLabelFrom;

  /// No description provided for @todoUnassigned.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get todoUnassigned;

  /// No description provided for @todoLabelCompletedAt.
  ///
  /// In en, this message translates to:
  /// **'Completed: '**
  String get todoLabelCompletedAt;

  /// No description provided for @todoLabelWaitingReview.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Review'**
  String get todoLabelWaitingReview;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @todoAddTaskTitleNew.
  ///
  /// In en, this message translates to:
  /// **'New Task'**
  String get todoAddTaskTitleNew;

  /// No description provided for @todoAddTaskTitleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Task'**
  String get todoAddTaskTitleEdit;

  /// No description provided for @todoAddTaskLabelTitle.
  ///
  /// In en, this message translates to:
  /// **'Task Title'**
  String get todoAddTaskLabelTitle;

  /// No description provided for @todoAddTaskLabelDesc.
  ///
  /// In en, this message translates to:
  /// **'Description (Optional)'**
  String get todoAddTaskLabelDesc;

  /// No description provided for @todoAddTaskLabelAssign.
  ///
  /// In en, this message translates to:
  /// **'Assign To:'**
  String get todoAddTaskLabelAssign;

  /// No description provided for @todoAddTaskSelectStaff.
  ///
  /// In en, this message translates to:
  /// **'Select Staff'**
  String get todoAddTaskSelectStaff;

  /// No description provided for @todoAddTaskSelectedStaff.
  ///
  /// In en, this message translates to:
  /// **'{count} Staff Selected'**
  String todoAddTaskSelectedStaff(Object count);

  /// No description provided for @todoAddTaskSetDueDate.
  ///
  /// In en, this message translates to:
  /// **'Set Due Date'**
  String get todoAddTaskSetDueDate;

  /// No description provided for @todoAddTaskSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get todoAddTaskSelectDate;

  /// No description provided for @todoAddTaskSetDueTime.
  ///
  /// In en, this message translates to:
  /// **'Set Due Time'**
  String get todoAddTaskSetDueTime;

  /// No description provided for @todoAddTaskSelectTime.
  ///
  /// In en, this message translates to:
  /// **'Select Time'**
  String get todoAddTaskSelectTime;

  /// No description provided for @notificationTodoEditTitle.
  ///
  /// In en, this message translates to:
  /// **'✏️ Task Updated'**
  String get notificationTodoEditTitle;

  /// No description provided for @notificationTodoEditBody.
  ///
  /// In en, this message translates to:
  /// **'Content updated: {task}'**
  String notificationTodoEditBody(Object task);

  /// No description provided for @notificationTodoUrgentUpdate.
  ///
  /// In en, this message translates to:
  /// **'🔥 Urgent Update'**
  String get notificationTodoUrgentUpdate;

  /// No description provided for @notificationTodoNewTitle.
  ///
  /// In en, this message translates to:
  /// **'📝 New Task'**
  String get notificationTodoNewTitle;

  /// No description provided for @notificationTodoNewBody.
  ///
  /// In en, this message translates to:
  /// **'{task}'**
  String notificationTodoNewBody(Object task);

  /// No description provided for @notificationTodoUrgentNew.
  ///
  /// In en, this message translates to:
  /// **'🔥 Urgent Task'**
  String get notificationTodoUrgentNew;

  /// No description provided for @costInputTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Cost'**
  String get costInputTitle;

  /// No description provided for @costInputTotalToday.
  ///
  /// In en, this message translates to:
  /// **'Total cost of today'**
  String get costInputTotalToday;

  /// No description provided for @costInputLabelName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get costInputLabelName;

  /// No description provided for @costInputLabelPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get costInputLabelPrice;

  /// No description provided for @costInputTabNotOpenTitle.
  ///
  /// In en, this message translates to:
  /// **'Tab is not open'**
  String get costInputTabNotOpenTitle;

  /// No description provided for @costInputTabNotOpenMsg.
  ///
  /// In en, this message translates to:
  /// **'Please open today\'s tab first.'**
  String get costInputTabNotOpenMsg;

  /// No description provided for @costInputTabNotOpenPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Please Open Today’s Tab'**
  String get costInputTabNotOpenPageTitle;

  /// No description provided for @costInputTabNotOpenPageDesc.
  ///
  /// In en, this message translates to:
  /// **'You must open the tab first before\nyou can start filling in the daily costs.'**
  String get costInputTabNotOpenPageDesc;

  /// No description provided for @costInputButtonOpenTab.
  ///
  /// In en, this message translates to:
  /// **'Go For Open Today’s Tab'**
  String get costInputButtonOpenTab;

  /// No description provided for @costInputErrorInputTitle.
  ///
  /// In en, this message translates to:
  /// **'Input Error'**
  String get costInputErrorInputTitle;

  /// No description provided for @costInputErrorInputMsg.
  ///
  /// In en, this message translates to:
  /// **'Please ensure item and price are filled correctly.'**
  String get costInputErrorInputMsg;

  /// No description provided for @costInputSuccess.
  ///
  /// In en, this message translates to:
  /// **'✅ Cost saved successfully'**
  String get costInputSuccess;

  /// No description provided for @costInputSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save Failed'**
  String get costInputSaveFailed;

  /// No description provided for @costInputLoadingCategories.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get costInputLoadingCategories;

  /// No description provided for @costDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Cost Detail'**
  String get costDetailTitle;

  /// No description provided for @costDetailNoRecords.
  ///
  /// In en, this message translates to:
  /// **'No cost records for this period.'**
  String get costDetailNoRecords;

  /// No description provided for @costDetailItemUntitled.
  ///
  /// In en, this message translates to:
  /// **'No Item Name'**
  String get costDetailItemUntitled;

  /// No description provided for @costDetailCategoryNA.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get costDetailCategoryNA;

  /// No description provided for @costDetailBuyerNA.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get costDetailBuyerNA;

  /// No description provided for @costDetailLabelCategory.
  ///
  /// In en, this message translates to:
  /// **'Category: {category}'**
  String costDetailLabelCategory(Object category);

  /// No description provided for @costDetailLabelBuyer.
  ///
  /// In en, this message translates to:
  /// **'Buyer: {buyer}'**
  String costDetailLabelBuyer(Object buyer);

  /// No description provided for @costDetailEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Daily Cost Detail'**
  String get costDetailEditTitle;

  /// No description provided for @costDetailDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Cost'**
  String get costDetailDeleteTitle;

  /// No description provided for @costDetailDeleteContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure to delete this cost?\n({name})'**
  String costDetailDeleteContent(Object name);

  /// No description provided for @costDetailErrorUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update Failed'**
  String get costDetailErrorUpdate;

  /// No description provided for @costDetailErrorDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Failed'**
  String get costDetailErrorDelete;

  /// No description provided for @cashSettlementDeposits.
  ///
  /// In en, this message translates to:
  /// **'Deposits'**
  String get cashSettlementDeposits;

  /// No description provided for @cashSettlementExpectedCash.
  ///
  /// In en, this message translates to:
  /// **'Expected Cash'**
  String get cashSettlementExpectedCash;

  /// No description provided for @cashSettlementDifference.
  ///
  /// In en, this message translates to:
  /// **'Difference'**
  String get cashSettlementDifference;

  /// No description provided for @cashSettlementConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Settlement'**
  String get cashSettlementConfirmTitle;

  /// No description provided for @commonSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get commonSubmit;

  /// No description provided for @cashSettlementDepositSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Deposit Sheet'**
  String get cashSettlementDepositSheetTitle;

  /// No description provided for @cashSettlementDepositNew.
  ///
  /// In en, this message translates to:
  /// **'New Deposit'**
  String get cashSettlementDepositNew;

  /// No description provided for @cashSettlementNewDepositTitle.
  ///
  /// In en, this message translates to:
  /// **'New Deposit'**
  String get cashSettlementNewDepositTitle;

  /// No description provided for @commonName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get commonName;

  /// No description provided for @commonPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get commonPhone;

  /// No description provided for @commonAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get commonAmount;

  /// No description provided for @commonNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get commonNotes;

  /// No description provided for @cashSettlementDepositAddSuccess.
  ///
  /// In en, this message translates to:
  /// **'Deposit Added Successfully'**
  String get cashSettlementDepositAddSuccess;

  /// No description provided for @cashSettlementSelectRedeemedDeposit.
  ///
  /// In en, this message translates to:
  /// **'Select Redeemed Deposit'**
  String get cashSettlementSelectRedeemedDeposit;

  /// No description provided for @commonNoData.
  ///
  /// In en, this message translates to:
  /// **'No Data'**
  String get commonNoData;

  /// No description provided for @cashSettlementTitleOpen.
  ///
  /// In en, this message translates to:
  /// **'Opening Check'**
  String get cashSettlementTitleOpen;

  /// No description provided for @cashSettlementTitleClose.
  ///
  /// In en, this message translates to:
  /// **'Closing Check'**
  String get cashSettlementTitleClose;

  /// No description provided for @cashSettlementTitleLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get cashSettlementTitleLoading;

  /// No description provided for @cashSettlementOpenDesc.
  ///
  /// In en, this message translates to:
  /// **'Please check and confirm that the number of bills and the total amount are consistent with the expected values.'**
  String get cashSettlementOpenDesc;

  /// No description provided for @cashSettlementTargetAmount.
  ///
  /// In en, this message translates to:
  /// **'Target amount:'**
  String get cashSettlementTargetAmount;

  /// No description provided for @cashSettlementTotal.
  ///
  /// In en, this message translates to:
  /// **'Total:'**
  String get cashSettlementTotal;

  /// No description provided for @cashSettlementRevenueAndPayment.
  ///
  /// In en, this message translates to:
  /// **'Daily Revenue and Payment Methods'**
  String get cashSettlementRevenueAndPayment;

  /// No description provided for @cashSettlementRevenueHint.
  ///
  /// In en, this message translates to:
  /// **'Total Revenue'**
  String get cashSettlementRevenueHint;

  /// No description provided for @cashSettlementDepositButton.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Deposit (Selected: \${amount})'**
  String cashSettlementDepositButton(Object amount);

  /// No description provided for @cashSettlementReceivableCash.
  ///
  /// In en, this message translates to:
  /// **'Receivable Cash:'**
  String get cashSettlementReceivableCash;

  /// No description provided for @cashSettlementCashCountingTitle.
  ///
  /// In en, this message translates to:
  /// **'Cash Counting\n(Please Enter Actual Number of Bills)'**
  String get cashSettlementCashCountingTitle;

  /// No description provided for @cashSettlementTotalCashCounted.
  ///
  /// In en, this message translates to:
  /// **'Total Cash Counted:'**
  String get cashSettlementTotalCashCounted;

  /// No description provided for @cashSettlementReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get cashSettlementReviewTitle;

  /// No description provided for @cashSettlementOpeningCash.
  ///
  /// In en, this message translates to:
  /// **'Opening Cash'**
  String get cashSettlementOpeningCash;

  /// No description provided for @cashSettlementDailyCosts.
  ///
  /// In en, this message translates to:
  /// **'Daily Costs'**
  String get cashSettlementDailyCosts;

  /// No description provided for @cashSettlementRedeemedDeposit.
  ///
  /// In en, this message translates to:
  /// **'Redeemed Deposit'**
  String get cashSettlementRedeemedDeposit;

  /// No description provided for @cashSettlementTotalExpectedCash.
  ///
  /// In en, this message translates to:
  /// **'Total Expected Cash'**
  String get cashSettlementTotalExpectedCash;

  /// No description provided for @cashSettlementTodaysCashCount.
  ///
  /// In en, this message translates to:
  /// **'Today’s Cash Count'**
  String get cashSettlementTodaysCashCount;

  /// No description provided for @cashSettlementSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary:'**
  String get cashSettlementSummary;

  /// No description provided for @cashSettlementErrorCountMismatch.
  ///
  /// In en, this message translates to:
  /// **'Counted total does not match target amount!'**
  String get cashSettlementErrorCountMismatch;

  /// No description provided for @cashSettlementOpenSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Successfully Opened'**
  String get cashSettlementOpenSuccessTitle;

  /// No description provided for @cashSettlementOpenSuccessMsg.
  ///
  /// In en, this message translates to:
  /// **'Shift {count} opened successfully!'**
  String cashSettlementOpenSuccessMsg(Object count);

  /// No description provided for @cashSettlementOpenFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Open Failed'**
  String get cashSettlementOpenFailedTitle;

  /// No description provided for @cashSettlementCloseSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Successfully Closed & Save'**
  String get cashSettlementCloseSuccessTitle;

  /// No description provided for @cashSettlementCloseSuccessMsg.
  ///
  /// In en, this message translates to:
  /// **'Bosses ❤️ U!'**
  String get cashSettlementCloseSuccessMsg;

  /// No description provided for @cashSettlementCloseFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Close Failed'**
  String get cashSettlementCloseFailedTitle;

  /// No description provided for @cashSettlementErrorInputRevenue.
  ///
  /// In en, this message translates to:
  /// **'Please enter total revenue.'**
  String get cashSettlementErrorInputRevenue;

  /// No description provided for @cashSettlementDepositTitle.
  ///
  /// In en, this message translates to:
  /// **'Deposite Management'**
  String get cashSettlementDepositTitle;

  /// No description provided for @cashSettlementDepositAdd.
  ///
  /// In en, this message translates to:
  /// **'Add New Deposite'**
  String get cashSettlementDepositAdd;

  /// No description provided for @cashSettlementDepositEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit All Deposite'**
  String get cashSettlementDepositEdit;

  /// No description provided for @cashSettlementDepositRedeemTitle.
  ///
  /// In en, this message translates to:
  /// **'Redeem Today\'s Deposit'**
  String get cashSettlementDepositRedeemTitle;

  /// No description provided for @cashSettlementDepositNoUnredeemed.
  ///
  /// In en, this message translates to:
  /// **'No unredeemed deposits'**
  String get cashSettlementDepositNoUnredeemed;

  /// No description provided for @cashSettlementDepositTotalRedeemed.
  ///
  /// In en, this message translates to:
  /// **'Total Redeemed: \${amount}'**
  String cashSettlementDepositTotalRedeemed(Object amount);

  /// No description provided for @cashSettlementDepositAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Deposit'**
  String get cashSettlementDepositAddTitle;

  /// No description provided for @cashSettlementDepositEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Deposit'**
  String get cashSettlementDepositEditTitle;

  /// No description provided for @cashSettlementDepositPaymentDate.
  ///
  /// In en, this message translates to:
  /// **'Payment Date'**
  String get cashSettlementDepositPaymentDate;

  /// No description provided for @cashSettlementDepositReservationDate.
  ///
  /// In en, this message translates to:
  /// **'Reservation Date'**
  String get cashSettlementDepositReservationDate;

  /// No description provided for @cashSettlementDepositReservationTime.
  ///
  /// In en, this message translates to:
  /// **'Reservation Time'**
  String get cashSettlementDepositReservationTime;

  /// No description provided for @cashSettlementDepositName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get cashSettlementDepositName;

  /// No description provided for @cashSettlementDepositPax.
  ///
  /// In en, this message translates to:
  /// **'Party Size'**
  String get cashSettlementDepositPax;

  /// No description provided for @cashSettlementDepositAmount.
  ///
  /// In en, this message translates to:
  /// **'Deposit Amount'**
  String get cashSettlementDepositAmount;

  /// No description provided for @cashSettlementErrorInputDates.
  ///
  /// In en, this message translates to:
  /// **'Please select all dates and times.'**
  String get cashSettlementErrorInputDates;

  /// No description provided for @cashSettlementErrorInputAmount.
  ///
  /// In en, this message translates to:
  /// **'Please fill in name and valid amount'**
  String get cashSettlementErrorInputAmount;

  /// No description provided for @cashSettlementErrorTimePast.
  ///
  /// In en, this message translates to:
  /// **'Booking time cannot be in the past'**
  String get cashSettlementErrorTimePast;

  /// No description provided for @cashSettlementSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save Failed'**
  String get cashSettlementSaveFailed;

  /// No description provided for @depositScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Deposit Management'**
  String get depositScreenTitle;

  /// No description provided for @depositScreenNoRecords.
  ///
  /// In en, this message translates to:
  /// **'No unredeemed deposits'**
  String get depositScreenNoRecords;

  /// No description provided for @depositScreenLabelName.
  ///
  /// In en, this message translates to:
  /// **'Name: {name}'**
  String depositScreenLabelName(Object name);

  /// No description provided for @depositScreenLabelReservationDate.
  ///
  /// In en, this message translates to:
  /// **'Reservation Date: {date}'**
  String depositScreenLabelReservationDate(Object date);

  /// No description provided for @depositScreenLabelReservationTime.
  ///
  /// In en, this message translates to:
  /// **'Reservation Time: {time}'**
  String depositScreenLabelReservationTime(Object time);

  /// No description provided for @depositScreenLabelGroupSize.
  ///
  /// In en, this message translates to:
  /// **'Group Size: {size}'**
  String depositScreenLabelGroupSize(Object size);

  /// No description provided for @depositScreenDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete Deposit'**
  String get depositScreenDeleteConfirm;

  /// No description provided for @depositScreenDeleteContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure to delete this deposit?'**
  String get depositScreenDeleteContent;

  /// No description provided for @depositScreenDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Deposit deleted'**
  String get depositScreenDeleteSuccess;

  /// No description provided for @depositScreenDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String depositScreenDeleteFailed(Object error);

  /// No description provided for @depositScreenSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String depositScreenSaveFailed(Object error);

  /// No description provided for @depositScreenInputError.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all required fields (Name, Amount, Date/Time).'**
  String get depositScreenInputError;

  /// No description provided for @depositScreenTimeError.
  ///
  /// In en, this message translates to:
  /// **'Booking time cannot be in the past.'**
  String get depositScreenTimeError;

  /// No description provided for @depositDialogTitleAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Deposit'**
  String get depositDialogTitleAdd;

  /// No description provided for @depositDialogTitleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Deposit'**
  String get depositDialogTitleEdit;

  /// No description provided for @depositDialogHintPaymentDate.
  ///
  /// In en, this message translates to:
  /// **'Payment Date'**
  String get depositDialogHintPaymentDate;

  /// No description provided for @depositDialogHintReservationDate.
  ///
  /// In en, this message translates to:
  /// **'Reservation Date'**
  String get depositDialogHintReservationDate;

  /// No description provided for @depositDialogHintReservationTime.
  ///
  /// In en, this message translates to:
  /// **'Reservation Time'**
  String get depositDialogHintReservationTime;

  /// No description provided for @depositDialogHintName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get depositDialogHintName;

  /// No description provided for @depositDialogHintGroupSize.
  ///
  /// In en, this message translates to:
  /// **'Group Size'**
  String get depositDialogHintGroupSize;

  /// No description provided for @depositDialogHintAmount.
  ///
  /// In en, this message translates to:
  /// **'Deposit Amount'**
  String get depositDialogHintAmount;

  /// No description provided for @monthlyCostTitle.
  ///
  /// In en, this message translates to:
  /// **'Monthly Cost'**
  String get monthlyCostTitle;

  /// No description provided for @monthlyCostTotal.
  ///
  /// In en, this message translates to:
  /// **'Total cost of this month'**
  String get monthlyCostTotal;

  /// No description provided for @monthlyCostLabelName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get monthlyCostLabelName;

  /// No description provided for @monthlyCostLabelPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get monthlyCostLabelPrice;

  /// No description provided for @monthlyCostLabelNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get monthlyCostLabelNote;

  /// No description provided for @monthlyCostErrorInputTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get monthlyCostErrorInputTitle;

  /// No description provided for @monthlyCostErrorInputMsg.
  ///
  /// In en, this message translates to:
  /// **'Name and Price are required.'**
  String get monthlyCostErrorInputMsg;

  /// No description provided for @monthlyCostErrorSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save Failed'**
  String get monthlyCostErrorSaveFailed;

  /// No description provided for @monthlyCostSuccess.
  ///
  /// In en, this message translates to:
  /// **'Cost saved successfully'**
  String get monthlyCostSuccess;

  /// No description provided for @monthlyCostDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Monthly Cost Detail'**
  String get monthlyCostDetailTitle;

  /// No description provided for @monthlyCostDetailNoRecords.
  ///
  /// In en, this message translates to:
  /// **'No cost records for this month.'**
  String get monthlyCostDetailNoRecords;

  /// No description provided for @monthlyCostDetailItemUntitled.
  ///
  /// In en, this message translates to:
  /// **'No Item Name'**
  String get monthlyCostDetailItemUntitled;

  /// No description provided for @monthlyCostDetailCategoryNA.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get monthlyCostDetailCategoryNA;

  /// No description provided for @monthlyCostDetailBuyerNA.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get monthlyCostDetailBuyerNA;

  /// No description provided for @monthlyCostDetailLabelCategory.
  ///
  /// In en, this message translates to:
  /// **'Category: {category}'**
  String monthlyCostDetailLabelCategory(Object category);

  /// No description provided for @monthlyCostDetailLabelDate.
  ///
  /// In en, this message translates to:
  /// **'Date: {date}'**
  String monthlyCostDetailLabelDate(Object date);

  /// No description provided for @monthlyCostDetailLabelBuyer.
  ///
  /// In en, this message translates to:
  /// **'Buyer: {buyer}'**
  String monthlyCostDetailLabelBuyer(Object buyer);

  /// No description provided for @monthlyCostDetailEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Monthly Cost Detail'**
  String get monthlyCostDetailEditTitle;

  /// No description provided for @monthlyCostDetailDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Cost'**
  String get monthlyCostDetailDeleteTitle;

  /// No description provided for @monthlyCostDetailDeleteContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure to delete this cost?\n({name})'**
  String monthlyCostDetailDeleteContent(Object name);

  /// No description provided for @monthlyCostDetailErrorFetch.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch expenses: {error}'**
  String monthlyCostDetailErrorFetch(Object error);

  /// No description provided for @monthlyCostDetailErrorUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update Failed'**
  String get monthlyCostDetailErrorUpdate;

  /// No description provided for @monthlyCostDetailErrorDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Failed'**
  String get monthlyCostDetailErrorDelete;

  /// No description provided for @cashFlowTitle.
  ///
  /// In en, this message translates to:
  /// **'Cash Flow Report'**
  String get cashFlowTitle;

  /// No description provided for @cashFlowMonthlyRevenue.
  ///
  /// In en, this message translates to:
  /// **'Monthly Revenue'**
  String get cashFlowMonthlyRevenue;

  /// No description provided for @cashFlowMonthlyDifference.
  ///
  /// In en, this message translates to:
  /// **'Monthly Difference'**
  String get cashFlowMonthlyDifference;

  /// No description provided for @cashFlowLabelShift.
  ///
  /// In en, this message translates to:
  /// **'Shift {count}'**
  String cashFlowLabelShift(Object count);

  /// No description provided for @cashFlowLabelRevenue.
  ///
  /// In en, this message translates to:
  /// **'Total Revenue:'**
  String get cashFlowLabelRevenue;

  /// No description provided for @cashFlowLabelCost.
  ///
  /// In en, this message translates to:
  /// **'Total Cost:'**
  String get cashFlowLabelCost;

  /// No description provided for @cashFlowLabelDifference.
  ///
  /// In en, this message translates to:
  /// **'Cash Difference:'**
  String get cashFlowLabelDifference;

  /// No description provided for @cashFlowNoRecords.
  ///
  /// In en, this message translates to:
  /// **'No records found.'**
  String get cashFlowNoRecords;

  /// No description provided for @costReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Cost Summary'**
  String get costReportTitle;

  /// No description provided for @costReportMonthlyTotal.
  ///
  /// In en, this message translates to:
  /// **'Monthly Cost Total'**
  String get costReportMonthlyTotal;

  /// No description provided for @costReportNoRecords.
  ///
  /// In en, this message translates to:
  /// **'No cost records.'**
  String get costReportNoRecords;

  /// No description provided for @costReportNoRecordsShift.
  ///
  /// In en, this message translates to:
  /// **'No cost records for this shift.'**
  String get costReportNoRecordsShift;

  /// No description provided for @costReportLabelTotalCost.
  ///
  /// In en, this message translates to:
  /// **'Total Cost:'**
  String get costReportLabelTotalCost;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Operation Dashboard'**
  String get dashboardTitle;

  /// No description provided for @dashboardTotalRevenue.
  ///
  /// In en, this message translates to:
  /// **'Total Revenue'**
  String get dashboardTotalRevenue;

  /// No description provided for @dashboardCogs.
  ///
  /// In en, this message translates to:
  /// **'Cost of Revenue'**
  String get dashboardCogs;

  /// No description provided for @dashboardGrossProfit.
  ///
  /// In en, this message translates to:
  /// **'Gross Profit'**
  String get dashboardGrossProfit;

  /// No description provided for @dashboardGrossMargin.
  ///
  /// In en, this message translates to:
  /// **'Gross Margin'**
  String get dashboardGrossMargin;

  /// No description provided for @dashboardOpex.
  ///
  /// In en, this message translates to:
  /// **'Operation Expense'**
  String get dashboardOpex;

  /// No description provided for @dashboardOpIncome.
  ///
  /// In en, this message translates to:
  /// **'Operation Income'**
  String get dashboardOpIncome;

  /// No description provided for @dashboardNetIncome.
  ///
  /// In en, this message translates to:
  /// **'Net Income'**
  String get dashboardNetIncome;

  /// No description provided for @dashboardNetProfitMargin.
  ///
  /// In en, this message translates to:
  /// **'Net Profit Margin'**
  String get dashboardNetProfitMargin;

  /// No description provided for @dashboardNoCostData.
  ///
  /// In en, this message translates to:
  /// **'No cost data available'**
  String get dashboardNoCostData;

  /// No description provided for @dashboardErrorLoad.
  ///
  /// In en, this message translates to:
  /// **'Data load error: {error}'**
  String dashboardErrorLoad(Object error);

  /// No description provided for @reportingTitle.
  ///
  /// In en, this message translates to:
  /// **'Backstage'**
  String get reportingTitle;

  /// No description provided for @reportingCashFlow.
  ///
  /// In en, this message translates to:
  /// **'Cash Flow'**
  String get reportingCashFlow;

  /// No description provided for @reportingCostSum.
  ///
  /// In en, this message translates to:
  /// **'Cost Sum'**
  String get reportingCostSum;

  /// No description provided for @reportingDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get reportingDashboard;

  /// No description provided for @reportingCashVault.
  ///
  /// In en, this message translates to:
  /// **'Cash Vault'**
  String get reportingCashVault;

  /// No description provided for @reportingClockIn.
  ///
  /// In en, this message translates to:
  /// **'Clock-in'**
  String get reportingClockIn;

  /// No description provided for @reportingWorkReport.
  ///
  /// In en, this message translates to:
  /// **'Work Report'**
  String get reportingWorkReport;

  /// No description provided for @reportingNoAccess.
  ///
  /// In en, this message translates to:
  /// **'No accessible features'**
  String get reportingNoAccess;

  /// No description provided for @vaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Cash Flow'**
  String get vaultTitle;

  /// No description provided for @vaultTotalCash.
  ///
  /// In en, this message translates to:
  /// **'Total Cash'**
  String get vaultTotalCash;

  /// No description provided for @vaultTitleVault.
  ///
  /// In en, this message translates to:
  /// **'Vault'**
  String get vaultTitleVault;

  /// No description provided for @vaultTitleCashbox.
  ///
  /// In en, this message translates to:
  /// **'Cashbox'**
  String get vaultTitleCashbox;

  /// No description provided for @vaultCashDetail.
  ///
  /// In en, this message translates to:
  /// **'Cash Detail'**
  String get vaultCashDetail;

  /// No description provided for @vaultDetailDenom.
  ///
  /// In en, this message translates to:
  /// **'\$ {cashboxCount} X {totalCount} (Vault {cashboxCount} + Cashbox {vaultCount})'**
  String vaultDetailDenom(Object cashboxCount, Object totalCount, Object vaultCount);

  /// No description provided for @vaultActivityHistory.
  ///
  /// In en, this message translates to:
  /// **'Activity History'**
  String get vaultActivityHistory;

  /// No description provided for @vaultTableDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get vaultTableDate;

  /// No description provided for @vaultTableStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get vaultTableStaff;

  /// No description provided for @vaultNoRecords.
  ///
  /// In en, this message translates to:
  /// **'No activity records.'**
  String get vaultNoRecords;

  /// No description provided for @vaultManagementSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Vault Management'**
  String get vaultManagementSheetTitle;

  /// No description provided for @vaultAdjustCounts.
  ///
  /// In en, this message translates to:
  /// **'Adjust Vault Counts'**
  String get vaultAdjustCounts;

  /// No description provided for @vaultSaveMoney.
  ///
  /// In en, this message translates to:
  /// **'Save Money (Deposit)'**
  String get vaultSaveMoney;

  /// No description provided for @vaultChangeMoney.
  ///
  /// In en, this message translates to:
  /// **'Change Money'**
  String get vaultChangeMoney;

  /// No description provided for @vaultPromptAdjust.
  ///
  /// In en, this message translates to:
  /// **'Enter the TOTAL counts (Vault + Cashbox).'**
  String get vaultPromptAdjust;

  /// No description provided for @vaultPromptDeposit.
  ///
  /// In en, this message translates to:
  /// **'Enter amount to deposit to bank'**
  String get vaultPromptDeposit;

  /// No description provided for @vaultPromptChangeOut.
  ///
  /// In en, this message translates to:
  /// **'Take OUT large bills from Vault'**
  String get vaultPromptChangeOut;

  /// No description provided for @vaultPromptChangeIn.
  ///
  /// In en, this message translates to:
  /// **'Put IN small bills to Vault'**
  String get vaultPromptChangeIn;

  /// No description provided for @vaultErrorMismatch.
  ///
  /// In en, this message translates to:
  /// **'Amount mismatch! Exchange cancelled.'**
  String get vaultErrorMismatch;

  /// No description provided for @vaultDialogTotal.
  ///
  /// In en, this message translates to:
  /// **'Total: {amount}'**
  String vaultDialogTotal(Object amount);

  /// No description provided for @clockInReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Clock-in Report'**
  String get clockInReportTitle;

  /// No description provided for @clockInReportTotalHours.
  ///
  /// In en, this message translates to:
  /// **'Total Hours'**
  String get clockInReportTotalHours;

  /// No description provided for @clockInReportStaffCount.
  ///
  /// In en, this message translates to:
  /// **'Staff Count'**
  String get clockInReportStaffCount;

  /// No description provided for @clockInReportWorkDays.
  ///
  /// In en, this message translates to:
  /// **'Work Days'**
  String get clockInReportWorkDays;

  /// No description provided for @clockInReportUnitPpl.
  ///
  /// In en, this message translates to:
  /// **'ppl'**
  String get clockInReportUnitPpl;

  /// No description provided for @clockInReportUnitDays.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get clockInReportUnitDays;

  /// No description provided for @clockInReportUnitHr.
  ///
  /// In en, this message translates to:
  /// **'hr'**
  String get clockInReportUnitHr;

  /// No description provided for @clockInReportNoRecords.
  ///
  /// In en, this message translates to:
  /// **'No records found.'**
  String get clockInReportNoRecords;

  /// No description provided for @clockInReportLabelManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get clockInReportLabelManual;

  /// No description provided for @clockInReportLabelIn.
  ///
  /// In en, this message translates to:
  /// **'In'**
  String get clockInReportLabelIn;

  /// No description provided for @clockInReportLabelOut.
  ///
  /// In en, this message translates to:
  /// **'Out'**
  String get clockInReportLabelOut;

  /// No description provided for @clockInReportStatusWorking.
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get clockInReportStatusWorking;

  /// No description provided for @clockInReportStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get clockInReportStatusCompleted;

  /// No description provided for @clockInReportStatusIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Incomplete'**
  String get clockInReportStatusIncomplete;

  /// No description provided for @clockInReportAllStaff.
  ///
  /// In en, this message translates to:
  /// **'All Staff'**
  String get clockInReportAllStaff;

  /// No description provided for @clockInReportSelectStaff.
  ///
  /// In en, this message translates to:
  /// **'Select Staff'**
  String get clockInReportSelectStaff;

  /// No description provided for @clockInDetailTitleIn.
  ///
  /// In en, this message translates to:
  /// **'Clock In'**
  String get clockInDetailTitleIn;

  /// No description provided for @clockInDetailTitleOut.
  ///
  /// In en, this message translates to:
  /// **'Clock Out'**
  String get clockInDetailTitleOut;

  /// No description provided for @clockInDetailMissing.
  ///
  /// In en, this message translates to:
  /// **'Missing Record'**
  String get clockInDetailMissing;

  /// No description provided for @clockInDetailFixButton.
  ///
  /// In en, this message translates to:
  /// **'Fix Clock-out'**
  String get clockInDetailFixButton;

  /// No description provided for @clockInDetailCloseButton.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get clockInDetailCloseButton;

  /// No description provided for @clockInDetailLabelWifi.
  ///
  /// In en, this message translates to:
  /// **'WiFi: {wifi}'**
  String clockInDetailLabelWifi(Object wifi);

  /// No description provided for @clockInDetailLabelReason.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String clockInDetailLabelReason(Object reason);

  /// No description provided for @clockInDetailReasonSupervisorFix.
  ///
  /// In en, this message translates to:
  /// **'Supervisor Fix'**
  String get clockInDetailReasonSupervisorFix;

  /// No description provided for @clockInDetailErrorInLaterThanOut.
  ///
  /// In en, this message translates to:
  /// **'Clock-in cannot be later than Clock-out.'**
  String get clockInDetailErrorInLaterThanOut;

  /// No description provided for @clockInDetailErrorOutEarlierThanIn.
  ///
  /// In en, this message translates to:
  /// **'Clock-out cannot be earlier than Clock-in.'**
  String get clockInDetailErrorOutEarlierThanIn;

  /// No description provided for @clockInDetailErrorDateCheck.
  ///
  /// In en, this message translates to:
  /// **'Date Error: Please check if you selected the correct date (e.g., next day).'**
  String get clockInDetailErrorDateCheck;

  /// No description provided for @clockInDetailSuccessUpdate.
  ///
  /// In en, this message translates to:
  /// **'Time updated successfully.'**
  String get clockInDetailSuccessUpdate;

  /// No description provided for @clockInDetailSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Clock-out Date'**
  String get clockInDetailSelectDate;

  /// No description provided for @commonNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get commonNone;

  /// No description provided for @workReportOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Work Reports'**
  String get workReportOverviewTitle;

  /// No description provided for @workReportOverviewNoRecords.
  ///
  /// In en, this message translates to:
  /// **'No reports found.'**
  String get workReportOverviewNoRecords;

  /// No description provided for @workReportOverviewSelectStaff.
  ///
  /// In en, this message translates to:
  /// **'Select Staff'**
  String get workReportOverviewSelectStaff;

  /// No description provided for @workReportOverviewAllStaff.
  ///
  /// In en, this message translates to:
  /// **'All Staff'**
  String get workReportOverviewAllStaff;

  /// No description provided for @workReportOverviewNoSubject.
  ///
  /// In en, this message translates to:
  /// **'No Subject'**
  String get workReportOverviewNoSubject;

  /// No description provided for @workReportOverviewNoContent.
  ///
  /// In en, this message translates to:
  /// **'No Content'**
  String get workReportOverviewNoContent;

  /// No description provided for @workReportOverviewOvertimeTag.
  ///
  /// In en, this message translates to:
  /// **'OT: {hours}h'**
  String workReportOverviewOvertimeTag(Object hours);

  /// No description provided for @workReportDetailOvertimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Overtime: {hours} hr'**
  String workReportDetailOvertimeLabel(Object hours);

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @userMgmtTitle.
  ///
  /// In en, this message translates to:
  /// **'User Management'**
  String get userMgmtTitle;

  /// No description provided for @userMgmtInviteNewUser.
  ///
  /// In en, this message translates to:
  /// **'Invite New User'**
  String get userMgmtInviteNewUser;

  /// No description provided for @userMgmtStatusInvited.
  ///
  /// In en, this message translates to:
  /// **'Invited'**
  String get userMgmtStatusInvited;

  /// No description provided for @userMgmtStatusWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting...'**
  String get userMgmtStatusWaiting;

  /// No description provided for @userMgmtLabelRole.
  ///
  /// In en, this message translates to:
  /// **'Role: {roleName}'**
  String userMgmtLabelRole(Object roleName);

  /// No description provided for @userMgmtNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get userMgmtNameHint;

  /// No description provided for @userMgmtInviteNote.
  ///
  /// In en, this message translates to:
  /// **'User will receive an email invitation.'**
  String get userMgmtInviteNote;

  /// No description provided for @userMgmtInviteButton.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get userMgmtInviteButton;

  /// No description provided for @userMgmtEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit User Info'**
  String get userMgmtEditTitle;

  /// No description provided for @userMgmtDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete User'**
  String get userMgmtDeleteTitle;

  /// No description provided for @userMgmtDeleteContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure to delete {userName}?'**
  String userMgmtDeleteContent(Object userName);

  /// No description provided for @userMgmtErrorLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String userMgmtErrorLoad(Object error);

  /// No description provided for @userMgmtInviteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Invitation sent! The user will receive an email to join.'**
  String get userMgmtInviteSuccess;

  /// No description provided for @userMgmtInviteFailed.
  ///
  /// In en, this message translates to:
  /// **'Invitation failed: {error}'**
  String userMgmtInviteFailed(Object error);

  /// No description provided for @userMgmtErrorConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection error: {error}'**
  String userMgmtErrorConnection(Object error);

  /// No description provided for @userMgmtDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Deletion failed: {error}'**
  String userMgmtDeleteFailed(Object error);

  /// No description provided for @userMgmtLabelEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get userMgmtLabelEmail;

  /// No description provided for @userMgmtLabelRolePicker.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get userMgmtLabelRolePicker;

  /// No description provided for @userMgmtButtonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get userMgmtButtonDone;

  /// No description provided for @userMgmtLabelRoleSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get userMgmtLabelRoleSelect;

  /// No description provided for @roleMgmtTitle.
  ///
  /// In en, this message translates to:
  /// **'Role Management'**
  String get roleMgmtTitle;

  /// No description provided for @roleMgmtSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get roleMgmtSystemDefault;

  /// No description provided for @roleMgmtPermissionGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Permissions - {groupName}'**
  String roleMgmtPermissionGroupTitle(Object groupName);

  /// No description provided for @roleMgmtRoleNameHint.
  ///
  /// In en, this message translates to:
  /// **'Role Name'**
  String get roleMgmtRoleNameHint;

  /// No description provided for @roleMgmtSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get roleMgmtSaveButton;

  /// No description provided for @roleMgmtDeleteRole.
  ///
  /// In en, this message translates to:
  /// **'Delete Role'**
  String get roleMgmtDeleteRole;

  /// No description provided for @roleMgmtAddNewRole.
  ///
  /// In en, this message translates to:
  /// **'Add New Role'**
  String get roleMgmtAddNewRole;

  /// No description provided for @roleMgmtEnterRoleName.
  ///
  /// In en, this message translates to:
  /// **'Enter role name (e.g. Server)'**
  String get roleMgmtEnterRoleName;

  /// No description provided for @roleMgmtCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get roleMgmtCreateButton;

  /// No description provided for @roleMgmtDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Role'**
  String get roleMgmtDeleteConfirmTitle;

  /// No description provided for @roleMgmtDeleteConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this role? This action cannot be undone.'**
  String get roleMgmtDeleteConfirmContent;

  /// No description provided for @roleMgmtCannotDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Cannot Delete Role'**
  String get roleMgmtCannotDeleteTitle;

  /// No description provided for @roleMgmtCannotDeleteContent.
  ///
  /// In en, this message translates to:
  /// **'There are still {count} users assigned to the role \"{roleName}\".\n\nPlease assign them to a different role before deleting.'**
  String roleMgmtCannotDeleteContent(Object count, Object roleName);

  /// No description provided for @roleMgmtUnderstandButton.
  ///
  /// In en, this message translates to:
  /// **'I Understand'**
  String get roleMgmtUnderstandButton;

  /// No description provided for @roleMgmtErrorLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load roles: {error}'**
  String roleMgmtErrorLoad(Object error);

  /// No description provided for @roleMgmtErrorSave.
  ///
  /// In en, this message translates to:
  /// **'Error saving permissions: {error}'**
  String roleMgmtErrorSave(Object error);

  /// No description provided for @roleMgmtErrorAdd.
  ///
  /// In en, this message translates to:
  /// **'Error adding role: {error}'**
  String roleMgmtErrorAdd(Object error);

  /// No description provided for @commonNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get commonNotificationTitle;

  /// No description provided for @permGroupMainScreen.
  ///
  /// In en, this message translates to:
  /// **'Main Screen'**
  String get permGroupMainScreen;

  /// No description provided for @permGroupSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get permGroupSchedule;

  /// No description provided for @permGroupBackstageDashboard.
  ///
  /// In en, this message translates to:
  /// **'Backstage Dashboard'**
  String get permGroupBackstageDashboard;

  /// No description provided for @permGroupSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get permGroupSettings;

  /// No description provided for @permHomeOrder.
  ///
  /// In en, this message translates to:
  /// **'Take Orders'**
  String get permHomeOrder;

  /// No description provided for @permHomePrep.
  ///
  /// In en, this message translates to:
  /// **'Prep List'**
  String get permHomePrep;

  /// No description provided for @permHomeStock.
  ///
  /// In en, this message translates to:
  /// **'Stock/Inventory'**
  String get permHomeStock;

  /// No description provided for @permHomeBackDashboard.
  ///
  /// In en, this message translates to:
  /// **'Backstage Dashboard'**
  String get permHomeBackDashboard;

  /// No description provided for @permHomeDailyCost.
  ///
  /// In en, this message translates to:
  /// **'Daily Cost Input'**
  String get permHomeDailyCost;

  /// No description provided for @permHomeCashFlow.
  ///
  /// In en, this message translates to:
  /// **'Cash Flow Report'**
  String get permHomeCashFlow;

  /// No description provided for @permHomeMonthlyCost.
  ///
  /// In en, this message translates to:
  /// **'Monthly Cost Input'**
  String get permHomeMonthlyCost;

  /// No description provided for @permHomeScan.
  ///
  /// In en, this message translates to:
  /// **'Smart Scan'**
  String get permHomeScan;

  /// No description provided for @permScheduleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Staff Schedule'**
  String get permScheduleEdit;

  /// No description provided for @permBackCashFlow.
  ///
  /// In en, this message translates to:
  /// **'Cash Flow Report'**
  String get permBackCashFlow;

  /// No description provided for @permBackCostSum.
  ///
  /// In en, this message translates to:
  /// **'Cost Sum Report'**
  String get permBackCostSum;

  /// No description provided for @permBackDashboard.
  ///
  /// In en, this message translates to:
  /// **'Operation Dashboard'**
  String get permBackDashboard;

  /// No description provided for @permBackCashVault.
  ///
  /// In en, this message translates to:
  /// **'Cash Vault Management'**
  String get permBackCashVault;

  /// No description provided for @permBackClockIn.
  ///
  /// In en, this message translates to:
  /// **'Clock-in Report'**
  String get permBackClockIn;

  /// No description provided for @permBackViewAllClockIn.
  ///
  /// In en, this message translates to:
  /// **'View All Staff Clock-ins'**
  String get permBackViewAllClockIn;

  /// No description provided for @permBackWorkReport.
  ///
  /// In en, this message translates to:
  /// **'Work Report Overview'**
  String get permBackWorkReport;

  /// No description provided for @permSetStaff.
  ///
  /// In en, this message translates to:
  /// **'Manage Users'**
  String get permSetStaff;

  /// No description provided for @permSetRole.
  ///
  /// In en, this message translates to:
  /// **'Role Management'**
  String get permSetRole;

  /// No description provided for @permSetPrinter.
  ///
  /// In en, this message translates to:
  /// **'Printer Settings'**
  String get permSetPrinter;

  /// No description provided for @permSetTableMap.
  ///
  /// In en, this message translates to:
  /// **'Table Map Management'**
  String get permSetTableMap;

  /// No description provided for @permSetTableList.
  ///
  /// In en, this message translates to:
  /// **'Table Status List'**
  String get permSetTableList;

  /// No description provided for @permSetMenu.
  ///
  /// In en, this message translates to:
  /// **'Edit Menu'**
  String get permSetMenu;

  /// No description provided for @permSetShift.
  ///
  /// In en, this message translates to:
  /// **'Shift Settings'**
  String get permSetShift;

  /// No description provided for @permSetPunch.
  ///
  /// In en, this message translates to:
  /// **'Punch Settings'**
  String get permSetPunch;

  /// No description provided for @permSetPay.
  ///
  /// In en, this message translates to:
  /// **'Payment Methods'**
  String get permSetPay;

  /// No description provided for @permSetCostCat.
  ///
  /// In en, this message translates to:
  /// **'Cost Category Settings'**
  String get permSetCostCat;

  /// No description provided for @permSetInv.
  ///
  /// In en, this message translates to:
  /// **'Inventory & Items'**
  String get permSetInv;

  /// No description provided for @permSetCashReg.
  ///
  /// In en, this message translates to:
  /// **'Cash Register Settings'**
  String get permSetCashReg;

  /// No description provided for @stockCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Prep Details'**
  String get stockCategoryTitle;

  /// No description provided for @stockCategoryAddButton.
  ///
  /// In en, this message translates to:
  /// **'＋ Add New Category'**
  String get stockCategoryAddButton;

  /// No description provided for @stockCategoryAddDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add New Category'**
  String get stockCategoryAddDialogTitle;

  /// No description provided for @stockCategoryEditDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Category'**
  String get stockCategoryEditDialogTitle;

  /// No description provided for @stockCategoryHintName.
  ///
  /// In en, this message translates to:
  /// **'Category Name'**
  String get stockCategoryHintName;

  /// No description provided for @stockCategoryDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Category'**
  String get stockCategoryDeleteTitle;

  /// No description provided for @stockCategoryDeleteContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure to delete Category: {categoryName}?'**
  String stockCategoryDeleteContent(Object categoryName);

  /// No description provided for @inventoryCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Stock List'**
  String get inventoryCategoryTitle;

  /// No description provided for @inventoryManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'Inventory Management'**
  String get inventoryManagementTitle;

  /// No description provided for @inventoryCategoryDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Product List'**
  String get inventoryCategoryDetailTitle;

  /// No description provided for @inventoryCategoryAddButton.
  ///
  /// In en, this message translates to:
  /// **'＋ Add New Category'**
  String get inventoryCategoryAddButton;

  /// No description provided for @inventoryCategoryAddDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add New Category'**
  String get inventoryCategoryAddDialogTitle;

  /// No description provided for @inventoryCategoryEditDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Category'**
  String get inventoryCategoryEditDialogTitle;

  /// No description provided for @inventoryCategoryHintName.
  ///
  /// In en, this message translates to:
  /// **'Category Name'**
  String get inventoryCategoryHintName;

  /// No description provided for @inventoryCategoryDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Category'**
  String get inventoryCategoryDeleteTitle;

  /// No description provided for @inventoryCategoryDeleteContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure to delete Category: {categoryName}?'**
  String inventoryCategoryDeleteContent(Object categoryName);

  /// No description provided for @inventoryItemAddButton.
  ///
  /// In en, this message translates to:
  /// **'＋ Add New Product'**
  String get inventoryItemAddButton;

  /// No description provided for @inventoryItemAddDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add New Product'**
  String get inventoryItemAddDialogTitle;

  /// No description provided for @inventoryItemEditDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Product'**
  String get inventoryItemEditDialogTitle;

  /// No description provided for @inventoryItemDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Product'**
  String get inventoryItemDeleteTitle;

  /// No description provided for @inventoryItemDeleteContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure to delete {itemName}?'**
  String inventoryItemDeleteContent(Object itemName);

  /// No description provided for @inventoryItemHintName.
  ///
  /// In en, this message translates to:
  /// **'Product Name'**
  String get inventoryItemHintName;

  /// No description provided for @inventoryItemHintUnit.
  ///
  /// In en, this message translates to:
  /// **'Product Unit'**
  String get inventoryItemHintUnit;

  /// No description provided for @inventoryItemHintStock.
  ///
  /// In en, this message translates to:
  /// **'Current Inventory Number'**
  String get inventoryItemHintStock;

  /// No description provided for @inventoryItemHintPar.
  ///
  /// In en, this message translates to:
  /// **'Safety Inventory Quantity'**
  String get inventoryItemHintPar;

  /// No description provided for @stockItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Product Info'**
  String get stockItemTitle;

  /// No description provided for @stockItemLabelName.
  ///
  /// In en, this message translates to:
  /// **'Product Name'**
  String get stockItemLabelName;

  /// No description provided for @stockItemLabelMainIngredients.
  ///
  /// In en, this message translates to:
  /// **'Main Ingredients'**
  String get stockItemLabelMainIngredients;

  /// No description provided for @stockItemLabelSubsidiaryIngredients.
  ///
  /// In en, this message translates to:
  /// **'Subsidiary Ingredient'**
  String get stockItemLabelSubsidiaryIngredients;

  /// No description provided for @stockItemLabelDetails.
  ///
  /// In en, this message translates to:
  /// **'Details {index}'**
  String stockItemLabelDetails(Object index);

  /// No description provided for @stockItemHintIngredient.
  ///
  /// In en, this message translates to:
  /// **'Ingredient'**
  String get stockItemHintIngredient;

  /// No description provided for @stockItemHintQty.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get stockItemHintQty;

  /// No description provided for @stockItemHintUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get stockItemHintUnit;

  /// No description provided for @stockItemHintInstructionsSub.
  ///
  /// In en, this message translates to:
  /// **'Instructions Details of Subsidiary'**
  String get stockItemHintInstructionsSub;

  /// No description provided for @stockItemHintInstructionsNote.
  ///
  /// In en, this message translates to:
  /// **'Instructions Details of Product'**
  String get stockItemHintInstructionsNote;

  /// No description provided for @stockItemAddSubDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Subsidiary Ingredient'**
  String get stockItemAddSubDialogTitle;

  /// No description provided for @stockItemEditSubDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Subsidiary Category'**
  String get stockItemEditSubDialogTitle;

  /// No description provided for @stockItemAddSubHintGroupName.
  ///
  /// In en, this message translates to:
  /// **'Group Name (e.g., Garnish)'**
  String get stockItemAddSubHintGroupName;

  /// No description provided for @stockItemAddOptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Subsidiary Ingredient or Detail'**
  String get stockItemAddOptionTitle;

  /// No description provided for @stockItemAddOptionSub.
  ///
  /// In en, this message translates to:
  /// **'Add Subsidiary Ingredient'**
  String get stockItemAddOptionSub;

  /// No description provided for @stockItemAddOptionDetail.
  ///
  /// In en, this message translates to:
  /// **'Add Detail'**
  String get stockItemAddOptionDetail;

  /// No description provided for @stockItemDeleteSubTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Subsidiary Ingredient'**
  String get stockItemDeleteSubTitle;

  /// No description provided for @stockItemDeleteSubContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure to delete this subsidiary ingredient and its notes?'**
  String get stockItemDeleteSubContent;

  /// No description provided for @stockItemDeleteNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Note'**
  String get stockItemDeleteNoteTitle;

  /// No description provided for @stockItemDeleteNoteContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure to delete this note?'**
  String get stockItemDeleteNoteContent;

  /// No description provided for @stockCategoryDetailItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Product List'**
  String get stockCategoryDetailItemTitle;

  /// No description provided for @stockCategoryDetailAddItemButton.
  ///
  /// In en, this message translates to:
  /// **'＋ Add New Product'**
  String get stockCategoryDetailAddItemButton;

  /// No description provided for @stockItemDetailDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Product'**
  String get stockItemDetailDeleteTitle;

  /// No description provided for @stockItemDetailDeleteContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure to delete {productName}?'**
  String stockItemDetailDeleteContent(Object productName);

  /// No description provided for @inventoryLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Stock Logs'**
  String get inventoryLogTitle;

  /// No description provided for @inventoryLogSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search Stock Item'**
  String get inventoryLogSearchHint;

  /// No description provided for @inventoryLogAllDates.
  ///
  /// In en, this message translates to:
  /// **'All Dates'**
  String get inventoryLogAllDates;

  /// No description provided for @inventoryLogDatePickerConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get inventoryLogDatePickerConfirm;

  /// No description provided for @inventoryLogReasonAll.
  ///
  /// In en, this message translates to:
  /// **'ALL'**
  String get inventoryLogReasonAll;

  /// No description provided for @inventoryLogReasonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get inventoryLogReasonAdd;

  /// No description provided for @inventoryLogReasonAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Inventory Adjustment'**
  String get inventoryLogReasonAdjustment;

  /// No description provided for @inventoryLogReasonWaste.
  ///
  /// In en, this message translates to:
  /// **'Waste'**
  String get inventoryLogReasonWaste;

  /// No description provided for @inventoryLogNoRecords.
  ///
  /// In en, this message translates to:
  /// **'No logs found.'**
  String get inventoryLogNoRecords;

  /// No description provided for @inventoryLogCardUnknownItem.
  ///
  /// In en, this message translates to:
  /// **'Unknown Item'**
  String get inventoryLogCardUnknownItem;

  /// No description provided for @inventoryLogCardUnknownUser.
  ///
  /// In en, this message translates to:
  /// **'Unknown Operator'**
  String get inventoryLogCardUnknownUser;

  /// No description provided for @inventoryLogCardLabelName.
  ///
  /// In en, this message translates to:
  /// **'Name: {userName}'**
  String inventoryLogCardLabelName(Object userName);

  /// No description provided for @inventoryLogCardLabelChange.
  ///
  /// In en, this message translates to:
  /// **'Change: {adjustment} {unit}'**
  String inventoryLogCardLabelChange(Object adjustment, Object unit);

  /// No description provided for @inventoryLogCardLabelStock.
  ///
  /// In en, this message translates to:
  /// **'Number {oldStock}→{newStock}'**
  String inventoryLogCardLabelStock(Object newStock, Object oldStock);

  /// No description provided for @printerSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Hardware Setting'**
  String get printerSettingsTitle;

  /// No description provided for @printerSettingsListTitle.
  ///
  /// In en, this message translates to:
  /// **'Printer List'**
  String get printerSettingsListTitle;

  /// No description provided for @printerSettingsNoPrinters.
  ///
  /// In en, this message translates to:
  /// **'No printers currently configured'**
  String get printerSettingsNoPrinters;

  /// No description provided for @printerSettingsLabelIP.
  ///
  /// In en, this message translates to:
  /// **'IP: {ip}'**
  String printerSettingsLabelIP(Object ip);

  /// No description provided for @printerDialogAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add New Printer'**
  String get printerDialogAddTitle;

  /// No description provided for @printerDialogEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Printer Info'**
  String get printerDialogEditTitle;

  /// No description provided for @printerDialogHintName.
  ///
  /// In en, this message translates to:
  /// **'Printer Name'**
  String get printerDialogHintName;

  /// No description provided for @printerDialogHintIP.
  ///
  /// In en, this message translates to:
  /// **'Printer IP Address'**
  String get printerDialogHintIP;

  /// No description provided for @printerTestConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'❌ Printer connection failed'**
  String get printerTestConnectionFailed;

  /// No description provided for @printerTestTicketSuccess.
  ///
  /// In en, this message translates to:
  /// **'✅ Test ticket printed'**
  String get printerTestTicketSuccess;

  /// No description provided for @printerCashDrawerOpenSuccess.
  ///
  /// In en, this message translates to:
  /// **'✅ Cash drawer opened'**
  String get printerCashDrawerOpenSuccess;

  /// No description provided for @printerDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Printer'**
  String get printerDeleteTitle;

  /// No description provided for @printerDeleteContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure to delete {printerName}?'**
  String printerDeleteContent(Object printerName);

  /// No description provided for @printerTestPrintTitle.
  ///
  /// In en, this message translates to:
  /// **'【TICKET TEST】'**
  String get printerTestPrintTitle;

  /// No description provided for @printerTestPrintSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Testing printer connection'**
  String get printerTestPrintSubtitle;

  /// No description provided for @printerTestPrintContent1.
  ///
  /// In en, this message translates to:
  /// **'This is a test ticket,'**
  String get printerTestPrintContent1;

  /// No description provided for @printerTestPrintContent2.
  ///
  /// In en, this message translates to:
  /// **'If you see this text,'**
  String get printerTestPrintContent2;

  /// No description provided for @printerTestPrintContent3.
  ///
  /// In en, this message translates to:
  /// **'It means text and image printing are normal.'**
  String get printerTestPrintContent3;

  /// No description provided for @printerTestPrintContent4.
  ///
  /// In en, this message translates to:
  /// **'It means text and image printing are normal.'**
  String get printerTestPrintContent4;

  /// No description provided for @printerTestPrintContent5.
  ///
  /// In en, this message translates to:
  /// **'Thank you for using Gallery 20.5'**
  String get printerTestPrintContent5;

  /// No description provided for @tableMapAreaSuffix.
  ///
  /// In en, this message translates to:
  /// **' Zone'**
  String get tableMapAreaSuffix;

  /// No description provided for @tableMapRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Table'**
  String get tableMapRemoveTitle;

  /// No description provided for @tableMapRemoveContent.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{tableName}\" from map?'**
  String tableMapRemoveContent(Object tableName);

  /// No description provided for @tableMapRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get tableMapRemoveConfirm;

  /// No description provided for @tableMapAddDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Table'**
  String get tableMapAddDialogTitle;

  /// No description provided for @tableMapShapeCircle.
  ///
  /// In en, this message translates to:
  /// **'Circle'**
  String get tableMapShapeCircle;

  /// No description provided for @tableMapShapeSquare.
  ///
  /// In en, this message translates to:
  /// **'Square'**
  String get tableMapShapeSquare;

  /// No description provided for @tableMapShapeRect.
  ///
  /// In en, this message translates to:
  /// **'Rect'**
  String get tableMapShapeRect;

  /// No description provided for @tableMapAddDialogHint.
  ///
  /// In en, this message translates to:
  /// **'Select Table No.'**
  String get tableMapAddDialogHint;

  /// No description provided for @tableMapNoAvailableTables.
  ///
  /// In en, this message translates to:
  /// **'No available tables in this zone.'**
  String get tableMapNoAvailableTables;

  /// No description provided for @tableMgmtTitle.
  ///
  /// In en, this message translates to:
  /// **'Table Management'**
  String get tableMgmtTitle;

  /// No description provided for @tableMgmtAreaListAddButton.
  ///
  /// In en, this message translates to:
  /// **'＋ Add New Area'**
  String get tableMgmtAreaListAddButton;

  /// No description provided for @tableMgmtAreaListAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add New Zone'**
  String get tableMgmtAreaListAddTitle;

  /// No description provided for @tableMgmtAreaListEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Zone'**
  String get tableMgmtAreaListEditTitle;

  /// No description provided for @tableMgmtAreaListHintName.
  ///
  /// In en, this message translates to:
  /// **'Zone Name'**
  String get tableMgmtAreaListHintName;

  /// No description provided for @tableMgmtAreaListDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Zone'**
  String get tableMgmtAreaListDeleteTitle;

  /// No description provided for @tableMgmtAreaListDeleteContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure to delete Zone {areaName}?'**
  String tableMgmtAreaListDeleteContent(Object areaName);

  /// No description provided for @tableMgmtAreaAddSuccess.
  ///
  /// In en, this message translates to:
  /// **'✅ Zone \"{name}\" added successfully'**
  String tableMgmtAreaAddSuccess(Object name);

  /// No description provided for @tableMgmtAreaAddFailure.
  ///
  /// In en, this message translates to:
  /// **'Failed to add zone'**
  String get tableMgmtAreaAddFailure;

  /// No description provided for @tableMgmtTableListAddButton.
  ///
  /// In en, this message translates to:
  /// **'＋ Add New Table'**
  String get tableMgmtTableListAddButton;

  /// No description provided for @tableMgmtTableListAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add New Table'**
  String get tableMgmtTableListAddTitle;

  /// No description provided for @tableMgmtTableListEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Table'**
  String get tableMgmtTableListEditTitle;

  /// No description provided for @tableMgmtTableListHintName.
  ///
  /// In en, this message translates to:
  /// **'Table Name'**
  String get tableMgmtTableListHintName;

  /// No description provided for @tableMgmtTableListDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Table'**
  String get tableMgmtTableListDeleteTitle;

  /// No description provided for @tableMgmtTableListDeleteContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure to delete Table {tableName}?'**
  String tableMgmtTableListDeleteContent(Object tableName);

  /// No description provided for @tableMgmtTableAddFailure.
  ///
  /// In en, this message translates to:
  /// **'Failed to add table'**
  String get tableMgmtTableAddFailure;

  /// No description provided for @tableMgmtTableDeleteFailure.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete table'**
  String get tableMgmtTableDeleteFailure;

  /// No description provided for @commonSaveFailure.
  ///
  /// In en, this message translates to:
  /// **'Failed to save data.'**
  String get commonSaveFailure;

  /// No description provided for @commonDeleteFailure.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete item.'**
  String get commonDeleteFailure;

  /// No description provided for @commonNameExists.
  ///
  /// In en, this message translates to:
  /// **'Name already exists.'**
  String get commonNameExists;

  /// No description provided for @menuEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Menu'**
  String get menuEditTitle;

  /// No description provided for @menuCategoryAddButton.
  ///
  /// In en, this message translates to:
  /// **'＋ Add New Category'**
  String get menuCategoryAddButton;

  /// No description provided for @menuDetailAddItemButton.
  ///
  /// In en, this message translates to:
  /// **'＋ Add New Product'**
  String get menuDetailAddItemButton;

  /// No description provided for @menuDeleteCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Category'**
  String get menuDeleteCategoryTitle;

  /// No description provided for @menuDeleteCategoryContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure to delete {categoryName}?'**
  String menuDeleteCategoryContent(Object categoryName);

  /// No description provided for @menuCategoryAddDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add New Category'**
  String get menuCategoryAddDialogTitle;

  /// No description provided for @menuCategoryEditDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Category Name'**
  String get menuCategoryEditDialogTitle;

  /// No description provided for @menuCategoryHintName.
  ///
  /// In en, this message translates to:
  /// **'Category Name'**
  String get menuCategoryHintName;

  /// No description provided for @menuItemAddDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add New Product'**
  String get menuItemAddDialogTitle;

  /// No description provided for @menuItemEditDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Product'**
  String get menuItemEditDialogTitle;

  /// No description provided for @menuItemPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Current Price'**
  String get menuItemPriceLabel;

  /// No description provided for @menuItemMarketPrice.
  ///
  /// In en, this message translates to:
  /// **'Market Price'**
  String get menuItemMarketPrice;

  /// No description provided for @menuItemHintPrice.
  ///
  /// In en, this message translates to:
  /// **'Product Price'**
  String get menuItemHintPrice;

  /// No description provided for @menuItemLabelMarketPrice.
  ///
  /// In en, this message translates to:
  /// **'Market Price'**
  String get menuItemLabelMarketPrice;

  /// No description provided for @menuItemLabelPrice.
  ///
  /// In en, this message translates to:
  /// **'Price: {price}'**
  String menuItemLabelPrice(Object price);

  /// No description provided for @shiftSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Shift Setup'**
  String get shiftSetupTitle;

  /// No description provided for @shiftSetupSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Defined Shift Types'**
  String get shiftSetupSectionTitle;

  /// No description provided for @shiftSetupListAddButton.
  ///
  /// In en, this message translates to:
  /// **'+ Add Shift Type'**
  String get shiftSetupListAddButton;

  /// No description provided for @shiftSetupSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get shiftSetupSaveButton;

  /// No description provided for @shiftListStartTime.
  ///
  /// In en, this message translates to:
  /// **'{startTime} - {endTime}'**
  String shiftListStartTime(Object endTime, Object startTime);

  /// No description provided for @shiftDialogAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Shift Type'**
  String get shiftDialogAddTitle;

  /// No description provided for @shiftDialogEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Shift Type'**
  String get shiftDialogEditTitle;

  /// No description provided for @shiftDialogHintName.
  ///
  /// In en, this message translates to:
  /// **'Shift Name'**
  String get shiftDialogHintName;

  /// No description provided for @shiftDialogLabelStartTime.
  ///
  /// In en, this message translates to:
  /// **'Start Time:'**
  String get shiftDialogLabelStartTime;

  /// No description provided for @shiftDialogLabelEndTime.
  ///
  /// In en, this message translates to:
  /// **'End Time:'**
  String get shiftDialogLabelEndTime;

  /// No description provided for @shiftDialogLabelColor.
  ///
  /// In en, this message translates to:
  /// **'Color Tag:'**
  String get shiftDialogLabelColor;

  /// No description provided for @shiftDialogErrorNameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a shift name.'**
  String get shiftDialogErrorNameEmpty;

  /// No description provided for @shiftDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get shiftDeleteConfirmTitle;

  /// No description provided for @shiftDeleteConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the shift type \"{shiftName}\"? This change must be saved.'**
  String shiftDeleteConfirmContent(Object shiftName);

  /// No description provided for @shiftDeleteLocalSuccess.
  ///
  /// In en, this message translates to:
  /// **'Shift type \"{shiftName}\" deleted locally.'**
  String shiftDeleteLocalSuccess(Object shiftName);

  /// No description provided for @shiftSaveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Shift settings saved successfully!'**
  String get shiftSaveSuccess;

  /// No description provided for @shiftSaveError.
  ///
  /// In en, this message translates to:
  /// **'Failed to save settings: {error}'**
  String shiftSaveError(Object error);

  /// No description provided for @shiftLoadError.
  ///
  /// In en, this message translates to:
  /// **'Error loading shifts: {error}'**
  String shiftLoadError(Object error);

  /// No description provided for @commonSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get commonSuccess;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonError;

  /// No description provided for @punchInSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Clock-in Info'**
  String get punchInSetupTitle;

  /// No description provided for @punchInWifiSection.
  ///
  /// In en, this message translates to:
  /// **'Current Wi-Fi Name'**
  String get punchInWifiSection;

  /// No description provided for @punchInLocationSection.
  ///
  /// In en, this message translates to:
  /// **'Current Location'**
  String get punchInLocationSection;

  /// No description provided for @punchInLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get punchInLoading;

  /// No description provided for @punchInErrorPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Permission Error'**
  String get punchInErrorPermissionTitle;

  /// No description provided for @punchInErrorPermissionContent.
  ///
  /// In en, this message translates to:
  /// **'Please enable location permission to use this feature.'**
  String get punchInErrorPermissionContent;

  /// No description provided for @punchInErrorFetchTitle.
  ///
  /// In en, this message translates to:
  /// **'Failed to Get Info'**
  String get punchInErrorFetchTitle;

  /// No description provided for @punchInErrorFetchContent.
  ///
  /// In en, this message translates to:
  /// **'Failed to get Wi-Fi or GPS information. Please check permissions and network connection.'**
  String get punchInErrorFetchContent;

  /// No description provided for @punchInSaveFailureTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get punchInSaveFailureTitle;

  /// No description provided for @punchInSaveFailureContent.
  ///
  /// In en, this message translates to:
  /// **'Failed to get necessary information.'**
  String get punchInSaveFailureContent;

  /// No description provided for @punchInSaveSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get punchInSaveSuccessTitle;

  /// No description provided for @punchInSaveSuccessContent.
  ///
  /// In en, this message translates to:
  /// **'Clock-in information saved.'**
  String get punchInSaveSuccessContent;

  /// No description provided for @punchInRegainButton.
  ///
  /// In en, this message translates to:
  /// **'Regain Wi-Fi & Location'**
  String get punchInRegainButton;

  /// No description provided for @punchInSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save Clock-in Info'**
  String get punchInSaveButton;

  /// No description provided for @punchInConfirmOverwriteTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Overwrite'**
  String get punchInConfirmOverwriteTitle;

  /// No description provided for @punchInConfirmOverwriteContent.
  ///
  /// In en, this message translates to:
  /// **'Clock-in information already exists for this shop. Do you want to overwrite the existing data?'**
  String get punchInConfirmOverwriteContent;

  /// No description provided for @commonOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get commonOverwrite;

  /// No description provided for @commonOK.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOK;

  /// No description provided for @paymentSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment Setup'**
  String get paymentSetupTitle;

  /// No description provided for @paymentSetupMethodsSection.
  ///
  /// In en, this message translates to:
  /// **'Enabled Payment Methods'**
  String get paymentSetupMethodsSection;

  /// No description provided for @paymentSetupFunctionModule.
  ///
  /// In en, this message translates to:
  /// **'Function Module'**
  String get paymentSetupFunctionModule;

  /// No description provided for @paymentSetupFunctionDeposit.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get paymentSetupFunctionDeposit;

  /// No description provided for @paymentSetupSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get paymentSetupSaveButton;

  /// No description provided for @paymentSetupLoadError.
  ///
  /// In en, this message translates to:
  /// **'Error loading shifts: {error}'**
  String paymentSetupLoadError(Object error);

  /// No description provided for @paymentSetupSaveSuccess.
  ///
  /// In en, this message translates to:
  /// **'✅ Settings saved'**
  String get paymentSetupSaveSuccess;

  /// No description provided for @paymentSetupSaveFailure.
  ///
  /// In en, this message translates to:
  /// **'Saving failed: {error}'**
  String paymentSetupSaveFailure(Object error);

  /// No description provided for @paymentAddDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'＋Add Payment Method'**
  String get paymentAddDialogTitle;

  /// No description provided for @paymentAddDialogHintName.
  ///
  /// In en, this message translates to:
  /// **'Method Name'**
  String get paymentAddDialogHintName;

  /// No description provided for @settlementDetailDailyRevenueSummary.
  ///
  /// In en, this message translates to:
  /// **'Daily Revenue Summary'**
  String get settlementDetailDailyRevenueSummary;

  /// No description provided for @settlementDetailPaymentDetails.
  ///
  /// In en, this message translates to:
  /// **'Payment Details'**
  String get settlementDetailPaymentDetails;

  /// No description provided for @settlementDetailCashCount.
  ///
  /// In en, this message translates to:
  /// **'Cash Count'**
  String get settlementDetailCashCount;

  /// No description provided for @settlementDetailValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get settlementDetailValue;

  /// No description provided for @settlementDetailSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get settlementDetailSummary;

  /// No description provided for @settlementDetailTotalRevenue.
  ///
  /// In en, this message translates to:
  /// **'Total Revenue:'**
  String get settlementDetailTotalRevenue;

  /// No description provided for @settlementDetailTotalCost.
  ///
  /// In en, this message translates to:
  /// **'Total Cost:'**
  String get settlementDetailTotalCost;

  /// No description provided for @settlementDetailCash.
  ///
  /// In en, this message translates to:
  /// **'Cash:'**
  String get settlementDetailCash;

  /// No description provided for @settlementDetailTodayDeposit.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Deposit:'**
  String get settlementDetailTodayDeposit;

  /// No description provided for @vaultChangeMoneyStep1.
  ///
  /// In en, this message translates to:
  /// **'Change Money (Step 1/2)'**
  String get vaultChangeMoneyStep1;

  /// No description provided for @vaultChangeMoneyStep2.
  ///
  /// In en, this message translates to:
  /// **'Change Money (Step 2/2)'**
  String get vaultChangeMoneyStep2;

  /// No description provided for @vaultSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String vaultSaveFailed(Object error);

  /// No description provided for @paymentAddDialogSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get paymentAddDialogSave;

  /// No description provided for @costCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Cost Category'**
  String get costCategoryTitle;

  /// No description provided for @costCategoryAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add New Category'**
  String get costCategoryAddButton;

  /// No description provided for @costCategoryTypeCOGS.
  ///
  /// In en, this message translates to:
  /// **'COGS'**
  String get costCategoryTypeCOGS;

  /// No description provided for @costCategoryTypeOPEX.
  ///
  /// In en, this message translates to:
  /// **'OPEX'**
  String get costCategoryTypeOPEX;

  /// No description provided for @costCategoryAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Category'**
  String get costCategoryAddTitle;

  /// No description provided for @costCategoryEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Category'**
  String get costCategoryEditTitle;

  /// No description provided for @costCategoryHintName.
  ///
  /// In en, this message translates to:
  /// **'Category Name'**
  String get costCategoryHintName;

  /// No description provided for @costCategoryDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {categoryName}'**
  String costCategoryDeleteTitle(Object categoryName);

  /// No description provided for @costCategoryDeleteContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure to delete this category?'**
  String get costCategoryDeleteContent;

  /// No description provided for @costCategoryNoticeErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get costCategoryNoticeErrorTitle;

  /// No description provided for @costCategoryNoticeErrorLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load categories.'**
  String get costCategoryNoticeErrorLoad;

  /// No description provided for @costCategoryNoticeErrorAdd.
  ///
  /// In en, this message translates to:
  /// **'Failed to add category.'**
  String get costCategoryNoticeErrorAdd;

  /// No description provided for @costCategoryNoticeErrorUpdate.
  ///
  /// In en, this message translates to:
  /// **'Failed to update category.'**
  String get costCategoryNoticeErrorUpdate;

  /// No description provided for @costCategoryNoticeErrorDelete.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete category.'**
  String get costCategoryNoticeErrorDelete;

  /// No description provided for @cashRegSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Cashbox Setup'**
  String get cashRegSetupTitle;

  /// No description provided for @cashRegSetupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please enter the default quantity of\neach denomination in the cash drawer.'**
  String get cashRegSetupSubtitle;

  /// No description provided for @cashRegSetupTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total: {totalAmount}'**
  String cashRegSetupTotalLabel(Object totalAmount);

  /// No description provided for @cashRegSetupInputHint.
  ///
  /// In en, this message translates to:
  /// **'0'**
  String get cashRegSetupInputHint;

  /// No description provided for @cashRegNoticeSaveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Cash float settings saved successfully!'**
  String get cashRegNoticeSaveSuccess;

  /// No description provided for @cashRegNoticeSaveFailure.
  ///
  /// In en, this message translates to:
  /// **'Saving failed: {error}'**
  String cashRegNoticeSaveFailure(Object error);

  /// No description provided for @cashRegNoticeLoadError.
  ///
  /// In en, this message translates to:
  /// **'Error loading cashbox settings: {error}'**
  String cashRegNoticeLoadError(Object error);

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageTraditionalChinese.
  ///
  /// In en, this message translates to:
  /// **'繁體中文'**
  String get languageTraditionalChinese;

  /// No description provided for @changePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePasswordTitle;

  /// No description provided for @changePasswordOldHint.
  ///
  /// In en, this message translates to:
  /// **'Old Password'**
  String get changePasswordOldHint;

  /// No description provided for @changePasswordNewHint.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get changePasswordNewHint;

  /// No description provided for @changePasswordConfirmHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get changePasswordConfirmHint;

  /// No description provided for @changePasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePasswordButton;

  /// No description provided for @passwordValidatorEmptyOld.
  ///
  /// In en, this message translates to:
  /// **'Please enter the old password'**
  String get passwordValidatorEmptyOld;

  /// No description provided for @passwordValidatorLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 digits'**
  String get passwordValidatorLength;

  /// No description provided for @passwordValidatorMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordValidatorMismatch;

  /// No description provided for @passwordErrorReLogin.
  ///
  /// In en, this message translates to:
  /// **'Please log in again'**
  String get passwordErrorReLogin;

  /// No description provided for @passwordErrorOldPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect old password'**
  String get passwordErrorOldPassword;

  /// No description provided for @passwordErrorUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Password update failed'**
  String get passwordErrorUpdateFailed;

  /// No description provided for @passwordSuccess.
  ///
  /// In en, this message translates to:
  /// **'✅ Password updated'**
  String get passwordSuccess;

  /// No description provided for @passwordFailure.
  ///
  /// In en, this message translates to:
  /// **'❌ Password update failed: {error}'**
  String passwordFailure(Object error);

  /// No description provided for @languageSimplifiedChinese.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get languageSimplifiedChinese;

  /// No description provided for @languageItalian.
  ///
  /// In en, this message translates to:
  /// **'Italiano'**
  String get languageItalian;

  /// No description provided for @languageVietnamese.
  ///
  /// In en, this message translates to:
  /// **'Tiếng Việt'**
  String get languageVietnamese;

  /// No description provided for @settingAppearance.
  ///
  /// In en, this message translates to:
  /// **'System Color'**
  String get settingAppearance;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System Color'**
  String get themeSystem;

  /// No description provided for @themeSage.
  ///
  /// In en, this message translates to:
  /// **'Gallery 20.5 Default'**
  String get themeSage;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get themeDark;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'it', 'vi', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {

  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh': {
  switch (locale.scriptCode) {
    case 'Hans': return AppLocalizationsZhHans();
   }
  break;
   }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'it': return AppLocalizationsIt();
    case 'vi': return AppLocalizationsVi();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
