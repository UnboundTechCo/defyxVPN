String doubleFormatNumber(double value) {
  double rounded = double.parse(value.toStringAsFixed(1));

  if (rounded == rounded.toInt()) {
    int intValue = rounded.toInt();
    String result = intValue.toString();
    if (intValue >= 1000 || intValue <= -1000) {
      result = result.replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
    }
    return result;
  }
  return rounded.toString();
}

String numFormatNumber(num value) {
  double rounded = double.parse(value.toStringAsFixed(1));

  if (rounded == rounded.toInt()) {
    int intValue = rounded.toInt();
    String result = intValue.toString();
    if (intValue >= 1000 || intValue <= -1000) {
      result = result.replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
    }
    return result;
  }
  return rounded.toString();
}

/// Formats a speed in Mbps: whole numbers from 1 up, one decimal below 1.
String formatSpeed(num mbps) {
  if (!mbps.isFinite || mbps <= 0) return '0';
  final oneDecimal = double.parse(mbps.toStringAsFixed(1));
  if (oneDecimal == 0) return '0';
  if (oneDecimal < 1) return oneDecimal.toStringAsFixed(1);
  return _groupThousands(mbps.round());
}

String _groupThousands(int value) => value.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
  (Match m) => '${m[1]},',
);
