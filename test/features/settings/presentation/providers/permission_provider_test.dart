import 'package:flutter_test/flutter_test.dart';
import 'package:gallery205_staff_app/features/settings/presentation/providers/profile_providers.dart';

void main() {
  group('PermissionHelper Tests', () {
    test('hasPermission returns true if code is in list', () {
      final helper = PermissionHelper(['manage_users', 'view_reports']);
      
      expect(helper.hasPermission('manage_users'), isTrue);
      expect(helper.hasPermission('view_reports'), isTrue);
    });

    test('hasPermission returns false if code is NOT in list', () {
      final helper = PermissionHelper(['manage_users']);
      
      expect(helper.hasPermission('delete_db'), isFalse);
    });

    test('hasPermission returns true if admin_all is present', () {
      final helper = PermissionHelper(['admin_all']);
      
      expect(helper.hasPermission('anything'), isTrue);
    });

    test('hasPermission is case sensitive (usually)', () {
      final helper = PermissionHelper(['manage_users']);
      
      expect(helper.hasPermission('MANAGE_USERS'), isFalse);
    });
  });
}
