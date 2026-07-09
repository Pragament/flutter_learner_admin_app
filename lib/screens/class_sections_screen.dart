import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/school.dart';
import '../services/auth_service.dart';

class ClassSectionsScreen extends StatefulWidget {
  final School school;
  const ClassSectionsScreen({super.key, required this.school});

  @override
  State<ClassSectionsScreen> createState() => _ClassSectionsScreenState();
}

class _ClassSectionsScreenState extends State<ClassSectionsScreen> {
  final _db = FirebaseFirestore.instance;
  final _auth = AuthService();

  CollectionReference<Map<String, dynamic>> get _classSections =>
      _db.collection('schools').doc(widget.school.docId)
         .collection('classSections');

  // ── Show students dialog when section is tapped ──────────────────────────
  void _showStudentsDialog(Map<String, dynamic> sectionData, String docId) {
    final sectionId = sectionData['sectionId']?.toString() ?? '';
    final grade = sectionData['grade']?.toString() ?? '';
    final section = sectionData['section']?.toString() ?? '';
    final fullName = sectionData['fullName']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.class_outlined,
                        color: Colors.indigo.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fullName,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.indigo.shade700)),
                          Text(
                            'Academic Year: ${sectionData['academicYear'] ?? ''}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              // Students list
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _buildStudentQuery(sectionId, grade, section),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    final students = snap.data?.docs ?? [];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Student count
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Row(
                            children: [
                              Icon(Icons.people,
                                  size: 18,
                                  color: Colors.indigo.shade700),
                              const SizedBox(width: 6),
                              Text(
                                '${students.length} students',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo.shade700),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),

                        if (students.isEmpty)
                          const Expanded(
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.people_outline,
                                      size: 48, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('No students in this section.',
                                      style:
                                          TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: SingleChildScrollView(
                              child: DataTable(
                                columnSpacing: 16,
                                columns: const [
                                  DataColumn(label: Text('Adm No')),
                                  DataColumn(label: Text('Name')),
                                  DataColumn(label: Text('Phone')),
                                  DataColumn(label: Text('Roll No')),
                                  DataColumn(label: Text('Parents')),
                                ],
                                rows: students.map((doc) {
                                  final s = doc.data();
                                  return DataRow(cells: [
                                    DataCell(Text(
                                        s['admissionNo']?.toString() ??
                                            '')),
                                    DataCell(Text(
                                        s['name']?.toString() ?? '')),
                                    DataCell(Text(
                                        s['phoneNumber']?.toString() ??
                                            '')),
                                    DataCell(Text(
                                        s['rollNo']?.toString() ?? '')),
                                    DataCell(Text(
                                      '${(s['parentIds'] as List?)?.length ?? 0}',
                                    )),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _buildStudentQuery(
      String sectionId, String grade, String section) {
    if (sectionId.isNotEmpty) {
      // Match by sectionId only — no schoolCode filter needed since sectionId is unique
      return _db.collection('students')
          .where('sectionId', isEqualTo: sectionId)
          .snapshots();
    }

    // Fallback: match by schoolCode + grade + classSection
    final base = _db.collection('students')
        .where('schoolCode', isEqualTo: widget.school.schoolCode);

    if (grade.isNotEmpty && section.isNotEmpty) {
      return base
          .where('class', isEqualTo: grade)
          .where('classSection', isEqualTo: section.toUpperCase())
          .snapshots();
    } else if (grade.isNotEmpty) {
      return base.where('class', isEqualTo: grade).snapshots();
    }
    return base.snapshots();
  }

  // ── Edit section dialog ───────────────────────────────────────────────────
  void _showEditDialog(String docId, Map<String, dynamic> existing) {
    final academicYearCtrl =
        TextEditingController(text: existing['academicYear'] ?? '2025-26');
    final gradeCtrl =
        TextEditingController(text: existing['grade']?.toString() ?? '');
    final sectionCtrl =
        TextEditingController(text: existing['section'] ?? '');
    final fullNameCtrl =
        TextEditingController(text: existing['fullName'] ?? '');
    final roomCtrl =
        TextEditingController(text: existing['roomNumber'] ?? '');
    bool saving = false;
    String? error;

    void autoFill(StateSetter setDlg) {
      final g = gradeCtrl.text.trim();
      final s = sectionCtrl.text.trim().toUpperCase();
      if (g.isNotEmpty && s.isNotEmpty) {
        fullNameCtrl.text = '$g-$s';
        setDlg(() {});
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Edit Section'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: academicYearCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Academic Year *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: gradeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Grade *',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => autoFill(setDlg),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sectionCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Section *',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => autoFill(setDlg),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: fullNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    border: OutlineInputBorder(),
                    helperText: 'Auto-filled from Grade + Section',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: roomCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Room Number (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!,
                      style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (academicYearCtrl.text.trim().isEmpty ||
                          gradeCtrl.text.trim().isEmpty ||
                          sectionCtrl.text.trim().isEmpty ||
                          fullNameCtrl.text.trim().isEmpty) {
                        setDlg(() =>
                            error = 'Fill all required fields.');
                        return;
                      }
                      setDlg(() { saving = true; error = null; });
                      try {
                        await _classSections.doc(docId).update({
                          'academicYear': academicYearCtrl.text.trim(),
                          'fullName': fullNameCtrl.text.trim(),
                          'grade': gradeCtrl.text.trim(),
                          'section': sectionCtrl.text.trim().toUpperCase(),
                          'roomNumber': roomCtrl.text.trim(),
                          'updatedAt': FieldValue.serverTimestamp(),
                          'updatedBy':
                              _auth.currentUser?.email ?? '',
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setDlg(() {
                          error = 'Error: $e';
                          saving = false;
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Add section dialog ────────────────────────────────────────────────────
  void _showAddDialog() {
    final academicYearCtrl = TextEditingController(text: '2025-26');
    final gradeCtrl = TextEditingController();
    final sectionCtrl = TextEditingController();
    final fullNameCtrl = TextEditingController();
    final roomCtrl = TextEditingController();
    bool saving = false;
    String? error;

    void autoFill(StateSetter setDlg) {
      final g = gradeCtrl.text.trim();
      final s = sectionCtrl.text.trim().toUpperCase();
      if (g.isNotEmpty && s.isNotEmpty) {
        fullNameCtrl.text = '$g-$s';
        setDlg(() {});
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Add Class Section'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: academicYearCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Academic Year *',
                    hintText: '2025-26',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: gradeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Grade *',
                    hintText: 'e.g. 4',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => autoFill(setDlg),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sectionCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Section *',
                    hintText: 'e.g. B',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => autoFill(setDlg),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: fullNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    hintText: 'e.g. 4-B',
                    border: OutlineInputBorder(),
                    helperText: 'Auto-filled from Grade + Section',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: roomCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Room Number (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!,
                      style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (academicYearCtrl.text.trim().isEmpty ||
                          gradeCtrl.text.trim().isEmpty ||
                          sectionCtrl.text.trim().isEmpty ||
                          fullNameCtrl.text.trim().isEmpty) {
                        setDlg(() =>
                            error = 'Fill all required fields.');
                        return;
                      }
                      setDlg(() { saving = true; error = null; });
                      try {
                        final now = FieldValue.serverTimestamp();
                        await _classSections.add({
                          'academicYear': academicYearCtrl.text.trim(),
                          'fullName': fullNameCtrl.text.trim(),
                          'grade': gradeCtrl.text.trim(),
                          'section': sectionCtrl.text.trim().toUpperCase(),
                          'roomNumber': roomCtrl.text.trim(),
                          'studentCount': 0,
                          'importedFromTimetable': false,
                          'createdAt': now,
                          'updatedAt': now,
                          'updatedBy': _auth.currentUser?.email ?? '',
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setDlg(() {
                          error = 'Error: $e';
                          saving = false;
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Add Section'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSection(String docId, String fullName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Section?'),
        content: Text('Delete "$fullName"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) await _classSections.doc(docId).delete();
  }

  Future<void> _importFromSchool() async {
    final sections = widget.school.sections;
    if (sections.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import existing sections?'),
        content: Text('Import ${sections.length} sections from school data.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Import')),
        ],
      ),
    );
    if (confirm != true) return;
    final userEmail = _auth.currentUser?.email ?? '';
    final now = FieldValue.serverTimestamp();
    for (final s in sections) {
      final className = s['className']?.toString() ?? '';
      final sectionName = s['sectionName']?.toString() ?? '';
      final year = s['year']?.toString() ?? '2025';
      final yearInt = int.tryParse(year) ?? 2025;
      await _classSections.add({
        'academicYear': '$year-${yearInt + 1}',
        'fullName': sectionName,
        'grade': className,
        'section': '',
        'roomNumber': '',
        'studentCount': 0,
        'importedFromTimetable': true,
        'sectionId': s['sectionId'] ?? '',
        'createdAt': now,
        'updatedAt': now,
        'updatedBy': userEmail,
      });
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${sections.length} sections!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Class Sections — ${widget.school.schoolName}'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Section'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _classSections.orderBy('grade').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.class_outlined,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No sections yet.',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Tap "Add Section" to create one.',
                      style: TextStyle(color: Colors.grey)),
                  if (widget.school.sections.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _importFromSchool,
                      icon: const Icon(Icons.download),
                      label: const Text('Import from school data'),
                    ),
                  ],
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Text('${docs.length} sections',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (widget.school.sections.isNotEmpty)
                      TextButton.icon(
                        onPressed: _importFromSchool,
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Import existing'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final d = docs[i].data();
                    final docId = docs[i].id;
                    final sectionId = d['sectionId']?.toString() ?? '';
                    final grade = d['grade']?.toString() ?? '';
                    final section = d['section']?.toString() ?? '';

                    return Card(
                      // Tap card → show students dialog
                      child: InkWell(
                        onTap: () => _showStudentsDialog(d, docId),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.indigo.shade50,
                                child: Text(
                                  grade,
                                  style: TextStyle(
                                      color: Colors.indigo.shade700,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(d['fullName'] ?? '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14)),
                                    const SizedBox(height: 2),
                                    // Live student count
                                    StreamBuilder<QuerySnapshot>(
                                      stream: _buildStudentQuery(
                                          sectionId, grade, section),
                                      builder: (ctx, snap) {
                                        final count =
                                            snap.data?.docs.length ?? 0;
                                        return Text(
                                          'Year: ${d['academicYear'] ?? ''}  •  $count students',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey),
                                        );
                                      },
                                    ),
                                    Text(
                                      'Updated by: ${d['updatedBy'] ?? ''}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              // Edit button (stops propagation to card tap)
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: Colors.indigo, size: 20),
                                tooltip: 'Edit section',
                                onPressed: () =>
                                    _showEditDialog(docId, d),
                              ),
                              // Delete button
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red, size: 20),
                                tooltip: 'Delete section',
                                onPressed: () => _deleteSection(
                                    docId, d['fullName'] ?? ''),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
