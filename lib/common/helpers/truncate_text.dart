String truncateText(String text, int maxLength) {
  if (text.length <= maxLength) {
    return text;
  }

  final truncated = text.substring(0, maxLength);
  return '$truncated...';
}
