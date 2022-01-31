import 'package:flutter/material.dart' show Color;

class ApplePayConfigs {
  final String merchantId;
  final String language;
  final Color? accentColor;

  const ApplePayConfigs({
    required this.merchantId,
    required this.language,
    this.accentColor,
  });

  Map<String, String?> toMap() {
    return {
      'apple_merchant_id': merchantId,
      'language_code': language,
      'accent_color_code': accentColor?.toHex(),
    };
  }
}

extension on Color {
  /// Prefixes a hash sign if [leadingHashSign] is set to `true` (default is `true`).
  String toHex({bool leadingHashSign = true}) => '${leadingHashSign ? '#' : ''}'
      '${alpha.toRadixString(16).padLeft(2, '0')}'
      '${red.toRadixString(16).padLeft(2, '0')}'
      '${green.toRadixString(16).padLeft(2, '0')}'
      '${blue.toRadixString(16).padLeft(2, '0')}';
}
