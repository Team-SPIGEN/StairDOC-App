class Validators {
  const Validators._();

  static final RegExp _emailRegExp = RegExp(
    r"^[a-zA-Z0-9.!#%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$",
  );

  static final RegExp _passwordRegExp = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[A-Za-z\d@$!%*?&]{8,}$',
  );

  static final RegExp _nameRegExp = RegExp(r'^[A-Za-z ]{2,}$');

  static final RegExp _phoneRegExp = RegExp(r'^\+?\d{7,15}$');

  static String? validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Email is required.';
    }
    if (!_emailRegExp.hasMatch(trimmed)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Password is required.';
    }
    if (!_passwordRegExp.hasMatch(trimmed)) {
      return 'At least 8 characters with uppercase, lowercase, and number.';
    }
    return null;
  }

  static String? validateName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Name is required.';
    }
    if (!_nameRegExp.hasMatch(trimmed)) {
      return 'Use letters only (min 2 characters).';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    if (!_phoneRegExp.hasMatch(trimmed)) {
      return 'Enter a valid phone number.';
    }
    return null;
  }

  static String? validateConfirmPassword(String? value, String password) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Confirm your password.';
    }
    if (trimmed != password.trim()) {
      return 'Passwords do not match.';
    }
    return null;
  }

  static double passwordStrength(String value) {
    if (value.isEmpty) {
      return 0;
    }
    double score = 0;
    if (value.length >= 8) score += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(value)) score += 0.25;
    if (RegExp(r'[a-z]').hasMatch(value)) score += 0.25;
    if (RegExp(r'[0-9]').hasMatch(value)) score += 0.15;
    if (RegExp(r'[@$!%*?&#]').hasMatch(value)) score += 0.1;
    return score.clamp(0, 1);
  }
}
