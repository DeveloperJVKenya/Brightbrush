import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_role.dart';

/// Currently signed-in role. `null` means logged out.
///
/// This is a placeholder for real Firebase Authentication + custom-claims
/// based role resolution. It exists so routing/navigation/permissions can
/// be built and demoed end-to-end before the backend is wired up.
final currentRoleProvider = StateProvider<AppRole?>((ref) => null);
