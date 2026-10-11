import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/fir_number.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
import '../../domain/entities/evidence_category.dart';
import '../../domain/entities/evidence_item.dart';
import '../controllers/evidence_providers.dart';
import '../widgets/evidence_tile.dart';

/// One file in the locker.
///
/// Addressed by `(firNo, filename)` in the route rather than handed an object,
/// because those two fields *are* the server's identity for a file — there is no
/// id — and because a screen that can rebuild itself from its URL survives the
/// process death that a camera excursion or a low-memory kill causes. It refetches
/// `GET /api/evidence?fir_no=` on open, which is also how it gets the timestamp
/// the list could not carry.
class EvidenceDetailScreen extends ConsumerStatefulWidget {
  const EvidenceDetailScreen({
    super.key,
    required this.firNo,
    required this.filename,
  });

  final String firNo;
  final String filename;

  @override
  ConsumerState<EvidenceDetailScreen> createState() =>
      _EvidenceDetailScreenState();
}

class _EvidenceDetailScreenState extends ConsumerState<EvidenceDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Fire-and-forget, and deliberately not awaited before the file is shown: a
    // locker that refuses to open because its audit log is down is a locker that
    // gets worked around. See EvidenceRepository.logAccess.
    ref.read(evidenceRepositoryProvider).logAccess(
          firNo: widget.firNo,
          filename: widget.filename,
          action: 'view',
        );
  }

  @override
  Widget build(BuildContext context) {
    final files = ref.watch(evidenceForFirProvider(widget.firNo));

    return Scaffold(
      // See EvidenceAddScreen: the theme's scaffold background is navy, and a
      // page that does not paint its own surface renders dark text on it.
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('Evidence')),
      body: SafeArea(
        child: files.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _Centered(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load this file',
            body: error is Failure
                ? error.message
                : 'Something went wrong. Go back and try again.',
          ),
          data: (items) {
            final item = _find(items);
            if (item == null) {
              return const _Centered(
                icon: Icons.help_outline_rounded,
                title: 'This file is no longer in the locker',
                body: 'It may have been replaced by an upload of the same name.',
              );
            }
            return _Body(item: item);
          },
        ),
      ),
    );
  }

  /// The row this screen is about, or null if it has gone.
  ///
  /// Falls back to a case-insensitive match: Android cameras write `.JPG`, the
  /// server stores what it was given, and a link built from one list and
  /// resolved against another should not miss over a capital letter.
  EvidenceItem? _find(List<EvidenceItem> items) {
    for (final item in items) {
      if (item.filename == widget.filename) return item;
    }
    final wanted = widget.filename.toLowerCase();
    for (final item in items) {
      if (item.filename.toLowerCase() == wanted) return item;
    }
    return null;
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.item});

  final EvidenceItem item;

  /// Absolute, because this is fetched by [Image.network] rather than by Dio and
  /// so does not inherit the client's `baseUrl`.
  ///
  /// That it works at all is a property of the server: `/evidence-file/...` is a
  /// bare `send_from_directory` with no session check, so the cookie jar Dio
  /// holds is not needed. If that route is ever secured — and it should be — this
  /// preview has to move behind Dio and become bytes in memory.
  String get _fileUrl =>
      '${AppConfig.baseUrl}${ApiEndpoints.evidenceFile(item.firNo, item.filename)}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xxl,
      ),
      children: [
        if (item.category.isPreviewable)
          _Preview(url: _fileUrl)
        else
          _FilePlaceholder(item: item),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          item.filename,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        _Field(label: 'Filed against', value: FirNumber.label(item.firNo)),
        _Field(label: 'Type', value: item.category.label),
        _Field(
          label: 'Uploaded at (UTC)',
          // The list's payload has no timestamp; this screen's does. Saying so
          // beats an empty line that reads as "never recorded".
          value: item.hasTimestamp ? item.uploadedAt : 'Not recorded',
        ),
        _Field(label: 'Stored at', value: _fileUrl, selectable: true),
      ],
    );
  }
}

/// The image itself, when there is one to show.
class _Preview extends StatelessWidget {
  const _Preview({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: Container(
        constraints: const BoxConstraints(minHeight: 180, maxHeight: 420),
        width: double.infinity,
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const Center(child: CircularProgressIndicator()),
          // A photo that will not load is not an error worth a red banner — the
          // record's other fields are still correct and still useful — but it
          // must not be a blank rectangle either.
          errorBuilder: (context, error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Text(
                'The preview could not be loaded from the station server.',
                textAlign: TextAlign.center,
                style: AppTypography.error.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Everything that is not an image.
///
/// Video, audio and PDF are shown as a described file rather than played or
/// rendered. Each needs its own player or viewer package, and a button that
/// opens a black rectangle is worse than one that is honestly absent — see the
/// feature doc's deliberate omissions.
class _FilePlaceholder extends StatelessWidget {
  const _FilePlaceholder({required this.item});

  final EvidenceItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Icon(
            EvidenceTile.iconFor(item.category),
            size: 44,
            color: scheme.primary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            item.category == EvidenceCategory.other
                ? 'Stored in the locker'
                : '${item.category.label} — open it at the station',
            style: AppTypography.error.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    this.selectable = false,
  });

  final String label;
  final String value;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.55);
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface,
          height: 1.35,
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.label.copyWith(color: muted)),
          const SizedBox(height: 2),
          selectable
              ? SelectableText(value, style: style)
              : Text(value, style: style),
        ],
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: muted),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: muted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
