import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/form_dates.dart';
import '../../../../shared/widgets/inputs/app_picker_field.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../fir/presentation/widgets/form_pickers.dart';
import '../../data/models/citizen_complaint_models.dart';
import '../controllers/citizen_section.dart';
import '../controllers/complaint_controllers.dart';
import '../widgets/citizen_widgets.dart';

/// File a Complaint — citizen_dashboard.html `<section id="file-complaint">`
/// (lines 388-463) and `submitComplaint()` (lines 813-863).
///
/// Five fields, two required. The checks run in the website's order and speak
/// its words (see `validateComplaint`), a failure is an alert, and success
/// replaces the form with the tracking ID.
class FileComplaintScreen extends ConsumerStatefulWidget {
  const FileComplaintScreen({super.key});

  @override
  ConsumerState<FileComplaintScreen> createState() =>
      _FileComplaintScreenState();
}

class _FileComplaintScreenState extends ConsumerState<FileComplaintScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();

  /// `yyyy-MM-dd`, or empty — what `<input type="date">` submits.
  String _date = '';

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    // The website's date box has no min or max, so neither does this; it
    // opens on today when nothing is chosen yet.
    final picked = await pickWireDate(
      context,
      current: _date.isEmpty ? FormDates.toWireDate(DateTime.now()) : _date,
      helpText: 'Date of Incident',
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final message =
        await ref.read(complaintFormControllerProvider.notifier).submit(
              ComplaintSubmission(
                fullName: _name.text,
                phone: _phone.text,
                incidentDate: _date,
                location: _location.text,
                incidentDescription: _description.text,
              ),
            );
    if (message != null && mounted) await showCitizenAlert(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(complaintFormControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final receipt = state.receipt;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'File a Complaint',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: AppSpacing.xs),
              Text(
                "Your complaint will be reviewed by an officer. You'll receive "
                'a tracking ID instantly.',
                style: TextStyle(color: Color(0xFFDBEAFE), fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (receipt != null)
          _Success(trackingId: receipt.trackingId)
        else ...[
          AppTextField(
            label: 'Your Full Name *',
            controller: _name,
            hintText: 'Enter your full name',
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            enabled: !state.busy,
            // `maxlength="60"` and `oninput` stripping anything that is not a
            // letter or a space (line 418-420).
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z ]')),
              LengthLimitingTextInputFormatter(60),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            label: 'Phone Number',
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            enabled: !state.busy,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppPickerField(
            label: 'Date of Incident',
            value: _date.isEmpty ? '' : FormDates.displayDate(_date),
            hintText: 'dd-mm-yyyy',
            icon: Icons.calendar_today_outlined,
            enabled: !state.busy,
            onTap: _pickDate,
            onClear: _date.isEmpty ? null : () => setState(() => _date = ''),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            label: 'Location / Area',
            controller: _location,
            hintText: 'Area, locality',
            textInputAction: TextInputAction.next,
            enabled: !state.busy,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextArea(
            label: 'Describe the Incident *',
            controller: _description,
            hintText: 'Describe what happened in your own words. Include who '
                'was involved, what happened, and any witnesses.',
            minLines: 5,
            enabled: !state.busy,
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'This complaint is not an official FIR. A police officer '
                    'will review it and may convert it to an official FIR if '
                    'applicable.',
                    style: TextStyle(color: scheme.primary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          CitizenButton(
            label: 'Submit Complaint',
            busyLabel: 'Submitting…',
            busy: state.busy,
            onPressed: _submit,
          ),
        ],
      ],
    );
  }
}

/// "Complaint Filed Successfully!" (lines 399-412).
class _Success extends ConsumerWidget {
  const _Success({required this.trackingId});

  final String trackingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const green = Color(0xFF15803D);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 48,
            color: Color(0xFF22C55E),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Complaint Filed Successfully!',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: Color(0xFF166534),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Your tracking ID is:',
            style: TextStyle(color: green, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4ADE80), width: 2),
            ),
            child: SelectableText(
              trackingId,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: green,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Save this ID to track your complaint status',
            style: TextStyle(fontSize: 12, color: Color(0xFF16A34A)),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
            ),
            // The website opens Track without filling the ID in; so does this.
            onPressed: () =>
                showCitizenSection(ref, CitizenSection.trackComplaint),
            child: const Text('Track My Complaint →'),
          ),
        ],
      ),
    );
  }
}
