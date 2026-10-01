import 'dart:async';

import 'package:web/web.dart' as web;

/// Whether the browser thinks it has a network (navigator.onLine).
bool? browserIsOnline() => web.window.navigator.onLine;

StreamController<bool>? _changes;

/// true/false each time the browser goes online/offline.
Stream<bool>? browserOnlineChanges() {
  if (_changes == null) {
    _changes = StreamController<bool>.broadcast();
    web.EventStreamProviders.onlineEvent
        .forTarget(web.window)
        .listen((_) => _changes!.add(true));
    web.EventStreamProviders.offlineEvent
        .forTarget(web.window)
        .listen((_) => _changes!.add(false));
  }
  return _changes!.stream;
}
