import 'package:flutter/material.dart';
import '../services/admin_firestore_service.dart';
import '../services/auth_service.dart';

class CreateSchoolScreen extends StatefulWidget {
  final bool isFirstTime;
  final String userEmail;
  final String uid;
  final String displayName;

  const CreateSchoolScreen({
    super.key,
    this.isFirstTime = false,
    this.userEmail = '',
    this.uid = '',
    this.displayName = '',
  });

  @override
  State<CreateSchoolScreen> createState() => _CreateSchoolScreenState();
}

class _CreateSchoolScreenState extends State<CreateSchoolScreen> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _service = AdminFirestoreService();
  final _auth = AuthService();
  bool _busy = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final user = _auth.currentUser;
    if (user == null) return;
    setState(() => _busy = true);
    try {
      final error = await _service.createSchool(
        schoolCode: _codeCtrl.text.trim().toUpperCase(),
        schoolName: _nameCtrl.text.trim(),
        uid: user.uid,
        email: user.email ?? widget.userEmail,
        displayName: user.displayName ?? widget.displayName,
      );
      if (!mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('School created successfully!')),
        );
        // Refresh auth gate
        Navigator.of(context).pushReplacementNamed('/');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.isFirstTime
          ? null
          : AppBar(title: const Text('Create School')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isFirstTime) ...[
                  const Icon(Icons.school_outlined,
                      size: 64, color: Colors.indigo),
                  const SizedBox(height: 16),
                  const Text(
                    'Welcome! No school found for your account.',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Signed in as: ${widget.userEmail}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                ],
                const Text(
                  'Create your school to get started. The school code is what '
                  'parents enter to link their child.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'School Code',
                    hintText: 'e.g. DSS2025',
                    border: OutlineInputBorder(),
                    helperText: 'Must be unique across all schools',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'School Name',
                    hintText: 'e.g. Delhi Secondary School',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _create,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Create School'),
                  ),
                ),
                if (widget.isFirstTime) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: _auth.signOut,
                      child: const Text('Sign out'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
