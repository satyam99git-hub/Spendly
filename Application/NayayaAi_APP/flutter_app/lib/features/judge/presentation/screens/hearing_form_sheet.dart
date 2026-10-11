import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_dimensions.dart';
import '../../../lawyer/presentation/widgets/lawyer_widgets.dart';
import '../../data/models/judge_models.dart';
import '../../domain/entities/judge_content.dart';
import '../controllers/judge_providers.dart';
import '../widgets/judge_widgets.dart';

/// Opens the hearing modal — new, or [entry] to edit — and reloads the docket
/// when it saved (`closeModal(); loadDocket();`, JD:761-762).
Future<void> openHearingForm(
  BuildContext context,
  WidgetRef ref, {
  DocketEntry? entry,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => HearingFormSheet(entry: entry),
  );
  if (saved == true) refreshDocket(ref);
}

/// `#docketModal` (JD:365-441) and its Save handler (JD:713-763).
///
/// Field for field the page's modal, validated in the page's order with the
/// page's sentences. Two additions, both about not misleading the judge: Save
/// is disabled while a request is in flight (the page lets a double tap send
/// twice), and the fields keep what was typed when the server refuses.
class HearingFormSheet extends ConsumerStatefulWidget {
  const HearingFormSheet({super.key, this.entry, this.now});

  /// Null for "New Hearing".
  final DocketEntry? entry;

  /// The clock, for tests.
  final DateTime Function()? now;

  @override
  ConsumerState<HearingFormSheet> createState() => _HearingFormSheetState();
}

class _HearingFormSheetState extends ConsumerState<HearingFormSheet> {
  late final TextEditingController _caseId;
  late final TextEditingController _caseType;
  late final TextEditingController _remarks;

  /// The `datetime-local` value: `YYYY-MM-DDTHH:MM`, or empty.
  late String _date;
  late String _urgency;
  late String _status;

  /// `editingOriginalDate` — the stored string, unnormalised (JD:663).
  String? _originalDate;

  bool _showSuggestions = false;
  bool _saving = false;
  String? _warning;

  bool get _editing => widget.entry != null;
  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _caseId = TextEditingController(text: e?.caseId ?? '');
    _caseType = TextEditingController(text: e == null ? '' : e.caseType);
    _remarks = TextEditingController(text: e == null ? '' : e.remarks);
    _date = e == null ? '' : editInputValue(e.hearingDate);
    // A value the select does not list shows its first option, as a <select>
    // given an unknown value does.
    _urgency = _option(JudgeContent.urgencyOptions, e?.urgency, 'normal');
    _status = _option(JudgeContent.statusOptions, e?.status, 'scheduled');
    _originalDate = e?.hearingDate;
  }

  static String _option(
    List<(String, String)> options,
    String? value,
    String fallback,
  ) {
    if (value == null) return fallback;
    return options.any((o) => o.$2 == value) ? value : options.first.$2;
  }

  @override
  void dispose() {
    _caseId.dispose();
    _caseType.dispose();
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = _now();
    final current = _date.isEmpty ? null : DateTime.tryParse(_date);
    // `min = nowLocalInput()` for a new entry, no minimum when editing (JD:664).
    final first =
        _editing ? DateTime(2000) : DateTime(now.year, now.month, now.day);
    final initial =
        current == null || current.isBefore(first) ? (current ?? now) : current;
    final day = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: DateTime(now.year + 20),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current ?? now),
    );
    if (time == null || !mounted) return;
    setState(() {
      _date = localInputValue(
        DateTime(day.year, day.month, day.day, time.hour, time.minute),
      );
    });
  }

  /// The Save listener (JD:713-763), step for step.
  Future<void> _save() async {
    if (_saving) return;
    final caseId = _caseId.text.trim();

    if (caseId.isEmpty) return _warn(JudgeContent.caseIdRequired);
    if (_date.isEmpty) return _warn(JudgeContent.hearingDateRequired);

    final hearingDate = _date.replaceFirst('T', ' ');
    final dateChanged = !_editing || hearingDate != _originalDate;
    final at = DateTime.tryParse(_date);
    if (dateChanged && at != null && at.isBefore(_now())) {
      return _warn(JudgeContent.hearingDatePast);
    }

    setState(() {
      _saving = true;
      _warning = null;
    });
    final repo = ref.read(judgeRepositoryProvider);
    try {
      // Duplicate check: only when creating (JD:731-738).
      if (!_editing) {
        final existing = await repo.docket();
        final lower = caseId.toLowerCase();
        if (existing.any((e) => e.caseId.toLowerCase() == lower)) {
          return _warn(JudgeContent.duplicate(caseId));
        }
      }
      final payload = DocketPayload(
        caseId: caseId,
        hearingDate: hearingDate,
        caseType: _caseType.text,
        urgency: _urgency,
        status: _status,
        remarks: _remarks.text,
      );
      final id = widget.entry?.id;
      if (_editing && id != null) {
        await repo.updateEntry(id, payload);
      } else {
        await repo.createEntry(payload);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _warn(judgeMessageOf(e));
    }
  }

  void _warn(String text) {
    if (!mounted) return;
    setState(() {
      _warning = text;
      _saving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final firs = ref.watch(judgeFirOptionsProvider);
    final all = firs.valueOrNull ?? const <JudgeFir>[];
    final typed = _caseId.text;
    final suggestions = _showSuggestions
        ? firSuggestions(all, typed, limit: JudgeContent.firSuggestionLimit)
        : null;

    // `updateFirPreview()` (JD:547-564).
    final trimmed = typed.trim();
    final match = all.where((f) => f.firNo == trimmed);
    final Widget? preview = trimmed.isEmpty
        ? null
        : match.isNotEmpty
            ? Text(
                match.first.previewLine,
                style: const TextStyle(
                  fontSize: 12,
                  color: LawyerColors.green600,
                ),
              )
            : const Text(
                JudgeContent.noFirPreview,
                style: TextStyle(fontSize: 12, color: LawyerColors.red600),
              );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          0,
          AppSpacing.xxl,
          AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _editing ? JudgeContent.modalEdit : JudgeContent.modalNew,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: LawyerColors.blue900,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const _Label(JudgeContent.caseIdLabel),
            TextField(
              key: const Key('judge-case-id'),
              controller: _caseId,
              autocorrect: false,
              decoration: const InputDecoration(
                hintText: JudgeContent.caseIdHint,
              ),
              onChanged: (_) => setState(() => _showSuggestions = true),
            ),
            if (firs.isLoading)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'Loading FIR records…',
                  style: TextStyle(fontSize: 12, color: LawyerColors.slate400),
                ),
              ),
            if (firs.hasError)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'FIR records could not be loaded, so no suggestions can be '
                  'shown. The hearing can still be saved.',
                  style: TextStyle(fontSize: 12, color: LawyerColors.slate500),
                ),
              ),
            if (suggestions != null)
              _Suggestions(
                suggestions: suggestions,
                onPick: (fir) => setState(() {
                  _caseId.text = fir.firNo;
                  _caseId.selection =
                      TextSelection.collapsed(offset: fir.firNo.length);
                  _showSuggestions = false;
                }),
              ),
            if (preview != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: preview,
              ),
            const SizedBox(height: AppSpacing.lg),
            const _Label(JudgeContent.hearingDateLabel),
            InkWell(
              key: const Key('judge-hearing-date'),
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  suffixIcon: Icon(Icons.event_outlined),
                ),
                child: Text(
                  _date.isEmpty
                      ? 'Pick a date and time'
                      : _date.replaceFirst('T', ' '),
                  style: _date.isEmpty
                      ? const TextStyle(color: LawyerColors.slate400)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const _Label(JudgeContent.caseTypeLabel),
            TextField(
              key: const Key('judge-case-type'),
              controller: _caseType,
              decoration: const InputDecoration(
                hintText: JudgeContent.caseTypeHint,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _Select(
                    label: 'Urgency',
                    fieldKey: 'judge-urgency',
                    value: _urgency,
                    options: JudgeContent.urgencyOptions,
                    onChanged: (v) => setState(() => _urgency = v),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _Select(
                    label: 'Status',
                    fieldKey: 'judge-status',
                    value: _status,
                    options: JudgeContent.statusOptions,
                    onChanged: (v) => setState(() => _status = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const _Label('Remarks'),
            TextField(
              key: const Key('judge-remarks'),
              controller: _remarks,
              minLines: 3,
              maxLines: 3,
            ),
            if (_warning != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Container(
                key: const Key('judge-form-warning'),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: LawyerColors.red50,
                  border: Border.all(color: LawyerColors.red200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _warning!,
                  style: const TextStyle(
                    color: LawyerColors.red700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    key: const Key('judge-save'),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      );
}

class _Select extends StatelessWidget {
  const _Select({
    required this.label,
    required this.fieldKey,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String fieldKey;
  final String value;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Label(label),
          DropdownButtonFormField<String>(
            key: Key(fieldKey),
            initialValue: value,
            isExpanded: true,
            items: [
              for (final (text, wire) in options)
                DropdownMenuItem(value: wire, child: Text(text)),
            ],
            onChanged: (v) => onChanged(v ?? value),
          ),
        ],
      );
}

/// `#firSearchResults` (JD:509-539): up to eight matches, or "No matching FIR
/// found".
class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.suggestions, required this.onPick});

  final List<JudgeFir> suggestions;
  final ValueChanged<JudgeFir> onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('judge-fir-suggestions'),
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: suggestions.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text(
                JudgeContent.noFirMatch,
                style: TextStyle(fontSize: 13, color: LawyerColors.slate400),
              ),
            )
          : Column(
              children: [
                for (final fir in suggestions)
                  InkWell(
                    onTap: () => onPick(fir),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fir.firNo,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: LawyerColors.blue700,
                            ),
                          ),
                          Text(
                            fir.suggestionSubtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: LawyerColors.slate400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
