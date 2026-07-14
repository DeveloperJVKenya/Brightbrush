/// The four pilot roles. Every route, nav shell, and permission check in the
/// app keys off this enum, resolved from the signed-in user's Firestore
/// `users/{uid}.role` field (see `resolvedRoleProvider`) — these enum names
/// must match the role strings used there and in firestore.rules exactly.
enum AppRole {
  customer,
  deliveryStaff,
  systemManager,
  admin;

  static AppRole fromRoleName(String? name) {
    return AppRole.values.firstWhere((r) => r.name == name, orElse: () => AppRole.customer);
  }

  String get label => switch (this) {
        AppRole.customer => 'Customer',
        AppRole.deliveryStaff => 'Delivery Staff',
        AppRole.systemManager => 'System Manager',
        AppRole.admin => 'Admin / CEO',
      };

  /// Root path each role lands on after choosing/authenticating.
  String get homePath => switch (this) {
        AppRole.customer => '/customer',
        AppRole.deliveryStaff => '/staff',
        AppRole.systemManager => '/manager',
        AppRole.admin => '/admin',
      };
}
