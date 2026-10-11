import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../../../theme/app_dimensions.dart';
import '../../data/models/lawyer_models.dart';

/// Pieces shared by the lawyer screens, each reproducing a piece of
/// `lawyer_dashboard.html`.

/// The page's Tailwind colours, named as the page names them.
abstract final class LawyerColors {
  const LawyerColors._();

  static const blue900 = Color(0xFF1E3A8A);
  static const blue700 = Color(0xFF1D4ED8);
  static const blue600 = Color(0xFF2563EB);
  static const blue100 = Color(0xFFDBEAFE);
  static const blue50 = Color(0xFFEFF6FF);
  static const green600 = Color(0xFF16A34A);
  static const green100 = Color(0xFFDCFCE7);
  static const green700 = Color(0xFF15803D);
  static const red600 = Color(0xFFDC2626);
  static const red700 = Color(0xFFB91C1C);
  static const red50 = Color(0xFFFEF2F2);
  static const red200 = Color(0xFFFECACA);
  static const amber600 = Color(0xFFD97706);
  static const purple600 = Color(0xFF9333EA);
  static const purple100 = Color(0xFFF3E8FF);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
}

/// `bg-white rounded-2xl border border-slate-100 shadow-sm`.
class LawyerCard extends StatelessWidget {
  const LawyerCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A section's serif title, e.g. "My Cases" (`text-3xl font-serif`).
class LawyerHeading extends StatelessWidget {
  const LawyerHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'serif',
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: scheme.brightness == Brightness.dark
            ? LawyerColors.blue100
            : LawyerColors.blue900,
      ),
    );
  }
}

/// `.status-pill.status-<key>` (lines 48-77). Keys without a class of their
/// own — `closed`, or anything unknown — get the bare pill.
class LawyerStatusPill extends StatelessWidget {
  const LawyerStatusPill(this.label, {super.key});

  final String label;

  static const _styles = {
    'investigation': (Color(0xFFFEF3C7), Color(0xFF92400E)),
    'court-proceedings': (Color(0xFFDBEAFE), Color(0xFF1E40AF)),
    'trial': (Color(0xFFFEE2E2), Color(0xFFB91C1C)),
    'saved-to-police-records': (Color(0xFFD1FAE5), Color(0xFF065F46)),
    'active': (Color(0xFFD1FAE5), Color(0xFF065F46)),
  };

  @override
  Widget build(BuildContext context) {
    final style = _styles[statusKeyOf(label)];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: style?.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: style?.$2,
        ),
      ),
    );
  }
}

/// One of the four stat cards (lines 324-341).
class LawyerStatCard extends StatelessWidget {
  const LawyerStatCard({
    super.key,
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return LawyerCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: LawyerColors.slate400,
            ),
          ),
        ],
      ),
    );
  }
}

/// The four stats in a two-by-two grid, as the page lays them on a phone
/// (`grid-cols-2 md:grid-cols-4`).
class LawyerStatGrid extends StatelessWidget {
  const LawyerStatGrid({super.key, required this.stats});

  /// Null while the cases are loading.
  final LawyerCaseStats? stats;

  @override
  Widget build(BuildContext context) {
    String n(int Function(LawyerCaseStats) pick) {
      final s = stats;
      return s == null ? '…' : '${pick(s)}';
    }

    final cards = [
      LawyerStatCard(
        value: n((s) => s.total),
        label: 'Total Cases',
        color: null,
      ),
      LawyerStatCard(
        value: n((s) => s.investigation),
        label: 'Investigation',
        color: LawyerColors.amber600,
      ),
      LawyerStatCard(
        value: n((s) => s.courtProceedings),
        label: 'Court Proceedings',
        color: LawyerColors.blue600,
      ),
      LawyerStatCard(
        value: n((s) => s.upcomingHearings.length),
        label: 'Hearings This Week',
        color: LawyerColors.green600,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - AppSpacing.md) / 2;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }
}

/// A coloured status line under an action — the page's `…-msg` elements.
class LawyerMessage {
  const LawyerMessage(this.text, this.color);

  final String text;
  final Color color;

  static LawyerMessage ok(String text) =>
      LawyerMessage(text, LawyerColors.green600);
  static LawyerMessage error(String text) =>
      LawyerMessage(text, LawyerColors.red600);
  static LawyerMessage muted(String text) =>
      LawyerMessage(text, LawyerColors.slate400);
}

class LawyerMessageText extends StatelessWidget {
  const LawyerMessageText(this.message, {super.key, this.fontSize = 13});

  final LawyerMessage? message;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final m = message;
    if (m == null) return const SizedBox.shrink();
    return Text(
      m.text,
      style: TextStyle(
        color: m.color,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// The small spinner and word the page shows while it waits — "Thinking…",
/// "Drafting…", "Loading drafts…".
class LawyerBusyLine extends StatelessWidget {
  const LawyerBusyLine(
    this.text, {
    super.key,
    this.color = LawyerColors.blue600,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: color),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(color: LawyerColors.slate400),
          ),
        ),
      ],
    );
  }
}

/// A blank area while a tab's list loads. The page shows nothing at all until
/// the fetch returns; a spinner says the same thing on a slower connection.
class LawyerLoading extends StatelessWidget {
  const LawyerLoading({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
}

/// A list's empty sentence (`text-sm text-slate-400 text-center`).
class LawyerEmptyText extends StatelessWidget {
  const LawyerEmptyText(this.text, {super.key, this.center = true});

  final String text;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final child = Text(
      text,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: const TextStyle(color: LawyerColors.slate400, fontSize: 14),
    );
    return center
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: Center(child: child),
          )
        : child;
  }
}

/// A light row — the page's `bg-slate-50 rounded-xl px-4 py-2.5` list items.
class LawyerRow extends StatelessWidget {
  const LawyerRow({
    super.key,
    required this.child,
    this.color,
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: color ?? scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: borderColor == null
            ? BorderSide.none
            : BorderSide(color: borderColor!),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A small bold text action — "VIEW", "DELETE", "OPEN CASE".
class LawyerTextAction extends StatelessWidget {
  const LawyerTextAction(
    this.label, {
    super.key,
    required this.onTap,
    this.color = LawyerColors.blue600,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(48, 40),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    );
  }
}

/// An AI answer or draft rendered as the page renders it: `marked.parse(raw)`
/// in an `.assistant-answer` box (lines 117-198).
///
/// Tables scroll sideways: the page's `width: 100%` table is narrower than its
/// columns on a phone, and wrapping them would lose the table.
class LawyerMarkdown extends StatelessWidget {
  const LawyerMarkdown(this.data, {super.key});

  final String data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final heading = dark ? LawyerColors.blue100 : LawyerColors.blue900;
    final body = theme.textTheme.bodyMedium?.copyWith(height: 1.6);
    final sheet = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: body,
      listBullet: body,
      h1: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: heading),
      h2: TextStyle(
        fontSize: 17.6,
        fontWeight: FontWeight.w700,
        color: heading,
      ),
      h3: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: heading),
      strong: const TextStyle(fontWeight: FontWeight.w700),
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: 12.5,
        backgroundColor:
            dark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      ),
      tableHead: TextStyle(fontWeight: FontWeight.w600, color: heading),
      tableBody: theme.textTheme.bodySmall,
      tableHeadAlign: TextAlign.left,
      tableColumnWidth: const IntrinsicColumnWidth(),
      tableBorder: TableBorder.all(color: theme.colorScheme.outlineVariant),
      tableHeadCellsDecoration: BoxDecoration(
        color: dark ? const Color(0xFF1E293B) : LawyerColors.blue50,
      ),
      tableCellsPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
    );
    return MarkdownBody(data: data, styleSheet: sheet, selectable: true);
  }
}
