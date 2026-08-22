import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Signal notifier used to programmatically open the car selector sheet from
/// anywhere in the widget tree without tight coupling to [MainNavigation].
///
/// Usage:
///   Call `ref.read(openCarSheetProvider.notifier).request()` to request open.
///   [MainNavigation] listens with `ref.listen` and calls [_openSheet()] then
///   immediately resets back to `false`.
///
/// This avoids threading a callback through the widget tree or a GlobalKey.
class OpenCarSheetNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Request the car sheet to open.
  void request() => state = true;

  /// Reset after the request has been handled.
  void reset() => state = false;
}

final NotifierProvider<OpenCarSheetNotifier, bool> openCarSheetProvider =
    NotifierProvider<OpenCarSheetNotifier, bool>(OpenCarSheetNotifier.new);
