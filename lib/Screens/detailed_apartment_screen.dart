import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:rentalapp/helper/ApartmentDocumentHelper.dart';
import 'package:rentalapp/helper/ApartmentImageHelper.dart';
import 'add_apartment_screen.dart';

class ApartmentDetailScreen extends StatefulWidget {
  final String apartmentId;

  const ApartmentDetailScreen({
    super.key,
    required this.apartmentId,
  });

  @override
  State<ApartmentDetailScreen> createState() => _ApartmentDetailScreenState();
}

class _ApartmentDetailScreenState extends State<ApartmentDetailScreen> {
  bool _dialogShown = false;
  
  // Dedicated helpers
  final ApartmentImageHelper _imageHelper = ApartmentImageHelper();
  final ApartmentDocumentHelper _documentHelper = ApartmentDocumentHelper();

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'N/A';
    if (dateValue is Timestamp) {
      return DateFormat('d- MMM- yy').format(dateValue.toDate());
    }
    return dateValue.toString();
  }

  DateTime? _parseDateTime(dynamic dateValue) {
    if (dateValue == null) return null;
    if (dateValue is Timestamp) return dateValue.toDate();

    if (dateValue is String) {
      try {
        return DateFormat('d- MMM- yy').parse(dateValue);
      } catch (_) {
        try {
          return DateFormat('dd/MM/yyyy').parse(dateValue);
        } catch (_) {
          try {
            return DateTime.parse(dateValue);
          } catch (_) {
            return null;
          }
        }
      }
    }
    return null;
  }

  bool _isExpired(dynamic dateValue) {
    final DateTime? toDate = _parseDateTime(dateValue);
    if (toDate == null) return false;

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime checkDate = DateTime(toDate.year, toDate.month, toDate.day);

    return checkDate.isBefore(today);
  }

  Future<void> _checkAndUpdateStatus(Map<String, dynamic> data) async {
    final String currentStatus = (data['status'] ?? 'Available').toString();
    final dynamic toDate = data['toDate'];

    // Only auto-update status to Available if it was explicitly Rented and the agreement expired
    if (currentStatus.toLowerCase() == 'rented' && _isExpired(toDate)) {
      await FirebaseFirestore.instance
          .collection('apartments')
          .doc(widget.apartmentId)
          .update({'status': 'Available'});
    }
  }

  bool _isCurrentMonth(dynamic dateValue) {
    final DateTime? toDate = _parseDateTime(dateValue);
    if (toDate == null) return false;

    final DateTime now = DateTime.now();
    return toDate.month == now.month && toDate.year == now.year;
  }

  void _showAgreementExpiringDialog(BuildContext context, bool isExpired) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Text(
              isExpired ? 'Agreement Expired' : 'Agreement Expiring',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          isExpired
              ? 'The agreement for this apartment has expired. The status has been automatically updated to Available.'
              : 'Agreement is going to complete in the current month.',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D6338),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteApartment(BuildContext context, Map<String, dynamic> data) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Apartment'),
        content: const Text('Are you sure you want to delete this apartment and all its associated files from storage?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: Color(0xFF0D6338)),
          ),
        );

        // 1. Delete all photos from Cloud Storage
        final List<String> photoUrls = _imageHelper.getPhotoUrls(data);
        for (String url in photoUrls) {
          if (url.isNotEmpty && url.contains('firebasestorage.googleapis.com')) {
            try {
              Reference photoRef = FirebaseStorage.instance.refFromURL(url);
              await photoRef.delete();
              debugPrint('Successfully deleted photo from storage: $url');
            } catch (e) {
              debugPrint('Error deleting photo from storage ($url): $e');
            }
          }
        }

        // 2. Delete all documents from Cloud Storage
        if (data['documents'] is Map) {
          Map<String, dynamic> docsMap = Map<String, dynamic>.from(data['documents']);
          for (var entry in docsMap.entries) {
            final String docUrl = entry.value?.toString() ?? '';
            if (docUrl.isNotEmpty && docUrl.contains('firebasestorage.googleapis.com')) {
              try {
                Reference docRef = FirebaseStorage.instance.refFromURL(docUrl);
                await docRef.delete();
                debugPrint('Successfully deleted document from storage: $docUrl');
              } catch (e) {
                debugPrint('Error deleting document from storage ($docUrl): $e');
              }
            }
          }
        }

        // 3. Delete the apartment document from Firestore
        final countryId = data['countryId'];
        await FirebaseFirestore.instance
            .collection('apartments')
            .doc(widget.apartmentId)
            .delete();

        // 4. Update the country apartment count
        if (countryId != null && countryId.toString().isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('countries')
              .doc(countryId)
              .update({'apartmentCount': FieldValue.increment(-1)});
        }

        if (context.mounted) {
          Navigator.pop(context); // Close loading dialog
          Navigator.pop(context); // Go back to previous screen
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context); // Close loading dialog on error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting apartment: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('apartments')
          .doc(widget.apartmentId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF0D6338)),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: Text('Apartment not found')),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;

        _checkAndUpdateStatus(data);

        final String title = data['title'] ?? 'Apartment Name';
        final dynamic price = data['price'] ?? 0;
        final dynamic serviceCharge = data['serviceCharge'] ?? 0;
        final String currency = data['currency'] ?? 'OMR';
        final String bhk = data['bhk'] ?? '2BHK';
        final String type = data['type'] ?? 'Semi';
        final String paymentType = data['paymentType'] ?? 'Pay 3 Months';
        final String size = data['size'] ?? '';
        final String tenantName = (data['tenantName'] ?? '').toString().trim();

        final bool expired = _isExpired(data['toDate']);
        final String rawStatus = (data['status'] ?? 'Available').toString();
        
        // Determine status and styling accurately for all 4 states
        final String statusLower = rawStatus.toLowerCase().replaceAll(' ', '');
        
        String displayStatus = rawStatus.isEmpty ? 'Available' : rawStatus;
        Color statusBgColor = const Color(0xFFE2F0E7);
        Color statusTextColor = const Color(0xFF0D6338);

        if (expired && statusLower == 'rented') {
          displayStatus = 'Available';
          statusBgColor = const Color(0xFFE2F0E7);
          statusTextColor = const Color(0xFF0D6338);
        } else if (statusLower == 'rented') {
          displayStatus = 'Rented';
          statusBgColor = const Color(0xFFFFECEB);
          statusTextColor = const Color(0xFFD9534F);
        } else if (statusLower == 'ownuse') {
          displayStatus = 'Own Use';
          statusBgColor = const Color(0xFFE3F2FD);
          statusTextColor = const Color(0xFF1976D2);
        } else if (statusLower == 'underconstruction') {
          displayStatus = 'Under Construction';
          statusBgColor = const Color(0xFFFFF3E0);
          statusTextColor = const Color(0xFFF57C00);
        } else {
          displayStatus = 'Available';
          statusBgColor = const Color(0xFFE2F0E7);
          statusTextColor = const Color(0xFF0D6338);
        }

        final List<String> photoUrls = _imageHelper.getPhotoUrls(data);
        const String defaultWebUrl = 'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?auto=format&fit=crop&w=800&q=80';

        final String fromDateStr = _formatDate(data['fromDate']);
        final String toDateStr = _formatDate(data['toDate']);

        final bool isEndingThisMonth = _isCurrentMonth(data['toDate']);

        Map<String, dynamic> documentsMap = {};
        if (data['documents'] is Map) {
          documentsMap = Map<String, dynamic>.from(data['documents']);
        }
        final List<Map<String, String>> uploadedDocuments =
            _documentHelper.getOrderedDocuments(documentsMap);

        if ((expired || isEndingThisMonth) && !_dialogShown) {
          _dialogShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showAgreementExpiringDialog(context, expired);
          });
        }

        final screenWidth = MediaQuery.of(context).size.width;

        return Scaffold(
          backgroundColor: Colors.white,
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Horizontal ScrollView for Images
                SizedBox(
                  height: 300,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      Container(
                        height: 300,
                        width: double.infinity,
                        color: Colors.grey.shade200,
                        child: photoUrls.isNotEmpty
                            ? ListView.builder(
                                scrollDirection: Axis.horizontal,
                                physics: const PageScrollPhysics(), 
                                itemCount: photoUrls.length,
                                itemBuilder: (context, index) {
                                  return SizedBox(
                                    width: screenWidth,
                                    child: Image.network(
                                      photoUrls[index],
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          _imageHelper.buildFallbackImage(defaultWebUrl),
                                    ),
                                  );
                                },
                              )
                            : _imageHelper.buildFallbackImage(defaultWebUrl),
                      ),
                      
                      // Back button
                      Positioned(
                        top: 48,
                        left: 16,
                        child: CircleAvatar(
                          backgroundColor: Colors.black.withOpacity(0.5),
                          radius: 20,
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                      
                      // Image Counter Badge
                      if (photoUrls.length > 1)
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.photo_library_outlined, color: Colors.white, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  '${photoUrls.length} Photos',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Apartment Details section
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (expired && statusLower == 'rented') ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.red.shade300, width: 1),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.error_outline,
                                  color: Colors.red, size: 22),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Agreement Expired — Property is now marked as Available.',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('From', style: TextStyle(fontSize: 13, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today_outlined, size: 18, color: Colors.black87),
                                    const SizedBox(width: 6),
                                    Text(fromDateStr, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('To', style: TextStyle(fontSize: 13, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 18,
                                      color: (expired || isEndingThisMonth) ? Colors.red : Colors.black87,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      toDateStr,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: (expired || isEndingThisMonth) ? Colors.red : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Text(
                        '$currency $price',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D6338),
                        ),
                      ),
                      const SizedBox(height: 8),

                      Text(
                        'Service Charge: $currency $serviceCharge',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildChip(paymentType),
                          _buildChip(bhk),
                          _buildChip(type),
                          if (size.isNotEmpty) _buildChip(size),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          displayStatus,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: statusTextColor,
                          ),
                        ),
                      ),
                      
                      if (tenantName.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Divider(color: Color(0xFFE0E0E0), thickness: 1),
                        const SizedBox(height: 12),
                        Text(
                          'Tenant Name: $tenantName',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],

                      if (uploadedDocuments.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Text(
                          'Attached Documents',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: uploadedDocuments.length,
                          itemBuilder: (context, index) {
                            final doc = uploadedDocuments[index];
                            return _buildModernDocumentTile(
                              title: doc['title']!,
                              url: doc['url']!,
                            );
                          },
                        ),
                      ],

                      const SizedBox(height: 32),

                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AddApartmentScreen(
                                        apartmentId: widget.apartmentId,
                                        apartmentData: data,
                                      ),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFF0D6338),
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Edit Apartment',
                                  style: TextStyle(
                                    color: Color(0xFF0D6338),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: OutlinedButton(
                                onPressed: () => _deleteApartment(context, data),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFFD9534F),
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Delete Apartment',
                                  style: TextStyle(
                                    color: Color(0xFFD9534F),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernDocumentTile({
    required String title,
    required String url,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE2F0E7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              color: Color(0xFF0D6338),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => _documentHelper.viewDocumentInApp(context, url, title),
            icon: const Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF0D6338)),
            label: const Text(
              'View',
              style: TextStyle(fontSize: 12, color: Color(0xFF0D6338), fontWeight: FontWeight.bold),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => _documentHelper.downloadDocument(context, url, title),
            icon: const Icon(Icons.download_rounded, size: 20, color: Color(0xFF0D6338)),
            tooltip: 'Download',
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }
}