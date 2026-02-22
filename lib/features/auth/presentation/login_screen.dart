import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_sfsymbols/flutter_sfsymbols.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';
import 'package:gallery205_staff_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:gallery205_staff_app/core/theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final LocalAuthentication auth = LocalAuthentication();
  final TextEditingController newShopController = TextEditingController();

  String? selectedShopCode;
  // We use this local flag to ensure we default-select the first shop only once
  bool _hasInitializedSelection = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    newShopController.dispose();
    super.dispose();
  }

  // --- Logic Helpers ---

  Future<void> _loadEmailForShop(String? shopCode) async {
    if (shopCode == null) return;
    final repo = ref.read(authRepositoryProvider);
    final credential = await repo.getLoginCredential(shopCode);
    
    if (mounted) {
      if (credential != null) {
        setState(() {
          emailController.text = credential['email'] ?? '';
          // Optionally auto-fill password too if saved? 
          // The previous implementation auto-filled email but password was inside the map.
          // Let's assume for security we might not auto-fill password visible, 
          // BUT the previous implementation stored password in plain text(!!) in the map.
          // And checking `_loadEmailForShop` in old code:
          // It SET emailController.text. It DID NOT set passwordController.
          // So we replicate that specific behavior.
        });
      } else {
        setState(() {
          emailController.clear();
        });
      }
    }
  }

  Future<void> _loginInternal(String shopCode, String email, String password) async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();
    
    final l10n = AppLocalizations.of(context)!;
    
    // Call Controller
    await ref.read(loginControllerProvider.notifier).login(
      email: email, 
      password: password, 
      shopCode: shopCode
    );
    
    // Result is handled by listen() in build()
  }

  Future<void> _loginWithEmail() async {
    final l10n = AppLocalizations.of(context)!;
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final shopCode = selectedShopCode?.trim() ?? '';

    if (shopCode.isEmpty || email.isEmpty || password.isEmpty) {
      _showMessage(l10n.loginMsgFillAll);
      return;
    }

    await _loginInternal(shopCode, email, password);
  }

  Future<void> _loginWithFaceID() async {
    final l10n = AppLocalizations.of(context)!;
    
    // 1. Authenticate (Biometric)
    // Note: In real production, we shouldn't prompt auth before checking if we even HAVE credentials.
    // But aligning with previous logic:
    
    // Original check: 'hasLoggedInBefore'. 
    // We can infer this: Do we have ANY saved shop codes?
    final savedShops = await ref.read(authRepositoryProvider).getSavedShopCodes();
    if (savedShops.isEmpty) {
       _showMessage(l10n.loginMsgFaceIdFirst);
       return;
    }

    final authenticated = await auth.authenticate(
      localizedReason: l10n.loginMsgFaceIdReason,
    );
    if (!authenticated) return;

    // 2. Retrieve Credential
    final email = emailController.text.trim();
    final shopCode = selectedShopCode?.trim() ?? '';
    
    if (shopCode.isEmpty) {
       _showMessage('Please select a shop first.');
       return;
    }

    final repo = ref.read(authRepositoryProvider);
    final credential = await repo.getLoginCredential(shopCode);
    
    // Note: The credential lookup logic in old code was specific: '$shopCode+$email'.
    // Our repository `getLoginCredential` currently finds purely by `shopCode` prefix.
    // This implies if multiple emails use same shop, it finds the first one.
    // However, if the user manually TYPED an email, we should verify it matches.
    
    if (credential == null) {
       _showMessage(l10n.loginMsgNoSavedData);
       return;
    }
    
    // Verify email match if user typed one (optional but good security)
    final savedEmail = credential['email'];
    if (email.isNotEmpty && savedEmail != email) {
        _showMessage(l10n.loginMsgNoFaceIdData); // "Credentials don't match input" roughly
        return;
    }

    final password = credential['password'];
    if (password == null) {
       _showMessage(l10n.loginMsgNoFaceIdData);
       return;
    }

    await _loginInternal(shopCode, savedEmail, password);
  }

  Future<void> _promptAddNewShop() async {
    final l10n = AppLocalizations.of(context)!;
    newShopController.clear();
    
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.loginAddShopDialogTitle),
        content: TextField(
          controller: newShopController,
          decoration: InputDecoration(hintText: l10n.loginAddShopDialogHint),
        ),
        actions: [
          TextButton(
            child: Text(l10n.commonCancel),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text(l10n.commonAdd),
            onPressed: () async {
              final newCode = newShopController.text.trim();
              final savedShops = await ref.read(authRepositoryProvider).getSavedShopCodes();
              
              if (newCode.isNotEmpty && !savedShops.contains(newCode)) {
                await ref.read(authRepositoryProvider).addSavedShopCode(newCode);
                // Refresh provider list
                ref.refresh(savedShopCodesProvider);
                
                setState(() {
                  selectedShopCode = newCode;
                });
                
                // Clear inputs for new shop
                 emailController.clear();
                 passwordController.clear();
              }
              if (mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
     if (!mounted) return;
     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  InputDecoration _buildInputDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
          color: Color(0xFF222222), fontSize: 16, fontWeight: FontWeight.w500),
      filled: true,
      fillColor: const Color(0xFFFAFAFA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(25),
        borderSide: BorderSide.none,
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screenPadding = MediaQuery.of(context).padding;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // --- State Listeners ---
    
    // 1. Listen for Login Result
    ref.listen(loginControllerProvider, (previous, next) {
      next.when(
        data: (user) {
          if (user != null) {
            context.go('/home');
          }
        },
        error: (err, stack) {
          _showMessage(l10n.loginMsgFailedReason(err.toString()));
        },
        loading: () {}, // Handled by UI spinner if needed
      );
    });
    
    // 2. Watch Saved Shops
    final savedShopsAsync = ref.watch(savedShopCodesProvider);
    final isLoggingIn = ref.watch(loginControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // --- Top Logo ---
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: screenPadding.top + 50),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      // If Sage Mode (Brand Dark Green Card), use the specific Sage Logo
                      // Otherwise use the standard app icon
                      Theme.of(context).cardColor.value == AppColors.sageCardBackground.value
                          ? 'assets/app_logo_icon_sage.svg'
                          : 'assets/app_logo_icon.svg',
                      height: 120,
                      placeholderBuilder: (BuildContext context) => const SizedBox(
                          height: 120,
                          width: 120,
                          child: Center(child: CupertinoActivityIndicator())),
                    ),
                    const SizedBox(height: 30),
                    SvgPicture.asset(
                      Theme.of(context).cardColor.value == AppColors.sageCardBackground.value
                          ? 'assets/app_logo_text_sage.svg'
                          : 'assets/app_logo_text.svg',
                      height: 40,
                      placeholderBuilder: (BuildContext context) => const SizedBox(
                          height: 60,
                          width: 150, // rough ratio estimate
                          child: Center(child: CupertinoActivityIndicator())),
                    ),
                  ],
                ),
              ),
            ),

            // --- Bottom Curve ---
            Align(
              alignment: Alignment.bottomCenter,
              child: Stack(
                children: [
                   // Ellipse 1 (Deepest)
                  ClipPath(
                    clipper: ArcClipper(offsetYFactor: 0.30),
                    child: Container(
                      // If Sage Mode: Brand Dark Green (#5C7A6B)
                      // Otherwise: Always Force #222222 (Dark Grey), covering both Dark & Light modes.
                      color: Theme.of(context).cardColor.value == AppColors.sageCardBackground.value
                          ? AppColors.sageCardBackground
                          : const Color(0xFF222222), 
                      width: double.infinity,
                      height: screenHeight * 0.65,
                    ),
                  ),
                  // Ellipse 2
                  ClipPath(
                    clipper: ArcClipper(offsetYFactor: 0.20),
                    child: Container(
                      // Check if we are in Sage Mode (approximated by checking cardColor)
                      color: Theme.of(context).cardColor.value == AppColors.sageCardBackground.value
                          ? AppColors.sageSecondary.withOpacity(0.6)
                          : const Color(0x99222222),
                      width: double.infinity,
                      height: screenHeight * 0.65,
                    ),
                  ),
                  // Ellipse 3
                  ClipPath(
                    clipper: ArcClipper(offsetYFactor: 0.10),
                    child: Container(
                      color: Theme.of(context).cardColor.value == AppColors.sageCardBackground.value
                          ? AppColors.sageSecondary.withOpacity(0.3)
                          : const Color(0x99222222),
                      width: double.infinity,
                      height: screenHeight * 0.65,
                    ),
                  ),

                  // --- Form Content ---
                  Container(
                    width: double.infinity,
                    height: screenHeight * 0.65,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 52.0),
                      child: AnimatedPadding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom,
                        ),
                        duration: const Duration(milliseconds: 150), 
                        curve: Curves.easeOut,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const SizedBox(height: 110),
                            Text(
                              l10n.loginTitle,
                              style: const TextStyle(
                                color: Color(0xFFFAFAFA),
                                fontSize: 30,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 30),
                            
                            // Shop Dropdown
                            savedShopsAsync.when(
                              loading: () => const SizedBox(height: 50, child: Center(child: CircularProgressIndicator())),
                              error: (err, _) => Text('Error: $err'),
                              data: (savedShopCodes) {
                                // Initialize default selection once
                                if (!_hasInitializedSelection && savedShopCodes.isNotEmpty && selectedShopCode == null) {
                                   // We schedule this because we can't setState during build
                                   Future.microtask(() {
                                      if (mounted) {
                                        setState(() {
                                          selectedShopCode = savedShopCodes.first;
                                          _hasInitializedSelection = true;
                                        });
                                        // Auto-load email for default
                                        _loadEmailForShop(selectedShopCode);
                                      }
                                   });
                                }
                                
                                return DropdownButtonFormField<String>(
                                  decoration: _buildInputDecoration(
                                    hintText: l10n.loginShopIdHint,
                                  ),
                                  value: selectedShopCode,
                                  selectedItemBuilder: (BuildContext context) {
                                    return [
                                      ...savedShopCodes.map((code) => Text(code)),
                                      Text(l10n.loginAddShopOption),
                                    ];
                                  },
                                  items: [
                                    ...savedShopCodes.map((code) =>
                                        DropdownMenuItem(
                                            value: code, 
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(code),
                                                GestureDetector(
                                                  behavior: HitTestBehavior.opaque,
                                                  onTap: () async {
                                                    final repo = ref.read(authRepositoryProvider);
                                                    await repo.removeSavedShopCode(code);
                                                    
                                                    // Refresh list
                                                    ref.refresh(savedShopCodesProvider);
                                                    
                                                    // Prepare to update selection if needed
                                                    if (selectedShopCode == code) {
                                                      setState(() {
                                                        selectedShopCode = null;
                                                        emailController.clear();
                                                      });
                                                    }

                                                    // Close the dropdown immediately to reflect changes
                                                    if (mounted) {
                                                      Navigator.of(context, rootNavigator: true).pop();
                                                    }
                                                  },
                                                  child: const Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                                    child: Icon(Icons.close, size: 20, color: Colors.grey),
                                                  ),
                                                )
                                              ],
                                            ))),
                                    DropdownMenuItem(
                                        value: '__new__',
                                        child: Text(l10n.loginAddShopOption)),
                                  ],
                                  onChanged: (value) async {
                                    if (value == '__new__') {
                                      _promptAddNewShop();
                                    } else {
                                      setState(() {
                                        selectedShopCode = value;
                                      });
                                      _loadEmailForShop(value);
                                    }
                                  },
                                  dropdownColor: const Color(0xFFFAFAFA),
                                  style: const TextStyle(
                                      color: Color(0xFF222222), fontSize: 16),
                                  icon: const Icon(Icons.keyboard_arrow_down,
                                      color: Color(0xFF222222)),
                                  isExpanded: true,
                                );
                              }
                            ),
                          
                            const SizedBox(height: 13),
                            TextField(
                              controller: emailController,
                              decoration: _buildInputDecoration(hintText: l10n.loginEmailHint),
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: Color(0xFF222222), fontSize: 16),
                            ),
                            const SizedBox(height: 13),
                            TextField(
                              controller: passwordController,
                              decoration: _buildInputDecoration(hintText: l10n.loginPasswordHint),
                              obscureText: true,
                              style: const TextStyle(color: Color(0xFF222222), fontSize: 16),
                            ),
                            const SizedBox(height: 13),
                            
                            // Login Button
                            ElevatedButton(
                              onPressed: isLoggingIn ? null : _loginWithEmail,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFAFAFA),
                                // If Sage Mode: Use Brand Dark Green for text. Else Dark Grey.
                                foregroundColor: Theme.of(context).cardColor.value == AppColors.sageCardBackground.value 
                                    ? AppColors.sageCardBackground 
                                    : const Color(0xFF222222),
                                minimumSize: const Size(285, 38),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              child: isLoggingIn 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                                : Text(
                                  l10n.loginButton,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                            ),
                            const SizedBox(height: 13),
                            
                            // FaceID Button
                            // Unified Design: Always ElevatedButton (Solid Circle)
                            ElevatedButton(
                              onPressed: isLoggingIn ? null : _loginWithFaceID,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFAFAFA),
                                // If Sage Mode: Use Brand Dark Green icons. Else Dark Grey.
                                foregroundColor: Theme.of(context).cardColor.value == AppColors.sageCardBackground.value 
                                    ? AppColors.sageCardBackground 
                                    : const Color(0xFF222222),
                                fixedSize: const Size(50, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.viewfinder,
                                    size: 40,
                                    // Use property from style (foregroundColor) automatically? 
                                    // Icon color defaults to IconTheme which might not pick up ElevatedButton foreground automatically if set explicitly.
                                    // Let's use explicit color based on logic to be safe.
                                    color: Theme.of(context).cardColor.value == AppColors.sageCardBackground.value 
                                        ? AppColors.sageCardBackground 
                                        : const Color(0xFF222222),
                                  ),
                                  Icon(
                                    CupertinoIcons.person_fill,
                                    size: 20,
                                    color: Theme.of(context).cardColor.value == AppColors.sageCardBackground.value 
                                        ? AppColors.sageCardBackground 
                                        : const Color(0xFF222222),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ArcClipper extends CustomClipper<Path> {
  final double offsetYFactor;

  ArcClipper({this.offsetYFactor = 0.20});

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, size.height); 
    path.lineTo(0, size.height * offsetYFactor); 
    path.quadraticBezierTo(
      size.width / 2, 
      0, 
      size.width, 
      size.height * offsetYFactor,
    );
    path.lineTo(size.width, size.height); 
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return oldClipper is ArcClipper && oldClipper.offsetYFactor != offsetYFactor;
  }
}