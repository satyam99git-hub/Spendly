import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_typography.dart';

/// Deployment provenance at the foot of the sign-in sheet: which station this
/// build is bound to, and which statutes it is aligned against.
///
/// This is not decoration. An officer signing in needs to see they are on the
/// right station's instance before entering credentials, and the statute line
/// (BNS / BNSS / BSA -- the 2023 codes that replaced the IPC, CrPC and Evidence
/// Act) tells them whether this build files under the current law. Both belong
/// in front of the officer at sign-in, not buried in an about screen.
///
/// Values are passed in rather than hard-coded so a station rebuild is a config
/// change, not a code change.
class StationFooter extends StatelessWidget {
  const StationFooter({
    super.key,
    required this.stationName,
    required this.jurisdiction,
    required this.buildLabel,
    required this.statuteLabel,
  });

  final String stationName;
  final String jurisdiction;
  final String buildLabel;
  final String statuteLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = isDark ? AppColors.saffronDark : AppColors.saffron;

    return Semantics(
      container: true,
      label:
          'Station $stationName, $jurisdiction. Build $buildLabel, $statuteLabel.',
      excludeSemantics: true,
      child: Column(
        children: [
          Text(
            '$stationName · $jurisdiction',
            textAlign: TextAlign.center,
            style: AppTypography.footer.copyWith(color: tint),
          ),
          Text(
            'Build $buildLabel · $statuteLabel',
            textAlign: TextAlign.center,
            style: AppTypography.footerFine.copyWith(
              color: tint.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
