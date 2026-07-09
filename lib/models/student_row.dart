class StudentRow {
  final String admissionNo;
  final String name;
  final String phoneNumber;
  final String rollNo;
  final String studentClass;
  final String sectionId;
  final String classSection; // e.g. "A" or "B" from CSV

  String? get error {
    if (admissionNo.trim().isEmpty) return 'Missing admissionNo';
    if (name.trim().isEmpty) return 'Missing name';
    if (phoneNumber.trim().isEmpty) return 'Missing phoneNumber';
    return null;
  }

  bool get isValid => error == null;

  StudentRow({
    required this.admissionNo,
    required this.name,
    required this.phoneNumber,
    required this.rollNo,
    required this.studentClass,
    required this.sectionId,
    required this.classSection,
  });

  /// Parse phone number — handles Excel scientific notation like 9.88E+09
  static String _parsePhone(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    
    // Handle scientific notation: 9.88E+09 → 9880000000
    if (trimmed.toUpperCase().contains('E')) {
      try {
        final d = double.parse(trimmed);
        return d.toInt().toString();
      } catch (_) {}
    }
    
    // Remove decimals if any: 9876543210.0 → 9876543210
    if (trimmed.contains('.')) {
      try {
        final d = double.parse(trimmed);
        return d.toInt().toString();
      } catch (_) {}
    }
    
    return trimmed;
  }

  factory StudentRow.fromCsvRow(Map<String, String> row) {
    String get(List<String> keys) {
      for (final k in keys) {
        final v = row[k.toLowerCase()]?.trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      return '';
    }

    final rawPhone = get(['phonenumber', 'phone_number', 'phone', 'mobile', 'mobilenumber']);

    return StudentRow(
      admissionNo: get(['admissionno', 'admission_no', 'admission no', 'id']),
      name: get(['name', 'studentname', 'student_name', 'student name']),
      phoneNumber: _parsePhone(rawPhone),
      rollNo: get(['rollno', 'roll_no', 'roll no', 'roll']),
      studentClass: get(['class', 'grade', 'std']),
      sectionId: get(['sectionid', 'section_id', 'section']),
      classSection: get(['classsection', 'class_section', 'section_letter']),
    );
  }

  Map<String, dynamic> toFirestore(String schoolCode) => {
    'schoolCode': schoolCode,
    'admissionNo': admissionNo.trim(),
    'name': name.trim(),
    'phoneNumber': phoneNumber.trim(),
    'rollNo': rollNo.trim(),
    'class': studentClass.trim(),
    'classSection': classSection.trim(), // "A" or "B"
    'sectionId': sectionId.trim(),
    'studentId': '',
    'parentIds': [],
  };
}
