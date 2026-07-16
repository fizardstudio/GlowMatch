class SkincareIngredient {
  final String name;
  final List<String> aliases;
  final String category;
  final String description;
  final int irritationScore; // 1 to 5 (1 = Low Risk, 5 = High Risk / Active Acid)
  final Map<String, double> compatibility; // Key: 'dry', 'oily', 'normal', 'sensitive', 'acne_prone'. Value: -1.0 to 1.0

  const SkincareIngredient({
    required this.name,
    required this.aliases,
    required this.category,
    required this.description,
    required this.irritationScore,
    required this.compatibility,
  });
}
