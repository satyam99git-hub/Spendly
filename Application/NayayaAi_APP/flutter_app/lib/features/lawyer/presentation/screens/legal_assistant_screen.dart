import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_dimensions.dart';
import '../../domain/entities/lawyer_content.dart';
import '../controllers/lawyer_providers.dart';
import '../widgets/lawyer_widgets.dart';

/// Legal Assistant — lawyer_dashboard.html `<section id="legal-assistant">`
/// (lines 466-514, `askLegalAssistant` 1574-1605).
///
/// One question, one answer: each answer replaces the last, and there is no
/// history, as on the page.
class LegalAssistantScreen extends ConsumerStatefulWidget {
  const LegalAssistantScreen({super.key});

  @override
  ConsumerState<LegalAssistantScreen> createState() =>
      _LegalAssistantScreenState();
}

class _LegalAssistantScreenState extends ConsumerState<LegalAssistantScreen> {
  final _query = TextEditingController();
  bool _busy = false;

  /// The answer card's content; null while it is hidden.
  String? _answer;

  /// Whether [_answer] is `marked.parse` output or the page's plain error.
  bool _answerIsMarkdown = true;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// `askSuggestion(text)`: fill the box and ask.
  void _askSuggestion(String question) {
    _query.text = question;
    _ask();
  }

  Future<void> _ask() async {
    final query = _query.text.trim();
    if (query.isEmpty || _busy) return;

    setState(() {
      _busy = true;
      _answer = null;
    });
    String answer;
    var markdown = true;
    try {
      answer = await ref.read(lawyerRepositoryProvider).findPrecedents(query) ??
          'No results found.';
    } catch (e) {
      if (kDebugMode) debugPrint('[lawyer] $e');
      answer = 'Something went wrong. Please try again.';
      markdown = false;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _answer = answer;
      _answerIsMarkdown = markdown;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        const LawyerHeading('Legal Assistant'),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          LawyerContent.assistantIntro,
          style: TextStyle(fontSize: 14, color: LawyerColors.slate500),
        ),
        const SizedBox(height: AppSpacing.xl),
        LawyerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _query,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: LawyerContent.assistantPlaceholder,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final (label, question)
                      in LawyerContent.assistantSuggestions)
                    ActionChip(
                      label: Text(label),
                      labelStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: LawyerColors.blue700,
                      ),
                      backgroundColor: LawyerColors.blue50,
                      side: const BorderSide(color: LawyerColors.blue100),
                      shape: const StadiumBorder(),
                      onPressed: () => _askSuggestion(question),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: _busy ? null : _ask,
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text('Ask'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (_busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: Center(child: LawyerBusyLine('Thinking…')),
          ),
        if (_answer != null)
          LawyerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: LawyerColors.blue600,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Answer',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color:
                            dark ? LawyerColors.blue100 : LawyerColors.blue900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _answerIsMarkdown ? LawyerMarkdown(_answer!) : Text(_answer!),
              ],
            ),
          ),
      ],
    );
  }
}
