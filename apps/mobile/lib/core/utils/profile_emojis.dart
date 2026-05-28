const List<String> profileEmojis = [
  '🙂',
  '✨',
  '🌙',
  '💙',
  '🫶',
  '🔥',
  '🌊',
  '🍀',
  '⚡',
  '🎧',
];

String emojiForSeed(String seed) {
  if (seed.isEmpty) {
    return profileEmojis.first;
  }

  final index = seed.hashCode.abs() % profileEmojis.length;
  return profileEmojis[index];
}
