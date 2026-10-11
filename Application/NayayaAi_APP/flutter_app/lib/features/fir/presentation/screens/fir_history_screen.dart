import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../routes/app_routes.dart';
import '../../../../shared/widgets/feedback/state_message.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../theme/app_dimensions.dart';
import '../../domain/entities/fir_record.dart';
import '../controllers/fir_history_providers.dart';
import '../widgets/fir_history_keys.dart';
import '../widgets/fir_record_tile.dart';

/// Every FIR the station has, newest first.
///
/// ---------------------------------------------------------------------------
/// WHY THE WHOLE COLLECTION, AND WHY SEARCH IS CLIENT-SIDE
///
/// `GET /api/fir-records` takes no query, no page and no sort. It answers with
/// the entire collection or with nothing, so there is no version of this screen
/// that asks the server a narrower question — the choice is only whether the
/// filtering happens here or not at all.
///
/// It happens here. Adding a debounce and a spinner around a client-side
/// `contains` would be ceremony over a list already in memory, and the same
/// call the evidence locker makes for the same reason.
///
/// The honest limit: a station with tens of thousands of FIRs will feel this,
/// because every open pulls every record. The fix is a paged, searchable
/// endpoint server-side — not a smarter client — and until that exists the app
/// should not pretend otherwise by paging a list it has already downloaded.
/// ---------------------------------------------------------------------------
class FirHistoryScreen extends ConsumerStatefulWidget {
  const FirHistoryScreen({super.key});

  @override
  ConsumerState<FirHistoryScreen> createState() => _FirHistoryScreenState();
}

class _FirHistoryScreenState extends ConsumerState<FirHistoryScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(firHistoryProvider);

    return Scaffold(
      // Stated rather than inherited. The theme's scaffold background is navy —
      // the auth screens are built on it — so a page that does not paint its own
      // surface renders dark-text-on-navy. See AppTheme.
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('FIR history')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.lg,
                AppSpacing.xxl,
                0,
              ),
              child: AppTextField(
                key: FirHistoryKeys.search,
                label: 'Search',
                controller: _search,
                hintText: 'FIR number, complainant, station or section',
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _query = value.trim()),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                // The only way to see an FIR a colleague filed. Nothing polls —
                // see firHistoryProvider.
                onRefresh: () async {
                  ref.invalidate(firHistoryProvider);
                  await ref.read(firHistoryProvider.future);
                },
                child: history.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      StateMessage(
                        icon: Icons.cloud_off_rounded,
                        title: 'Police records could not be loaded',
                        body: error is Failure
                            ? error.message
                            : 'Something went wrong. Pull down to try again.',
                      ),
                    ],
                  ),
                  data: _buildList,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<FirRecord> all) {
    final query = _query.toLowerCase();
    final records = all.where((r) => r.matches(query)).toList();

    if (records.isEmpty) {
      // Scrollable even when empty, or RefreshIndicator has nothing to pull.
      return ListView(
        key: FirHistoryKeys.list,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          StateMessage(
            icon: all.isEmpty
                ? Icons.folder_open_outlined
                : Icons.search_off_rounded,
            title: all.isEmpty
                ? 'No FIRs on record'
                : 'Nothing matches “$_query”',
            body: all.isEmpty
                ? 'An FIR filed here or at the desk appears in this list.'
                : 'Try the FIR number on its own, or the complainant’s name.',
          ),
        ],
      );
    }

    return ListView.separated(
      key: FirHistoryKeys.list,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xxxl,
      ),
      itemCount: records.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        indent: AppSpacing.md + AppSizes.iconChip + AppSpacing.lg,
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.35),
      ),
      itemBuilder: (context, index) {
        final record = records[index];
        return FirRecordTile(
          record: record,
          onTap: () => context.pushNamed(
            AppRoutes.firRecordName,
            pathParameters: {'firNo': record.firNo},
          ),
        );
      },
    );
  }
}
