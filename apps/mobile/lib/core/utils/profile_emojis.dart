const List<String> profileEmojis = [
  '\u{1F642}',
  '\u2728',
  '\u{1F319}',
  '\u{1F499}',
  '\u{1FAF6}',
  '\u{1F525}',
  '\u{1F30A}',
  '\u{1F340}',
  '\u26A1',
  '\u{1F3A7}',
];

String emojiForSeed(String seed) {
  if (seed.isEmpty) {
    return profileEmojis.first;
  }

  final index = seed.hashCode.abs() % profileEmojis.length;
  return profileEmojis[index];
}
