/// D-91 - 04-17. Intrinsic-aware coverage matrix.
///
/// Axes = dimensions referenced by at least one active inflectional
/// rule's featureBindings for this POS (both intrinsic and non-intrinsic
/// are included if referenced; unreferenced intrinsic dims collapse OUT).
/// Cells = Cartesian product of (axis × levels).
///
/// BLOCKER-3 revision: canonical value-equal key for Cartesian coverage
/// cells. Dart's `Map<Map<int,int>, bool>` is a BROKEN data structure
/// because Maps use reference equality on non-primitive keys — two
/// structurally-equal inner maps hash to different buckets and any cell
/// lookup silently misses, causing coverage reports to return "uncovered"
/// for every cell. [FeatureSetKey] fixes this by imposing a canonical
/// sorted-by-dimensionId order and implementing proper `==` / `hashCode`.
class FeatureSetKey implements Comparable<FeatureSetKey> {
  FeatureSetKey(Map<int, int> entries)
      : _sorted = (entries.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)));

  final List<MapEntry<int, int>> _sorted;

  /// Read-only view as a Map. Cheap wrapper — do NOT mutate.
  Map<int, int> toMap() => {for (final e in _sorted) e.key: e.value};

  int? operator [](int dimensionId) {
    for (final e in _sorted) {
      if (e.key == dimensionId) return e.value;
      if (e.key > dimensionId) return null;
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FeatureSetKey) return false;
    if (other._sorted.length != _sorted.length) return false;
    for (var i = 0; i < _sorted.length; i++) {
      if (_sorted[i].key != other._sorted[i].key) return false;
      if (_sorted[i].value != other._sorted[i].value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll([
        for (final e in _sorted) ...[e.key, e.value]
      ]);

  @override
  int compareTo(FeatureSetKey other) {
    final n = _sorted.length < other._sorted.length
        ? _sorted.length
        : other._sorted.length;
    for (var i = 0; i < n; i++) {
      final kc = _sorted[i].key.compareTo(other._sorted[i].key);
      if (kc != 0) return kc;
      final vc = _sorted[i].value.compareTo(other._sorted[i].value);
      if (vc != 0) return vc;
    }
    return _sorted.length.compareTo(other._sorted.length);
  }

  @override
  String toString() =>
      '{${_sorted.map((e) => "${e.key}:${e.value}").join(",")}}';
}

/// D-91 — 04-17. Coverage matrix struct returned by
/// [paradigmCoverageMatrixProvider]. Axes are the union of referenced
/// dimension ids across active inflectional rules for the POS (intrinsic
/// or not). Cells are the Cartesian product of (axis × levels) keyed by
/// [FeatureSetKey] for value equality.
///
/// A rule covers a cell iff, for every axis in [axes], EITHER the rule
/// has no binding on that axis (covers all levels), OR the rule's
/// binding level equals the cell's level on that axis.
class CoverageMatrix {
  const CoverageMatrix({
    required this.axes,
    required this.cells,
  });

  /// Dimension ids that are paradigm axes. Order is deterministic
  /// (stable sorted by id).
  final List<int> axes;

  /// Cells keyed by [FeatureSetKey] (canonical value-equal wrapper around
  /// a `{dimId -> levelId}` map). Value is true when at least one rule
  /// covers the cell.
  ///
  /// BLOCKER-3 revision: the key type is [FeatureSetKey], NOT
  /// `Map<int, int>` — raw Maps use reference equality and would silently
  /// break cell lookups.
  final Map<FeatureSetKey, bool> cells;

  int get totalCells => cells.length;
  int get coveredCells => cells.values.where((v) => v).length;
  int get uncoveredCells => totalCells - coveredCells;
}
