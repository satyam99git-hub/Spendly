import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../shared/widgets/inputs/app_picker_field.dart';
import '../../../../shared/widgets/inputs/option_picker_sheet.dart';
import '../../../../shared/widgets/inputs/text_entry_dialog.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';

/// A picker fed by a server list, with a way through when the server is not
/// there.
///
/// The three states are not decoration:
///
/// - **loading** — the field is inert and says so. Enabled-but-empty would let
///   an officer open a sheet that is about to fill itself underneath them.
/// - **loaded** — the sheet, with search.
/// - **failed** — the officer types the value instead, and a Retry sits beside
///   the field. This is the state worth arguing about, and the argument is:
///   registering an FIR is a legal duty with a clock on it, and the district
///   list is a *convenience*. An app that refuses to file because it could not
///   fetch 31 strings has confused its own reference data for the record.
///
/// A typed value goes to the same place a picked one does. The server does not
/// validate either against its list — `/api/police-stations/<district>` invents
/// `"<district> PS"` for anything it does not recognise — so a typed district is
/// no less acceptable to it than a chosen one.
class FirLookupField extends StatelessWidget {
  const FirLookupField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.onRetry,
    this.sheetTitle,
    this.hintText,
    this.searchHint,
    this.errorText,
    this.enabled = true,
    this.disabledHint,
  });

  final String label;
  final String value;

  /// The list, as Riverpod hands it over.
  final AsyncValue<List<String>> options;

  final ValueChanged<String> onChanged;

  /// Re-runs the request. Wired to `ref.invalidate(theProvider)`.
  final VoidCallback onRetry;

  final String? sheetTitle;
  final String? hintText;
  final String? searchHint;
  final String? errorText;

  /// False when a prerequisite is unmet — a station cannot be chosen before a
  /// district. [disabledHint] is what the field says instead of its hint.
  final bool enabled;
  final String? disabledHint;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return AppPickerField(
        label: label,
        value: value,
        hintText: disabledHint ?? hintText,
        icon: Icons.expand_more_rounded,
        enabled: false,
        errorText: errorText,
        onTap: () {},
      );
    }

    return options.when(
      loading: () => AppPickerField(
        label: label,
        value: value,
        hintText: 'Loading…',
        icon: Icons.hourglass_empty_rounded,
        enabled: false,
        errorText: errorText,
        onTap: () {},
      ),
      error: (error, _) => _FailedLookup(
        label: label,
        value: value,
        hintText: hintText,
        errorText: errorText,
        failure: error is Failure ? error : null,
        onChanged: onChanged,
        onRetry: onRetry,
      ),
      data: (values) => AppPickerField(
        label: label,
        value: value,
        hintText: hintText,
        icon: Icons.expand_more_rounded,
        errorText: errorText,
        onTap: () async {
          final picked = await showOptionPicker(
            context,
            title: sheetTitle ?? label,
            options: values,
            selected: value.isEmpty ? null : value,
            searchHint: searchHint,
          );
          // Null is a dismissal, not a clear. See showOptionPicker.
          if (picked != null) onChanged(picked);
        },
      ),
    );
  }
}

/// The lookup failed. The field becomes a typed entry and explains why.
class _FailedLookup extends StatelessWidget {
  const _FailedLookup({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onRetry,
    this.hintText,
    this.errorText,
    this.failure,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onRetry;
  final String? hintText;
  final String? errorText;
  final Failure? failure;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppPickerField(
          label: label,
          value: value,
          hintText: hintText,
          icon: Icons.edit_outlined,
          errorText: errorText,
          onTap: () async {
            final typed = await showTextEntryDialog(
              context,
              title: label,
              initialValue: value,
              hintText: hintText,
              helperText: 'The list could not be loaded, so type the '
                  '${label.toLowerCase()} exactly as it should appear on the FIR.',
            );
            if (typed != null) onChanged(typed);
          },
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cloud_off_rounded, size: 14, color: muted),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  // The failure's own message when there is one — it already
                  // distinguishes "no connection" from "the server erred", and
                  // those call for different things from the officer.
                  failure?.message ?? 'The list could not be loaded.',
                  style: AppTypography.error.copyWith(color: muted, height: 1.3),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              GestureDetector(
                onTap: onRetry,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    'Retry',
                    style: AppTypography.link.copyWith(color: scheme.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
