import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/school.dart';
import '../utils/section_utils.dart';

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

  /// Uses the SAME source of truth as the Class Sections page:
  /// a student belongs to a section when student.sectionId equals the
  /// classSection document's `sectionId` field. Section names come straight
  /// from the Firestore classSections documents (`fullName`) and are never
  /// reconstructed or generated (no "6-A" guessing).
  Future<void> _loadData() async {
    setState(() => _loading = true);

    // Source of truth: this school's own classSections documents.
    final sectionsSnap = await _db
        .collection('schools')
        .doc(widget.school.docId)
        .collection('classSections')
        .get();
    final sections = sectionsSnap.docs.map((d) => d.data()).toList();

    // Sort by grade then section letter (mirrors the Class Sections ordering).
    sections.sort((a, b) {
      final gradeA = int.tryParse(a['grade']?.toString() ?? '0') ?? 0;
      final gradeB = int.tryParse(b['grade']?.toString() ?? '0') ?? 0;
      if (gradeA != gradeB) return gradeA.compareTo(gradeB);
      return (a['section'] ?? '')
          .toString()
          .compareTo((b['section'] ?? '').toString());
    });

    final grouped = <String, List<Map<String, dynamic>>>{};
    final knownSectionIds = <String>{};
    final seenDocIds = <String>{};

    // Hide the same empty-sectionId duplicate placeholders the Class Sections
    // page hides, so both pages show an identical section list.
    final realGrades = gradesWithRealSection(sections);

    // Group students under each real Firestore section, using the exact same
    // query the Class Sections page uses (by sectionId, with a grade/classSection
    // fallback for sections that have no sectionId).
    for (final s in sections) {
      if (isHiddenDuplicateSection(s, realGrades)) continue;
      final fullName = s['fullName']?.toString() ?? '';
      if (fullName.isEmpty) continue;
      final sectionId = s['sectionId']?.toString() ?? '';
      final grade = s['grade']?.toString() ?? '';
      final section = s['section']?.toString() ?? '';
      if (sectionId.isNotEmpty) knownSectionIds.add(sectionId);

      final snap = await _studentsForSection(sectionId, grade, section);
      final list = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        if (seenDocIds.add(doc.id)) list.add(doc.data());
      }
      grouped[fullName] = list;
    }

    // "No Section" is a UI fallback ONLY — never a Firestore section.
    // It holds students who belong to this school (by schoolCode) but whose
    // sectionId does not resolve to any of this school's sections.
    final noSection = <Map<String, dynamic>>[];
    final code = widget.school.schoolCode;
    if (code.isNotEmpty) {
      final schoolStudentsSnap = await _db
          .collection('students')
          .where('schoolCode', isEqualTo: code)
          .get();
      for (final doc in schoolStudentsSnap.docs) {
        if (seenDocIds.contains(doc.id)) continue;
        final data = doc.data();
        final sid = data['sectionId']?.toString() ?? '';
        if (sid.isEmpty || !knownSectionIds.contains(sid)) {
          noSection.add(data);
          seenDocIds.add(doc.id);
        }
      }
    }
    if (noSection.isNotEmpty) grouped['No Section'] = noSection;

    final all = grouped.values.expand((l) => l).toList();

    setState(() {
      _grouped = grouped;
      _allStudents = all;
      _loading = false;
    });
  }

  /// One-shot equivalent of ClassSectionsScreen._buildStudentQuery so both
  /// pages resolve students identically.
  Future<QuerySnapshot<Map<String, dynamic>>> _studentsForSection(
      String sectionId, String grade, String section) {
    if (sectionId.isNotEmpty) {
      // Primary link — identical to the Class Sections page. No schoolCode
      // filter, because sectionId is globally unique.
      return _db
          .collection('students')
          .where('sectionId', isEqualTo: sectionId)
          .get();
    }
    // Fallback for sections with no sectionId (e.g. manually added sections).
    final base = _db
        .collection('students')
        .where('schoolCode', isEqualTo: widget.school.schoolCode);
    if (grade.isNotEmpty && section.isNotEmpty) {
      return base
          .where('class', isEqualTo: grade)
          .where('classSection', isEqualTo: section.toUpperCase())
          .get();
    } else if (grade.isNotEmpty) {
      return base.where('class', isEqualTo: grade).get();
    }
    return base.get();
  }

  @override
  Widget build(BuildContext context) {
    // Count only real Firestore sections; "No Section" is a fallback, not a section.
    final realSectionCount =
        _grouped.keys.where((k) => k != 'No Section').length;
    final noSectionStudents = _grouped['No Section']?.length ?? 0;
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
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.groups, color: Colors.indigo.shade700),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${_allStudents.length} total students',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.indigo.shade700)),
                                const SizedBox(height: 2),
                                Text(
                                  '$realSectionCount Firestore section(s)'
                                  '${noSectionStudents > 0 ? '  •  $noSectionStudents unassigned' : ''}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
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
