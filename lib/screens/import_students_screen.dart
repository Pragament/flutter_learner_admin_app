import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/school.dart';
import '../models/student_row.dart';
import '../services/admin_firestore_service.dart';
import '../services/csv_parser.dart';

class ImportStudentsScreen extends StatefulWidget {
  final School school;
  const ImportStudentsScreen({super.key, required this.school});

  @override
  State<ImportStudentsScreen> createState() => _ImportStudentsScreenState();
}

class _ImportStudentsScreenState extends State<ImportStudentsScreen> {
  final _service = AdminFirestoreService();
  List<StudentRow>? _preview;
  bool _overwrite = false;
  bool _importing = false;
  bool _picking = false;
  String? _fileName;
  ImportResult? _result;
  String? _pickError;

  Future<void> _pickFile() async {
    setState(() { _picking = true; _pickError = null; });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _picking = false);
        return;
      }
      final file = result.files.first;
      if (file.bytes == null) {
        setState(() { _pickError = 'Could not read file.'; _picking = false; });
        return;
      }
      final text = utf8.decode(file.bytes!);
      final rows = CsvParser.parse(text);
      setState(() {
        _fileName = file.name;
        _preview = rows;
        _result = null;
        _picking = false;
      });
    } catch (e) {
      setState(() { _pickError = 'Error: $e'; _picking = false; });
    }
  }

  Future<void> _import() async {
    final rows = _preview;
    if (rows == null) return;
    final validRows = rows.where((r) => r.isValid).toList();
    if (validRows.isEmpty) return;

    setState(() { _importing = true; _result = null; });
    try {
      final result = await _service.importStudents(
        schoolCode: widget.school.schoolCode,
        rows: validRows,
        overwriteExisting: _overwrite,
      );
      await _service.saveImportHistory(
        schoolCode: widget.school.schoolCode,
        fileName: _fileName ?? 'unknown.csv',
        inserted: result.inserted,
        updated: result.updated,
        skipped: result.skipped,
        errors: result.errors,
      );
      setState(() {
        _result = result;
        if (result.errors == 0) { _preview = null; _fileName = null; }
      });
    } catch (e) {
      setState(() => _result = ImportResult(
        inserted: 0, updated: 0, skipped: 0, errors: 1,
        errorMessages: ['Import failed: $e'],
      ));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final validRows = preview?.where((r) => r.isValid).length ?? 0;
    final invalidRows = preview?.where((r) => !r.isValid).length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Import Students — ${widget.school.schoolName}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Import History
            Text('Import History',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _service.getImportHistory(widget.school.schoolCode),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                final history = snap.data ?? [];
                if (history.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('No imports yet.',
                        style: TextStyle(color: Colors.grey)),
                  );
                }
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: history.map((h) {
                      final at = h['importedAt'];
                      String dateStr = '';
                      if (at != null) {
                        try {
                          final dt = (at as dynamic).toDate() as DateTime;
                          dateStr =
                              '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
                        } catch (_) {}
                      }
                      return ListTile(
                        leading: const Icon(Icons.history,
                            color: Colors.indigo),
                        title: Text(h['fileName'] ?? 'CSV file'),
                        subtitle: Text(dateStr),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if ((h['inserted'] ?? 0) > 0)
                              _Badge('${h['inserted']} added',
                                  Colors.green),
                            const SizedBox(width: 4),
                            if ((h['updated'] ?? 0) > 0)
                              _Badge('${h['updated']} updated',
                                  Colors.blue),
                            const SizedBox(width: 4),
                            if ((h['errors'] ?? 0) > 0)
                              _Badge('${h['errors']} errors',
                                  Colors.red),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            Text('Import New CSV',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: const Text(
                  'Required columns: admissionNo, name, phoneNumber\n'
                  'Optional: grade/class, classSection, rollNo\n\n'
                  'Example:\n'
                  'admissionNo,name,phoneNumber,grade,classSection\n'
                  '1,MOKSHITH,9876543210,4,A\n'
                  '2,SRESHTA,9876543211,4,B',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                FilledButton.icon(
                  onPressed: _picking ? null : _pickFile,
                  icon: _picking
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.upload_file),
                  label: Text(_picking ? 'Reading...' : 'Pick CSV File'),
                ),
                if (_fileName != null) ...[
                  const SizedBox(width: 12),
                  Text(_fileName!,
                      style: const TextStyle(color: Colors.grey)),
                ],
              ],
            ),

            if (_pickError != null) ...[
              const SizedBox(height: 8),
              Text(_pickError!,
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],

            if (preview != null) ...[
              const SizedBox(height: 16),
              Row(children: [
                Text('${preview.length} rows found',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(width: 8),
                _Badge('$validRows valid', Colors.green),
                const SizedBox(width: 4),
                if (invalidRows > 0) _Badge('$invalidRows errors', Colors.red),
              ]),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('admNo')),
                    DataColumn(label: Text('name')),
                    DataColumn(label: Text('phone')),
                    DataColumn(label: Text('grade')),
                    DataColumn(label: Text('section')),
                    DataColumn(label: Text('status')),
                  ],
                  rows: preview.take(20).map((r) => DataRow(cells: [
                    DataCell(Text(r.admissionNo)),
                    DataCell(Text(r.name)),
                    DataCell(Text(r.phoneNumber)),
                    DataCell(Text(r.studentClass)),
                    DataCell(Text(r.classSection)),
                    DataCell(r.isValid
                        ? const Icon(Icons.check_circle,
                            color: Colors.green, size: 18)
                        : Tooltip(
                            message: r.error ?? '',
                            child: const Icon(Icons.error,
                                color: Colors.red, size: 18))),
                  ])).toList(),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Update existing students'),
                subtitle: const Text(
                    'If admissionNo already exists, update name and phone'),
                value: _overwrite,
                onChanged: (v) => setState(() => _overwrite = v),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (_importing || validRows == 0) ? null : _import,
                  icon: _importing
                      ? const SizedBox(
                          height: 18, width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.cloud_upload),
                  label: Text(_importing
                      ? 'Importing...'
                      : 'Import $validRows Students to '
                        '${widget.school.schoolCode}'),
                ),
              ),
            ],

            if (_result != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _result!.errors == 0
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  border: Border.all(
                    color: _result!.errors == 0
                        ? Colors.green.shade300
                        : Colors.orange.shade300,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _result!.errors == 0
                          ? '✅ Import Complete!'
                          : '⚠️ Import completed with errors',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _result!.errors == 0
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_result!.inserted > 0)
                      Text('${_result!.inserted} students added'),
                    if (_result!.updated > 0)
                      Text('${_result!.updated} students updated'),
                    if (_result!.skipped > 0)
                      Text('${_result!.skipped} skipped'),
                    if (_result!.errors > 0)
                      Text('${_result!.errors} errors',
                          style: const TextStyle(color: Colors.red)),
                    ..._result!.errorMessages.map((e) => Text(e,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.red))),
                  ],
                ),
              ),
            ],
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
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}
