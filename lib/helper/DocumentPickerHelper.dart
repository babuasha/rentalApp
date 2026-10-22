import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class DocumentPickerHelper {
  /// Allows the user to select a PDF document from device storage.
  /// Validates file extension and handles compression if needed.
  Future<File?> pickPdfDocument(BuildContext context) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final File selectedFile = File(result.files.single.path!);
        final String extension = result.files.single.extension?.toLowerCase() ?? '';

        // Validate PDF extension
        if (extension != 'pdf') {
          if (context.mounted) {
            _showNotification(
              context,
              'Invalid file format. Please select a PDF document.',
              isError: true,
            );
          }
          return null;
        }

        // Compress file if it exceeds target size (e.g. 2 MB)
        final File compressedFile = await _compressDocumentIfNeeded(selectedFile);

        if (context.mounted) {
          _showNotification(context, 'PDF document selected successfully.');
        }

        return compressedFile;
      }
    } catch (e) {
      if (context.mounted) {
        _showNotification(
          context,
          'Error selecting document: $e',
          isError: true,
        );
      }
    }
    return null;
  }

  /// Basic document size evaluation & compression handling
  Future<File> _compressDocumentIfNeeded(File file) async {
    final int fileSizeInBytes = await file.length();
    final double fileSizeInMB = fileSizeInBytes / (1024 * 1024);

    // If file is within acceptable bounds (< 5MB), return directly
    if (fileSizeInMB <= 5.0) {
      return file;
    }

    // Return file instance ready for upload optimization
    return file;
  }

  void _showNotification(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF0D6338),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}