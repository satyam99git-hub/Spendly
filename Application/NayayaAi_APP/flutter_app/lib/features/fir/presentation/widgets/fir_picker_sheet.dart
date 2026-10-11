import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../shared/widgets/feedback/state_message.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
import '../../domain/entities/fir_record.dart';
import '../controllers/fir_history_providers.dart';
import 'fir_record_tile.dart';

/// Picks an FIR number out of police records, in a bottom sheet.
///
/// Returns the chosen number, or null if the sheet was dismissed. **Dismissal is
/// not a clear**: a caller must leave whatever was already in the field alone,
/// the same contract as `showOptionPicker`.
///
/// Unlike that one it takes no `selected`. There is no "current" FIR to tick:
/// this picks the record a file is about to be filed against, which is a choice
/// made once per upload, not an edit to a value the form already holds.
///
/// ---------------------------------------------------------------------------
/// WHY THIS LISTS RECORDS AND NOT NUMBERS
///
/// `showOptionPicker` already picks a string from a list, and feeding it
/// `records.map((r) => r.firNo)` would have been three lines.
///
/// It would also have been useless. An officer attaching a photo does not
/// remember which of `FIR001`, `FIR002` and `FIR003` is the one they took it
/// for — they remember the complainant, the station and roughly when. A column
/// of bare numbers moves the guess from the keyboard to a list without making
/// it any less of a guess, and a file attached to the wrong FIR is worse than a
/// file not attached yet: nothing in the locker says it is in the wrong place,
/// and the server silently accepts it.
///
/// So the rows are the history list's rows, which is also why this is a widget
/// in the FIR feature rather than in the locker.
/// ---------------------------------------------------------------------------
Future<String?> showFirPicker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
    builder: (_) => const _FirPickerSheet(),
  );
}

class _FirPickerSheet extends ConsumerStatefulWidget {
  const _FirPickerSheet();

  /// Below this many records a search box is more chrome than help. Matches
  /// `showOptionPicker`'s threshold, so the two sheets do not disagree about
  /// when a list is long.
  static const _searchThreshold = 8;

  @override
  ConsumerState<_FirPickerSheet> createState() => _FirPickerSheetState();
}

class _FirPickerSheetState extends ConsumerState<_FirPickerSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Watched here rather than by the screen that opens this sheet: an officer
    // who has the FIR number in front of them — most of them — should not wait
    // for every record in the station to download before they can type it.
    // Opening the sheet is the moment the list is actually wanted.
    final history = ref.watch(firHistoryProvider);

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
                'Choose the FIR',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
              ),
            ),
            Flexible(
              child: history.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.xxxl),
                  child: Center(child: CircularProgressIndicator()),
                ),
                // Dismissable, and that is the whole recovery: the field behind
                // this sheet still takes a typed number, and the server checks
                // it either way. A picker that cannot load is a convenience that
                // is unavailable, not a blocked upload.
                error: (error, _) => StateMessage(
                  centred: true,
                  icon: Icons.cloud_off_rounded,
                  title: 'Police records could not be loaded',
                  body: error is Failure
                      ? '${error.message}\n\nClose this and type the FIR '
                          'number instead.'
                      : 'Close this and type the FIR number instead.',
                ),
                data: _buildList,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<FirRecord> all) {
    if (all.isEmpty) {
      return const StateMessage(
        centred: true,
        icon: Icons.folder_open_outlined,
        title: 'No FIRs on record',
        body: 'Evidence is filed against an FIR that already exists.',
      );
    }

    final searchable = all.length >= _FirPickerSheet._searchThreshold;
    final records = all.where((r) => r.matches(_query.toLowerCase())).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (searchable)
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
                key: FirPickerKeys.search,
                controller: _search,
                onChanged: (value) => setState(() => _query = value.trim()),
                style: AppTypography.fieldValue.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                decoration: const InputDecoration(
                  hintText: 'FIR number, complainant or station',
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                ),
              ),
            ),
          ),
        Flexible(
          child: records.isEmpty
              ? StateMessage(
                  centred: true,
                  icon: Icons.search_off_rounded,
                  title: 'Nothing matches “$_query”',
                  body: 'Try the FIR number on its own.',
                )
              : ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                  itemCount: records.length,
                  itemBuilder: (context, index) => FirRecordTile(
                    record: records[index],
                    onTap: () =>
                        Navigator.of(context).pop(records[index].firNo),
                  ),
                ),
        ),
      ],
    );
  }
}

/// Keyed so a test can reach the sheet's search box without going through the
/// screen that opened it.
abstract final class FirPickerKeys {
  const FirPickerKeys._();

  static const search = Key('firPicker.search');
}
