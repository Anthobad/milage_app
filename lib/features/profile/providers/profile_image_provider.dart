// ---------------------------------------------------------------------------
// ProfileImageState — Phase 7.1 minimal abstraction
// ---------------------------------------------------------------------------
//
// Minimal local-only profile image abstraction.
//
// ## Design goals
//
// * No cloud storage, no accounts, no network.
// * No onboarding prompt.
// * The image is entirely optional — the UI defaults to a generic icon.
// * A future phase can call [setImagePath] to persist a local file path and
//   the Profile header will update automatically via Riverpod.
//
// ## Current implementation
//
// Phase 7.1 only scaffolds the state/provider so the Profile header widget
// can read from it.  Actual image selection (image_picker, file_picker, etc.)
// is deferred to a later phase when the user-facing "change photo" action
// is implemented.
//
// ## Storage
//
// The chosen local image path will be persisted in SharedPreferences
// (key: `profile_image_path`) in the phase that implements image selection.
// For now the provider simply holds `null` (no image selected).

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// ProfileImageNotifier
// ---------------------------------------------------------------------------

/// Manages the optional local profile image path.
///
/// `null` means no image is selected — the UI should show the default icon.
/// A non-null value is an absolute path on the local file system.
class ProfileImageNotifier extends Notifier<String?> {
  @override
  String? build() {
    // Phase 7.1: always starts with no image.
    // A future phase will load the persisted path from SharedPreferences here.
    return null;
  }

  /// Updates the profile image path.
  ///
  /// Pass `null` to revert to the default generic icon.
  /// Pass an absolute local file path to display a user-selected photo.
  void setImagePath(String? path) {
    state = path;
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Exposes the optional local profile image path.
///
/// `null`  → show generic profile icon (default).
/// String  → absolute path to a local image file chosen by the user.
final profileImageProvider = NotifierProvider<ProfileImageNotifier, String?>(
  ProfileImageNotifier.new,
);
