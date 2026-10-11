import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/validators.dart';
import '../../../../routes/app_routes.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/inputs/password_field.dart';
import '../../../../theme/app_dimensions.dart';
import '../controllers/auth_controller.dart';
import '../controllers/auth_state.dart';
import '../../../../shared/widgets/feedback/form_banner.dart';
import '../widgets/auth_header.dart';
import '../widgets/station_footer.dart';

/// Sign-in for every role.
///
/// The NyayaAI server has one credential check for all four roles -- citizen,
/// police, lawyer and judge all POST the same `{email, password}` to `/login` --
/// and the role comes back in the response. So this screen asks no role
/// question: making the user pick one before signing in would be a guess the
/// server is about to answer authoritatively, and getting it wrong would be a
/// confusing failure for something that is not actually ambiguous.
///
/// NAVIGATION: this screen never pushes. On success the controller flips the
/// auth state and the router's redirect moves the user to `/home`. Navigating
/// here as well would race that redirect.
///
/// LAYOUT: a fixed navy masthead over a scrolling sheet. The sheet -- not the
/// page -- scrolls, so the heading stays put while the form moves under the
/// keyboard, and the masthead collapses when the keyboard appears to hand its
/// space to the fields.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  /// Rendered above the form. Held in local state rather than read straight off
  /// AuthState so that navigating away and back does not resurrect a failure the
  /// user has already seen and moved on from.
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    FocusScope.of(context).unfocus();
    setState(() => _errorMessage = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final controller = ref.read(authControllerProvider.notifier);
    final succeeded = await controller.login(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted || succeeded) return;

    // Read the failure the controller recorded, then clear it so it cannot
    // reappear on an unrelated rebuild.
    final failure = ref.read(authControllerProvider).failure;
    controller.clearFailure();

    setState(() {
      _errorMessage = failure?.message ?? 'Sign-in failed. Please try again.';
      // Clear the password but keep the email: the email is almost never the
      // thing that was mistyped, and re-entering it on every retry is friction
      // for no benefit.
      _passwordController.clear();
    });
    _passwordFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final busy = ref.watch(
      authControllerProvider
          .select((s) => s.status == AuthStatus.authenticating),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        // Light glyphs: the status bar always sits on navy here, in both themes.
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: scheme.surface,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        // Matches the masthead so the status-bar strip above it is continuous.
        backgroundColor: AuthHeader.backgroundFor(context),
        body: Column(
          children: [
            SafeArea(
              bottom: false,
              child: AuthHeader(
                title: 'Sign in',
                subtitle: 'Authorised access only. Activity is logged.',
                compact: keyboardOpen,
              ),
            ),
            Expanded(child: _buildSheet(context, scheme, busy)),
          ],
        ),
      ),
    );
  }

  Widget _buildSheet(BuildContext context, ColorScheme scheme, bool busy) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppRadius.sheetTop,
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          // Bounce even when the content fits, so it is discoverable that the
          // sheet scrolls once the keyboard shortens it.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.xxl + AppSpacing.xs,
            AppSpacing.xxl,
            AppSpacing.xxl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.maxFormWidth,
              ),
              child: _buildForm(context, busy),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, bool busy) {
    return Form(
      key: _formKey,
      // AutofillGroup lets a password manager fill both fields as one credential
      // rather than treating them as unrelated boxes.
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null) ...[
              FormBanner(message: _errorMessage!),
              const SizedBox(height: AppSpacing.lg),
            ],
            AppTextField(
              label: 'Email address',
              controller: _emailController,
              focusNode: _emailFocus,
              validator: Validators.email,
              enabled: !busy,
              hintText: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              inputFormatters: [
                // Email addresses are case-insensitive and the server matches
                // them exactly, so a stray shift key must not become a failed
                // sign-in. Spaces are stripped for the same reason -- a trailing
                // space from autocomplete is invisible and unexplainable.
                TextInputFormatter.withFunction(
                  (_, next) => next.copyWith(text: next.text.toLowerCase()),
                ),
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
              ],
              onSubmitted: (_) => _passwordFocus.requestFocus(),
            ),
            const SizedBox(height: AppSpacing.sm),
            PasswordField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              // Presence only. See Validators.password -- a length floor here
              // would lock out accounts that already exist in the database.
              validator: Validators.password,
              enabled: !busy,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleSignIn(),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Sign in',
              icon: Icons.verified_user_outlined,
              isLoading: busy,
              onPressed: _handleSignIn,
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildSignupPrompt(context, busy),
            const SizedBox(height: AppSpacing.xxxl),
            const StationFooter(
              stationName: 'NyayaAI',
              jurisdiction: 'Government of India',
              buildLabel: '2.4.0',
              statuteLabel: 'BNS / BNSS / BSA aligned',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignupPrompt(BuildContext context, bool busy) {
    final theme = Theme.of(context);

    // Wrap, not Row: the prompt and the action together are wider than a narrow
    // handset's form column, and a Row would clip the button rather than move
    // it. Wrapping to a second line is the only outcome that keeps both
    // readable at every width and text scale.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'New to NyayaAI?',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        TextButton(
          onPressed:
              busy ? null : () => context.pushNamed(AppRoutes.signupName),
          child: const Text('Create an account'),
        ),
      ],
    );
  }
}
