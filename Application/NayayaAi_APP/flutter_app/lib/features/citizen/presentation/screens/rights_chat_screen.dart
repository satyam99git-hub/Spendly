import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_dimensions.dart';
import '../../domain/entities/citizen_content.dart';
import '../controllers/rights_and_case_controllers.dart';
import '../widgets/citizen_widgets.dart';

/// Know Your Rights — citizen_dashboard.html `<section id="know-rights">`
/// (lines 570-650) and `askRightsQuestion()` (lines 958-1016).
///
/// Six topic cards that each send a fixed question, a chat, and a box to ask
/// anything else. Answers come from `/api/rights-chat` — a search over the
/// law database with an AI summary on top — and are shown as the website shows
/// them, including the website's "Could not connect…" for the questions the
/// server currently fails on (limitation L2).
class RightsChatScreen extends ConsumerStatefulWidget {
  const RightsChatScreen({super.key});

  @override
  ConsumerState<RightsChatScreen> createState() => _RightsChatScreenState();
}

class _RightsChatScreenState extends ConsumerState<RightsChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _ask([String? preset]) {
    final question = preset ?? _input.text.trim();
    if (question.isEmpty) return;
    // The typed question is cleared; a topic card leaves the box alone
    // (`if (!preset) input.value = ''`).
    if (preset == null) _input.clear();
    ref.read(rightsChatControllerProvider.notifier).ask(question);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(rightsChatControllerProvider);
    ref.listen(rightsChatControllerProvider, (_, __) => _scrollToEnd());

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.all(AppSpacing.xxl),
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9333EA), Color(0xFF6B21A8)],
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Know Your Rights',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      'Ask anything about your legal rights in plain language. '
                      'Powered by AI + Indian Law DB.',
                      style: TextStyle(color: Color(0xFFF3E8FF), fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Two to a row, each as tall as its own words.
              //
              // NOT a GridView: that gives every cell the same height, fixed by
              // an aspect ratio, and a subtitle that wraps to two lines then
              // overflows it — which is exactly what "Right to bail, lawyer,
              // silence" did at the default text size. A Wrap lets each card
              // take the height it needs, at any text scale.
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - AppSpacing.md) / 2;
                  return Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: [
                      for (final topic in CitizenContent.rightsTopics)
                        SizedBox(
                          width: width,
                          child: _TopicCard(
                            topic: topic,
                            onTap: () => _ask(topic.question),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              for (final message in messages) ...[
                _Bubble(message: message),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    textInputAction: TextInputAction.send,
                    decoration: const InputDecoration(
                      hintText: 'Ask about your rights…',
                    ),
                    onSubmitted: (_) => _ask(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  height: AppSizes.controlHeight,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF9333EA),
                    ),
                    onPressed: _ask,
                    child: const Text('Ask'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.topic, required this.onTap});

  final RightsTopic topic;
  final VoidCallback onTap;

  static const _icons = {
    'If You Are Arrested': Icons.gavel_rounded,
    'Right to Bail': Icons.key_rounded,
    'Right to Lawyer': Icons.work_outline_rounded,
    'FIR Refused?': Icons.cancel_presentation_outlined,
    "Women's Rights": Icons.volunteer_activism_outlined,
    'Free Legal Aid': Icons.balance_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.onSurface.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _icons[topic.title] ?? Icons.shield_outlined,
                size: 20,
                color: const Color(0xFF9333EA),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                topic.title,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              Text(
                topic.subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (message.fromUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFF1D4ED8),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child:
              Text(message.text, style: const TextStyle(color: Colors.white)),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CircleAvatar(
          radius: 16,
          backgroundColor: Color(0xFFF3E8FF),
          child: Icon(
            Icons.smart_toy_outlined,
            size: 16,
            color: Color(0xFF9333EA),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.onSurface.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: message.pending
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFC084FC),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        message.text,
                        style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  )
                : message.isError
                    ? Text(
                        message.text,
                        style: const TextStyle(color: Color(0xFFEF4444)),
                      )
                    : RightsAnswerText(
                        message.text,
                        style: TextStyle(color: scheme.onSurface),
                      ),
          ),
        ),
      ],
    );
  }
}
