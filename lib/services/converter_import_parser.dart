import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

import '../models/converter_draft.dart';

class ConverterImportPreview {
  const ConverterImportPreview({
    required this.fileName,
    required this.rows,
    required this.errors,
  });

  final String fileName;
  final List<ConverterDraft> rows;
  final List<String> errors;

  bool get isReady => rows.isNotEmpty && errors.isEmpty;
}

/// Parses a CSV or XLSX file into the same draft model used by single entry.
/// It deliberately does not submit rows: the backend currently exposes no
/// atomic bulk-import API endpoint.
class ConverterImportParser {
  ConverterImportPreview parse(PlatformFile file) {
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      return ConverterImportPreview(
        fileName: file.name,
        rows: const [],
        errors: const ['The selected file could not be read.'],
      );
    }

    try {
      final table = _readTable(file.name, bytes);
      return _toPreview(file.name, table);
    } on FormatException catch (error) {
      return ConverterImportPreview(
        fileName: file.name,
        rows: const [],
        errors: [error.message],
      );
    } on Object {
      return ConverterImportPreview(
        fileName: file.name,
        rows: const [],
        errors: const ['The file could not be parsed as CSV or XLSX.'],
      );
    }
  }

  List<List<String>> _readTable(String fileName, Uint8List bytes) {
    final extension = fileName.split('.').last.toLowerCase();
    if (extension == 'csv') {
      return const CsvToListConverter(shouldParseNumbers: false)
          .convert(utf8.decode(bytes))
          .map((row) => row.map((cell) => cell.toString().trim()).toList())
          .toList();
    }
    if (extension != 'xlsx') {
      throw const FormatException('Select a .csv or .xlsx file.');
    }

    final workbook = Excel.decodeBytes(bytes);
    if (workbook.tables.isEmpty) {
      throw const FormatException('The spreadsheet does not contain a sheet.');
    }
    final sheet = workbook.tables.values.first;
    return sheet.rows
        .map(
          (row) => row
              .map((cell) => cell?.value?.toString().trim() ?? '')
              .toList(),
        )
        .toList();
  }

  ConverterImportPreview _toPreview(String fileName, List<List<String>> table) {
    if (table.length < 2) {
      throw const FormatException('Include a header row and at least one record.');
    }

    final headers = table.first.map(_headerKey).toList();
    const requiredHeaders = {'brand_id', 'code_reference'};
    if (!requiredHeaders.every(headers.contains)) {
      throw const FormatException(
        'Required headers: brand_id and code_reference.',
      );
    }

    final rows = <ConverterDraft>[];
    final errors = <String>[];
    for (var index = 1; index < table.length; index++) {
      final values = table[index];
      if (values.every((value) => value.trim().isEmpty)) {
        continue;
      }
      final row = <String, String>{
        for (var column = 0; column < headers.length; column++)
          headers[column]: column < values.length ? values[column] : '',
      };
      try {
        rows.add(_draftFromRow(row));
      } on FormatException catch (error) {
        errors.add('Row ${index + 1}: ${error.message}');
      }
    }

    return ConverterImportPreview(fileName: fileName, rows: rows, errors: errors);
  }

  ConverterDraft _draftFromRow(Map<String, String> row) {
    final brandId = int.tryParse(row['brand_id']?.trim() ?? '');
    final codeReference = row['code_reference']?.trim() ?? '';
    if (brandId == null) {
      throw const FormatException('brand_id must be a whole number.');
    }
    if (codeReference.isEmpty) {
      throw const FormatException('code_reference is required.');
    }

    return ConverterDraft(
      brandId: brandId,
      codeReference: codeReference,
      model: _optional(row['model']),
      converterType: _optional(row['converter_type']),
      category: _optional(row['category']),
      localLingo: _optional(row['local_lingo']),
      monolithWeightGrams: _number(row, 'monolith_weight_g'),
      ptPpm: _number(row, 'pt_ppm'),
      pdPpm: _number(row, 'pd_ppm'),
      rhPpm: _number(row, 'rh_ppm'),
      markings: _items(row['markings']),
      images: _items(row['images']),
      remarks: _optional(row['remarks']),
      notes: _optional(row['notes']),
    );
  }

  double? _number(Map<String, String> row, String key) {
    final value = _optional(row[key]);
    if (value == null) {
      return null;
    }
    final number = double.tryParse(value);
    if (number == null) {
      throw FormatException('$key must be numeric.');
    }
    return number;
  }

  String? _optional(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  List<String> _items(String? value) {
    return (value ?? '')
        .split(RegExp(r'[|,;]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _headerKey(String header) {
    return header
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}
