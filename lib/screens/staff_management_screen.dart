import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/school.dart';
import '../services/auth_service.dart';

class StaffManagementScreen extends StatefulWidget {
  final School school;
  const StaffManagementScreen({super.key, required this.school});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final _db = FirebaseFirestore.instance;
  final _auth = AuthService();
  final _emailCtrl = TextEditingController();
  String _selectedRole = 'staff';
  bool _adding = false;
  String? _addError;

  CollectionReference<Map<String, dynamic>> get _staffRef =>
      _db.collection('schools').doc(widget.school.docId).collection('staff');

  Future<void> _addStaff() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _addError = 'Enter a valid email address.');
      return;
    }

    setState(() { _adding = true; _addError = null; });

    try {
      // Check if already exists
      final existing = await _staffRef
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        setState(() {
          _addError = '$email is already in the staff list.';
          _adding = false;
        });
        return;
      }

      final inviterEmail = _auth.currentUser?.email ?? '';
      await _staffRef.add({
        'email': email,
        'displayName': '',
        'uid': '',
        'role': _selectedRole,
        'status': 'active',
        'customRoleId': null,
        'customRoleName': null,
        'invitedAt': FieldValue.serverTimestamp(),
        'invitedBy': inviterEmail,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _emailCtrl.clear();
      setState(() => _adding = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '$email added. They can now sign in with Google to access this school.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() { _addError = 'Error: $e'; _adding = false; });
    }
  }

  Future<void> _removeStaff(String docId, String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove staff member?'),
        content: Text('Remove $email from this school? They will lose access immediately.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _staffRef.doc(docId).update({'status': 'inactive'});
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Staff — ${widget.school.schoolName}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Add staff emails here. Once added, they can sign in '
                      'with Google using that email to access this school. '
                      'No school code needed.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Text('Add Staff Member',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),

            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email Address',
                hintText: 'teacher@school.com',
                border: const OutlineInputBorder(),
                errorText: _addError,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                const Text('Role: '),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedRole,
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    DropdownMenuItem(value: 'staff', child: Text('Staff')),
                    DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                  ],
                  onChanged: (v) => setState(() => _selectedRole = v ?? 'staff'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _adding ? null : _addStaff,
                icon: _adding
                    ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.person_add),
                label: Text(_adding ? 'Adding...' : 'Add Staff Member'),
              ),
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),

            Text('Current Staff',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),

            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _staffRef
                  .where('status', isEqualTo: 'active')
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Text('No staff members yet.',
                      style: TextStyle(color: Colors.grey));
                }
                return Column(
                  children: docs.map((doc) {
                    final d = doc.data();
                    final isMe = d['email'] == _auth.currentUser?.email;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo.shade50,
                          child: Text(
                            (d['email'] as String? ?? '?')[0].toUpperCase(),
                            style: TextStyle(color: Colors.indigo.shade700),
                          ),
                        ),
                        title: Text(d['email'] ?? ''),
                        subtitle: Row(
                          children: [
                            _RoleBadge(d['role'] ?? 'staff'),
                            if ((d['uid'] as String? ?? '').isEmpty) ...[
                              const SizedBox(width: 6),
                              const _RoleBadge('not logged in yet', isWarning: true),
                            ],
                          ],
                        ),
                        trailing: isMe
                            ? const Chip(label: Text('You'))
                            : IconButton(
                                icon: const Icon(Icons.person_remove,
                                    color: Colors.red),
                                tooltip: 'Remove',
                                onPressed: () =>
                                    _removeStaff(doc.id, d['email'] ?? ''),
                              ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  final bool isWarning;
  const _RoleBadge(this.label, {this.isWarning = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: isWarning ? Colors.orange.shade100 : Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: isWarning ? Colors.orange.shade700 : Colors.indigo.shade700,
        ),
      ),
    );
  }
}
