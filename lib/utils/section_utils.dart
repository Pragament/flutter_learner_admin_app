// Shared logic for hiding leftover duplicate/default sections from the UI
// WITHOUT deleting them from Firestore.
//
// A section is treated as a hideable duplicate when it has NO sectionId AND
// another section of the same grade DOES have a real sectionId — e.g. a
// placeholder "6-A" (empty sectionId) sitting next to the real, timetable-
// imported "DSS 2025 class 6" (which has a sectionId and the students).
//
// Standalone empty sections (whose grade has NO real section) are kept, because
// an empty section may be legitimate. Firestore is never modified here; this is
// display-only filtering, so all pages show the same set of sections.

/// Grades that have at least one "real" section (non-empty sectionId).
Set<String> gradesWithRealSection(Iterable<Map<String, dynamic>> sections) {
  final grades = <String>{};
  for (final s in sections) {
    final sid = s['sectionId']?.toString() ?? '';
    final grade = s['grade']?.toString() ?? '';
    if (sid.isNotEmpty && grade.isNotEmpty) grades.add(grade);
  }
  return grades;
}

/// True when [section] is an empty-sectionId placeholder whose grade already
/// has a real section — i.e. a duplicate that should be hidden from the UI.
bool isHiddenDuplicateSection(
    Map<String, dynamic> section, Set<String> realGrades) {
  final sid = section['sectionId']?.toString() ?? '';
  final grade = section['grade']?.toString() ?? '';
  return sid.isEmpty && realGrades.contains(grade);
}
