import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/culture_providers.dart';
import '../../project/data/project_providers.dart';
import '../../../db/app_database.dart' show CulturePage;

String _formatDate(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

/// Displays a single culture wiki page: header (emoji + title + timestamps)
/// and content area with raw Markdown text.
///
/// Plan 02: renders content as plain [Text] showing raw Markdown.
/// Plan 03 will replace this with the block editor + rendered Markdown.
class CulturePageView extends ConsumerStatefulWidget {
  const CulturePageView({super.key, required this.pageId});

  final int pageId;

  @override
  ConsumerState<CulturePageView> createState() => _CulturePageViewState();
}

class _CulturePageViewState extends ConsumerState<CulturePageView> {
  bool _editingTitle = false;
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _saveTitle(CulturePage page, String newTitle) async {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty || trimmed == page.title) {
      setState(() => _editingTitle = false);
      return;
    }
    final db = ref.read(currentDatabaseProvider);
    if (db == null) return;
    await db.cultureDao.updatePage(page.id, title: trimmed);
    if (mounted) setState(() => _editingTitle = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pageAsync = ref.watch(culturePageProvider(widget.pageId));

    return pageAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Could not load page.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
      data: (page) {
        if (page == null) {
          return Center(
            child: Text(
              'Page not found.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          );
        }

        final createdStr = _formatDate(page.createdAt);
        final modifiedStr = _formatDate(page.updatedAt);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Page header: emoji + title + timestamps + edit pencil
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Emoji icon prefix
                  if (page.icon != null && page.icon!.isNotEmpty) ...[
                    Text(page.icon!, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                  ],

                  // Title (editable)
                  Expanded(
                    child: _editingTitle
                        ? TextField(
                            controller: _titleController,
                            autofocus: true,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 4),
                              border: UnderlineInputBorder(),
                            ),
                            onSubmitted: (v) => _saveTitle(page, v),
                            onEditingComplete: () =>
                                _saveTitle(page, _titleController.text),
                          )
                        : Text(
                            page.title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),

                  const SizedBox(width: 8),

                  // Pencil edit button for title
                  if (!_editingTitle)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      tooltip: 'Rename page',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        _titleController.text = page.title;
                        setState(() => _editingTitle = true);
                      },
                    ),

                  const SizedBox(width: 12),

                  // Timestamps (right-aligned)
                  Text(
                    'Created: $createdStr  Modified: $modifiedStr',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 1, thickness: 1, color: colorScheme.outlineVariant),

            // Content area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 16),
                child: Text(
                  page.content.isEmpty
                      ? '(No content yet)'
                      : page.content,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: page.content.isEmpty
                        ? colorScheme.onSurface.withValues(alpha: 0.35)
                        : null,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
