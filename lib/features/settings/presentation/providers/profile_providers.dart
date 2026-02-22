import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gallery205_staff_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:gallery205_staff_app/features/settings/data/datasources/profile_remote_data_source.dart';
import 'package:gallery205_staff_app/features/settings/data/repositories/profile_repository_impl.dart';
import 'package:gallery205_staff_app/features/settings/domain/entities/staff_profile.dart';
import 'package:gallery205_staff_app/features/settings/domain/repositories/profile_repository.dart';

// --- Data Layer ---

final profileRemoteDataSourceProvider = Provider<ProfileRemoteDataSource>((ref) {
  return ProfileRemoteDataSourceImpl(ref.watch(supabaseClientProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl(
    remoteDataSource: ref.watch(profileRemoteDataSourceProvider),
    sharedPreferences: ref.watch(sharedPreferencesProvider),
    supabaseClient: ref.watch(supabaseClientProvider),
  );
});

// --- Domain / State ---

/// Fetches the current user's full profile (including permissions).
/// Use ref.refresh(profileProvider) to reload if roles change.
final profileProvider = FutureProvider<StaffProfile>((ref) async {
  // Watch auth state to invalidate cache on logout/login
  ref.watch(authStateProvider); 
  
  final repo = ref.watch(profileRepositoryProvider);
  return repo.getCurrentProfile();
});

// --- Helpers ---

class PermissionHelper {
  final List<String> permissions;
  final String roleName;

  PermissionHelper(this.permissions, {this.roleName = ''});

  bool hasPermission(String code) {
    // 👑 Super Admin Check
    if (roleName.toLowerCase() == 'admin' || roleName.toLowerCase() == 'superadmin') {
      return true;
    }
    return permissions.contains(code) || permissions.contains('admin_all');
  }
}

/// Helper provider to check permissions easily.
/// Usage: ref.watch(permissionProvider).hasPermission('manage_users')
/// Returns a dummy helper with NO permissions if profile is loading/error (safe default).
final permissionProvider = Provider<PermissionHelper>((ref) {
  final profileAsync = ref.watch(profileProvider);
  
  return profileAsync.maybeWhen(
    data: (profile) => PermissionHelper(profile.permissions, roleName: profile.roleName),
    orElse: () => PermissionHelper([])
  );
});
