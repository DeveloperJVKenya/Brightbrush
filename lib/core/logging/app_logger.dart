import 'package:logger/logger.dart';

/// One shared, leveled logger for the whole app. Every auth transition,
/// Firestore read/write, and routing decision that's easy to get subtly
/// wrong (role resolution, permission-denied, staff assignment) logs
/// through this so it's traceable from the terminal instead of guessed at
/// from a blank/erroring screen.
///
/// Named `_logger`-style aliases in each file just re-export this instance —
/// see usage throughout `core/auth`, `core/router`, and the `orders`/
/// `catalog` repositories.
final Logger appLogger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 6,
    lineLength: 100,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);
