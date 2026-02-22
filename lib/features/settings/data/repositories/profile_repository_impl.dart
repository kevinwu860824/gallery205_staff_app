import 'package:shared_preferences/shared_preferences.dart';
import 'package:gallery205_staff_app/features/settings/data/datasources/profile_remote_data_source.dart';
import 'package:gallery205_staff_app/features/settings/domain/entities/staff_profile.dart';
import 'package:gallery205_staff_app/features/settings/domain/repositories/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remoteDataSource;
  final SharedPreferences sharedPreferences;
  final SupabaseClient supabaseClient;

  ProfileRepositoryImpl({
    required this.remoteDataSource, 
    required this.sharedPreferences,
    required this.supabaseClient,
  });

  @override
  Future<StaffProfile> getCurrentProfile() async {
    final user = supabaseClient.auth.currentUser;
    if (user == null) throw Exception("No authenticated user");

    final shopId = sharedPreferences.getString('savedShopId');
    if (shopId == null) throw Exception("No shop selected");

    return remoteDataSource.fetchUserProfile(user.id, shopId);
  }
}
