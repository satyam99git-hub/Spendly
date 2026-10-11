import 'package:flutter/material.dart';

import '../../../../theme/app_dimensions.dart';
import '../../domain/entities/citizen_content.dart';
import '../widgets/citizen_widgets.dart';

/// Emergency Contacts — citizen_dashboard.html `<section id="emergency">`
/// (lines 666-756). Nine one-tap cards and the Safety Tips list, all static.
class EmergencyContactsScreen extends StatelessWidget {
  const EmergencyContactsScreen({super.key});

  /// Each card's colour, in card order (lines 672-728).
  static const _colours = [
    Color(0xFFDC2626), // 100 Police
    Color(0xFFF97316), // 112 National Emergency
    Color(0xFF16A34A), // 108 Ambulance
    Color(0xFFEAB308), // 101 Fire Brigade
    Color(0xFFDB2777), // 1091 Women Helpline
    Color(0xFF2563EB), // 1930 Cyber Crime
    Color(0xFF0D9488), // 1098 Child Helpline
    Color(0xFF4F46E5), // 14567 Senior Citizen
    Color(0xFF334155), // 15100 Legal Aid
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        const CitizenSectionHeader(
          title: 'Emergency Contacts',
          subtitle: 'One tap to call. Available 24×7 across India.',
        ),
        const SizedBox(height: AppSpacing.xxl),
        for (var i = 0; i < CitizenContent.emergencyContacts.length; i++) ...[
          _EmergencyCard(
            contact: CitizenContent.emergencyContacts[i],
            colour: _colours[i],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline_rounded,
                    color: Color(0xFFEAB308),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Safety Tips',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final tip in CitizenContent.safetyTips)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '✓',
                        style: TextStyle(
                          color: Color(0xFF16A34A),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          tip,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.75),
                              ),
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

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({required this.contact, required this.colour});

  final EmergencyContact contact;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${contact.title}, ${contact.number}. Tap to call',
      excludeSemantics: true,
      child: Material(
        color: colour,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => dialNumber(context, contact.number),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                Text(
                  contact.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  contact.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Icon(
                      Icons.phone,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Tap to call',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
