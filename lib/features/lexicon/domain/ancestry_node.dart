import '../../../db/app_database.dart';

/// An immutable node in the ancestry tree for a [Lexeme].
///
/// The tree is built upward from a given lexeme toward its roots: each node
/// holds the [lexeme] itself plus its [parents] as a list of [AncestryNode]
/// instances. Leaf nodes (roots with no parents) have an empty [parents] list.
///
/// Two sentinel flags are used for special traversal outcomes:
/// - [isCycle]: this node was already visited in the current ancestor branch
///   (true only for cycles in a single branch — shared ancestors in a DAG are
///   NOT flagged as cycles).
/// - [isTruncated]: ancestry traversal reached the maximum depth (10 levels)
///   at this node; parents were not expanded.
///
/// [edgeLabel] describes the relationship from this node to its child
/// (i.e. the word that listed this node as a parent):
/// - `"via Rule Name"` for rule-derived parents
/// - `"parent"` for unlabelled manual parents
/// - custom relationship string if the user provided one
///
/// This type is read-only. No [copyWith] is provided.
class AncestryNode {
  /// Creates an [AncestryNode].
  const AncestryNode({
    required this.lexemeId,
    required this.lexeme,
    required this.edgeLabel,
    required this.isRuleDerived,
    this.parents = const [],
    this.isCycle = false,
    this.isTruncated = false,
  });

  /// The database ID of the lexeme this node represents.
  final int lexemeId;

  /// The [Lexeme] row for this node. Null only when the parent lexeme has been
  /// deleted from the database while a child still references it.
  final Lexeme? lexeme;

  /// Relationship label from this node toward its child in the tree.
  ///
  /// Set by the *child* node that lists this node as a parent:
  /// - `"via Rule Name"` for rule-derived edges
  /// - `"parent"` when the manual link has no relationship string
  /// - the custom [LexemeParentRow.relationship] string otherwise
  ///
  /// Empty string `""` for the root / query word itself (depth 0).
  final String edgeLabel;

  /// True when this parent edge was created via a morphological rule
  /// ([Lexeme.derivedFromLexemeId] + [Lexeme.derivedViaRuleId]).
  /// False for manual parent links (stored in the [LexemeParents] table).
  final bool isRuleDerived;

  /// This node's own parents, each carrying their sub-tree. Empty for root
  /// words (words with no further ancestry).
  final List<AncestryNode> parents;

  /// True when this node's [lexemeId] was already visited in the current
  /// branch, indicating a cyclic parent reference. When true, [parents] is
  /// always empty and the renderer should show a cycle warning.
  final bool isCycle;

  /// True when this node was reached at the maximum traversal depth (10
  /// levels). When true, [parents] is always empty and the renderer should
  /// show a truncation indicator (e.g. "↑ N more ancestors").
  final bool isTruncated;
}
