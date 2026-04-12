/// Splits raw Markdown into heading-delimited sections.
/// Per D-06: each heading (##, ###, etc.) defines an editable block;
/// content between headings is one editable unit.
///
/// Returns a list of block strings. The first entry is pre-heading
/// content (may be empty string). Each subsequent entry starts with
/// a heading line.
///
/// Code fences (```) are respected — headings inside code fences
/// are NOT treated as block boundaries.
List<String> splitIntoBlocks(String markdown) {
  if (markdown.isEmpty) return [''];

  final lines = markdown.split('\n');
  final blocks = <String>[];
  final buffer = StringBuffer();
  bool inCodeFence = false;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];

    // Track code fence state
    if (line.trimLeft().startsWith('```')) {
      inCodeFence = !inCodeFence;
    }

    // Check for heading at start of line (outside code fence)
    final isHeading = !inCodeFence && RegExp(r'^#{1,6} ').hasMatch(line);

    if (isHeading && buffer.isNotEmpty) {
      blocks.add(buffer.toString());
      buffer.clear();
    }

    buffer.write(line);
    if (i < lines.length - 1) buffer.write('\n');
  }

  if (buffer.isNotEmpty) {
    blocks.add(buffer.toString());
  }

  return blocks.isEmpty ? [''] : blocks;
}

/// Joins blocks back into a single Markdown string.
/// Inverse of splitIntoBlocks — round-trip must be lossless.
String joinBlocks(List<String> blocks) {
  return blocks.join('');
}
