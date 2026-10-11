import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../theme/app_dimensions.dart';
import '../../../lawyer/presentation/widgets/lawyer_widgets.dart';
import '../../data/models/judge_models.dart';
import '../../domain/entities/judge_content.dart';
import '../controllers/judge_providers.dart';
import '../widgets/judge_widgets.dart';

/// Precedent Research — the library's second tab (JD:336-349, 1064-1188).
///
/// `POST /judge/precedents` answers from NyayaAI's curated tables — the
/// current-law mapping, five verified precedents and their principles
/// (app.py:1538-1755) — plus one AI paragraph written only from that material.
/// Nothing here is generated on the phone; every block is printed from the
/// reply, in the page's order, and only when the reply has it.
class ResearchTab extends ConsumerStatefulWidget {
  const ResearchTab({super.key});

  @override
  ConsumerState<ResearchTab> createState() => _ResearchTabState();
}

class _ResearchTabState extends ConsumerState<ResearchTab>
    with AutomaticKeepAliveClientMixin {
  final _query = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _run() {
    FocusScope.of(context).unfocus();
    ref.read(judgeResearchProvider.notifier).run(_query.text);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final result = ref.watch(judgeResearchProvider);
    final busy = result?.isLoading ?? false;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        LawyerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                JudgeContent.researchLabel,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const Key('judge-research-query'),
                controller: _query,
                minLines: 3,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: JudgeContent.researchHint,
                  hintMaxLines: 3,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  key: const Key('judge-research-run'),
                  onPressed: busy ? null : _run,
                  child: Text(
                    busy ? JudgeContent.researching : JudgeContent.research,
                  ),
                ),
              ),
              if (result != null) ...[
                const SizedBox(height: AppSpacing.xl),
                result.when(
                  loading: () =>
                      const LawyerBusyLine(JudgeContent.researchWaiting),
                  error: (e, _) => Text(
                    judgeMessageOf(e),
                    style: const TextStyle(
                      color: LawyerColors.red600,
                      fontSize: 14,
                    ),
                  ),
                  data: (r) => ResearchResultView(result: r),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// `renderResearchResult(data)` (JD:1082-1158).
class ResearchResultView extends StatelessWidget {
  const ResearchResultView({super.key, required this.result});

  final PrecedentResearch result;

  @override
  Widget build(BuildContext context) {
    if (result.isEmpty) {
      return const Text(
        JudgeContent.noResults,
        style: TextStyle(color: LawyerColors.slate400),
      );
    }
    final blocks = <Widget>[];
    void add(Widget w) {
      if (blocks.isNotEmpty) blocks.add(const SizedBox(height: AppSpacing.xl));
      blocks.add(w);
    }

    final cl = result.currentLaw;
    if (cl != null) {
      add(
        _Box(
          color: LawyerColors.blue50,
          border: const Color(0xFFBFDBFE),
          children: [
            const JudgeBlockHeading('Current Law'),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Section ${nested(cl, 'current', 'section')} — '
              '${nested(cl, 'current', 'act')}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: LawyerColors.blue900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              nested(cl, 'current', 'subject'),
              style: const TextStyle(color: LawyerColors.slate600),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Historical corresponding provision: Section '
              '${nested(cl, 'historical', 'section')}, '
              '${nested(cl, 'historical', 'act')}',
              style:
                  const TextStyle(fontSize: 12, color: LawyerColors.slate400),
            ),
          ],
        ),
      );
    }

    final direct = result.directlyRelevant;
    if (direct.isNotEmpty) {
      add(
        _CaseGroup(
          title: 'Directly Relevant Precedents',
          cases: direct,
          related: false,
        ),
      );
    } else if (result.noResultNotice.isNotEmpty) {
      add(
        _Box(
          color: const Color(0xFFFFF7ED),
          border: const Color(0xFFFED7AA),
          children: [
            Text(
              result.noResultNotice,
              style: const TextStyle(color: Color(0xFF9A3412), fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (result.relatedAuthorities.isNotEmpty) {
      add(
        _CaseGroup(
          title: 'Related Authorities',
          cases: result.relatedAuthorities,
          related: true,
        ),
      );
    }

    if (result.principles.isNotEmpty) {
      add(
        _Box(
          children: [
            const JudgeBlockHeading('Key Legal Principles'),
            const SizedBox(height: AppSpacing.sm),
            for (final p in result.principles)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${jsText(p['principle'])}: ',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: jsText(p['explanation'])),
                    ],
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
          ],
        ),
      );
    }

    if (result.statutorySections.isNotEmpty) {
      add(
        _Box(
          children: [
            const JudgeBlockHeading('Relevant Statutory Provisions'),
            const SizedBox(height: AppSpacing.sm),
            for (final s in result.statutorySections)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: 4,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text:
                                '${jsText(s['act'])} § ${jsText(s['section'])}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: LawyerColors.blue700,
                            ),
                          ),
                          TextSpan(
                            text: ' — ${jsText(s['subject'])}',
                            style: const TextStyle(
                              color: LawyerColors.slate500,
                            ),
                          ),
                        ],
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                    _Badge(
                      jsText(s['status']),
                      positive: s['status'] == 'Current',
                      orange: true,
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    final syn = result.synthesis;
    if (syn != null) {
      Widget labelled(String label, Object? value) {
        final text = jsText(value);
        if (text.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: text),
              ],
            ),
            style: const TextStyle(fontSize: 14),
          ),
        );
      }

      final summary = jsText(syn['summary']);
      add(
        _Box(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          children: [
            const JudgeBlockHeading('AI-Generated Research Synthesis'),
            const SizedBox(height: AppSpacing.sm),
            if (summary.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: SelectableText(
                  summary,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ),
            labelled('Current-law position', syn['current_position']),
            labelled('Historical-law position', syn['historical_position']),
            labelled('Important qualification', syn['qualification']),
            const Divider(),
            Text(
              result.aiNotice,
              style: const TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: LawyerColors.slate400,
              ),
            ),
          ],
        ),
      );
    }

    if (result.sources.isNotEmpty) {
      add(
        _Box(
          children: [
            const JudgeBlockHeading('Sources & Verification'),
            const SizedBox(height: AppSpacing.sm),
            for (final s in result.sources)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${jsText(s['case'])} — ${jsText(s['citation'])}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _Badge(
                      s['verification_status'] == 'Verified'
                          ? 'Verified'
                          : 'Unverified',
                      positive: s['verification_status'] == 'Verified',
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    return Column(
      key: const Key('judge-research-result'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: blocks,
    );
  }
}

class _CaseGroup extends StatelessWidget {
  const _CaseGroup({
    required this.title,
    required this.cases,
    required this.related,
  });

  final String title;
  final List<Map<String, dynamic>> cases;
  final bool related;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JudgeBlockHeading(title),
          const SizedBox(height: AppSpacing.md),
          for (final c in cases) ...[
            _CaseCard(c: c, related: related),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      );
}

/// `renderCaseCard(c, related)` (JD:1064-1080).
class _CaseCard extends StatelessWidget {
  const _CaseCard({required this.c, required this.related});

  final Map<String, dynamic> c;
  final bool related;

  @override
  Widget build(BuildContext context) {
    final bench = jsText(c['bench']);
    final later = jsText(c['later_development_text']);
    final source = jsText(c['source_url']);
    final verified = c['verification_status'] == 'Verified';
    return _Box(
      border: related ? null : const Color(0xFFBFDBFE),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    jsText(c['case']),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: LawyerColors.blue900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${jsText(c['citation'])} · ${jsText(c['court'])}'
                    '${bench.isNotEmpty ? ' · $bench' : ''} · ${c['year']}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: LawyerColors.slate400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _Badge(jsText(c['verification_status']), positive: verified),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Historical provision: Section ${nested(c, 'statute_then', 'section')} '
          '${nested(c, 'statute_then', 'act')}',
          style: const TextStyle(fontSize: 12, color: LawyerColors.slate400),
        ),
        const SizedBox(height: AppSpacing.md),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: 'Key Holding: ',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              TextSpan(text: jsText(c['key_holding'])),
            ],
          ),
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: 'Why Relevant: ',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              TextSpan(text: jsText(c['why_relevant'])),
            ],
          ),
          style: const TextStyle(fontSize: 14, color: LawyerColors.slate600),
        ),
        if (later.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            later,
            style: const TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Color(0xFFC2410C),
            ),
          ),
        ],
        if (source.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(48, 40),
              ),
              onPressed: () => _openSource(context, source),
              child: const Text('Source ↗', style: TextStyle(fontSize: 12)),
            ),
          ),
      ],
    );
  }

  /// `<a href=… target="_blank">` — outside the app.
  static Future<void> _openSource(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    var opened = false;
    if (uri != null) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        opened = false;
      }
    }
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the source.')),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.children, this.color, this.border});

  final List<Widget> children;
  final Color? color;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerLowest,
        border: Border.all(color: border ?? scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, {required this.positive, this.orange = false});

  final String text;
  final bool positive;

  /// The statutory list's non-current badge is orange (JD:1125); the
  /// verification badges' is slate.
  final bool orange;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: positive
              ? LawyerColors.green100
              : orange
                  ? const Color(0xFFFFEDD5)
                  : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: positive
                ? LawyerColors.green700
                : orange
                    ? const Color(0xFFC2410C)
                    : LawyerColors.slate600,
          ),
        ),
      );
}
