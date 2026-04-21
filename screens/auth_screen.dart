import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _loading = false;
  bool _obscure = true;

  final _email    = TextEditingController();
  final _password = TextEditingController();
  final _username = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      if (_isLogin) {
        await supabase.auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      } else {
        final res = await supabase.auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          data: {'username': _username.text.trim()},
        );
        if (res.user != null) {
          await supabase.from('profiles').upsert({
            'id': res.user!.id,
            'username': _username.text.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      }
    } on AuthException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.danger),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(children: [
        // ambient glow top-left
        Positioned(
          top: -180, left: -120,
          child: Container(
            width: 550, height: 550,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppTheme.accent.withOpacity(0.07),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        // ambient glow bottom-right
        Positioned(
          bottom: -160, right: -100,
          child: Container(
            width: 480, height: 480,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppTheme.accentGlow.withOpacity(0.05),
                Colors.transparent,
              ]),
            ),
          ),
        ),

        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  _buildBrand(),
                  const SizedBox(height: 48),
                  _buildCard(),
                  const SizedBox(height: 22),
                  _buildToggle(),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildBrand() {
    return Column(children: [
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.accent, AppTheme.accentGlow],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withOpacity(0.38),
              blurRadius: 22, offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.hexagon_outlined, color: Colors.white, size: 30),
      ),
      const SizedBox(height: 16),
      Text(
        'ONYX IX',
        style: GoogleFonts.spaceGrotesk(
          fontSize: 28, fontWeight: FontWeight.w800,
          color: AppTheme.textPrimary, letterSpacing: 4,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'ENCRYPTED  ·  REAL-TIME  ·  SLEEK',
        style: GoogleFonts.spaceGrotesk(
          fontSize: 10, color: AppTheme.textMuted, letterSpacing: 2.5,
        ),
      ),
    ]);
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withOpacity(0.05),
            blurRadius: 40,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isLogin ? 'Welcome back' : 'Create account',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22, fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isLogin
                ? 'Sign in to your ONYX IX account'
                : 'Join the ONYX IX network',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 28),

          if (!_isLogin) ...[
            _field(
              controller: _username,
              hint: 'Username',
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 14),
          ],

          _field(
            controller: _email,
            hint: 'Email address',
            icon: Icons.mail_outline_rounded,
            type: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),

          _field(
            controller: _password,
            hint: 'Password',
            icon: Icons.lock_outline_rounded,
            obscure: _obscure,
            suffix: IconButton(
              icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppTheme.textMuted, size: 18,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isLogin ? 'Sign In' : 'Create Account'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(
        _isLogin ? "Don't have an account? " : 'Already have an account? ',
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
      ),
      GestureDetector(
        onTap: () => setState(() => _isLogin = !_isLogin),
        child: Text(
          _isLogin ? 'Sign up' : 'Sign in',
          style: const TextStyle(
            color: AppTheme.accentGlow,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ]);
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? type,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      obscureText: obscure,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 18),
        suffixIcon: suffix,
      ),
    );
  }
}
