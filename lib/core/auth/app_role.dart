/// The four pilot roles. Every route, nav shell, and permission check in the
/// app keys off this enum until real Firebase custom-claims/roles land.
enum AppRole {
  customer,
  deliveryStaff,
  systemManager,
  admin;

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
