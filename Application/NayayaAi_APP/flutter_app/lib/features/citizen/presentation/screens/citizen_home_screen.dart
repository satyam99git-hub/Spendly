import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_dimensions.dart';
import '../../domain/entities/citizen_content.dart';
import '../controllers/citizen_section.dart';
import '../controllers/rights_and_case_controllers.dart';
import '../widgets/citizen_widgets.dart';

/// Home — citizen_dashboard.html `<section id="home">` (lines 244-385).
///
/// It shows no data about the citizen, because the website's home shows none:
/// no name, no ID, no counts. Everything on it is a way into another section.
class CitizenHomeScreen extends ConsumerWidget {
  const CitizenHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const _Hero(),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Stat cards (lines 286-320). Static text, not counts.
              _ShortcutCard(
                icon: Icons.note_add_outlined,
                tint: const Color(0xFF2563EB),
                eyebrow: 'FILE COMPLAINT',
                title: 'Simple 2-min form',
                subtitle: 'Instant tracking ID',
                onTap: () =>
                    showCitizenSection(ref, CitizenSection.fileComplaint),
              ),
              const SizedBox(height: AppSpacing.md),
              _ShortcutCard(
                icon: Icons.search_rounded,
                tint: const Color(0xFF16A34A),
                eyebrow: 'TRACK STATUS',
                title: 'Real-time updates',
                subtitle: '4-stage timeline',
                onTap: () =>
                    showCitizenSection(ref, CitizenSection.trackComplaint),
              ),
              const SizedBox(height: AppSpacing.md),
              _ShortcutCard(
                icon: Icons.shield_outlined,
                tint: const Color(0xFF9333EA),
                eyebrow: 'KNOW YOUR RIGHTS',
                title: 'AI-powered help',
                subtitle: 'Indian law, plain language',
                onTap: () => showCitizenSection(ref, CitizenSection.knowRights),
              ),
              const SizedBox(height: AppSpacing.xxxl),

              // Quick Actions (lines 322-353).
              Row(
                children: [
                  Icon(Icons.bolt_rounded, size: 18, color: scheme.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Quick Actions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // Content-sized, for the reason the rights topics are: a fixed
              // cell height is a cell a longer label overflows.
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - AppSpacing.md) / 2;
                  return Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: [
                      for (final action in CitizenContent.quickActions)
                        SizedBox(
                          width: width,
                          child: _QuickAction(action: action),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xxxl),
              const _EmergencyStrip(),
            ],
          ),
        ),
      ],
    );
  }
}

class _Hero extends ConsumerWidget {
  const _Hero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xxxl,
        AppSpacing.xxl,
        AppSpacing.xxxl,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF2563EB)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 14,
                  color: Color(0xFFBFDBFE),
                ),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Powered by NyayaAI · Citizen Portal',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFBFDBFE),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Justice, '),
                TextSpan(
                  text: 'at your fingertips.',
                  style: TextStyle(color: Color(0xFF93C5FD)),
                ),
              ],
            ),
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'File complaints, track their real-time status, and know your legal '
            'rights — all from one secure portal.',
            style:
                TextStyle(color: Color(0xFFDBEAFE), fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1D4ED8),
                ),
                onPressed: () =>
                    showCitizenSection(ref, CitizenSection.fileComplaint),
                icon: const Icon(Icons.note_add_outlined, size: 18),
                label: const Text('File a Complaint'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0x803B82F6)),
                ),
                onPressed: () =>
                    showCitizenSection(ref, CitizenSection.trackComplaint),
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('Track My Complaint'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.icon,
    required this.tint,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final String eyebrow;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: tint),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CitizenFieldLabel(eyebrow),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One Quick Action. A question-bearing action asks it and then opens Know
/// Your Rights — `askRightsQuestion(q); showSection('know-rights')`, in that
/// order; the other opens Missing Persons.
class _QuickAction extends ConsumerWidget {
  const _QuickAction({required this.action});

  final QuickAction action;

  static const _icons = {
    'Arrest Rights': (Icons.warning_amber_rounded, Color(0xFFEA580C)),
    'FIR Refused?': (Icons.cancel_presentation_outlined, Color(0xFFDC2626)),
    'Free Legal Aid': (Icons.balance_rounded, Color(0xFF0D9488)),
    'Missing Persons': (Icons.person_search_outlined, Color(0xFF2563EB)),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final look = _icons[action.label] ?? (Icons.bolt_rounded, scheme.primary);

    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          final question = action.question;
          if (question == null) {
            showCitizenSection(ref, CitizenSection.missingPersons);
            return;
          }
          ref.read(rightsChatControllerProvider.notifier).ask(question);
          showCitizenSection(ref, CitizenSection.knowRights);
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.3)),
          ),
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(look.$1, color: look.$2, size: 20),
              const SizedBox(height: AppSpacing.xs),
              Text(
                action.label,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The red "Emergency Contacts" strip (lines 355-382).
class _EmergencyStrip extends StatelessWidget {
  const _EmergencyStrip();

  static const _colours = [
    Color(0xFFDC2626),
    Color(0xFFDB2777),
    Color(0xFFEA580C),
    Color(0xFF2563EB),
    Color(0xFF0D9488),
    Color(0xFF334155),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.phone_in_talk_outlined,
                size: 16,
                color: Color(0xFFDC2626),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Emergency Contacts',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB91C1C),
                  ),
                ),
              ),
              Text(
                'Available 24×7',
                style: TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (var i = 0; i < CitizenContent.homeStrip.length; i++)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _colours[i],
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () =>
                      dialNumber(context, CitizenContent.homeStrip[i].number),
                  icon: const Icon(Icons.phone, size: 14),
                  label: Text(
                    CitizenContent.homeStrip[i].label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
