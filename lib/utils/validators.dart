class Validators {
  static String? validateNationalId(String? value, String errorMsg) {
    if (value == null || value.isEmpty) return errorMsg;
    if (value.length != 10 || int.tryParse(value) == null) return errorMsg;
    return null;
  }

  static String? validateLandSize(String? value, String errorMsg) {
    if (value == null || value.isEmpty) return errorMsg;
    final size = double.tryParse(value);
    if (size == null || size <= 0) return errorMsg;
    return null;
  }

  static String? validateRequired(String? value, String errorMsg) {
    if (value == null || value.isEmpty) return errorMsg;
    return null;
  }
}
