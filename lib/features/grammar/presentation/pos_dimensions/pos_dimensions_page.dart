import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// POS & Dimensions master-detail page — Phase 4 plan 04-04.
///
/// Task 1 ships the minimal class declaration so the router compiles and
/// the route smoke test can `find.byType(PosDimensionsPage)`. Task 2
/// expands this into a full master-detail editor with the dimension
/// template picker.
class PosDimensionsPage extends ConsumerStatefulWidget {
  const PosDimensionsPage({super.key});

  @override
  ConsumerState<PosDimensionsPage> createState() => _PosDimensionsPageState();
}

class _PosDimensionsPageState extends ConsumerState<PosDimensionsPage> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
