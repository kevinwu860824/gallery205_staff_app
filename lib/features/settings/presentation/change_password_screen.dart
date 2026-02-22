// lib/features/settings/presentation/change_password_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final oldPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;

  Future<void> _changePassword() async {
    final l10n = AppLocalizations.of(context)!;
    
    // 點擊按鈕時，先取消所有焦點以收起鍵盤
    FocusScope.of(context).unfocus();
    
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('savedEmail');
      final oldPassword = oldPasswordController.text.trim();
      final newPassword = newPasswordController.text.trim();

      if (email == null) throw l10n.passwordErrorReLogin;

      // 重新登入進行身份驗證（確保舊密碼正確）
      final signInRes = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: oldPassword,
      );

      if (signInRes.user == null) throw l10n.passwordErrorOldPassword;

      // 更新密碼
      final updateRes = await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (updateRes.user == null) {
        throw l10n.passwordErrorUpdateFailed;
      }

      // 更新 SharedPreferences 中儲存的密碼
      // (如果 LoginScreen 的 Face ID 登入是依賴這個)
      final savedLoginsRaw = prefs.getString('savedLogins');
      final shopCode = prefs.getString('savedShopCode');
      if (savedLoginsRaw != null && shopCode != null) {
        final Map<String, dynamic> loginMap = jsonDecode(savedLoginsRaw);
        final key = '$shopCode+$email';
        if (loginMap.containsKey(key)) {
          loginMap[key]['password'] = newPassword;
          await prefs.setString('savedLogins', jsonEncode(loginMap));
        }
      }


      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.passwordSuccess)),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.passwordFailure(e.toString()))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  /// 輔助方法：建立輸入框的統一樣式
  InputDecoration _buildInputDecoration({required String hintText, required BuildContext context}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
          color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500),
      filled: true,
      fillColor: theme.cardColor, // Use card color for input background
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(25), // 圓角 10
        borderSide: BorderSide.none, // 移除邊框
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, 
      resizeToAvoidBottomInset: false, // 關閉預設鍵盤動畫

      appBar: AppBar(
        title: Text(l10n.changePasswordTitle), 
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: colorScheme.onSurface, 
        elevation: 0, 
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 30,
          fontWeight: FontWeight.w500,
        ),
      ),
      
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          child: AnimatedPadding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 54.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // 頂部間距 
                    const SizedBox(height: 90),
                    TextFormField(
                      controller: oldPasswordController,
                      obscureText: true,
                      // 使用自訂的 Input Decoration
                      decoration: _buildInputDecoration(hintText: l10n.changePasswordOldHint, context: context), 
                      style: TextStyle(color: colorScheme.onSurface), // 輸入的文字
                      validator: (value) =>
                          value == null || value.isEmpty ? l10n.passwordValidatorEmptyOld : null, 
                    ),
                    const SizedBox(height: 13), // 欄位間距
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: true,
                      decoration: _buildInputDecoration(hintText: l10n.changePasswordNewHint, context: context), 
                      style: TextStyle(color: colorScheme.onSurface),
                      validator: (value) =>
                          value == null || value.length < 6 ? l10n.passwordValidatorLength : null, 
                    ),
                    const SizedBox(height: 13),
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      decoration: _buildInputDecoration(hintText: l10n.changePasswordConfirmHint, context: context), 
                      style: TextStyle(color: colorScheme.onSurface),
                      validator: (value) => value != newPasswordController.text
                          ? l10n.passwordValidatorMismatch 
                          : null,
                    ),
                    const SizedBox(height: 13),
                    
                    Center(
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _changePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary, 
                          foregroundColor: colorScheme.onPrimary, 
                          // Figma: 寬 161, 高 38
                          minimumSize: const Size(161, 38), 
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: isLoading
                            // 載入時顯示一個小型指示器
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.onPrimary,
                                ),
                              )
                            // 正常時顯示文字
                            : Text(
                                l10n.changePasswordButton, 
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}