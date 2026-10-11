import 'package:flutter/material.dart';

import '../../../theme/app_dimensions.dart';
import '../../../theme/app_typography.dart';

/// Picks one value from a list, in a bottom sheet.
///
/// Used instead of [DropdownButton] because the lists here are long — 31
/// districts — and a Material dropdown renders them as a menu that overlays the
/// form, scrolls in a small window and cannot be searched. A sheet gets the full
/// height of the screen, a search box once the list is long enough to need one,
/// and a target the size of a thumb per row.
///
/// Returns the chosen value, or null if the sheet was dismissed. Dismissal is
/// distinct from choosing: a caller must not read "no change" as "cleared".
Future<String?> showOptionPicker(
  BuildContext context, {
  required String title,
  required List<String> options,
  String? selected,
  String? searchHint,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
    builder: (sheetContext) => _OptionPickerSheet(
      title: title,
      options: options,
      selected: selected,
      searchHint: searchHint,
    ),
  );
}

class _OptionPickerSheet extends StatefulWidget {
  const _OptionPickerSheet({
    required this.title,
    required this.options,
    this.selected,
    this.searchHint,
  });

  final String title;
  final List<String> options;
  final String? selected;
  final String? searchHint;

  /// Below this many options a search box is more chrome than help — it costs a
  /// row of height and a keyboard to filter a list already visible in full.
  static const _searchThreshold = 8;

  @override
  State<_OptionPickerSheet> createState() => _OptionPickerSheetState();
}

class _OptionPickerSheetState extends State<_OptionPickerSheet> {
  final _searchController = TextEditingController();
  late List<String> _visible = widget.options;

  bool get _searchable => widget.options.length >= _OptionPickerSheet._searchThreshold;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _visible = q.isEmpty
          ? widget.options
          : widget.options
              .where((option) => option.toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      // Lifts the sheet clear of the keyboard the search box summons.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.md),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.lg,
                AppSpacing.xxl,
                AppSpacing.md,
              ),
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
              ),
            ),
            if (_searchable)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  0,
                  AppSpacing.xxl,
                  AppSpacing.md,
                ),
                child: SizedBox(
                  height: AppSizes.controlHeight,
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filter,
                    autofocus: false,
                    style: AppTypography.fieldValue
                        .copyWith(color: scheme.onSurface),
                    decoration: InputDecoration(
                      hintText: widget.searchHint ?? 'Search',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    ),
                  ),
                ),
              ),
            Flexible(
              child: _visible.isEmpty
                  ? _EmptyResult(query: _searchController.text)
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                      itemCount: _visible.length,
                      itemBuilder: (context, index) {
                        final option = _visible[index];
                        final isSelected = option == widget.selected;

                        return ListTile(
                          title: Text(
                            option,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  color: scheme.onSurface,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_rounded,
                                  color: scheme.primary,
                                  size: 20,
                                )
                              : null,
                          onTap: () => Navigator.of(context).pop(option),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Text(
        'Nothing matches "${query.trim()}".',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
      ),
    );
  }
}
