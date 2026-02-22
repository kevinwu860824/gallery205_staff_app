import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gallery205_staff_app/core/theme/app_theme.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:gallery205_staff_app/features/auth/presentation/providers/auth_providers.dart';

class SettingsCategoryScreen extends ConsumerWidget {
  final String categoryId;
  final String title;
  final List<Map<String, dynamic>> options;

  const SettingsCategoryScreen({
    super.key,
    required this.categoryId,
    required this.title,
    required this.options,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CupertinoNavigationBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        border: null,
        middle: Text(
          title,
          style: AppTextStyles.settingsListItem.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        previousPageTitle: AppLocalizations.of(context)!.settingsTitle,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(25),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Column(
                  children: [
                    for (int i = 0; i < options.length; i++) ...[
                      _buildListTile(context, ref, options[i]),
                      if (i < options.length - 1)
                        Divider(
                          height: 1.0,
                          thickness: 1.2,
                          color: colorScheme.onSurface.withOpacity(0.1),
                          indent: 61.0,
                          endIndent: 20.0,
                        )
                    ]
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconContainer(BuildContext context, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 29,
      height: 29,
      decoration: BoxDecoration(
        color: colorScheme.onSurface,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(
        icon,
        color: Theme.of(context).scaffoldBackgroundColor,
        size: 18,
      ),
    );
  }

  Widget _buildListTile(BuildContext context, WidgetRef ref, Map<String, dynamic> option) {
    return CupertinoListTile(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
      leading: _buildIconContainer(context, option['icon'] as IconData),
      title: Text(
        option['label'] as String,
        style: AppTextStyles.settingsListItem.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      trailing: Icon(
        CupertinoIcons.chevron_right,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
        size: 18,
      ),
      onTap: () async {
        if (option['action'] == 'logout') {
          await ref.read(authRepositoryProvider).logout();
          if (context.mounted) context.go('/');
        } else {
          context.push(option['route'] as String);
        }
      },
    );
  }
}
