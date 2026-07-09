import 'package:flutter/material.dart';
import '../services/admin_firestore_service.dart';
import '../services/auth_service.dart';

/// Shown when a logged-in user is not in any school's staff.
/// Option 1 — Invite only:
///   - If email already pre-added to staff by admin → they get access on login
///   - If not → show "contact your admin" message
///   - ONLY option is to Create a new school (for new schools)
class JoinOrCreateSchoolScreen extends StatefulWidget {
  final String userEmail;
  final String uid;
  final String displayName;
  final VoidCallback onSchoolJoinedOrCreated;

  const JoinOrCreateSchoolScreen({
    super.key,
    required this.userEmail,
    required this.uid,
    required this.displayName,
    required this.onSchoolJoinedOrCreated,
  });

  @override
  State<JoinOrCreateSchoolScreen> createState() =>
      _JoinOrCreateSchoolScreenState();
}

class _JoinOrCreateSchoolScreenState
    extends State<JoinOrCreateSchoolScreen> {
  final _service = AdminFirestoreService();
  final _auth = AuthService();

  final _newCodeCtrl = TextEditingController();
  final _newNameCtrl = TextEditingController();
  bool _creating = false;
  String? _createError;
  bool _showCreate = false;

  @override
  void dispose() {
    _newCodeCtrl.dispose();
    _newNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _createSchool() async {
    final code = _newCodeCtrl.text.trim().toUpperCase();
    final name = _newNameCtrl.text.trim();
    if (code.isEmpty || name.isEmpty) {
      setState(() => _createError = 'Both fields are required.');
      return;
    }
    setState(() { _creating = true; _createError = null; });
    try {
      final error = await _service.createSchool(
        schoolCode: code,
        schoolName: name,
        uid: widget.uid,
        email: widget.userEmail,
        displayName: widget.displayName,
      );
      if (!mounted) return;
      if (error != null) {
        setState(() { _createError = error; _creating = false; });
      } else {
        widget.onSchoolJoinedOrCreated();
      }
    } catch (e) {
      setState(() { _createError = 'Error: $e'; _creating = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.school_outlined,
                    size: 56, color: Colors.indigo),
                const SizedBox(height: 16),
                const Text('Welcome to School Admin',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Signed in as: ${widget.userEmail}',
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 32),

                // ── No access message ─────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange.shade200),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Text('No school access found',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your email has not been added to any school\'s staff list yet.\n\n'
                        'Ask your school admin to add your email address '
                        'to the staff list. Once added, sign out and sign '
                        'in again to get access.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Sign out ──────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _auth.signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
                ),

                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),

                // ── Create new school (for new admins only) ───────────────
                GestureDetector(
                  onTap: () =>
                      setState(() => _showCreate = !_showCreate),
                  child: Row(
                    children: [
                      Text(
                        'Are you setting up a new school?',
                        style: TextStyle(
                            color: Colors.indigo.shade700,
                            fontWeight: FontWeight.w500),
                      ),
                      Icon(
                        _showCreate
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: Colors.indigo.shade700,
                      ),
                    ],
                  ),
                ),

                if (_showCreate) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Create a new school. You will be the admin and can '
                    'add other staff members from the staff management page.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newCodeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'School Code',
                      hintText: 'e.g. SPRK2025',
                      border: OutlineInputBorder(),
                      helperText: 'Must be unique — parents use this to claim students',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'School Name',
                      hintText: 'e.g. Sri Prakash School',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_createError != null) ...[
                    const SizedBox(height: 8),
                    Text(_createError!,
                        style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _creating ? null : _createSchool,
                      icon: _creating
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Icon(Icons.add_business),
                      label: Text(_creating
                          ? 'Creating...'
                          : 'Create New School'),
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
