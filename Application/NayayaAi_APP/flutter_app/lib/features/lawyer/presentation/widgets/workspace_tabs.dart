import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/failure.dart';
import '../../../../theme/app_dimensions.dart';
import '../../data/models/lawyer_models.dart';
import '../../domain/entities/lawyer_content.dart';
import '../controllers/lawyer_providers.dart';
import 'lawyer_widgets.dart';

/// The six Case Workspace tabs (lawyer_dashboard.html:601-745).
///
/// Every tab keeps its state while another is shown, as the page's hidden
/// panels do; opening a case again starts them over (see
/// `CaseWorkspaceScreen`).

const _tabPadding = EdgeInsets.all(AppSpacing.xxl);

/// `console.error(...)` — what the page does with most load failures.
void _logOnly(Object error) {
  if (kDebugMode) debugPrint('[lawyer] $error');
}

// ---- Overview -----------------------------------------------------------------

/// Overview (lines 602-647): the FIR's facts and the "Message to client"
/// card.
class OverviewTab extends ConsumerStatefulWidget {
  const OverviewTab({super.key, required this.firNo});

  final String firNo;

  @override
  ConsumerState<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<OverviewTab>
    with AutomaticKeepAliveClientMixin {
  final _note = TextEditingController();

  /// Null until the case has loaded; the badge is blank until then.
  bool? _visible;
  LawyerMessage? _message;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // `cwLoadOverview` fills the note box and the badge once (lines 889-890).
    ref.listenManual<AsyncValue<LawyerCase>>(
      caseDetailProvider(widget.firNo),
      (previous, next) {
        final c = next.valueOrNull;
        if (c == null || _visible != null) return;
        _note.text = c.clientNote;
        if (mounted) setState(() => _visible = c.visibleToClient);
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// `cwSendToClient()` (lines 939-964).
  Future<void> _send() async {
    setState(() => _message = LawyerMessage.muted('Sending…'));
    try {
      await ref.read(lawyerRepositoryProvider).setClientVisibility(
            widget.firNo,
            visible: true,
            note: _note.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _message = LawyerMessage.ok('✓ Sent — visible to client now.');
        _visible = true;
      });
    } catch (e) {
      if (!mounted) return;
      final reason = e is Failure ? e.message : 'Failed to fetch';
      setState(() => _message = LawyerMessage.error('Could not send. $reason'));
    }
  }

  /// `cwStopSharing()` (lines 966-989).
  Future<void> _stop() async {
    try {
      await ref.read(lawyerRepositoryProvider).setClientVisibility(
            widget.firNo,
            visible: false,
            note: _note.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _message = const LawyerMessage(
          '✓ Hidden from client.',
          LawyerColors.slate600,
        );
        _visible = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _message = LawyerMessage.error('Could not update.'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final detail = ref.watch(caseDetailProvider(widget.firNo));
    final c = detail.valueOrNull;
    if (detail.hasError) _logOnly(detail.error!);

    String f(String key) => c == null ? '' : c.field(key);

    return ListView(
      padding: _tabPadding,
      children: [
        LawyerCard(
          child: detail.isLoading && c == null
              ? const LawyerLoading()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _Fact('District', f('dist'))),
                        const SizedBox(width: AppSpacing.xl),
                        Expanded(child: _Fact('Police Station', f('ps'))),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _Fact('FIR Date', f('fir_date'))),
                        const SizedBox(width: AppSpacing.xl),
                        Expanded(
                          child: _Fact('Occurrence Date', f('occurrence_date')),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _Fact('Act / Sections', f('act_sections')),
                    const SizedBox(height: AppSpacing.lg),
                    _Fact('Accused Details', f('details_of_accused')),
                    const SizedBox(height: AppSpacing.lg),
                    _Fact('Narrative', f('statement')),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.lg),
        LawyerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Message to client',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          LawyerContent.clientNoteHelp,
                          style: TextStyle(
                            fontSize: 12,
                            color: LawyerColors.slate400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_visible != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    _VisibilityBadge(visible: _visible!),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _note,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: LawyerContent.clientNotePlaceholder,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.md,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton(
                    onPressed: _send,
                    child: const Text('Send to Client'),
                  ),
                  if (_visible == true)
                    LawyerTextAction(
                      'Stop sharing with client',
                      color: LawyerColors.slate400,
                      onTap: _stop,
                    ),
                ],
              ),
              if (_message != null) ...[
                const SizedBox(height: AppSpacing.sm),
                LawyerMessageText(_message, fontSize: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: LawyerColors.slate400,
          ),
        ),
        const SizedBox(height: 2),
        SelectableText(value, style: const TextStyle(height: 1.5)),
      ],
    );
  }
}

class _VisibilityBadge extends StatelessWidget {
  const _VisibilityBadge({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: visible ? LawyerColors.green100 : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        visible ? 'Visible to client' : 'Not shared',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: visible ? LawyerColors.green700 : LawyerColors.slate500,
        ),
      ),
    );
  }
}

// ---- AI Summary -------------------------------------------------------------

/// The result area of the AI tabs: `marked.parse(raw)` for an answer,
/// `textContent` for the page's own error sentence.
class _AiResult {
  const _AiResult(this.text, {required this.markdown});

  final String text;
  final bool markdown;
}

class _AiResultView extends StatelessWidget {
  const _AiResultView(this.result);

  final _AiResult? result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    if (r == null) return const SizedBox.shrink();
    return r.markdown ? LawyerMarkdown(r.text) : Text(r.text);
  }
}

/// AI Summary (lines 652-664, `cwGenerateSummary` 1207-1240).
class SummaryTab extends ConsumerStatefulWidget {
  const SummaryTab({super.key, required this.firNo});

  final String firNo;

  @override
  ConsumerState<SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends ConsumerState<SummaryTab>
    with AutomaticKeepAliveClientMixin {
  bool _busy = false;
  _AiResult? _result;

  @override
  bool get wantKeepAlive => true;

  Future<void> _generate() async {
    // `if (!cwCurrentFir || !cwCurrentCaseData) return;`
    final c = ref.read(caseDetailProvider(widget.firNo)).valueOrNull;
    if (c == null || _busy) return;

    setState(() {
      _busy = true;
      _result = null;
    });
    _AiResult result;
    try {
      final answer = await ref
          .read(lawyerRepositoryProvider)
          .findPrecedents(LawyerContent.summaryQuery(c.raw));
      result = _AiResult(answer ?? 'No summary returned.', markdown: true);
    } catch (e) {
      _logOnly(e);
      result = const _AiResult(
        'Something went wrong generating the summary.',
        markdown: false,
      );
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: _tabPadding,
      children: [
        LawyerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: LawyerColors.purple600,
                  foregroundColor: Colors.white,
                ),
                onPressed: _busy ? null : _generate,
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: const Text('Generate Case Summary'),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_busy)
                const LawyerBusyLine(
                  'Thinking…',
                  color: LawyerColors.purple600,
                ),
              _AiResultView(_result),
            ],
          ),
        ),
      ],
    );
  }
}

// ---- Documents ----------------------------------------------------------------

/// Documents (lines 667-674, `cwLoadDocuments` 1005-1028).
class DocumentsTab extends ConsumerWidget {
  const DocumentsTab({super.key, required this.firNo});

  final String firNo;

  /// The page's VIEW is `<a href="${f.file_url}" target="_blank">`: the file
  /// opens outside the page, in the browser.
  Future<void> _view(BuildContext context, CaseDocument doc) async {
    final uri = Uri.parse('${AppConfig.baseUrl}${Uri.encodeFull(doc.fileUrl)}');
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open ${doc.filename}.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(caseDocumentsProvider(firNo));

    return ListView(
      padding: _tabPadding,
      children: [
        LawyerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Pulled from the Evidence Locker for this FIR.',
                style: TextStyle(fontSize: 12, color: LawyerColors.slate400),
              ),
              const SizedBox(height: AppSpacing.lg),
              docs.when(
                loading: () => const LawyerLoading(),
                error: (e, _) {
                  _logOnly(e);
                  return const SizedBox.shrink();
                },
                data: (list) {
                  if (list.isEmpty) {
                    return const LawyerEmptyText(
                      'No documents uploaded for this case yet.',
                    );
                  }
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final width = (constraints.maxWidth - AppSpacing.md) / 2;
                      return Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.md,
                        children: [
                          for (final doc in list)
                            SizedBox(
                              width: width,
                              child: _DocumentTile(
                                doc: doc,
                                onView: () => _view(context, doc),
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.doc, required this.onView});

  final CaseDocument doc;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            doc.filename,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            doc.fileType.toUpperCase(),
            style: const TextStyle(fontSize: 10, color: LawyerColors.slate400),
          ),
          const SizedBox(height: AppSpacing.xs),
          LawyerTextAction('VIEW', onTap: onView),
        ],
      ),
    );
  }
}

// ---- date input ---------------------------------------------------------------

/// `<input type="date">`: empty or a `YYYY-MM-DD` value.
class _DateField extends StatelessWidget {
  const _DateField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  Future<void> _pick(BuildContext context) async {
    final current = DateTime.tryParse(value);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    String two(int n) => n.toString().padLeft(2, '0');
    onChanged('${picked.year}-${two(picked.month)}-${two(picked.day)}');
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: InputDecorator(
        decoration: const InputDecoration(
          suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
        ),
        isEmpty: value.isEmpty,
        child: Text(
          value.isEmpty ? 'yyyy-mm-dd' : value,
          style: value.isEmpty
              ? const TextStyle(color: LawyerColors.slate400)
              : null,
        ),
      ),
    );
  }
}

// ---- Hearings -----------------------------------------------------------------

/// Hearings (lines 677-690; `cwLoadHearings` / `cwAddHearing` 1030-1074).
/// There is no edit and no delete, on the page or on the server.
class HearingsTab extends ConsumerStatefulWidget {
  const HearingsTab({super.key, required this.firNo});

  final String firNo;

  @override
  ConsumerState<HearingsTab> createState() => _HearingsTabState();
}

class _HearingsTabState extends ConsumerState<HearingsTab>
    with AutomaticKeepAliveClientMixin {
  String _date = '';
  final _note = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    // `if (!date) return;`
    if (_date.isEmpty) return;
    try {
      await ref
          .read(lawyerRepositoryProvider)
          .addHearing(widget.firNo, _date, _note.text.trim());
      if (!mounted) return;
      setState(() => _date = '');
      _note.clear();
      ref.invalidate(caseHearingsProvider(widget.firNo));
      // The server moved the FIR's next hearing date (app.py:2378-2383).
      ref.invalidate(lawyerCasesProvider);
    } catch (e) {
      _logOnly(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final hearings = ref.watch(caseHearingsProvider(widget.firNo));

    return ListView(
      padding: _tabPadding,
      children: [
        LawyerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DateField(
                value: _date,
                onChanged: (v) => setState(() => _date = v),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _note,
                decoration: const InputDecoration(hintText: 'Note (optional)'),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(onPressed: _add, child: const Text('Add')),
              const SizedBox(height: AppSpacing.xl),
              hearings.when(
                loading: () => const LawyerLoading(),
                error: (e, _) {
                  _logOnly(e);
                  return const SizedBox.shrink();
                },
                data: (list) => list.isEmpty
                    ? const LawyerEmptyText('No hearings scheduled yet.')
                    : Column(
                        children: [
                          for (final h in list)
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: LawyerRow(
                                child: Row(
                                  children: [
                                    Text(
                                      h.hearingDate,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Text(
                                        h.note,
                                        textAlign: TextAlign.end,
                                        style: const TextStyle(
                                          color: LawyerColors.slate500,
                                        ),
                                      ),
                                    ),
                                  ],
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

// ---- Deadlines ------------------------------------------------------------------

/// Deadlines (lines 693-714; 1076-1165).
class DeadlinesTab extends ConsumerStatefulWidget {
  const DeadlinesTab({super.key, required this.firNo});

  final String firNo;

  @override
  ConsumerState<DeadlinesTab> createState() => _DeadlinesTabState();
}

class _DeadlinesTabState extends ConsumerState<DeadlinesTab>
    with AutomaticKeepAliveClientMixin {
  String _type = LawyerContent.deadlineTypes.first;
  String _date = '';
  final _note = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _reload() {
    ref
      ..invalidate(caseDeadlinesProvider(widget.firNo))
      // Home's "Upcoming Deadlines" reads the same rows.
      ..invalidate(lawyerUpcomingDeadlinesProvider);
  }

  Future<void> _add() async {
    // `if (!due_date) return;`
    if (_date.isEmpty) return;
    try {
      await ref.read(lawyerRepositoryProvider).addDeadline(
            widget.firNo,
            deadlineType: _type,
            dueDate: _date,
            note: _note.text.trim(),
          );
      if (!mounted) return;
      setState(() => _date = '');
      _note.clear();
      _reload();
    } catch (e) {
      _logOnly(e);
    }
  }

  Future<void> _toggle(CaseDeadline d, bool completed) async {
    try {
      await ref
          .read(lawyerRepositoryProvider)
          .setDeadlineCompleted(widget.firNo, d.id, completed: completed);
    } catch (e) {
      _logOnly(e);
    }
    if (mounted) _reload();
  }

  /// No confirmation, as on the page (line 1112).
  Future<void> _delete(CaseDeadline d) async {
    try {
      await ref
          .read(lawyerRepositoryProvider)
          .deleteDeadline(widget.firNo, d.id);
    } catch (e) {
      _logOnly(e);
    }
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final deadlines = ref.watch(caseDeadlinesProvider(widget.firNo));
    final today = jsTodayUtc();

    return ListView(
      padding: _tabPadding,
      children: [
        LawyerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _type,
                isExpanded: true,
                items: [
                  for (final type in LawyerContent.deadlineTypes)
                    DropdownMenuItem(value: type, child: Text(type)),
                ],
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: AppSpacing.md),
              _DateField(
                value: _date,
                onChanged: (v) => setState(() => _date = v),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _note,
                decoration: const InputDecoration(hintText: 'Note (optional)'),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: LawyerColors.red600,
                  foregroundColor: Colors.white,
                ),
                onPressed: _add,
                child: const Text('Add'),
              ),
              const SizedBox(height: AppSpacing.xl),
              deadlines.when(
                loading: () => const LawyerLoading(),
                error: (e, _) {
                  _logOnly(e);
                  return const SizedBox.shrink();
                },
                data: (list) => list.isEmpty
                    ? const LawyerEmptyText('No deadlines tracked yet.')
                    : Column(
                        children: [
                          for (final d in list)
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: _DeadlineRow(
                                deadline: d,
                                overdue: !d.completed && d.isPastDue(today),
                                onToggle: (v) => _toggle(d, v),
                                onDelete: () => _delete(d),
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

class _DeadlineRow extends StatelessWidget {
  const _DeadlineRow({
    required this.deadline,
    required this.overdue,
    required this.onToggle,
    required this.onDelete,
  });

  final CaseDeadline deadline;
  final bool overdue;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final d = deadline;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final row = LawyerRow(
      color: overdue && !dark ? LawyerColors.red50 : null,
      borderColor: overdue ? LawyerColors.red200 : null,
      child: Row(
        children: [
          Checkbox(
            value: d.completed,
            onChanged: (v) => onToggle(v ?? false),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.deadlineType,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: d.completed ? TextDecoration.lineThrough : null,
                    color: d.completed
                        ? LawyerColors.slate400
                        : overdue
                            ? LawyerColors.red700
                            : null,
                  ),
                ),
                Text(
                  '${d.dueDate}${overdue ? ' — OVERDUE' : ''}',
                  style: TextStyle(
                    color:
                        overdue ? LawyerColors.red600 : LawyerColors.slate500,
                    fontWeight: overdue ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                if (d.note.isNotEmpty)
                  Text(
                    d.note,
                    style: const TextStyle(color: LawyerColors.slate400),
                  ),
              ],
            ),
          ),
          LawyerTextAction(
            'DELETE',
            color: LawyerColors.red600,
            onTap: onDelete,
          ),
        ],
      ),
    );
    // `opacity-60` on a completed row.
    return d.completed ? Opacity(opacity: 0.6, child: row) : row;
  }
}

// ---- Drafts --------------------------------------------------------------------

/// Drafts (lines 717-745; 1242-1352).
class DraftsTab extends ConsumerStatefulWidget {
  const DraftsTab({super.key, required this.firNo});

  final String firNo;

  @override
  ConsumerState<DraftsTab> createState() => _DraftsTabState();
}

class _DraftsTabState extends ConsumerState<DraftsTab>
    with AutomaticKeepAliveClientMixin {
  bool _drafting = false;
  _AiResult? _result;

  /// `cwLastDraftKind` / `cwLastDraftText` — what "Save Draft" sends.
  String? _lastKind;
  String? _lastText;
  bool _showSave = false;
  LawyerMessage? _saveMessage;
  int _request = 0;

  @override
  bool get wantKeepAlive => true;

  /// `cwGenerateDraft(kind)`.
  Future<void> _generate(String kind) async {
    final c = ref.read(caseDetailProvider(widget.firNo)).valueOrNull;
    if (c == null) return;

    final request = ++_request;
    setState(() {
      _drafting = true;
      _result = null;
      _showSave = false;
      _saveMessage = null;
    });

    final bail = kind == 'bail';
    _AiResult result;
    var generated = false;
    try {
      final text = await ref.read(lawyerRepositoryProvider).generateDraft(
            bail: bail,
            prompt: bail
                ? LawyerContent.bailPrompt(c.raw)
                : LawyerContent.documentPrompt(c.raw),
          );
      result = _AiResult(text, markdown: true);
      _lastKind = kind;
      _lastText = text;
      generated = true;
    } catch (e) {
      _logOnly(e);
      result = const _AiResult(
        'Something went wrong generating the draft.',
        markdown: false,
      );
    }
    if (!mounted || request != _request) return;
    setState(() {
      _drafting = false;
      _result = result;
      if (generated) _showSave = true;
    });
  }

  /// `cwSaveDraft()`.
  Future<void> _save() async {
    final kind = _lastKind;
    final text = _lastText;
    if (kind == null || text == null) return;
    try {
      await ref
          .read(lawyerRepositoryProvider)
          .saveDraft(widget.firNo, kind, text);
      if (!mounted) return;
      setState(() => _saveMessage = LawyerMessage.ok('✓ Draft saved.'));
      ref.invalidate(caseDraftsProvider(widget.firNo));
    } catch (_) {
      if (mounted) {
        setState(
          () => _saveMessage = LawyerMessage.error('✗ Could not save draft.'),
        );
      }
    }
  }

  /// `cwViewDraft(content)`.
  void _view(CaseDraft draft) {
    setState(() {
      _result = _AiResult(draft.content, markdown: true);
      _showSave = false;
      _saveMessage = null;
    });
  }

  /// `cwDeleteDraft(id)` — no confirmation.
  Future<void> _delete(CaseDraft draft) async {
    try {
      await ref
          .read(lawyerRepositoryProvider)
          .deleteDraft(widget.firNo, draft.id);
    } catch (e) {
      _logOnly(e);
    }
    if (mounted) ref.invalidate(caseDraftsProvider(widget.firNo));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final saved = ref.watch(caseDraftsProvider(widget.firNo));

    Widget kindButton(String label, String kind) => OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: LawyerColors.blue700,
            backgroundColor: LawyerColors.blue50,
            side: const BorderSide(color: LawyerColors.blue100),
          ),
          onPressed: () => _generate(kind),
          child: Text(label),
        );

    return ListView(
      padding: _tabPadding,
      children: [
        LawyerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  kindButton('Bail Application', 'bail'),
                  kindButton('General Document', 'document'),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_drafting) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: LawyerBusyLine('Drafting…'),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              _AiResultView(_result),
              if (_showSave) ...[
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: LawyerColors.green600,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _save,
                    child: const Text('Save Draft'),
                  ),
                ),
              ],
              if (_saveMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                LawyerMessageText(_saveMessage),
              ],
              const Divider(height: AppSpacing.xxxl * 1.5),
              const Text(
                'SAVED DRAFTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: LawyerColors.slate400,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              saved.when(
                loading: () => const LawyerLoading(),
                error: (e, _) {
                  _logOnly(e);
                  return const SizedBox.shrink();
                },
                data: (list) => list.isEmpty
                    ? const LawyerEmptyText(
                        'No saved drafts for this case yet.',
                      )
                    : Column(
                        children: [
                          for (final d in list)
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: LawyerRow(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: d.kindLabel,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            TextSpan(
                                              text: '  ${d.createdAt}',
                                              style: const TextStyle(
                                                color: LawyerColors.slate400,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    LawyerTextAction(
                                      'VIEW',
                                      onTap: () => _view(d),
                                    ),
                                    LawyerTextAction(
                                      'DELETE',
                                      color: LawyerColors.red600,
                                      onTap: () => _delete(d),
                                    ),
                                  ],
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
