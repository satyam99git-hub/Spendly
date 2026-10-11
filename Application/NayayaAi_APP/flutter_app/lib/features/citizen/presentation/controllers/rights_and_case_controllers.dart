import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../data/datasources/citizen_remote_data_sources.dart';
import '../../data/models/case_client_status.dart';
import '../../domain/entities/citizen_content.dart';
import 'citizen_providers.dart';

// ---- Know Your Rights -------------------------------------------------------

/// One bubble in the rights chat.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.fromUser,
    this.pending = false,
    this.isError = false,
  });

  final int id;
  final String text;
  final bool fromUser;

  /// The "Thinking…" bubble, waiting for its answer.
  final bool pending;

  /// The red "Could not connect…" bubble.
  final bool isError;
}

final rightsChatControllerProvider =
    NotifierProvider.autoDispose<RightsChatController, List<ChatMessage>>(
  RightsChatController.new,
);

/// The chat as `askRightsQuestion()` keeps it: in memory, gone on reload.
///
/// There is no lock. The website lets a second question go out while the first
/// is still "Thinking…" — each gets its own bubble and each is answered where
/// it stands — and so does this.
class RightsChatController extends AutoDisposeNotifier<List<ChatMessage>> {
  bool _disposed = false;
  int _nextId = 1;

  @override
  List<ChatMessage> build() {
    ref.onDispose(() => _disposed = true);
    return const [
      ChatMessage(id: 0, text: CitizenContent.rightsGreeting, fromUser: false),
    ];
  }

  Future<void> ask(String question) async {
    final text = question.trim();
    if (text.isEmpty) return;

    final pendingId = _nextId + 1;
    state = [
      ...state,
      ChatMessage(id: _nextId, text: text, fromUser: true),
      ChatMessage(
        id: pendingId,
        text: 'Thinking…',
        fromUser: false,
        pending: true,
      ),
    ];
    _nextId += 2;

    ChatMessage reply;
    try {
      final answer = await ref.read(rightsChatRepositoryProvider).ask(text);
      reply = ChatMessage(id: pendingId, text: answer, fromUser: false);
    } on Failure catch (failure) {
      reply = ChatMessage(
        id: pendingId,
        text: failure.message.isEmpty
            ? RightsChatRemoteDataSource.couldNotConnect
            : failure.message,
        fromUser: false,
        isError: true,
      );
    }

    if (_disposed) return;
    state = [
      for (final message in state) message.id == pendingId ? reply : message,
    ];
  }
}

// ---- My Case Status ---------------------------------------------------------

class CaseStatusState {
  const CaseStatusState({this.busy = false, this.status, this.error});

  final bool busy;
  final CaseClientStatus? status;

  /// Shown in the amber box, as `#csError` is.
  final String? error;
}

final caseStatusControllerProvider =
    NotifierProvider.autoDispose<CaseStatusController, CaseStatusState>(
  CaseStatusController.new,
);

class CaseStatusController extends AutoDisposeNotifier<CaseStatusState> {
  bool _disposed = false;

  @override
  CaseStatusState build() {
    ref.onDispose(() => _disposed = true);
    return const CaseStatusState();
  }

  /// An empty FIR number does nothing, as `if (!firNo) return;` does.
  Future<void> check(String firNo) async {
    final fir = firNo.trim();
    if (fir.isEmpty || state.busy) return;

    state = const CaseStatusState(busy: true);
    try {
      final status = await ref.read(caseStatusRepositoryProvider).lookup(fir);
      if (!_disposed) state = CaseStatusState(status: status);
    } on Failure catch (failure) {
      if (!_disposed) state = CaseStatusState(error: failure.message);
    }
  }
}
