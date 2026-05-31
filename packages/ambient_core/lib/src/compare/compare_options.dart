class CompareOptions {
  const CompareOptions({
    this.threshold = 0.1,
    this.includeAA = false,
    this.alpha = 0.1,
    this.diffColor = CompareColor.highlight,
  }) : assert(
         threshold >= 0 && threshold <= 1,
         'threshold must be between 0 and 1.',
       ),
       assert(alpha >= 0 && alpha <= 1, 'alpha must be between 0 and 1.');

  final double threshold;
  final bool includeAA;
  final double alpha;
  final CompareColor diffColor;

  CompareOptions copyWith({
    double? threshold,
    bool? includeAA,
    double? alpha,
    CompareColor? diffColor,
  }) {
    return CompareOptions(
      threshold: threshold ?? this.threshold,
      includeAA: includeAA ?? this.includeAA,
      alpha: alpha ?? this.alpha,
      diffColor: diffColor ?? this.diffColor,
    );
  }

  Map<String, Object> toPixelmatchOptions() => {
    'threshold': threshold,
    'includeAA': includeAA,
    'alpha': alpha,
    'diffColor': diffColor.toPixelmatchColor(),
  };

  @override
  bool operator ==(Object other) =>
      other is CompareOptions &&
      other.threshold == threshold &&
      other.includeAA == includeAA &&
      other.alpha == alpha &&
      other.diffColor == diffColor;

  @override
  int get hashCode => Object.hash(threshold, includeAA, alpha, diffColor);

  @override
  String toString() =>
      'CompareOptions(threshold: $threshold, includeAA: $includeAA, alpha: $alpha, diffColor: $diffColor)';
}

class CompareColor {
  const CompareColor(this.red, this.green, this.blue)
    : assert(red >= 0 && red <= 255, 'red must be between 0 and 255.'),
      assert(green >= 0 && green <= 255, 'green must be between 0 and 255.'),
      assert(blue >= 0 && blue <= 255, 'blue must be between 0 and 255.');

  static const CompareColor highlight = CompareColor(255, 0, 0);

  final int red;
  final int green;
  final int blue;

  List<int> toPixelmatchColor() => [red, green, blue];

  @override
  bool operator ==(Object other) =>
      other is CompareColor &&
      other.red == red &&
      other.green == green &&
      other.blue == blue;

  @override
  int get hashCode => Object.hash(red, green, blue);

  @override
  String toString() => 'CompareColor($red, $green, $blue)';
}
