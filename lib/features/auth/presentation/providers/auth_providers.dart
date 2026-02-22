import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gallery205_staff_app/features/auth/data/datasources/auth_data_source.dart';
import 'package:gallery205_staff_app/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:gallery205_staff_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:gallery205_staff_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:gallery205_staff_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:gallery205_staff_app/features/auth/domain/entities/auth_user.dart';

// --- Core Dependencies ---

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main.dart');
});

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// --- Data Sources ---

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSourceImpl(ref.watch(supabaseClientProvider));
});

final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  return AuthLocalDataSourceImpl(ref.watch(sharedPreferencesProvider));
});

// --- Repository ---

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.watch(authRemoteDataSourceProvider),
    ref.watch(authLocalDataSourceProvider),
  );
});

// --- State Providers ---

/// Stream of the current authenticated user.
final authStateProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// Controller for Login Actions
class LoginController extends StateNotifier<AsyncValue<AuthUser?>> {
  final AuthRepository _repository;

  LoginController(this._repository) : super(const AsyncValue.data(null));

  Future<void> login({
    required String email, 
    required String password, 
    required String shopCode
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.login(
        email: email, 
        password: password, 
        shopCode: shopCode
      );
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final loginControllerProvider = StateNotifierProvider<LoginController, AsyncValue<AuthUser?>>((ref) {
  return LoginController(ref.watch(authRepositoryProvider));
});

// --- Helper Providers for UI ---

final savedShopCodesProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(authRepositoryProvider).getSavedShopCodes();
});

final credentialForShopProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, shopCode) {
  return ref.watch(authRepositoryProvider).getLoginCredential(shopCode);
});
