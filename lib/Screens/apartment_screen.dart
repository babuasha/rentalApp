import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rentalapp/Screens/add_apartment_screen.dart';
import 'package:rentalapp/Screens/detailed_apartment_screen.dart';

class ApartmentsScreen extends StatefulWidget {
  final String? countryId;
  final String? countryName;

  const ApartmentsScreen({
    super.key,
    this.countryId,
    this.countryName,
  });

  @override
  State<ApartmentsScreen> createState() => _ApartmentsScreenState();
}

class _ApartmentsScreenState extends State<ApartmentsScreen> {
  String _selectedFilter = 'All';

  // Helper method to parse Timestamp or String into DateTime
  DateTime? _parseDateTime(dynamic dateValue) {
    if (dateValue == null) return null;
    if (dateValue is Timestamp) return dateValue.toDate();
    if (dateValue is String) {
      try {
        return DateFormat('d- MMM- yy').parse(dateValue);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  // Checks if the date falls within the current month and year
  bool _isCurrentMonth(dynamic dateValue) {
    final DateTime? toDate = _parseDateTime(dateValue);
    if (toDate == null) return false;

    final DateTime now = DateTime.now();
    return toDate.month == now.month && toDate.year == now.year;
  }

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection('apartments');

    // Filter by country if countryId is provided
    if (widget.countryId != null && widget.countryId!.isNotEmpty) {
      query = query.where('countryId', isEqualTo: widget.countryId);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        // Title with total apartment count in parentheses
        title: StreamBuilder<QuerySnapshot>(
          stream: query.snapshots(),
          builder: (context, snapshot) {
            final totalCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
            final countryTitle = widget.countryName ?? 'Apartments';
            return Text(
              '$countryTitle ($totalCount)',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            );
          },
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF0D6338)),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Column(
              children: [
                _buildTabs(
                  allCount: 0, 
                  availableCount: 0, 
                  rentedCount: 0,
                  ownUseCount: 0,
                  underConstructionCount: 0,
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      'No apartments found',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                ),
              ],
            );
          }

          final allDocs = snapshot.data!.docs;

          // Calculate real-time counts for each filter tab
          int availableCount = 0;
          int rentedCount = 0;
          int ownUseCount = 0;
          int underConstructionCount = 0;

          for (var doc in allDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final statusRaw = (data['status'] ?? 'Available').toString();
            // Clean up string to safely check varying formats like "OwnUse" or "Own Use"
            final status = statusRaw.toLowerCase().replaceAll(' ', '');

            if (status == 'rented') {
              rentedCount++;
            } else if (status == 'ownuse') {
              ownUseCount++;
            } else if (status == 'underconstruction') {
              underConstructionCount++;
            } else {
              availableCount++;
            }
          }

          // Filter documents based on currently selected tab
          final displayedDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final statusRaw = (data['status'] ?? 'Available').toString();
            final status = statusRaw.toLowerCase().replaceAll(' ', '');

            if (_selectedFilter == 'Rented') return status == 'rented';
            if (_selectedFilter == 'Available') return status == 'available';
            if (_selectedFilter == 'Own Use') return status == 'ownuse';
            if (_selectedFilter == 'Under Construction') return status == 'underconstruction';
            return true;
          }).toList();

          return Column(
            children: [
              // Filter tabs across screen width showing total counts
              _buildTabs(
                allCount: allDocs.length,
                availableCount: availableCount,
                rentedCount: rentedCount,
                ownUseCount: ownUseCount,
                underConstructionCount: underConstructionCount,
              ),
              const SizedBox(height: 8),

              // Apartment Items List
              Expanded(
                child: displayedDocs.isEmpty
                    ? const Center(
                        child: Text(
                          'No apartments match the filter',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: displayedDocs.length,
                        itemBuilder: (context, index) {
                          final DocumentSnapshot doc = displayedDocs[index];
                          final data = doc.data() as Map<String, dynamic>;

                          final title = data['title'] ?? 'Apartment';
                          final bhk = data['bhk'] ?? '2BHK';
                          final type = data['type'] ?? 'Semi';
                          final size = data['size'] ?? ''; // Fetch apartment size
                          final price = data['price'] ?? 0;
                          final currency = data['currency'] ?? 'OMR';
                          
                          // Extract image URL from 'photos' array if available
                          String? firstImageUrl;
                          if (data['photos'] is List && (data['photos'] as List).isNotEmpty) {
                            firstImageUrl = (data['photos'] as List).first.toString();
                          }

                          // Determine status styling
                          final statusRaw = (data['status'] ?? 'Available').toString();
                          final statusLower = statusRaw.toLowerCase().replaceAll(' ', '');
                          
                          String displayStatus = 'Available';
                          Color statusBgColor = const Color(0xFFE2F0E7);
                          Color statusTextColor = const Color(0xFF0D6338);

                          if (statusLower == 'rented') {
                            displayStatus = 'Rented';
                            statusBgColor = const Color(0xFFFFECEB);
                            statusTextColor = const Color(0xFFD9534F);
                          } else if (statusLower == 'ownuse') {
                            displayStatus = 'Own Use';
                            statusBgColor = const Color(0xFFE3F2FD); // Light Blue
                            statusTextColor = const Color(0xFF1976D2); // Dark Blue
                          } else if (statusLower == 'underconstruction') {
                            displayStatus = 'Under Construction';
                            statusBgColor = const Color(0xFFFFF3E0); // Light Orange
                            statusTextColor = const Color(0xFFF57C00); // Dark Orange
                          }

                          // Check if 'toDate' falls in current month
                          final bool isEndingThisMonth = _isCurrentMonth(data['toDate']);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ApartmentDetailScreen(
                                      apartmentId: doc.id,
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  // Soft red background & border when expiring this month
                                  color: isEndingThisMonth
                                      ? const Color(0xFFFFF2F2)
                                      : const Color(0xFFF2F5F3),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isEndingThisMonth
                                        ? const Color(0xFFFFCDD2)
                                        : Colors.black.withOpacity(0.04),
                                    width: isEndingThisMonth ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Icon Box / Image Thumbnail
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: isEndingThisMonth
                                            ? const Color(0xFFFFEBEE)
                                            : Colors.black.withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: firstImageUrl != null && firstImageUrl.isNotEmpty
                                            ? Image.network(
                                                firstImageUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Icon(
                                                    Icons.apartment,
                                                    color: isEndingThisMonth ? Colors.red : Colors.black54,
                                                    size: 36,
                                                  );
                                                },
                                              )
                                            : Icon(
                                                Icons.apartment,
                                                color: isEndingThisMonth ? Colors.red : Colors.black54,
                                                size: 36,
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),

                                    // Apartment Information
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            size.isNotEmpty ? '$bhk • $type • $size' : '$bhk • $type',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF0D6338),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$currency $price',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF0D6338),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Status Badges & Arrow
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isEndingThisMonth) ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                margin: const EdgeInsets.only(right: 6),
                                                decoration: BoxDecoration(
                                                  color: Colors.red,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'Expiring',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: statusBgColor,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                displayStatus,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: statusTextColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        const Icon(
                                          Icons.chevron_right,
                                          color: Colors.black54,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),

      // Floating Action Button to Add New Apartment
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0D6338),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddApartmentScreen(
                initialCountryId: widget.countryId,
                initialCountryName: widget.countryName,
              ),
            ),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // Widget to build tab bars fitted across the screen with count labels
  Widget _buildTabs({
    required int allCount,
    required int availableCount,
    required int rentedCount,
    required int ownUseCount,
    required int underConstructionCount,
  }) {
    // Wrapped in a SingleChildScrollView so that adding more tabs 
    // doesn't cause a layout overflow on smaller screens.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          _buildFittedTab('All', allCount),
          const SizedBox(width: 8),
          _buildFittedTab('Available', availableCount),
          const SizedBox(width: 8),
          _buildFittedTab('Rented', rentedCount),
          const SizedBox(width: 8),
          _buildFittedTab('Own Use', ownUseCount),
          const SizedBox(width: 8),
          _buildFittedTab('Under Construction', underConstructionCount),
        ],
      ),
    );
  }

  Widget _buildFittedTab(String label, int count) {
    final bool isSelected = _selectedFilter == label;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D6338) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0D6338) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}