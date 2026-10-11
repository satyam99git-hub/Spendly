import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_dimensions.dart';
import '../../../evidence/data/datasources/evidence_file_picker.dart';
import '../../../evidence/presentation/controllers/evidence_providers.dart';
import '../../data/models/lawyer_models.dart';
import '../controllers/lawyer_providers.dart';
import '../widgets/lawyer_widgets.dart';
import 'lawyer_shell.dart';

/// `openProfileModal()` — the "My Profile" modal (lawyer_dashboard.html:
/// 751-832, 1607-1731). Closed by × or by a tap outside it.
Future<void> showLawyerProfile(BuildContext context) => showDialog<void>(
      context: context,
      builder: (_) => const LawyerProfileDialog(),
    );

class LawyerProfileDialog extends ConsumerStatefulWidget {
  const LawyerProfileDialog({super.key});

  @override
  ConsumerState<LawyerProfileDialog> createState() =>
      _LawyerProfileDialogState();
}

class _LawyerProfileDialogState extends ConsumerState<LawyerProfileDialog> {
  final _phone = TextEditingController();
  final _years = TextEditingController();
  final _office = TextEditingController();
  final _barNo = TextEditingController();
  final _practiceArea = TextEditingController();
  final _bio = TextEditingController();

  /// The read-only block; `—` until loaded, as the fields' fallback is.
  String _fullname = '';
  String _uniqueId = '';
  String _email = '';

  /// The preview circle — empty until `updateAvatarDisplay` runs.
  LawyerAvatar? _preview;

  LawyerMessage? _photoMessage;
  LawyerMessage? _saveMessage;
  Timer? _hidePhoto;
  Timer? _hideSave;

  /// `accept="image/*"`.
  static const _imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'heic',
    'heif',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hidePhoto?.cancel();
    _hideSave?.cancel();
    for (final c in [_phone, _years, _office, _barNo, _practiceArea, _bio]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final LawyerProfile? profile;
    try {
      profile = await ref.read(lawyerRepositoryProvider).profile();
    } catch (e) {
      if (kDebugMode) debugPrint('[lawyer] $e');
      return;
    }
    // `if (!res.ok) return;` — the fields stay as they were.
    if (profile == null || !mounted) return;
    setState(() {
      _fullname = profile!.fullname;
      _uniqueId = profile.uniqueId;
      _email = profile.email;
      _phone.text = profile.phone;
      _office.text = profile.officeAddress;
      _barNo.text = profile.barEnrollmentNo;
      _years.text = profile.yearsExperience;
      _practiceArea.text = profile.practiceArea;
      _bio.text = profile.bio;
    });
    _updateAvatar(profile.photoUrl, profile.fullname);
  }

  /// `updateAvatarDisplay(photoUrl, fullname)` — sets the modal preview and
  /// the sidebar avatar together.
  void _updateAvatar(String photoUrl, String fullname) {
    final initial = (fullname.isEmpty ? 'L' : fullname[0]).toUpperCase();
    final avatar = LawyerAvatar(photoUrl: photoUrl, initial: initial);
    setState(() => _preview = avatar);
    ref.read(lawyerAvatarProvider.notifier).state = avatar;
  }

  String _shown(String value) => value.isEmpty ? '—' : value;

  /// `uploadProfilePhoto()` (lines 1653-1678).
  Future<void> _changePhoto() async {
    final source = await showModalBottomSheet<EvidenceSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(EvidenceSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose a photo'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(EvidenceSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final file = await ref.read(evidenceFilePickerProvider).pick(source);
    if (file == null || !mounted) return;
    final ext =
        file.name.contains('.') ? file.name.split('.').last.toLowerCase() : '';
    if (!_imageExtensions.contains(ext)) return;

    setState(() => _photoMessage = LawyerMessage.muted('Uploading…'));
    try {
      final url = await ref
          .read(lawyerRepositoryProvider)
          .uploadPhoto(path: file.path, filename: file.name);
      if (!mounted) return;
      _updateAvatar(url, _shown(_fullname));
      setState(() => _photoMessage = LawyerMessage.ok('✓ Photo updated.'));
      _hidePhoto?.cancel();
      _hidePhoto = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _photoMessage = null);
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[lawyer] $e');
      if (mounted) {
        setState(() => _photoMessage = LawyerMessage.error('Upload failed.'));
      }
    }
  }

  /// `saveProfile()` (lines 1680-1727).
  Future<void> _save() async {
    final update = LawyerProfileUpdate(
      phone: _phone.text.trim(),
      officeAddress: _office.text.trim(),
      barEnrollmentNo: _barNo.text.trim(),
      yearsExperience: _years.text.trim(),
      practiceArea: _practiceArea.text.trim(),
      bio: _bio.text.trim(),
    );
    final invalid = update.validate();
    if (invalid != null) {
      setState(() => _saveMessage = LawyerMessage.error(invalid));
      return;
    }

    setState(() => _saveMessage = LawyerMessage.muted('Saving…'));
    try {
      await ref.read(lawyerRepositoryProvider).saveProfile(update);
      if (!mounted) return;
      setState(() => _saveMessage = LawyerMessage.ok('✓ Profile saved.'));
      _hideSave?.cancel();
      _hideSave = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _saveMessage = null);
      });
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _saveMessage = LawyerMessage.error('Could not save. Try again.'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;

    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        );

    Widget readOnly(String title, String value, {bool mono = false}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: LawyerColors.slate400,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ],
        );

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 448),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'My Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color:
                            dark ? LawyerColors.blue100 : LawyerColors.blue900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        LawyerAvatarCircle(
                          initial: _preview?.initial ?? '',
                          photoUrl: _preview?.photoUrl ?? '',
                          size: 56,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: LawyerColors.blue700,
                                  backgroundColor: LawyerColors.blue50,
                                  side: const BorderSide(
                                    color: LawyerColors.blue100,
                                  ),
                                ),
                                onPressed: _changePhoto,
                                child: const Text('Change Photo'),
                              ),
                              if (_photoMessage != null)
                                LawyerMessageText(_photoMessage, fontSize: 12),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: readOnly('Name', _shown(_fullname)),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: readOnly(
                                  'Unique ID',
                                  _shown(_uniqueId),
                                  mono: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          readOnly('Email', _shown(_email)),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    label('Phone'),
                    TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      // `oninput`: digits only, at most ten.
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    label('Years of Experience'),
                    TextField(
                      controller: _years,
                      keyboardType: TextInputType.number,
                      // `min="0"`, and `oninput` keeps it to two digits.
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    label('Office Address'),
                    TextField(controller: _office),
                    const SizedBox(height: AppSpacing.md),
                    label('Bar Enrollment No.'),
                    TextField(
                      controller: _barNo,
                      decoration:
                          const InputDecoration(hintText: 'MAH/1234/2020'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    label('Practice Area'),
                    TextField(
                      controller: _practiceArea,
                      decoration:
                          const InputDecoration(hintText: 'Criminal Law'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    label('Bio'),
                    TextField(controller: _bio, minLines: 2, maxLines: 4),
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton(
                      onPressed: _save,
                      child: const Text('Save Profile'),
                    ),
                    if (_saveMessage != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Center(child: LawyerMessageText(_saveMessage)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
