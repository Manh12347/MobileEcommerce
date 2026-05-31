import 'package:flutter/foundation.dart';

// When a screen wants the main shell to switch tabs it can set this
// notifier to the desired tab index (0-based). The shell clears the
// value after handling it.
final ValueNotifier<int?> navigateToTabNotifier = ValueNotifier<int?>(null);
