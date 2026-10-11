import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/form_banner.dart';
import '../../../../shared/widgets/feedback/state_message.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
import '../controllers/legal_query_controllers.dart';
import '../widgets/legal_keys.dart';

/// A legal question in plain words, answered out of the section tables.
///
/// ---------------------------------------------------------------------------
/// WHY THIS IS NOT A CHAT
///
/// `POST /api/ask-law` has no memory. Every call runs the question through a
/// retrieval index over the same section tables the library browses and builds
/// an answer from what it matched; the one before it is not in scope. A screen
/// with a message list and a growing thread would promise a conversation the
/// server cannot hold up its end of — the second question would be answered as
/// though the first had never been asked, and the officer would have no way to
/// know that from the layout.
///
/// So it is one box and one answer, and asking again replaces it.
///
/// The answer arrives as pre-formatted prose — emoji headings, box-drawing
/// rules — and is shown as it came. Parsing it into cards would mean the app
/// deciding what the sections are, which is exactly the thing the server was
/// asked to do.
/// ---------------------------------------------------------------------------
class AskLawScreen extends ConsumerStatefulWidget {
  const AskLawScreen({super.key});

  @override
  ConsumerState<AskLawScreen> createState() => _AskLawScreenState();
}

class _AskLawScreenState extends ConsumerState<AskLawScreen> {
  final _question = TextEditingController();

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  void _ask() {
    FocusScope.of(context).unfocus();
    ref.read(askLawControllerProvider.notifier).ask(_question.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(askLawControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);

    return Scaffold(
      key: LegalKeys.ask,
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Ask NyayaAI'),
        backgroundColor: scheme.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        children: [
          AppTextArea(
            key: LegalKeys.askInput,
            label: 'Your question',
            controller: _question,
            hintText: 'What is the punishment for theft? What are the arrest '
                'rules for a woman?',
            enabled: !state.busy,
            minLines: 3,
            maxLines: 8,
            maxLength: 500,
          ),
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(
            key: LegalKeys.askSubmit,
            label: 'Ask',
            icon: Icons.auto_awesome_outlined,
            isLoading: state.busy,
            onPressed: state.busy ? null : _ask,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            // Two engines behind one box, and the difference matters enough
            // to say. Naming a section is an exact lookup across all eight act
            // tables; a question in plain words is a semantic search over a
            // much smaller IPC-only index. This used to claim the whole library
            // for both, which was false for every question of the second kind.
            'Name a section — “CrPC 154”, “IPC 420” — and it is looked up in '
            'all eight acts. A question in plain words is answered from a '
            'smaller index of IPC sections only. A reading aid, not advice, '
            'and it remembers nothing of the last question.',
            style: AppTypography.error.copyWith(color: muted),
          ),
          if (state.failure != null) ...[
            const SizedBox(height: AppSpacing.xxl),
            FormBanner(message: state.failure!.message),
          ],
          if (state.hasAnswer) ...[
            const SizedBox(height: AppSpacing.xxl),
            _Answer(question: state.asked, answer: state.answer!),
          ] else if (!state.busy && state.failure == null) ...[
            const SizedBox(height: AppSpacing.xxxl),
            const StateMessage(
              icon: Icons.auto_awesome_outlined,
              title: 'Ask about Indian law',
              body: 'Arrest, bail, FIR procedure, what a section covers — '
                  'anything the eight acts speak to.',
              centred: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// The question, then the server's answer verbatim.
class _Answer extends StatelessWidget {
  const _Answer({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOU ASKED',
          style: AppTypography.label.copyWith(color: muted, letterSpacing: 1.2),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          question,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface,
                fontStyle: FontStyle.italic,
              ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.05),
            borderRadius: AppRadius.controlBorder,
            border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
          ),
          // Monospaced and selectable. The server lays the answer out with
          // box-drawing rules that only line up in a fixed-pitch face, and the
          // reason an officer asks is often to paste a sentence of the reply
          // into an FIR narrative.
          child: SelectableText(
            answer,
            key: LegalKeys.askAnswer,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.5,
              color: scheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
