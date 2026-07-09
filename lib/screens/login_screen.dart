import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() { _busy = true; _error = null; });
    try {
      await _auth.signInWithGoogle();
    } catch (e) {
      setState(() => _error = 'Sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.admin_panel_settings, size: 72, color: Colors.indigo),
                const SizedBox(height: 16),
                Text('School Admin', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text('Manage schools and import student data',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 32),
                if (_busy)
                  const CircularProgressIndicator()
                else
                  FilledButton.icon(
                    onPressed: _signIn,
                    icon: const Icon(Icons.login),
                    label: const Text('Sign in with Google'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
