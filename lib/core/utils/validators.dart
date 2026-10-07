/// Form validators shared by the auth and setup forms.
abstract final class Validators {
  static final RegExp _email = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'required';
    if (!_email.hasMatch(v)) return 'invalid_email';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'required';
    if (v.length < 6) return 'too_short';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    final v = value ?? '';
    if (v.isEmpty) return 'required';
    if (v != original) return 'mismatch';
    return null;
  }

  static String? required(String? value, {int? max}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'required';
    if (max != null && v.length > max) return 'too_long';
    return null;
  }

  static String? inviteCode(String? value) {
    final v = value?.trim().toUpperCase() ?? '';
    if (v.isEmpty) return 'required';
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(v)) return 'invalid_code';
    return null;
  }

  /// Person / household display name: 1-40 chars after trimming.
  static String? displayName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'required';
    if (v.length > 40) return 'too_long';
    return null;
  }
}
