import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../theme/app_dimensions.dart';
import '../../domain/entities/citizen_content.dart';

/// Pieces shared by the citizen screens. Each reproduces a piece of the
/// website's citizen page that has no equivalent in the police console.

// ---- dialling ---------------------------------------------------------------

/// Opens the dialler on [number] — what the website's `<a href="tel:…">` does.
///
/// Dials rather than calls: the system dialler opens with the number filled in
/// and the citizen presses call, exactly as a `tel:` link behaves on a phone.
Future<void> dialNumber(BuildContext context, String number) async {
  final uri = Uri(scheme: 'tel', path: number);
  var opened = false;
  try {
    opened = await launchUrl(uri);
  } catch (_) {
    opened = false;
  }
  if (opened || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Could not open the dialler. Call $number.')),
  );
}

// ---- alerts -----------------------------------------------------------------

/// The website's `alert(message)`: a blocking message with one OK.
Future<void> showCitizenAlert(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

// ---- headings ---------------------------------------------------------------

/// A section's heading and the sentence under it.
class CitizenSectionHeader extends StatelessWidget {
  const CitizenSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.65),
              ),
        ),
      ],
    );
  }
}

/// A small uppercase field label, as the website's result grids use.
class CitizenFieldLabel extends StatelessWidget {
  const CitizenFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
          ),
    );
  }
}

// ---- buttons ----------------------------------------------------------------

/// A filled button that keeps a label while it works.
///
/// The shared `PrimaryButton` swaps its label for a spinner. The website's
/// buttons say what they are doing instead — "Submitting…", "Analysing face…"
/// — so this shows the spinner *and* [busyLabel].
class CitizenButton extends StatelessWidget {
  const CitizenButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.busyLabel,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final String? busyLabel;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: AppSizes.controlHeight,
      width: double.infinity,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy) ...[
              SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ] else if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: AppSpacing.sm),
            ],
            Flexible(
              child: Text(
                busy ? (busyLabel ?? label) : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- status pill ------------------------------------------------------------

/// The website's `.status-pill` (citizen_dashboard.html:50-78).
///
/// Four statuses have a colour class of their own; anything else — the
/// lawyer's case statuses, or a word the website does not know — gets the bare
/// pill with no colour, because `status-Investigation` is a class nothing
/// defines.
class CitizenStatusPill extends StatelessWidget {
  const CitizenStatusPill(this.status, {super.key});

  final String status;

  static const _styles = {
    'Pending': (Color(0xFFFEF3C7), Color(0xFF92400E)),
    'Under Review': (Color(0xFFDBEAFE), Color(0xFF1E40AF)),
    'FIR Filed': (Color(0xFFD1FAE5), Color(0xFF065F46)),
    'Closed': (Color(0xFFF1F5F9), Color(0xFF475569)),
  };

  @override
  Widget build(BuildContext context) {
    final style = _styles[status];
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: style?.$1,
        borderRadius: BorderRadius.circular(999),
        border: style == null
            ? Border.all(color: scheme.outline.withValues(alpha: 0.5))
            : null,
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: style?.$2 ?? scheme.onSurface,
        ),
      ),
    );
  }
}

// ---- timeline ---------------------------------------------------------------

/// "Status Timeline" (citizen_dashboard.html:906-923).
///
/// Every step up to the current one is filled; steps before it carry a tick,
/// the current one its number. A status the website does not list matches no
/// step, and nothing is filled.
class ComplaintTimeline extends StatelessWidget {
  const ComplaintTimeline({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = CitizenContent.timelineIndex(status);
    final muted = scheme.onSurface.withValues(alpha: 0.35);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < CitizenContent.timeline.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= current
                        ? scheme.primary
                        : scheme.onSurface.withValues(alpha: 0.1),
                  ),
                  child: i < current
                      ? Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: scheme.onPrimary,
                        )
                      : Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: i <= current ? scheme.onPrimary : muted,
                          ),
                        ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        CitizenContent.timeline[i].status,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: i <= current ? scheme.onSurface : muted,
                        ),
                      ),
                      Text(
                        CitizenContent.timeline[i].description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: i <= current
                                  ? scheme.onSurface.withValues(alpha: 0.6)
                                  : muted,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---- rights answer ----------------------------------------------------------

/// The website's `formatAnswer` (citizen_dashboard.html:936-953), as spans.
///
/// `**bold**` becomes bold; a line that starts with `- ` or `• ` becomes an
/// indented bullet; line breaks stay line breaks. Nothing else is interpreted —
/// the website escapes everything else, and a `Text` never interprets anything.
class RightsAnswerText extends StatelessWidget {
  const RightsAnswerText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  static final _bullet = RegExp(r'^[-•]\s+(.*)$');
  static final _bold = RegExp(r'\*\*(.*?)\*\*');

  /// The spans for [text]. Public so a test can check the conversion without
  /// pumping a widget.
  static List<InlineSpan> spansFor(String text) {
    final spans = <InlineSpan>[];
    final lines = text.split('\n');
    for (var l = 0; l < lines.length; l++) {
      var line = lines[l];
      final bullet = _bullet.firstMatch(line);
      if (bullet != null) line = '  • ${bullet.group(1)}';

      var at = 0;
      for (final match in _bold.allMatches(line)) {
        if (match.start > at) {
          spans.add(TextSpan(text: line.substring(at, match.start)));
        }
        spans.add(
          TextSpan(
            text: match.group(1),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
        at = match.end;
      }
      if (at < line.length) spans.add(TextSpan(text: line.substring(at)));
      if (l < lines.length - 1) spans.add(const TextSpan(text: '\n'));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(TextSpan(style: style, children: spansFor(text)));
  }
}
