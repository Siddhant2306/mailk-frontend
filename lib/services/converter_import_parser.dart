import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

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

/// Parses a bounded CSV or XLSX file into the same draft model used by single
/// entry. Submission remains separate so invalid data never reaches the API.
class ConverterImportParser {
  static const maxFileBytes = 2 * 1024 * 1024;
  static const maxRows = 100;

  ConverterImportPreview parse(PlatformFile file) {
    final invalidPreview = _invalidPreview(file);
    if (invalidPreview != null) return invalidPreview;
    return _parse(file.name, file.bytes!);
  }

  /// Parses native files away from the UI isolate. The browser implementation
  /// runs synchronously, but the strict file size limit keeps that work small.
  Future<ConverterImportPreview> parseAsync(PlatformFile file) {
    final invalidPreview = _invalidPreview(file);
    if (invalidPreview != null) return Future.value(invalidPreview);
    return compute(_parseImportFile, {
      'fileName': file.name,
      'bytes': file.bytes!,
    });
  }

  ConverterImportPreview? _invalidPreview(PlatformFile file) {
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      return ConverterImportPreview(
        fileName: file.name,
        rows: const [],
        errors: const ['The selected file could not be read.'],
      );
    }
    if (file.size > maxFileBytes || bytes.length > maxFileBytes) {
      return ConverterImportPreview(
        fileName: file.name,
        rows: const [],
        errors: const ['Import files must be 2 MB or smaller.'],
      );
    }
    return null;
  }

  ConverterImportPreview _parse(String fileName, Uint8List bytes) {
    try {
      final table = _readTable(fileName, bytes);
      return _toPreview(fileName, table);
    } on FormatException catch (error) {
      return ConverterImportPreview(
        fileName: fileName,
        rows: const [],
        errors: [error.message],
      );
    } on Object {
      return ConverterImportPreview(
        fileName: fileName,
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
          (row) =>
              row.map((cell) => cell?.value?.toString().trim() ?? '').toList(),
        )
        .toList();
  }

  ConverterImportPreview _toPreview(String fileName, List<List<String>> table) {
    if (table.length < 2) {
      throw const FormatException(
        'Include a header row and at least one record.',
      );
    }
    if (table.length - 1 > maxRows) {
      throw const FormatException('Import no more than 100 rows at a time.');
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

    return ConverterImportPreview(
      fileName: fileName,
      rows: rows,
      errors: errors,
    );
  }

  ConverterDraft _draftFromRow(Map<String, String> row) {
    final brandId = int.tryParse(row['brand_id']?.trim() ?? '');
    final codeReference = row['code_reference']?.trim() ?? '';
    if (brandId == null || brandId <= 0) {
      throw const FormatException('brand_id must be a positive whole number.');
    }
    if (codeReference.isEmpty || codeReference.length > 150) {
      throw const FormatException(
        'code_reference must contain 1 to 150 characters.',
      );
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
      markings: _markings(row['markings']),
      images: _images(row['images']),
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
    if (number == null || !number.isFinite || number < 0) {
      throw FormatException('$key must be a non-negative number.');
    }
    return number;
  }

  String? _optional(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  List<String> _markings(String? value) {
    final items = _splitItems(value);
    if (items.length > 25 || items.any((item) => item.length > 200)) {
      throw const FormatException(
        'A row can have at most 25 markings of up to 200 characters.',
      );
    }
    return items;
  }

  List<String> _images(String? value) {
    final items = _splitItems(value);
    if (items.length > 4 ||
        items.any(
          (item) => !item.startsWith('https://') || item.length > 500,
        )) {
      throw const FormatException(
        'A row can have at most 4 HTTPS image URLs of up to 500 characters.',
      );
    }
    return items;
  }

  List<String> _splitItems(String? value) {
    final items = (value ?? '')
        .split(RegExp(r'[|,;]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    return items;
  }

  String _headerKey(String header) {
    return header
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}

ConverterImportPreview _parseImportFile(Map<String, Object> input) {
  return ConverterImportParser()._parse(
    input['fileName']! as String,
    input['bytes']! as Uint8List,
  );
}
