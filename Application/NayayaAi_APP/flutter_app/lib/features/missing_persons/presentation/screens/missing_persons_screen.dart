import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../routes/app_routes.dart';
import '../../../../shared/widgets/feedback/state_message.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
import '../../domain/entities/confirmed_match.dart';
import '../../domain/entities/missing_person.dart';
import '../controllers/missing_person_providers.dart';
import '../widgets/missing_person_keys.dart';
import '../widgets/person_photo.dart';

/// The open missing-person cases, with the confirmed face matches above them.
///
/// ---------------------------------------------------------------------------
/// WHY THE MATCHES ARE AT THE TOP AND NOT ON A TAB OF THEIR OWN
///
/// A confirmed match is the only thing on this screen that is asking for
/// something. The register itself is reference — thirty faces an officer scrolls
/// when somebody walks in with a lead — and a match is a person the face
/// comparison believes has been seen, which is work that has arrived and is
/// waiting.
///
/// On a tab it would be work nobody looks at until they think to. At the top of
/// the list it is the first thing on the screen an officer opens for any reason
/// at all, and it collapses to nothing when there are none.
/// ---------------------------------------------------------------------------
class MissingPersonsScreen extends ConsumerStatefulWidget {
  const MissingPersonsScreen({super.key});

  @override
  ConsumerState<MissingPersonsScreen> createState() =>
      _MissingPersonsScreenState();
}

class _MissingPersonsScreenState extends ConsumerState<MissingPersonsScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref
      ..invalidate(missingPersonsProvider)
      ..invalidate(confirmedMatchesProvider);
    await ref.read(missingPersonsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final people = ref.watch(missingPersonsProvider);

    return Scaffold(
      key: MissingPersonKeys.list,
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Missing persons'),
        backgroundColor: scheme.surface,
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: MissingPersonKeys.registerAction,
        onPressed: () => context.pushNamed(AppRoutes.missingPersonNewName),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Register'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: people.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: AppSpacing.xxxl * 2),
              StateMessage(
                icon: Icons.cloud_off_rounded,
                title: 'The register could not be loaded',
                body: '$error',
                centred: true,
              ),
            ],
          ),
          data: (all) {
            final needle = _query.trim().toLowerCase();
            final shown = all.where((p) => p.matches(needle)).toList();

            return ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxxl * 2),
              children: [
                const _Matches(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                    AppSpacing.sm,
                  ),
                  child: AppTextField(
                    key: MissingPersonKeys.search,
                    label: 'Search',
                    controller: _search,
                    hintText: 'Name, place last seen, or what they were wearing',
                    textInputAction: TextInputAction.search,
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxxl),
                    child: StateMessage(
                      icon: all.isEmpty
                          ? Icons.person_search_outlined
                          : Icons.search_off_rounded,
                      title: all.isEmpty
                          ? 'No open cases'
                          : 'Nothing matches “${_query.trim()}”',
                      body: all.isEmpty
                          ? 'Cases marked Found or Closed leave this list and '
                              'cannot be reopened from the app.'
                          : 'The search reads the name, the place last seen '
                              'and the description.',
                      centred: true,
                    ),
                  )
                else
                  for (final person in shown)
                    _PersonTile(
                      person: person,
                      onTap: () => context.pushNamed(
                        AppRoutes.missingPersonName,
                        pathParameters: {'personId': person.personId},
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The confirmed matches, when there are any.
///
/// Renders nothing at all otherwise — including when the call fails. A police
/// officer whose session has lapsed gets a 403 here, and a red banner over the
/// register would be reporting a problem with a panel that is not the reason
/// they opened the screen. The register below still loads; it has no session
/// check.
class _Matches extends ConsumerWidget {
  const _Matches();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(confirmedMatchesProvider);

    return matches.maybeWhen(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Padding(
          key: MissingPersonKeys.matchesBanner,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.lg,
            AppSpacing.xxl,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                list.length == 1
                    ? 'ONE POSSIBLE MATCH'
                    : '${list.length} POSSIBLE MATCHES',
                style: AppTypography.label.copyWith(
                  color: Theme.of(context).colorScheme.error,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final match in list) ...[
                _MatchCard(match: match),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// One confirmed match: the two photographs side by side, and the score.
///
/// Both pictures, always. The comparison runs at a tolerance of 0.55, which is
/// loose enough that an officer has to be able to look at the two faces and
/// disagree — and a card that showed only the score would be asking them to
/// take a number's word for whether a missing child has been found.
class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match});

  final ConfirmedMatch match;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    final best = match.best;

    return InkWell(
      key: MissingPersonKeys.matchCard(match.personId),
      onTap: () => context.pushNamed(
        AppRoutes.missingPersonName,
        pathParameters: {'personId': match.personId},
      ),
      borderRadius: AppRadius.controlBorder,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.error.withValues(alpha: 0.05),
          borderRadius: AppRadius.controlBorder,
          border: Border.all(color: scheme.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            PersonPhoto(path: match.personPhotoPath, size: 56),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Icon(Icons.compare_arrows_rounded, size: 18),
            ),
            PersonPhoto(path: best?.photoPath ?? '', size: 56),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    match.name.isEmpty ? match.personId : match.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                  ),
                  if (best != null)
                    Text(
                      '${best.matchLabel} match'
                      '${best.location.isEmpty ? '' : ' · ${best.location}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.error.copyWith(color: muted),
                    ),
                  if (match.otherCount > 0)
                    Text(
                      match.otherCount == 1
                          ? '1 more sighting'
                          : '${match.otherCount} more sightings',
                      style: AppTypography.error.copyWith(color: muted),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.person, required this.onTap});

  final MissingPerson person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);

    return InkWell(
      key: MissingPersonKeys.tile(person.personId),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PersonPhoto(path: person.photoPath),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name.isEmpty ? 'No name recorded' : person.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                  ),
                  if (person.ageAndGender.isNotEmpty)
                    Text(
                      person.ageAndGender,
                      style: AppTypography.error.copyWith(color: muted),
                    ),
                  if (person.lastSeenLocation.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Last seen · ${person.lastSeenLocation}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.error.copyWith(color: muted),
                    ),
                  ],
                  if (person.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      person.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(Icons.chevron_right_rounded, size: 20, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
