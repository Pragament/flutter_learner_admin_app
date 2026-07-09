import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/school.dart';
import '../services/admin_firestore_service.dart';
import '../services/auth_service.dart';
import 'class_sections_screen.dart';
import 'create_school_screen.dart';
import 'import_students_screen.dart';
import 'staff_management_screen.dart';
import 'students_list_screen.dart';

class DashboardScreen extends StatelessWidget {
  DashboardScreen({super.key});

  final _auth = AuthService();
  final _service = AdminFirestoreService();

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) return const SizedBox.shrink();
    final email = user.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('School Admin'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Text(user.displayName ?? email,
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'Sign out',
                  onPressed: _auth.signOut,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateSchoolScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New School'),
      ),
      body: StreamBuilder<List<School>>(
        stream: _service.streamMySchools(email),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final schools = snap.data ?? [];
          if (schools.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.school_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No schools yet.',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('Tap "New School" to create one.',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: schools.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _SchoolCard(school: schools[i]),
          );
        },
      ),
    );
  }
}

class _SchoolCard extends StatelessWidget {
  final School school;
  const _SchoolCard({required this.school});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.school, color: Colors.indigo),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(school.schoolName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (school.schoolCode.isNotEmpty)
                            _Badge('Code: ${school.schoolCode}', Colors.indigo),
                          const SizedBox(width: 6),
                          // Live section count from classSections subcollection
                          StreamBuilder<QuerySnapshot>(
                            stream: db
                                .collection('schools')
                                .doc(school.docId)
                                .collection('classSections')
                                .snapshots(),
                            builder: (context, snap) {
                              final count = snap.data?.docs.length ?? 0;
                              return _Badge('$count sections', Colors.teal);
                            },
                          ),
                          const SizedBox(width: 6),
                          // Live student count
                          StreamBuilder<QuerySnapshot>(
                            stream: db
                                .collection('students')
                                .where('schoolCode',
                                isEqualTo: school.schoolCode)
                                .snapshots(),
                            builder: (context, snap) {
                              final count = snap.data?.docs.length ?? 0;
                              return _Badge('$count students', Colors.green);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: school.schoolCode.isEmpty
                      ? null
                      : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ImportStudentsScreen(school: school),
                    ),
                  ),
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Import CSV'),
                ),
                OutlinedButton.icon(
                  onPressed: school.schoolCode.isEmpty
                      ? null
                      : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          StudentsListScreen(school: school),
                    ),
                  ),
                  icon: const Icon(Icons.people, size: 18),
                  label: const Text('View Students'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ClassSectionsScreen(school: school),
                    ),
                  ),
                  icon: const Icon(Icons.class_outlined, size: 18),
                  label: const Text('Class Sections'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StaffManagementScreen(school: school),
                    ),
                  ),
                  icon: const Icon(Icons.people_outline, size: 18),
                  label: const Text('Staff'),
                ),
              ],
            ),
            if (school.schoolCode.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '⚠️ No school code. Add schoolCode in Firestore to enable CSV import.',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }
}