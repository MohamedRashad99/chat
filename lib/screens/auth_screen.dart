import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
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
  final _emailFocus    = FocusNode();
  final _passwordFocus = FocusNode();
  final _usernameFocus = FocusNode();
  final _picker = ImagePicker();
  XFile? _selectedAvatar;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _username.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _usernameFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      _snack('Please fill all fields');
      return;
    }
    if (!_isLogin && _username.text.trim().isEmpty) {
      _snack('Please enter a username');
      return;
    }
    if (!_isLogin && _selectedAvatar == null) {
      _snack('Please select a profile photo');
      return;
    }

    setState(() => _loading = true);
    try {
      if (_isLogin) {
        await supabase.auth.signInWithPassword(
          email: email, password: password);
      } else {
        final res = await supabase.auth.signUp(
          email: email,
          password: password,
          data: {'username': _username.text.trim()},
        );
        if (res.user != null) {
          String? avatarUrl;
          if (_selectedAvatar != null) {
            final bytes = await _selectedAvatar!.readAsBytes();
            final ext = _selectedAvatar!.path.split('.').last;
            // Upload to 'avatars' bucket (matches SQL)
            final key = '${res.user!.id}/avatar.$ext';
            await supabase.storage.from('avatars').uploadBinary(
              key,
              bytes,
              fileOptions: const FileOptions(upsert: true),
            );
            avatarUrl = supabase.storage.from('avatars').getPublicUrl(key);
          }

          await supabase.from('profiles').upsert({
            'id': res.user!.id,
            'username': _username.text.trim(),
            'avatar_url': avatarUrl,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = AppTheme.bgColor(context);
    final textPrimary = AppTheme.primaryText(context);
    final textSecondary = AppTheme.secondaryText(context);
    final inputBg = AppTheme.inputBgColor(context);

    return Scaffold(
      backgroundColor: bg,
      body: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.enter) {
            if (!_loading) _submit();
          }
        },
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withOpacity(0.35),
                        blurRadius: 24, offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.chat, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 24),
                Text(
                  'ONYX IX',
                  style: GoogleFonts.notoSans(
                    fontSize: 26, fontWeight: FontWeight.w700,
                    color: textPrimary, letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isLogin ? 'Sign in to continue' : 'Create your account',
                  style: TextStyle(color: textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 40),

                if (!_isLogin) ...[
                  // Avatar picker — required
                  GestureDetector(
                    onTap: _loading
                        ? null
                        : () async {
                            final file = await _picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 80,
                            );
                            if (file == null) return;
                            setState(() => _selectedAvatar = file);
                          },
                    child: Stack(
                      children: [
                        Container(
                          width: 96, height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: inputBg,
                            border: Border.all(
                              color: _selectedAvatar == null
                                  ? AppTheme.borderLight
                                  : AppTheme.accent,
                              width: 2,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _selectedAvatar == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo_outlined,
                                        color: AppTheme.accent, size: 28),
                                    const SizedBox(height: 4),
                                    Text('Required',
                                        style: TextStyle(
                                          color: AppTheme.accent,
                                          fontSize: 10,
                                        )),
                                  ],
                                )
                              : Image.file(
                                  File(_selectedAvatar!.path),
                                  fit: BoxFit.cover,
                                ),
                        ),
                        if (_selectedAvatar != null)
                          Positioned(
                            right: 0, bottom: 0,
                            child: Container(
                              width: 26, height: 26,
                              decoration: const BoxDecoration(
                                color: AppTheme.accent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.edit,
                                  color: Colors.white, size: 14),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _username,
                    focusNode: _usernameFocus,
                    hint: 'Username',
                    icon: Icons.person_outline,
                    textInputAction: TextInputAction.next,
                    onSubmitted: () => _emailFocus.requestFocus(),
                    inputBg: inputBg,
                    textColor: textPrimary,
                  ),
                  const SizedBox(height: 12),
                ],

                _field(
                  controller: _email,
                  focusNode: _emailFocus,
                  hint: 'Email',
                  icon: Icons.mail_outline,
                  type: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onSubmitted: () => _passwordFocus.requestFocus(),
                  inputBg: inputBg,
                  textColor: textPrimary,
                ),
                const SizedBox(height: 12),

                // Password field — Enter triggers Sign In
                TextField(
                  controller: _password,
                  focusNode: _passwordFocus,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) { if (!_loading) _submit(); },
                  style: TextStyle(color: textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline,
                        color: AppTheme.textMuted, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppTheme.textMuted, size: 20,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    filled: true,
                    fillColor: inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(
                            _isLogin ? 'SIGN IN' : 'CREATE ACCOUNT',
                            style: const TextStyle(letterSpacing: 1),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(
                    _isLogin
                        ? "Don't have an account? "
                        : 'Already have an account? ',
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _isLogin = !_isLogin;
                      _selectedAvatar = null;
                    }),
                    child: Text(
                      _isLogin ? 'Sign up' : 'Sign in',
                      style: const TextStyle(
                        color: AppTheme.accent, fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color inputBg,
    required Color textColor,
    FocusNode? focusNode,
    TextInputType? type,
    bool obscure = false,
    TextInputAction? textInputAction,
    VoidCallback? onSubmitted,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: type,
      obscureText: obscure,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted != null ? (_) => onSubmitted() : null,
      style: TextStyle(color: textColor, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
