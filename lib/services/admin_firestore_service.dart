import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/school.dart';
import '../models/student_row.dart';

class AdminFirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _schools =>
      _db.collection('schools');
  CollectionReference<Map<String, dynamic>> get _students =>
      _db.collection('students');
  CollectionReference<Map<String, dynamic>> get _importHistory =>
      _db.collection('importHistory');

  // ── Find school by staff email ────────────────────────────────────────────
  // Searches all schools' staff subcollections for this email.
  // Returns the school if found, null if not.

  Future<School?> findSchoolByStaffEmail(String email) async {
    final schoolsSnap = await _schools.get();
    for (final schoolDoc in schoolsSnap.docs) {
      final staffSnap = await schoolDoc.reference
          .collection('staff')
          .where('email', isEqualTo: email)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
      if (staffSnap.docs.isNotEmpty) {
        return School.fromDoc(schoolDoc);
      }
    }
    return null;
  }

  // ── Create new school + add creator to staff ──────────────────────────────

  Future<String?> createSchool({
    required String schoolCode,
    required String schoolName,
    required String uid,
    required String email,
    required String displayName,
  }) async {
    final code = schoolCode.trim().toUpperCase();
    if (code.isEmpty || schoolName.trim().isEmpty) {
      return 'School code and name are required.';
    }

    // Check school code uniqueness
    final existing = await _schools
        .where('schoolCode', isEqualTo: code)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      return 'School code "$code" is already taken.';
    }

    // Create school doc matching existing structure
    final now = FieldValue.serverTimestamp();
    final schoolRef = await _schools.add({
      'schoolId': '',          // will update after creation
      'schoolName': schoolName.trim(),
      'schoolCode': code,      // new field we add
      'sections': [],
      'lastSyncedAt': now,
    });

    // Set schoolId to the Firestore doc id
    await schoolRef.update({'schoolId': schoolRef.id});

    // Reverse-index schoolCode -> schoolId. The parent app's Firestore
    // Security Rules need this to resolve a schoolCode to a doc path in
    // a single get() (rules can't run a `where` query), so a Teacher/
    // Admin's school access can actually be scoped server-side, not just
    // trusted from the client's own query.
    await _db.collection('schoolCodes').doc(code).set({'schoolId': schoolRef.id});

    // Add creator to staff subcollection, keyed by email (not an
    // auto-generated ID) so it can be looked up by exact path — same
    // reason as the schoolCodes index above.
    await schoolRef.collection('staff').doc(email).set({
      'email': email,
      'displayName': displayName,
      'uid': uid,
      'role': 'admin',
      'status': 'active',
      'customRoleId': null,
      'customRoleName': null,
      'invitedAt': now,
      'invitedBy': email,
      'updatedAt': now,
    });

    return null;
  }

  // ── Join existing school by school code ──────────────────────────────────

  Future<String?> joinSchoolByCode({
    required String schoolCode,
    required String uid,
    required String email,
    required String displayName,
  }) async {
    // Find school by code
    final snap = await _schools
        .where('schoolCode', isEqualTo: schoolCode)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      return 'No school found with code "$schoolCode". Check the code and try again.';
    }

    final schoolRef = snap.docs.first.reference;

    // Check if already in staff
    final existing = await schoolRef
        .collection('staff')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      // Already in staff — just activate if inactive
      final staffDoc = existing.docs.first;
      if (staffDoc.data()['status'] != 'active') {
        await staffDoc.reference.update({'status': 'active'});
      }
      return null; // success
    }

    // Add to staff, keyed by email (see createSchool for why).
    await schoolRef.collection('staff').doc(email).set({
      'email': email,
      'displayName': displayName,
      'uid': uid,
      'role': 'staff',
      'status': 'active',
      'customRoleId': null,
      'customRoleName': null,
      'invitedAt': FieldValue.serverTimestamp(),
      'invitedBy': email,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return null; // success
  }

  // ── Stream schools where this user is staff ───────────────────────────────

  Stream<List<School>> streamMySchools(String email) {
    // Can't do a collection group query on staff easily without index,
    // so we stream all schools and filter client-side
    return _schools.snapshots().asyncMap((snap) async {
      final mySchools = <School>[];
      for (final doc in snap.docs) {
        final staffSnap = await doc.reference
            .collection('staff')
            .where('email', isEqualTo: email)
            .where('status', isEqualTo: 'active')
            .limit(1)
            .get();
        if (staffSnap.docs.isNotEmpty) {
          mySchools.add(School.fromDoc(doc));
        }
      }
      return mySchools;
    });
  }

  // ── Import History ────────────────────────────────────────────────────────

  /// Get import history as a one-time fetch (no index needed)
  Future<List<Map<String, dynamic>>> getImportHistory(String schoolCode) async {
    final snap = await _importHistory
        .where('schoolCode', isEqualTo: schoolCode)
        .get();
    final list = snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
    list.sort((a, b) {
      final at = a['importedAt'];
      final bt = b['importedAt'];
      if (at == null || bt == null) return 0;
      return bt.compareTo(at);
    });
    return list;
  }

  Stream<List<Map<String, dynamic>>> streamImportHistory(String schoolCode) {
    return _importHistory
        .where('schoolCode', isEqualTo: schoolCode)
        .orderBy('importedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }

  Future<void> saveImportHistory({
    required String schoolCode,
    required String fileName,
    required int inserted,
    required int updated,
    required int skipped,
    required int errors,
  }) async {
    await _importHistory.add({
      'schoolCode': schoolCode,
      'fileName': fileName,
      'inserted': inserted,
      'updated': updated,
      'skipped': skipped,
      'errors': errors,
      'importedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Students CSV import ───────────────────────────────────────────────────

  Future<ImportResult> importStudents({
    required String schoolCode,
    required List<StudentRow> rows,
    required bool overwriteExisting,
  }) async {
    int inserted = 0, updated = 0, skipped = 0, errors = 0;
    final errorMessages = <String>[];

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (!row.isValid) {
        errors++;
        errorMessages.add('Row ${i + 2}: ${row.error}');
        continue;
      }
      try {
        final existing = await _students
            .where('schoolCode', isEqualTo: schoolCode)
            .where('admissionNo', isEqualTo: row.admissionNo.trim())
            .limit(1)
            .get();

        if (existing.docs.isNotEmpty) {
          if (overwriteExisting) {
            // Update ALL fields from the CSV — not just name/phone —
            // so re-imports always fix stale data (e.g. missing classSection
            // from students imported before that field existed).
            await existing.docs.first.reference.update({
              'name': row.name.trim(),
              'phoneNumber': row.phoneNumber.trim(),
              'rollNo': row.rollNo.trim(),
              'class': row.studentClass.trim(),
              'classSection': row.classSection.trim(),
              'sectionId': row.sectionId.trim(),
            });
            updated++;
          } else {
            skipped++;
          }
        } else {
          await _students.add({
            'schoolCode': schoolCode,
            'admissionNo': row.admissionNo.trim(),
            'name': row.name.trim(),
            'phoneNumber': row.phoneNumber.trim(),
            'rollNo': row.rollNo.trim(),
            'class': row.studentClass.trim(),
            'sectionId': row.sectionId.trim(),
            'studentId': '',
            'parentIds': [],
          });
          inserted++;
        }
      } catch (e) {
        errors++;
        errorMessages.add('Row ${i + 2} (${row.admissionNo}): $e');
      }
    }

    // After import, update studentCount in classSections subcollection
    // Find the school doc by schoolCode
    final schoolSnap = await _schools
        .where('schoolCode', isEqualTo: schoolCode)
        .limit(1)
        .get();

    if (schoolSnap.docs.isNotEmpty) {
      final schoolDocId = schoolSnap.docs.first.id;
      final classSectionsRef = schoolSnap.docs.first.reference
          .collection('classSections');
      final classSectionsSnap = await classSectionsRef.get();

      for (final sectionDoc in classSectionsSnap.docs) {
        final grade = sectionDoc.data()['grade']?.toString() ?? '';
        final section = sectionDoc.data()['section']?.toString() ?? '';

        final studentCount = await _students
            .where('schoolCode', isEqualTo: schoolCode)
            .where('class', isEqualTo: grade)
            .where('classSection', isEqualTo: section)
            .count()
            .get();

        await sectionDoc.reference.update({
          'studentCount': studentCount.count ?? 0,
        });
      }
    }

    return ImportResult(
      inserted: inserted,
      updated: updated,
      skipped: skipped,
      errors: errors,
      errorMessages: errorMessages,
    );
  }

  // ── Stream students for a school ─────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> streamStudents(String schoolCode) {
    return _students
        .where('schoolCode', isEqualTo: schoolCode)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }
}

class ImportResult {
  final int inserted, updated, skipped, errors;
  final List<String> errorMessages;
  ImportResult({
    required this.inserted,
    required this.updated,
    required this.skipped,
    required this.errors,
    required this.errorMessages,
  });
}
