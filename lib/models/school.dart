import 'package:cloud_firestore/cloud_firestore.dart';

class School {
  final String docId;        // Firestore document id
  final String schoolId;     // schools.schoolId field
  final String schoolName;
  final String schoolCode;   // we add this field
  final List<Map<String, dynamic>> sections;

  School({
    required this.docId,
    required this.schoolId,
    required this.schoolName,
    required this.schoolCode,
    required this.sections,
  });

  factory School.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return School(
      docId: doc.id,
      schoolId: (d['schoolId'] ?? '').toString(),
      schoolName: (d['schoolName'] ?? '').toString(),
      schoolCode: (d['schoolCode'] ?? '').toString(),
      sections: List<Map<String, dynamic>>.from(d['sections'] ?? []),
    );
  }
}
