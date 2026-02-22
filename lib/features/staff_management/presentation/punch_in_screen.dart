// lib/features/staff_management/presentation/punch_in_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; 
import 'package:geolocator/geolocator.dart';
import 'package:network_info_plus/network_info_plus.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart'; // [新增] 引入多語言

// -------------------------------------------------------------------
// 1. UI 樣式定義
// -------------------------------------------------------------------

// -------------------------------------------------------------------
// 1. UI 樣式定義
// -------------------------------------------------------------------

// Note: _AppColors removed, using Theme.of(context) instead.

InputDecoration _buildInputDecoration(BuildContext context, {required String hintText}) { // Added context
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16, fontWeight: FontWeight.w500),
    filled: true,
    fillColor: Theme.of(context).inputDecorationTheme.fillColor ?? Theme.of(context).colorScheme.surfaceContainerHighest,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(25),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
  );
}

// -------------------------------------------------------------------
// 2. PunchInScreen (主頁面)
// -------------------------------------------------------------------

class PunchInScreen extends StatefulWidget {
  const PunchInScreen({super.key});

  @override
  State<PunchInScreen> createState() => _PunchInScreenState();
}

class _PunchInScreenState extends State<PunchInScreen> {
  String? _shopId;
  String? _userId;
  String? _wifiName;
  Position? _position;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadShopAndUser();
  }

  Future<void> _loadShopAndUser() async {
    final prefs = await SharedPreferences.getInstance();
    _shopId = prefs.getString('savedShopId');
    final user = Supabase.instance.client.auth.currentUser;
    _userId = user?.id;
  }

  Future<void> _getLocationAndWiFi() async {
    final l10n = AppLocalizations.of(context)!; // [新增]
    final info = NetworkInfo();
    _wifiName = await info.getWifiName();

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(l10n.punchLocDisabled); // 'Location services are disabled...'
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception(l10n.punchLocDenied); // 'Location permissions are denied'
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw Exception(l10n.punchLocDeniedForever); // 'Location permissions are permanently denied...'
    } 

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high, 
    );
    
    setState(() {
      _position = position;
    });
  }

  // ✅ 核心修正 1：只檢查「過去 24 小時內」是否有未下班的紀錄
  Future<Map<String, dynamic>?> _getCurrentActiveLog() async {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    
    final res = await Supabase.instance.client
        .from('work_logs')
        .select()
        .eq('user_id', _userId!)
        .eq('shop_id', _shopId!)
        .filter('clock_out', 'is', 'null') // 尚未下班
        .gte('clock_in', cutoff.toIso8601String()) // 且是 24 小時內的
        .limit(1)
        .maybeSingle();
    return res;
  }

  Future<void> _punchIn() async {
    final l10n = AppLocalizations.of(context)!; // [新增]
    setState(() => isLoading = true);
    try {
      await _getLocationAndWiFi();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final shopData = await Supabase.instance.client
          .from('shop_punch_in_data')
          .select()
          .eq('shop_id', _shopId!)
          .maybeSingle();

      if (shopData == null) {
         _showAlert(l10n.inventoryErrorTitle, l10n.punchErrorSettingsNotFound); // 'Error', 'Shop punch-in settings not found...'
         setState(() => isLoading = false);
         return;
      }

      final requiredWifi = shopData['wifi_name'] as String?;
      if (requiredWifi != null && requiredWifi.isNotEmpty && requiredWifi != _wifiName) {
         _showAlert(l10n.punchErrorInTitle, l10n.punchErrorWifi(requiredWifi)); // 'Clock-in Failed', 'Wi-Fi incorrect...'
         setState(() => isLoading = false);
         return;
      }

      if (!_isLocationClose(shopData)) {
         _showAlert(l10n.punchErrorInTitle, l10n.punchErrorDistance); // 'Clock-in Failed', 'You are too far...'
         setState(() => isLoading = false);
         return;
      }

      // 檢查是否已在上班中 (只看 24 小時內的)
      final activeLog = await _getCurrentActiveLog();
      if (activeLog != null) {
        _showAlert(l10n.punchErrorInTitle, l10n.punchErrorAlreadyIn); // 'Clock-in Failed', 'You are already clocked in.'
        setState(() => isLoading = false);
        return;
      }

      await Supabase.instance.client.from('work_logs').insert({
        'user_id': _userId,
        'shop_id': _shopId,
        'date': today,
        'clock_in': DateTime.now().toUtc().toIso8601String(),
        'wifi_name': _wifiName,
        'latitude': _position?.latitude,
        'longitude': _position?.longitude,
      });

      _showAlert(l10n.punchSuccessInTitle, l10n.punchSuccessInMsg); // 'Clock-in Succeeded', 'Have a nice shift : )'
    } catch (e) {
      _showAlert(l10n.punchErrorInTitle, l10n.punchErrorGeneric(e.toString())); // 'Clock-in Failed', 'An error occurred...'
    }
    setState(() => isLoading = false);
  }

  Future<void> _punchOut() async {
    final l10n = AppLocalizations.of(context)!; // [新增]
    setState(() => isLoading = true);
    try {
      await _getLocationAndWiFi();
      
      final log = await _getCurrentActiveLog();

      if (log == null) {
        // 如果找不到 24 小時內的上班紀錄 (可能是超過 24 小時了)
        _showAlert(l10n.punchErrorOutTitle, l10n.punchErrorNoSession); // 'Clock-out Failed', 'No active session found...'
        setState(() => isLoading = false);
        return;
      }

      final clockInTime = DateTime.parse(log['clock_in']);
      final diff = DateTime.now().difference(clockInTime);

      // ✅ 核心修正 2：如果超過 12 小時，強迫使用 Make Up
      if (diff.inHours >= 12) {
        _showAlert(l10n.punchErrorOutTitle, l10n.punchErrorOverTime); // 'Clock-out Failed', 'Over 12 hours...'
        setState(() => isLoading = false);
        return;
      }

      await Supabase.instance.client.from('work_logs').update({
        'clock_out': DateTime.now().toUtc().toIso8601String(),
        'wifi_name_out': _wifiName,
        'latitude_out': _position?.latitude,
        'longitude_out': _position?.longitude,
      }).eq('id', log['id']);

      _showAlert(l10n.punchSuccessOutTitle, l10n.punchSuccessOutMsg); // 'Clock-out Succeeded', 'Boss love you ❤️'
    } catch (e) {
      _showAlert(l10n.punchErrorOutTitle, l10n.punchErrorGeneric(e.toString())); // 'Clock-out Failed', 'An error occurred...'
    }
    setState(() => isLoading = false);
  }

  bool _isLocationClose(Map shopData) {
    if (_position == null) return false;
    const radius = 100;
    final shopLat = shopData['latitude'] as double?;
    final shopLng = shopData['longitude'] as double?;
    if (shopLat == null || shopLng == null) return false;
    final distance = Geolocator.distanceBetween(
      _position!.latitude,
      _position!.longitude,
      shopLat,
      shopLng,
    );
    return distance < radius;
  }

  Future<void> _showAlert(String title, String content) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => _NoticeDialog(title: title, content: content),
    );
  }

  Future<void> _showManualPunchDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MakeUpDialog(
        shopId: _shopId!,
        userId: _userId!,
        onShowAlert: _showAlert, 
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // [新增]
    final safeAreaTop = MediaQuery.of(context).padding.top;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          if (isLoading)
            Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
          else
            Container(
              padding: EdgeInsets.only(top: safeAreaTop + 120, left: 16, right: 16),
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _WhiteButton(
                    text: l10n.punchInButton, // 'Clock-in'
                    onPressed: _punchIn,
                  ),
                  const SizedBox(height: 20),
                  _WhiteButton(
                    text: l10n.punchOutButton, // 'Clock-out'
                    onPressed: _punchOut,
                  ),
                  const SizedBox(height: 30),
                  _WhiteButton(
                    text: l10n.punchMakeUpButton, // 'Make Up For Clock-in/out'
                    onPressed: _showManualPunchDialog,
                  ),
                ],
              ),
            ),
          
          _buildHeader(context, safeAreaTop, l10n.punchTitle), // 'Clock-in'
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// 3. 補打卡 Dialog (_MakeUpDialog)
// -------------------------------------------------------------------

class _MakeUpDialog extends StatefulWidget {
  final String shopId;
  final String userId;
  final Future<void> Function(String, String) onShowAlert;

  const _MakeUpDialog({
    required this.shopId,
    required this.userId,
    required this.onShowAlert,
  });

  @override
  State<_MakeUpDialog> createState() => _MakeUpDialogState();
}

class _MakeUpDialogState extends State<_MakeUpDialog> {
  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();
  String type = 'Clock-in'; // 預設值，實際上會對應到 arb 的 key
  final reasonController = TextEditingController();
  bool _isSaving = false;

  Future<void> _onSavePressed() async {
    final l10n = AppLocalizations.of(context)!;
    if (reasonController.text.trim().isEmpty) {
      widget.onShowAlert(l10n.inventoryErrorTitle, l10n.punchMakeUpErrorReason); // 'Failed', 'Please fill up the reason'
      return;
    }

    setState(() => _isSaving = true);
    
    // 延遲一點點讓 UI 顯示 Loading
    await Future.delayed(const Duration(milliseconds: 300));

    final DateTime fullDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    final now = DateTime.now();

    if (fullDateTime.isAfter(now)) {
      widget.onShowAlert(l10n.inventoryErrorTitle, l10n.punchMakeUpErrorFuture); // 'Failed', 'Cannot make up for a future time'
      setState(() => _isSaving = false);
      return;
    }
    
    // ✅ 核心修正 3：補打卡不能超過 72 小時
    if (now.difference(fullDateTime).inHours > 72) {
      widget.onShowAlert(l10n.inventoryErrorTitle, l10n.punchMakeUpError72h); // 'Failed', 'Cannot make up beyond 72 hours...'
      setState(() => _isSaving = false);
      return;
    }

    // 注意：原本邏輯有一個二次確認視窗 _ConfirmMakeUpDialog，
    // 為保持 UX 一致性，這裡也應該跳出確認。
    
    // 暫時隱藏原本的 Dialog，因為 showDialog 會蓋在上面
    // 但因為我們是在 Dialog 裡面再 call Dialog，所以沒關係。
    
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ConfirmMakeUpDialog(
        // 這裡傳入翻譯後的字串供確認對話框顯示
        type: type == 'Clock-in' ? l10n.punchMakeUpTypeIn : l10n.punchMakeUpTypeOut,
        dateTime: fullDateTime,
        reason: reasonController.text.trim(),
      ),
    );

    if (confirm != true) {
      if (mounted) setState(() => _isSaving = false);
      return;
    }

    try {
      if (type == 'Clock-in') {
        // 補上班卡邏輯 (檢查 24 小時內是否重複)
        final cutoff = fullDateTime.subtract(const Duration(hours: 24));
        final lastLog = await Supabase.instance.client
            .from('work_logs')
            .select()
            .eq('shop_id', widget.shopId)
            .eq('user_id', widget.userId)
            .filter('clock_out', 'is', 'null') 
            .gte('clock_in', cutoff.toIso8601String()) // 只檢查近期的
            .limit(1)
            .maybeSingle();

        if (lastLog != null) {
          final lastIn = DateTime.parse(lastLog['clock_in']);
          final timeStr = DateFormat('HH:mm').format(lastIn);
          widget.onShowAlert(l10n.inventoryErrorTitle, l10n.punchMakeUpErrorOverlap(timeStr)); // 'Failed', 'Active session found at...'
          setState(() => _isSaving = false);
          return;
        }

        await Supabase.instance.client.from('work_logs').insert({
          'shop_id': widget.shopId,
          'user_id': widget.userId,
          'date': DateFormat('yyyy-MM-dd').format(fullDateTime),
          'clock_in': fullDateTime.toUtc().toIso8601String(),
          'manual_in': true,
          'reason_in': reasonController.text.trim(),
        });

      } else { 
        // ✅ 核心修正 4：補下班卡邏輯
        // 只能補 72 小時內的班
        final cutoff = fullDateTime.subtract(const Duration(hours: 72));
        
        final matchLog = await Supabase.instance.client
            .from('work_logs')
            .select()
            .eq('shop_id', widget.shopId)
            .eq('user_id', widget.userId)
            .filter('clock_out', 'is', 'null')
            // 找這筆補打時間之前的上班紀錄 (但不能早於 72 小時)
            .gte('clock_in', cutoff.toIso8601String()) 
            .lte('clock_in', fullDateTime.toIso8601String())
            .order('clock_in', ascending: false)
            .limit(1)
            .maybeSingle();

        // 如果找不到 -> 代表超過 72 小時了
        if (matchLog == null) {
          widget.onShowAlert(l10n.inventoryErrorTitle, l10n.punchMakeUpErrorNoRecord); // 'Failed', 'No matching record...'
          setState(() => _isSaving = false);
          return;
        }
        
        // ✅ 核心修正 5：檢查補打的工時是否超過 12 小時
        final clockInTime = DateTime.parse(matchLog['clock_in']);
        final durationHours = fullDateTime.difference(clockInTime).inHours;
        
        if (durationHours > 12) {
           widget.onShowAlert(l10n.inventoryErrorTitle, l10n.punchMakeUpErrorOver12h); // 'Failed', 'Shift duration exceeds...'
           setState(() => _isSaving = false);
           return;
        }

        await Supabase.instance.client
            .from('work_logs')
            .update({
              'clock_out': fullDateTime.toUtc().toIso8601String(),
              'manual_out': true,
              'reason_out': reasonController.text.trim(),
            })
            .eq('id', matchLog['id']);
      }
      
      if (mounted) Navigator.of(context).pop(); 
      widget.onShowAlert(l10n.punchMakeUpSuccessTitle, l10n.punchMakeUpSuccessMsg); // 'Succeeded', 'Your make up...'

    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
      widget.onShowAlert(l10n.inventoryErrorTitle, l10n.punchErrorGeneric(e.toString())); // 'Failed', 'Database error...'
    }
  }

  @override
  void dispose() {
    reasonController.dispose();
    super.dispose();
  }
  
  Future<void> _selectDate(BuildContext context) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: colorScheme.primary,
              onPrimary: colorScheme.onPrimary,
              surface: theme.cardColor,
              onSurface: colorScheme.onSurface,
            ),
            dialogBackgroundColor: theme.cardColor,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future<void> _selectTime(BuildContext context) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: colorScheme.primary,
              onPrimary: colorScheme.onPrimary,
              surface: theme.cardColor,
              onSurface: colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      }
    );
    if (picked != null) setState(() => selectedTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; 
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final inputDecoration = BoxDecoration(
        color: theme.scaffoldBackgroundColor, 
        borderRadius: BorderRadius.circular(10)
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20), // Match AddTaskDialog
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(25),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, // Match AddTaskDialog
            children: [
              // Title
              Center(
                child: Text(
                  l10n.punchMakeUpTitle, // 'Make up for clock-in/out'
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold), // Match AddTaskDialog
                ),
              ),
              const SizedBox(height: 20),
              
              // Type Selector (Simulating Dropdown with Container)
              GestureDetector(
                onTap: () async {
                  // Show simple selection dialog
                  final result = await showCupertinoModalPopup<String>(
                    context: context,
                    builder: (ctx) => CupertinoActionSheet(
                      actions: [
                        CupertinoActionSheetAction(
                          onPressed: () => Navigator.pop(ctx, 'Clock-in'),
                          child: Text(l10n.punchMakeUpTypeIn),
                        ),
                        CupertinoActionSheetAction(
                          onPressed: () => Navigator.pop(ctx, 'Clock-out'),
                          child: Text(l10n.punchMakeUpTypeOut),
                        ),
                      ],
                      cancelButton: CupertinoActionSheetAction(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(l10n.commonCancel),
                      ),
                    ),
                  );
                  if (result != null) {
                    setState(() => type = result);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: inputDecoration,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        type == 'Clock-in' ? l10n.punchMakeUpTypeIn : l10n.punchMakeUpTypeOut,
                        style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                      ),
                      Icon(Icons.arrow_drop_down, color: colorScheme.onSurface),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // Date Picker
              GestureDetector(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: inputDecoration,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('yyyy-MM-dd').format(selectedDate),
                        style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                      ),
                      Icon(Icons.calendar_month, color: colorScheme.onSurface),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Time Picker
              GestureDetector(
                onTap: () => _selectTime(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: inputDecoration,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        selectedTime.format(context), 
                        style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                      ),
                      Icon(Icons.access_time, color: colorScheme.onSurface),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Reason
              CupertinoTextField(
                  controller: reasonController,
                  placeholder: l10n.punchMakeUpReasonHint, 
                  padding: const EdgeInsets.all(12),
                  style: TextStyle(color: colorScheme.onSurface),
                  placeholderStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                  decoration: inputDecoration,
              ),
              const SizedBox(height: 30),

              // Buttons
              Row(
                children: [
                   Expanded(
                    child: CupertinoButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.commonCancel, style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CupertinoButton(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                      onPressed: _isSaving ? null : _onSavePressed,
                      child: _isSaving
                          ? const CupertinoActivityIndicator()
                          : Text(l10n.commonSave, style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// 4. 自訂 Dialog Widget (Figma 樣式) - 保持不變
// -------------------------------------------------------------------

Widget _buildHeader(BuildContext context, double safeAreaTop, String title) {
  return Positioned(
    top: 0,
    left: 0,
    right: 0,
    child: Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: EdgeInsets.only(top: safeAreaTop, bottom: 10, left: 16, right: 16),
      child: Row(
        children: [
          IconButton(
            icon: Icon(CupertinoIcons.chevron_left, color: Theme.of(context).iconTheme.color, size: 30),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 30,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.03,
              ),
            ),
          ),
          const SizedBox(width: 48), 
        ],
      ),
    ),
  );
}

class _WhiteButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  const _WhiteButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 245, 
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).brightness == Brightness.light 
              ? Colors.black 
              : Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).brightness == Brightness.light
              ? Colors.white
              : Theme.of(context).colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          padding: const EdgeInsets.symmetric(vertical: 9), 
        ),
        child: Text(
          text,
          textAlign: TextAlign.center, 
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.white
                : Theme.of(context).colorScheme.onPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _DialogWhiteButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  const _DialogWhiteButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 109.6, 
      height: 38,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).brightness == Brightness.light 
              ? Colors.black 
              : Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).brightness == Brightness.light
              ? Colors.white
              : Theme.of(context).colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.white
                : Theme.of(context).colorScheme.onPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TextCancelButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _TextCancelButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // [新增]
    return TextButton(
      onPressed: onPressed,
      child: Text(
        l10n.commonCancel, // 'Cancel'
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _NoticeDialog extends StatelessWidget {
  final String title;
  final String content;
  const _NoticeDialog({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // [新增]
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              content,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            _DialogWhiteButton(
              text: l10n.commonOk, // 'OK'
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmMakeUpDialog extends StatelessWidget {
  final String type;
  final DateTime dateTime;
  final String reason;

  const _ConfirmMakeUpDialog({
    required this.type,
    required this.dateTime,
    required this.reason,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // [新增]
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Center( 
              child: Text(
                l10n.punchMakeUpCheckInfo, // 'Please Check The Info'
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.punchMakeUpLabelType(type), // 'Type: {type}'
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500, height: 1.5),
            ),
            Text(
              l10n.punchMakeUpLabelTime(DateFormat('yyyy/MM/dd HH:mm').format(dateTime)), // 'Time: ...'
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500, height: 1.5),
            ),
            Text(
              l10n.punchMakeUpLabelReason(reason), // 'Reason: ...'
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _TextCancelButton(
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                _DialogWhiteButton(
                  text: l10n.commonSave, // 'Save'
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


