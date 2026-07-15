/// The five system roles. Every route, nav shell, and permission check in
/// the app keys off this enum, resolved from the signed-in user's Firestore
/// `users/{uid}.role` field (see `resolvedRoleProvider`) — these enum names
/// must match the role strings used there and in firestore.rules exactly.
///
/// [user] is the default role every self-registered account gets (labeled
/// "User" — this used to be called "Customer" internally; the shopping/
/// ordering routes under `/customer` keep that path for historical reasons,
/// but the role name and label are just "User" now). Every other role is
/// assigned by an Admin/CEO or Developer via the Role Management screen
/// (`/admin/settings`) — never self-service.
enum AppRole {
  user,
  deliveryStaff,
  systemManager,
  admin,
  developer;

  static AppRole fromRoleName(String? name) {
    return AppRole.values.firstWhere((r) => r.name == name, orElse: () => AppRole.user);
  }

  String get label => switch (this) {
        AppRole.user => 'User',
        AppRole.deliveryStaff => 'Delivery Staff',
        AppRole.systemManager => 'System Manager',
        AppRole.admin => 'Admin / CEO',
        AppRole.developer => 'Developer',
      };

  /// Root path each role lands on after choosing/authenticating. Developer
  /// lands on a picker that lets them browse into any other role's shell —
  /// their Firestore permissions already allow all of them, so that's a
  /// pure navigation affordance, not a separate access grant.
  String get homePath => switch (this) {
        AppRole.user => '/customer',
        AppRole.deliveryStaff => '/staff',
        AppRole.systemManager => '/manager',
        AppRole.admin => '/admin',
        AppRole.developer => '/developer',
      };
}
