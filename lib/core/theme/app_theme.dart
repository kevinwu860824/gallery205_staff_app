// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; 
import 'package:flutter/cupertino.dart'; // 為了 CupertinoColors

/* Figma 設計語言 (Design System)
  合併了 Home 和 Settings 的樣式
*/
class AppColors {

  // --- 佈局顏色 (Home Screen) ---
  static const Color homeBackground = Color(0xFF000000); // 淺灰
  static const Color homeCardBackground = Color(0xFF222222); // 深黑/藍
  static const Color homeTextPrimary = Color(0xFFFFFFFF); // 深色 (用於淺色背景)
  static const Color homeTextInvert = Color(0xFFFAFAFA); // 白色 (用於深色卡片)
  static const Color homeIconFill = Color(0xFFFAFAFA); // 圖示線條 (白色)
  
  // --- 佈局顏色 (Settings Screen) ---
  static const Color settingsBackground = Color(0xFF000000); // 背景: #222222
  static const Color settingsCardBackground = Color(0xFF222222); // 卡片: #FAFAFA
  static const Color settingsTextPrimary = Color(0xFFFFFFFF); // 文字 (卡片上): #222222
  static const Color settingsTextInvert = Color(0xFFFFFFFF); // 文字 (背景上): #FAFAFA
  static const Color settingsIconFill = Color(0xFFFAFAFA); // 圖示 (卡片上): #222222
  static const Color settingsIconGlyph = Color(0xFF222222); // 圖示線條: #FAFAFA
  static const Color settingsSeparator = Color(0xFFFAFAFA); // 分隔線

  static const Color loginBackground = Color(0xFFFAFAFA); // 背景 (白色)
  static const Color loginWaveTop = Color(0xFF222222);    // 波浪頂部 (深色)
  static const Color loginWaveBottom = Color(0xFF222222); // 波浪底部 (深色)

  static const Color loginDivider = Color(0xFFE5E5E5); // 分隔線
  static const Color loginTextLight = Color(0xFFFAFAFA); // 淺色文字 (用於深色背景)
  static const Color loginTextDark = Color(0xFF222222);  // 深色文字 (用於淺色背景)
  static const Color loginAccent = Color(0xFFF74040);    // 亮紅色 (用於連結)
  static const Color loginInputUnderline = Color(0xFFF74040); // 輸入框底線 (紅色)
  static const Color loginCheckboxChecked = Color(0xFFF74040); // Checkbox 勾選色
  static const Color loginCheckboxUnchecked = Color(0xFFC0C0C0); // Checkbox 未勾選
  static const Color loginEllipse = Color(0xFF222222);    // 2. 底部橢圓 (深色)

  static const Color loginCardBackground = Color(0xFFFAFAFA); // 3. 輸入框背景 (淺色)
  static const Color loginCardText = Color(0xFF222222);       // 4. 輸入框文字 (深色)
  static const Color loginTitle = Color(0xFFFAFAFA);        // 5. "Login" 標題 (淺色)
  static const Color loginButtonText = Color(0xFF222222);   // 6. 登入按鈕文字 (深色)
  static const Color loginFaceIDIcon = Color(0xFF222222);     // 7. FaceID 圖示 (深色)
  static const Color accentRed = Color(0xFFF74040);

  static const Color lightBackground = Color(0xFFF2F2F6); // 淺灰背景 (iOS Style)
  static const Color lightCardBackground = Color(0xFFFFFFFF); // 純白卡片

  // --- 陰影 (共用) ---
  static const Color shadow = Color(0x1A000000); // 10% 透明度黑色

  // --- Sage Calm Theme Colors (App Default) ---
  // [Modified] New Palette Request (2026-01-05)
  static const Color sageBackground = Color(0xFF8DA399); // 淺鼠尾草綠 (Bg) - User Requested
  static const Color sageCardBackground = Color(0xFF5C7A6B); // Brand Dark Green
  // [Modified] Primary is now Light for contrast against Dark Bg/Card
  static const Color sagePrimary = Color(0xFFFAFCFA); // 極淡綠白 (Primary / Icon)
  static const Color sageSecondary = Color(0xFF8DA399); // 淺鼠尾草綠 (Inactive)
  static const Color sageTextTitle = Color(0xFFF2F4F5); // 淺灰 (Title > Bg)
  static const Color sageTextBody = Color(0xFFFAFCFA); // 極淡綠白 (Body)
  static const Color sageIconFill = Color(0xFFFAFCFA); // Same as Primary

  // --- Aliases for Generic Theme Usage (Fixing compilation errors) ---
  static const Color background = homeBackground; // 0xFF000000
  static const Color cardBackground = homeCardBackground; // 0xFF222222
  static const Color textPrimary = homeTextPrimary; // 0xFFFFFFFF
  static const Color iconColor = homeIconFill; // 0xFFFAFAFA
}

class AppTheme {

  // --- 主題定義 (Theme Definitions) ---
  
  // 1. Sage Calm Theme (Default)
  static ThemeData get sageTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark, // ✅ Sage is now a Dark Theme
      primaryColor: AppColors.sagePrimary,
      scaffoldBackgroundColor: AppColors.sageBackground,
      cardColor: AppColors.sageCardBackground,
      
      colorScheme: const ColorScheme.dark( // ✅ Use dark scheme base
        primary: AppColors.sagePrimary,
        secondary: AppColors.sageSecondary,
        surface: AppColors.sageCardBackground,
        onPrimary: AppColors.sageBackground, 
        onSecondary: Colors.white,
        onSurface: AppColors.sageTextBody, // ✅ [Modified] Text on Sage Green Card (#FAFCFA)
        error: AppColors.accentRed,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.sageBackground,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.sageTextTitle),
        titleTextStyle: GoogleFonts.notoSansTc(
          color: AppColors.sageTextTitle,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      
      extensions: const [], // Can add custom extensions later

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.sageCardBackground, 
        titleTextStyle: GoogleFonts.notoSansTc(
          color: AppColors.sageTextTitle, 
          fontSize: 20,
          fontWeight: FontWeight.w500
        ),
        contentTextStyle: GoogleFonts.notoSansTc(
          color: AppColors.sageTextBody, 
          fontSize: 16,
        ),
      ),
      
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.sageCardBackground,
        modalBackgroundColor: AppColors.sageCardBackground,
      ),

      dividerColor: AppColors.sageSecondary.withOpacity(0.5),

      // ✅ [New] Detailed Text Theme for Sage Calm
      textTheme: TextTheme(
        // Titles (Light / F2F4F5)
        displayLarge: GoogleFonts.notoSansTc(color: AppColors.sageTextTitle, fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.notoSansTc(color: AppColors.sageTextTitle, fontWeight: FontWeight.bold),
        displaySmall: GoogleFonts.notoSansTc(color: AppColors.sageTextTitle, fontWeight: FontWeight.bold),
        headlineLarge: GoogleFonts.notoSansTc(color: AppColors.sageTextTitle, fontWeight: FontWeight.bold),
        headlineMedium: GoogleFonts.notoSansTc(color: AppColors.sageTextTitle, fontWeight: FontWeight.bold),
        headlineSmall: GoogleFonts.notoSansTc(color: AppColors.sageTextTitle, fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.notoSansTc(color: AppColors.sageTextTitle, fontWeight: FontWeight.bold),
        titleMedium: GoogleFonts.notoSansTc(color: AppColors.sageTextTitle, fontWeight: FontWeight.w500),
        titleSmall: GoogleFonts.notoSansTc(color: AppColors.sageTextTitle, fontWeight: FontWeight.w500),

        // Body (Very Light / FAFCFA)
        bodyLarge: GoogleFonts.notoSansTc(color: AppColors.sageTextBody),
        bodyMedium: GoogleFonts.notoSansTc(color: AppColors.sageTextBody), 
        bodySmall: GoogleFonts.notoSansTc(color: AppColors.sageTextBody),

        // Captions
        labelLarge: GoogleFonts.notoSansTc(color: AppColors.sageTextBody, fontWeight: FontWeight.w500),
        labelMedium: GoogleFonts.notoSansTc(color: AppColors.sageTextBody, fontWeight: FontWeight.w500),
        labelSmall: GoogleFonts.notoSansTc(color: AppColors.sageTextBody, fontWeight: FontWeight.w500),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.lightBackground,
      scaffoldBackgroundColor: AppColors.lightBackground, // Changed to #FFFFFF
      cardColor: AppColors.lightCardBackground, // Changed to #F5F5F5
      
      colorScheme: const ColorScheme.light(
        primary: AppColors.loginTextDark, // Black text as primary
        secondary: AppColors.loginAccent,
        surface: AppColors.lightCardBackground, 
        error: AppColors.accentRed,
        onPrimary: AppColors.loginTextLight,
        onSurface: AppColors.loginTextDark,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightCardBackground, 
        titleTextStyle: GoogleFonts.notoSansTc(
          color: AppColors.loginTextDark, 
          fontSize: 20,
          fontWeight: FontWeight.w500
        ),
        contentTextStyle: GoogleFonts.notoSansTc(
          color: AppColors.loginTextDark, 
          fontSize: 16,
        ),
      ),
      
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightCardBackground,
      ),

      dividerColor: AppColors.loginDivider,
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.background,
      scaffoldBackgroundColor: AppColors.background, // Black
      cardColor: AppColors.cardBackground, // Dark Grey
      
      colorScheme: const ColorScheme.dark(
        primary: AppColors.textPrimary, // White text as primary
        secondary: AppColors.iconColor,
        surface: AppColors.cardBackground, // Dark card
        error:  Color(0xFFCF6679),
        onPrimary: AppColors.background,
        onSurface: AppColors.textPrimary,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardBackground, // Dark
        titleTextStyle: GoogleFonts.notoSansTc(
          color: AppColors.textPrimary, // White
          fontSize: 20,
          fontWeight: FontWeight.w500
        ),
        contentTextStyle: GoogleFonts.notoSansTc(
          color: AppColors.textPrimary, // White
          fontSize: 16,
        ),
      ),
      
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cardBackground,
        modalBackgroundColor: AppColors.cardBackground,
      ),

      dividerColor: AppColors.textPrimary, // White
    );
  }
}

class AppTextStyles {
  // ... existing styles ...
  // [Note: Ideally we migrate these to use Theme.of(context) eventually]
  
  // --- Home 頁樣式 ---
  static final TextStyle homeButtonLabel = GoogleFonts.notoSansTc(
    fontSize: 12,
    fontWeight: FontWeight.w500, // 510 Weight (Medium)
    color: AppColors.homeTextPrimary, 
    decoration: TextDecoration.none,
    height: 1.16, 
  );
  
  static final TextStyle homeAppBarTitle = GoogleFonts.notoSansTc(
    color: AppColors.homeTextPrimary, 
    fontWeight: FontWeight.bold,
  );

  // --- Settings 頁樣式 ---
  static final TextStyle settingsPageTitle = GoogleFonts.notoSansTc(
    fontSize: 34,
    fontWeight: FontWeight.w500, // 590 Weight (Medium-Semibold)
    color: AppColors.settingsTextInvert,
    letterSpacing: 0.03 * 34, 
  );
  
  static final TextStyle settingsUserDisplayName = GoogleFonts.notoSansTc(
    fontSize: 20,
    fontWeight: FontWeight.w500, // 510 Weight (Medium)
    color: AppColors.settingsTextPrimary,
    letterSpacing: -0.015 * 20, 
  );
  
  static final TextStyle settingsListItem = GoogleFonts.notoSansTc(
    fontSize: 16,
    fontWeight: FontWeight.w500, // 510 Weight (Medium)
    color: AppColors.settingsTextPrimary,
  );
}