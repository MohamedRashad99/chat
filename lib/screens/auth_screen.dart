import 'package:flutter/material.dart';
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
  final _picker = ImagePicker();
  XFile? _selectedAvatar;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _username.dispose();
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
            final key = 'profiles/${res.user!.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';
            await supabase.storage.from('chat-media').uploadBinary(key, bytes);
            avatarUrl = supabase.storage.from('chat-media').getPublicUrl(key);
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
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(children: [
              // WA-style logo
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
                  color: AppTheme.textPrimary, letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isLogin ? 'Sign in to continue' : 'Create your account',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 40),

              // fields
              if (!_isLogin) ...[
                GestureDetector(
                  onTap: _loading
                      ? null
                      : () async {
                          final file = await _picker.pickImage(source: ImageSource.gallery);
                          if (file == null) return;
                          setState(() => _selectedAvatar = file);
                        },
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.inputBg,
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _selectedAvatar == null
                        ? const Icon(Icons.add_a_photo_outlined, color: AppTheme.textMuted)
                        : Image.file(
                            File(_selectedAvatar!.path),
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                _field(controller: _username, hint: 'Username',
                    icon: Icons.person_outline),
                const SizedBox(height: 12),
              ],
              _field(controller: _email, hint: 'Email',
                  icon: Icons.mail_outline,
                  type: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _field(
                controller: _password, hint: 'Password',
                icon: Icons.lock_outline, obscure: _obscure,
                suffix: IconButton(
                  icon: Icon(_obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                      color: AppTheme.textMuted, size: 20),
                  onPressed: () => setState(() => _obscure = !_obscure),
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
                      : Text(_isLogin ? 'SIGN IN' : 'CREATE ACCOUNT',
                          style: const TextStyle(letterSpacing: 1)),
                ),
              ),
              const SizedBox(height: 20),

              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(
                  _isLogin
                      ? "Don't have an account? "
                      : 'Already have an account? ',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                ),
                GestureDetector(
                  onTap: () => setState(() => _isLogin = !_isLogin),
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
    );
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
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppTheme.inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
