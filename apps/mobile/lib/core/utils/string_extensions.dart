extension StringTitleCaseX on String {
  /// Convierte el texto a Title Case, haciendo que la primera letra de cada palabra sea mayúscula.
  /// Ejemplo: "grupo de amigos" -> "Grupo De Amigos", "LOS PIBES" -> "Los Pibes"
  String toTitleCase() {
    if (trim().isEmpty) return this;
    return split(' ').map((word) {
      if (word.isEmpty) return word;
      final lower = word.toLowerCase();
      return lower[0].toUpperCase() + lower.substring(1);
    }).join(' ');
  }
}
