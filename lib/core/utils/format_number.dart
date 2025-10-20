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
