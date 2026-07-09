import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/school.dart';

class StudentsListScreen extends StatefulWidget {
  final School school;
  const StudentsListScreen({super.key, required this.school});

  @override
  State<StudentsListScreen> createState() => _StudentsListScreenState();
}

class _StudentsListScreenState extends State<StudentsListScreen> {
  final _db = FirebaseFirestore.instance;
  Map<String, List<Map<String, dynamic>>> _grouped = {};
  List<Map<String, dynamic>> _allStudents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    // Load students
    final studentsSnap = await _db
        .collection('students')
        .where('schoolCode', isEqualTo: widget.school.schoolCode)
        .get();
    _allStudents = studentsSnap.docs.map((d) => d.data()).toList();

    // Load classSections ordered by grade then section
    final sectionsSnap = await _db
        .collection('schools')
        .doc(widget.school.docId)
        .collection('classSections')
        .get();
    final sections = sectionsSnap.docs.map((d) => d.data()).toList();

    // Sort sections by grade then section letter
    sections.sort((a, b) {
      final gradeA = int.tryParse(a['grade']?.toString() ?? '0') ?? 0;
      final gradeB = int.tryParse(b['grade']?.toString() ?? '0') ?? 0;
      if (gradeA != gradeB) return gradeA.compareTo(gradeB);
      return (a['section'] ?? '').compareTo(b['section'] ?? '');
    });

    // Build grouped map with section fullName as key
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final s in sections) {
      final key = s['fullName']?.toString() ?? '';
      if (key.isNotEmpty) grouped[key] = [];
    }
    grouped['No Section'] = [];

    for (final student in _allStudents) {
      final grade = student['class']?.toString().trim() ?? '';
      final classSection = student['classSection']?.toString().trim().toUpperCase() ?? '';

      String? matchKey;

      // Match by grade + classSection → fullName "4-A"
      if (grade.isNotEmpty && classSection.isNotEmpty) {
        final expected = '$grade-$classSection';
        if (grouped.containsKey(expected)) {
          matchKey = expected;
        }
      }

      // If no match found, put in No Section
      grouped[matchKey ?? 'No Section']!.add(student);
    }

    if (grouped['No Section']!.isEmpty) {
      grouped.remove('No Section');
    }

    setState(() {
      _grouped = grouped;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Students — ${widget.school.schoolCode}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _allStudents.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No students imported yet.',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text('Use "Import CSV" to add students.',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '${_allStudents.length} total students'
                        ' across ${_grouped.length} section(s)',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                    ..._grouped.entries.map((entry) => _SectionTable(
                          sectionName: entry.key,
                          students: entry.value,
                        )),
                  ],
                ),
    );
  }
}

class _SectionTable extends StatelessWidget {
  final String sectionName;
  final List<Map<String, dynamic>> students;
  const _SectionTable({required this.sectionName, required this.students});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.class_outlined,
                    size: 18, color: Colors.indigo.shade700),
                const SizedBox(width: 8),
                Text(sectionName,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade700,
                        fontSize: 15)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${students.length} students',
                      style: TextStyle(
                          fontSize: 12, color: Colors.indigo.shade700)),
                ),
              ],
            ),
          ),
          if (students.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No students in this section yet.',
                  style: TextStyle(color: Colors.grey)),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                columns: const [
                  DataColumn(label: Text('Adm No')),
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Phone')),
                  DataColumn(label: Text('Roll No')),
                  DataColumn(label: Text('Parents')),
                ],
                rows: students
                    .map((s) => DataRow(cells: [
                          DataCell(Text(s['admissionNo']?.toString() ?? '')),
                          DataCell(Text(s['name']?.toString() ?? '')),
                          DataCell(Text(s['phoneNumber']?.toString() ?? '')),
                          DataCell(Text(s['rollNo']?.toString() ?? '')),
                          DataCell(Text(
                              '${(s['parentIds'] as List?)?.length ?? 0}')),
                        ]))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
