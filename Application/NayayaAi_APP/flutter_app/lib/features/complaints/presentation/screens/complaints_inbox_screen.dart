import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../routes/app_routes.dart';
import '../../../../shared/widgets/feedback/state_message.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
import '../../domain/entities/complaint.dart';
import '../../domain/entities/complaint_category.dart';
import '../controllers/complaint_filter_controller.dart';
import '../controllers/complaint_fir_link_controller.dart';
import '../controllers/complaint_providers.dart';
import '../widgets/complaint_filter_bar.dart';
import '../widgets/complaint_keys.dart';
import '../widgets/complaint_stat_row.dart';
import '../widgets/complaint_tile.dart';

/// The Complaints tab: every complaint a citizen has filed, newest first.
///
/// ---------------------------------------------------------------------------
/// WHY THE WHOLE TABLE, AND WHY EVERY FILTER IS CLIENT-SIDE
///
/// `GET /api/complaints/all` takes no query, no page and no filter. It answers
/// with the entire table or with nothing, so there is no version of this screen
/// that asks the server a narrower question — the only choice is whether the
/// narrowing happens here or not at all.
///
/// It happens here, the same call FIR history makes. The honest limit is the
/// same too: a district with tens of thousands of complaints will feel every
/// open of this tab, because each one pulls every row. The fix is a filtered,
/// paged endpoint server-side rather than a cleverer client, and until that
/// exists the app should not pretend otherwise by paging a list it has already
/// downloaded.
/// ---------------------------------------------------------------------------
class ComplaintsInboxScreen extends ConsumerStatefulWidget {
  const ComplaintsInboxScreen({super.key});

  @override
  ConsumerState<ComplaintsInboxScreen> createState() =>
      _ComplaintsInboxScreenState();
}

class _ComplaintsInboxScreenState extends ConsumerState<ComplaintsInboxScreen> {
  /// Owned here rather than by the filter bar, which rebuilds on every
  /// keystroke. The text lives in [complaintFilterProvider]; this is only the
  /// box's own copy of it.
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final complaints = ref.watch(filteredComplaintsProvider);
    final filter = ref.watch(complaintFilterProvider);

    // Reading the link controller here is what creates it, and it registers the
    // listener that turns a filed FIR into a linked complaint — see
    // ComplaintFirLinkController.build. The tab is the right place for that:
    // it is where a conversion can start, and it outlives the FIR form.
    final link = ref.watch(complaintFirLinkProvider);

    // Shown once and then cleared, so a rebuild does not raise the same
    // snackbar again. Conversions finish while the officer is somewhere else
    // entirely, so this is where they find out how it went.
    ref.listen(complaintFirLinkProvider, (previous, next) {
      final firNo = next.linkedFirNo;
      if (firNo == null || firNo == previous?.linkedFirNo) return;

      final failed = next.failure != null;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              failed
                  // The distinction matters: re-filing would be a duplicate FIR.
                  ? 'FIR $firNo was registered, but ${next.linkedTrackingId} '
                      'could not be updated. Open it and add the number.'
                  : 'FIR $firNo linked to ${next.linkedTrackingId}.',
            ),
            duration: Duration(seconds: failed ? 8 : 4),
          ),
        );
      ref.read(complaintFirLinkProvider.notifier).acknowledge();
    });

    return Scaffold(
      // Transparent, not `scheme.surface`: this is a tab inside the police
      // console's own Scaffold, and painting a second opaque surface over it
      // would sit on top of the shell's background.
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // The four counts, above the filters. It reads the unfiltered
            // provider itself, so the numbers do not move when a filter narrows
            // the list beneath them — see ComplaintStatRow.
            const ComplaintStatRow(),
            ComplaintFilterBar(searchController: _search),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: RefreshIndicator(
                // The only way to see a complaint filed since the tab opened.
                // Nothing polls — see complaintsProvider.
                onRefresh: () async {
                  ref.invalidate(complaintsProvider);
                  await ref.read(complaintsProvider.future);
                },
                child: complaints.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      StateMessage(
                        icon: Icons.cloud_off_rounded,
                        title: 'Complaints could not be loaded',
                        body: error is Failure
                            ? error.message
                            : 'Something went wrong. Pull down to try again.',
                      ),
                    ],
                  ),
                  data: (list) => _List(
                    complaints: list,
                    // The unfiltered length, for the denominator in the count.
                    // Read from the inbox rather than passed down from a widget
                    // that only ever sees the narrowed list.
                    total: ref
                            .watch(complaintsProvider)
                            .valueOrNull
                            ?.length ??
                        list.length,
                    filtered: filter.isActive,
                    linkingTrackingId:
                        link.isPending ? link.pendingTrackingId : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List({
    required this.complaints,
    required this.total,
    required this.filtered,
    required this.linkingTrackingId,
  });

  final List<Complaint> complaints;

  /// How many complaints the station has before any filter. The denominator.
  final int total;

  /// Whether anything is narrowing the list, which decides whether an empty
  /// result means "nothing here" or "nothing matches".
  final bool filtered;

  /// The complaint whose FIR is being written right now, if any. Marked in the
  /// list so an officer who left the form half-finished can see which row they
  /// were working on.
  final String? linkingTrackingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (complaints.isEmpty) {
      // Scrollable even when empty, or RefreshIndicator has nothing to pull.
      return ListView(
        key: ComplaintKeys.list,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          StateMessage(
            icon: filtered ? Icons.search_off_rounded : Icons.inbox_outlined,
            title: filtered
                ? 'Nothing matches these filters'
                : 'No complaints have been filed',
            body: filtered
                ? 'Widen the dates, or choose All, or clear the search box.'
                : 'A complaint filed from the website appears in this list.',
          ),
        ],
      );
    }

    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // The count, always — and with a denominator whenever a filter is on.
        //
        // "12 complaints" over a filtered list reads as a station with twelve
        // complaints in it. "12 of 48 complaints" is the only version an officer
        // can act on: it says both what they are looking at and how much of the
        // inbox they are not.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.sm,
            AppSpacing.xxl,
            AppSpacing.xs,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              filtered && total != complaints.length
                  ? '${complaints.length} of $total complaints'
                  : '$total complaint${total == 1 ? '' : 's'}',
              style: AppTypography.error.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
        Expanded(
          child: ref.watch(complaintViewProvider).isGrouped
              ? _Grouped(
                  complaints: complaints,
                  linkingTrackingId: linkingTrackingId,
                )
              : _Flat(
                  complaints: complaints,
                  linkingTrackingId: linkingTrackingId,
                ),
        ),
      ],
    );
  }
}

/// Newest first, ungrouped.
class _Flat extends StatelessWidget {
  const _Flat({required this.complaints, required this.linkingTrackingId});

  final List<Complaint> complaints;
  final String? linkingTrackingId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView.separated(
            key: ComplaintKeys.list,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
            itemCount: complaints.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              indent: AppSpacing.lg,
              endIndent: AppSpacing.lg,
              color: scheme.outline.withValues(alpha: 0.35),
            ),
            itemBuilder: (context, index) {
              final complaint = complaints[index];
              return ComplaintTile(
                complaint: complaint,
                writingFir: complaint.trackingId == linkingTrackingId,
                onTap: () => context.pushNamed(
                  AppRoutes.complaintDetailName,
                  pathParameters: {'trackingId': complaint.trackingId},
                ),
              );
            },
    );
  }
}

/// The same complaints, divided the way the website's board divides them.
///
/// One section per category that has anything in it, in the board's own order,
/// each headed with its name and a count. See [ComplaintView] for why this is
/// vertical where the website's is horizontal.
///
/// Categories with nothing in them are omitted. The website draws all eight
/// columns whether or not they hold anything — on a desktop an empty column is
/// information ("no homicides this week") and costs nothing; on a phone it is a
/// heading the officer scrolls past to reach the complaints.
class _Grouped extends StatelessWidget {
  const _Grouped({required this.complaints, required this.linkingTrackingId});

  final List<Complaint> complaints;
  final String? linkingTrackingId;

  /// The board's column order, then everything the categoriser could not place.
  static const _order = [
    ComplaintCategory.murder,
    ComplaintCategory.sexualOffence,
    ComplaintCategory.kidnapping,
    ComplaintCategory.assault,
    ComplaintCategory.theft,
    ComplaintCategory.cybercrime,
    ComplaintCategory.financialFraud,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);

    final groups = <({String label, List<Complaint> rows})>[
      for (final category in _order)
        (
          label: category.label,
          rows: complaints.where((c) => c.category == category).toList(),
        ),
      // The three "we could not tell" buckets and everything unclassified,
      // collapsed exactly as the board collapses them.
      (
        label: 'Needs a read',
        rows: complaints
            .where((c) => c.category?.isUnclassified ?? true)
            .toList(),
      ),
    ].where((g) => g.rows.isNotEmpty).toList();

    return ListView.builder(
      key: ComplaintKeys.list,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.lg,
                AppSpacing.xxl,
                AppSpacing.xs,
              ),
              child: Text(
                '${group.label.toUpperCase()} · ${group.rows.length}',
                style: AppTypography.label
                    .copyWith(color: muted, letterSpacing: 1.1),
              ),
            ),
            for (final complaint in group.rows)
              ComplaintTile(
                complaint: complaint,
                writingFir: complaint.trackingId == linkingTrackingId,
                onTap: () => context.pushNamed(
                  AppRoutes.complaintDetailName,
                  pathParameters: {'trackingId': complaint.trackingId},
                ),
              ),
          ],
        );
      },
    );
  }
}
