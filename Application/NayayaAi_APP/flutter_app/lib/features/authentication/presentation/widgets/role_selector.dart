import 'package:flutter/material.dart';

import '../../../../core/enums/user_role.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';

/// Role picker for registration.
///
/// A segmented row of cards rather than a dropdown: there are exactly four
/// options, the choice changes what the rest of the form asks for (professional
/// roles gain a unique-ID field), and a dropdown hides that consequence behind a
/// tap. Laid out as a 2x2 grid so every option is legible on a narrow handset --
/// four across would truncate "Police Officer".
class RoleSelector extends StatelessWidget {
  const RoleSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final UserRole value;
  final ValueChanged<UserRole> onChanged;
  final bool enabled;

  static const _icons = {
    UserRole.citizen: Icons.person_outline_rounded,
    UserRole.police: Icons.local_police_outlined,
    UserRole.lawyer: Icons.balance_outlined,
    UserRole.judge: Icons.gavel_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'I am registering as',
          style: AppTypography.label.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Two fixed rows rather than a GridView: the option count is known and
        // constant, and a scrollable inside a scrollable is a gesture conflict
        // waiting to happen.
        Row(
          children: [
            Expanded(child: _tile(context, UserRole.registerable[0])),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _tile(context, UserRole.registerable[1])),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(child: _tile(context, UserRole.registerable[2])),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _tile(context, UserRole.registerable[3])),
          ],
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, UserRole role) {
    final scheme = Theme.of(context).colorScheme;
    final selected = role == value;

    final foreground = selected
        ? scheme.primary
        : scheme.onSurface.withValues(alpha: enabled ? 0.75 : 0.38);

    return Semantics(
      button: true,
      selected: selected,
      label: role.label,
      excludeSemantics: true,
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: AppRadius.controlBorder,
        child: InkWell(
          borderRadius: AppRadius.controlBorder,
          onTap: enabled ? () => onChanged(role) : null,
          child: Container(
            height: AppSizes.controlHeight,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: AppRadius.controlBorder,
              border: Border.all(
                color: selected
                    ? scheme.primary
                    : scheme.outline.withValues(alpha: 0.6),
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(_icons[role], size: 18, color: foreground),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    role.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: foreground,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
