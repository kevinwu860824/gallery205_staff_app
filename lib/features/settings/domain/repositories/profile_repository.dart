import 'package:gallery205_staff_app/features/settings/domain/entities/staff_profile.dart';

abstract class ProfileRepository {
  /// Fetches the profile of the current authenticated user.
  /// Including their mapped Shop Role and Permissions.
  Future<StaffProfile> getCurrentProfile();
}
