import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

class ApartmentDocumentHelper {
  // Defined exact required order
  static const List<String> requiredDocumentOrder = [
    'Property Document',
    'Property Plan',
    'Tenancy Agreement',
    'Tenant ID',
    'Tenant Passport',
  ];

  /// Extracts documents from Firestore and sorts them in the specified order.
  List<Map<String, String>> getOrderedDocuments(Map<String, dynamic> documentsMap) {
    if (documentsMap.containsKey('Plan') && !documentsMap.containsKey('Property Plan')) {
      documentsMap['Property Plan'] = documentsMap['Plan'];
    }

    List<Map<String, String>> orderedList = [];

    for (String docType in requiredDocumentOrder) {
      final String? url = documentsMap[docType]?.toString();
      if (url != null && url.isNotEmpty) {
        orderedList.add({
          'title': docType,
          'url': url,
        });
      }
    }

    return orderedList;
  }

  /// Downloads and caches the document safely, then opens it in-app.
  Future<void> viewDocumentInApp(BuildContext context, String? urlStr, String title) async {
    if (urlStr == null || urlStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document file not available')),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF0D6338)),
      ),
    );

    try {
      final File file = await DefaultCacheManager().getSingleFile(urlStr);

      if (context.mounted) {
        Navigator.pop(context); // Remove loading dialog
        
        // Open in-app PDF Viewer Dialog
        showDialog(
          context: context,
          builder: (context) => Dialog(
            insetPadding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: SizedBox(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.8,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: PDFView(
                      filePath: file.path,
                      enableSwipe: true,
                      swipeHorizontal: false,
                      autoSpacing: true,
                      pageFling: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Dismiss loader if active
        
        final Uri uri = Uri.parse(urlStr);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not open document')),
            );
          }
        }
      }
    }
  }

  /// Safely downloads and saves the document to the app's local storage directory.
  Future<void> downloadDocument(BuildContext context, String? urlStr, String title) async {
    if (urlStr == null || urlStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document file not available')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloading $title...')),
    );

    try {
      final File cachedFile = await DefaultCacheManager().getSingleFile(urlStr);
      
      // Use app documents directory to avoid permission-denied crashes on modern Android
      final Directory directory = await getApplicationDocumentsDirectory();

      final sanitizedTitle = title.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');
      final targetPath = '${directory.path}/${sanitizedTitle}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      await cachedFile.copy(targetPath);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded successfully to app storage!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }
}