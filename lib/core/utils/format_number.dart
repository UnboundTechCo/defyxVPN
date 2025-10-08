String doubleFormatNumber(double value) {
  double rounded = double.parse(value.toStringAsFixed(1));

  if (rounded == rounded.toInt()) {
    return rounded.toInt().toString();
  }
  return rounded.toString();
}

String numFormatNumber(num value) {
  double rounded = double.parse(value.toStringAsFixed(1));

  if (rounded == rounded.toInt()) {
    return rounded.toInt().toString();
  }
  return rounded.toString();
}
