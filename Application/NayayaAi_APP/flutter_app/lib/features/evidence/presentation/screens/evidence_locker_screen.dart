import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../routes/app_routes.dart';
import '../controllers/evidence_lock_controller.dart';
import '../widgets/evidence_keys.dart';
import '../widgets/evidence_list_view.dart';
import '../widgets/evidence_pin_gate.dart';

/// The Evidence tab: the gate, or the locker behind it.
///
/// One widget rather than two routes, and the gate is a *state* rather than a
/// screen you navigate past. A pushed PIN route can be popped, deep-linked
/// around, or left behind by a back gesture that reveals the list underneath it;
/// this cannot, because the list is simply not built while the lock is on.
///
/// An inner [Scaffold] so the Add button belongs to the locker rather than to
/// the dashboard around it. The alternative — a floating action button on the
/// dashboard that appears and disappears with the selected tab — puts knowledge
/// of the locker's lock state in the shell.
class EvidenceLockerScreen extends ConsumerWidget {
  const EvidenceLockerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked =
        ref.watch(evidenceLockControllerProvider.select((s) => s.unlocked));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: unlocked
          ? FloatingActionButton.extended(
              key: EvidenceKeys.addButton,
              onPressed: () => context.pushNamed(AppRoutes.evidenceAddName),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add evidence'),
            )
          : null,
      body: unlocked ? const EvidenceListView() : const EvidencePinGate(),
    );
  }
}
