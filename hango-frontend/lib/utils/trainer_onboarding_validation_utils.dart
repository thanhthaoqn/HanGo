const List<String> _trainerImageExtensions = <String>[
  '.jpg',
  '.jpeg',
  '.png',
  '.webp',
];

const List<String> _trainerDocumentExtensions = <String>[
  ..._trainerImageExtensions,
  '.pdf',
];

final RegExp _vietnamesePhoneRegex = RegExp(r'^(03|05|07|08|09)\d{8}$');
final RegExp _dummyPhoneRegex = RegExp(r'^(\d)\1{9}$');
final RegExp _digitsOnlyRegex = RegExp(r'^\d+$');
final RegExp _uppercaseAccountNameRegex = RegExp(r'^[A-Z ]+$');

bool _isDummyFinancialNumber(String value) {
  return RegExp(r'^(\d)\1+$').hasMatch(value) ||
      value == '1234567890' ||
      value == '123456789012' ||
      value == '1234567890123' ||
      value == '0123456789';
}

bool isValidVietnamesePhoneNumber(String? phone) {
  if (phone == null) {
    return false;
  }

  final trimmed = phone.trim();
  if (trimmed.isEmpty) {
    return false;
  }

  return _vietnamesePhoneRegex.hasMatch(trimmed) &&
      !_dummyPhoneRegex.hasMatch(trimmed) &&
      trimmed != '1234567890';
}

String? validateVietnamesePhoneNumber(
  String? phone, {
  required bool isVi,
  bool requiredField = true,
}) {
  final trimmed = phone?.trim() ?? '';

  if (trimmed.isEmpty) {
    if (!requiredField) {
      return null;
    }

    return isVi
        ? 'Vui lòng nhập số điện thoại liên hệ.'
        : 'Please enter contact phone number.';
  }

  if (isValidVietnamesePhoneNumber(trimmed)) {
    return null;
  }

  return isVi
      ? 'Số điện thoại không hợp lệ (bắt đầu bằng 03/05/07/08/09, đủ 10 số).'
      : 'Invalid phone number (must be 10 digits starting with 03/05/07/08/09).';
}

String? validateTrainerBankAccount(
  String? value, {
  required bool isVi,
  bool requiredField = true,
}) {
  final account = value?.trim() ?? '';
  if (account.isEmpty) {
    if (!requiredField) return null;
    return isVi
        ? 'Vui lòng nhập số tài khoản ngân hàng.'
        : 'Please enter the bank account number.';
  }
  if (!_digitsOnlyRegex.hasMatch(account) ||
      account.length < 6 ||
      account.length > 20 ||
      _isDummyFinancialNumber(account)) {
    return isVi
        ? 'Số tài khoản phải gồm 6-20 chữ số hợp lệ.'
        : 'Bank account must contain 6-20 valid digits.';
  }
  return null;
}

String? validateTrainerBankAccountName(
  String? value, {
  required bool isVi,
  bool requiredField = true,
}) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) {
    if (!requiredField) return null;
    return isVi
        ? 'Vui lòng nhập tên chủ tài khoản.'
        : 'Please enter the account owner name.';
  }
  if (!_uppercaseAccountNameRegex.hasMatch(name)) {
    return isVi
        ? 'Tên chủ tài khoản phải viết hoa, không dấu.'
        : 'Account owner name must be uppercase and unaccented.';
  }
  return null;
}

String? validateTrainerTaxCode(String? value, {required bool isVi}) {
  final taxCode = value?.trim() ?? '';
  if (taxCode.isEmpty) return null;
  if (!RegExp(r'^\d{10}(\d{3})?$').hasMatch(taxCode) ||
      _isDummyFinancialNumber(taxCode)) {
    return isVi
        ? 'Mã số thuế phải có 10 hoặc 13 chữ số hợp lệ.'
        : 'Tax ID must contain 10 or 13 valid digits.';
  }
  return null;
}

String? validateTrainerCitizenId(
  String? value, {
  required bool isVi,
  bool requiredField = true,
}) {
  final citizenId = value?.trim() ?? '';
  if (citizenId.isEmpty) {
    if (!requiredField) return null;
    return isVi ? 'Vui lòng nhập số CCCD.' : 'Please enter the Citizen ID.';
  }
  if (!RegExp(r'^\d{12}$').hasMatch(citizenId) ||
      _isDummyFinancialNumber(citizenId)) {
    return isVi
        ? 'Số CCCD phải có đúng 12 chữ số hợp lệ.'
        : 'Citizen ID must contain exactly 12 valid digits.';
  }
  return null;
}

String? validateTrainerUploadFile({
  required String fileName,
  required int fileSizeBytes,
  required int maxSizeBytes,
  required bool allowPdf,
  required bool isVi,
}) {
  if (fileSizeBytes > maxSizeBytes) {
    final maxMb = (maxSizeBytes / (1024 * 1024)).toStringAsFixed(0);
    return isVi
        ? 'Dung lượng file "$fileName" vượt quá $maxMb MB. Vui lòng chọn file nhỏ hơn.'
        : 'File "$fileName" exceeds the $maxMb MB size limit. Please choose a smaller file.';
  }

  final lowerName = fileName.toLowerCase();
  final allowedExtensions = allowPdf
      ? _trainerDocumentExtensions
      : _trainerImageExtensions;
  final isValidExtension = allowedExtensions.any(lowerName.endsWith);

  if (isValidExtension) {
    return null;
  }

  return isVi
      ? 'Định dạng file "$fileName" không được hỗ trợ. Chỉ chấp nhận (${allowedExtensions.join(", ")}).'
      : 'File format of "$fileName" is not supported. Allowed formats: (${allowedExtensions.join(", ")}).';
}
