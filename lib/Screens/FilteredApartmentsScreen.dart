import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentalapp/Screens/detailed_apartment_screen.dart';

class FilteredApartmentsScreen extends StatelessWidget {
  final String filterType; // 'all', 'rented', 'available', 'ownuse', 'under construction'
  final String headingTitle;

  const FilteredApartmentsScreen({
    super.key,
    required this.filterType,
    required this.headingTitle,
  });

  Color _getStatusColor(String status) {
    final s = status.toLowerCase().replaceAll(' ', '');
    if (s.contains('rent')) return Colors.red;
    if (s.contains('avail')) return const Color(0xFF0D6338);
    if (s.contains('own')) return Colors.blue;
    return Colors.orange;
  }

  // Helper method to safely extract the first image URL from Firestore 'photos' array
  String _getFirstImageUrl(Map<String, dynamic> data) {
    // Check 'photos' array first as per your database structure
    for (var key in ['photos', 'photoUrls', 'imageUrls']) {
      if (data[key] is List && (data[key] as List).isNotEmpty) {
        final firstItem = data[key][0];
        if (firstItem != null && firstItem.toString().trim().isNotEmpty) {
          return firstItem.toString().trim();
        }
      }
    }

    // Check single string fields next as fallback
    for (var key in ['imageUrl', 'image', 'photoUrl']) {
      if (data[key] != null && data[key].toString().trim().isNotEmpty) {
        return data[key].toString().trim();
      }
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: StreamBuilder<QuerySnapshot>(
        // Queries all apartments globally without country limitations
        stream: FirebaseFirestore.instance.collection('apartments').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: const Color(0xFFFAFAFA),
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  headingTitle,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              body: const Center(
                child: CircularProgressIndicator(color: Color(0xFF0D6338)),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Scaffold(
              backgroundColor: const Color(0xFFFAFAFA),
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  '$headingTitle (0)',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              body: const Center(
                child: Text('No apartments found.'),
              ),
            );
          }

          final allDocs = snapshot.data!.docs;

          // Dynamically filter documents based on the category clicked
          final filteredDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = (data['status'] ?? 'Available').toString().toLowerCase().replaceAll(' ', '');

            if (filterType == 'all') return true;
            if (filterType == 'rented') return status == 'rented';
            if (filterType == 'available') return status == 'available';
            if (filterType == 'ownuse') return status == 'ownuse';
            if (filterType == 'under construction') return status.contains('construction');

            return true;
          }).toList();

          return Scaffold(
            backgroundColor: const Color(0xFFFAFAFA),
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                '$headingTitle (${filteredDocs.length})',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            body: filteredDocs.isEmpty
                ? const Center(
                    child: Text('No apartments match this category.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      final String title = data['title'] ?? 'Apartment Name';
                      
                      // Apartment Type maps to 'bhk' field (e.g., "Shop")
                      final String apartmentType = data['bhk'] ?? '';
                      
                      // Furnished status maps to 'type' field (e.g., "Fitout")
                      final String furnishing = data['type'] ?? '';

                      // Size maps to 'size' field, removing 'sqft' if present
                      final dynamic sizeRaw = data['size'] ?? '';
                      final String rawSizeStr = sizeRaw.toString().trim();
                      final String size = rawSizeStr.isNotEmpty
                          ? rawSizeStr.replaceAll(RegExp(r'\s*sqft\b', caseSensitive: false), '').trim()
                          : '';

                      final dynamic price = data['price'] ?? 0;
                      final String currency = data['currency'] ?? 'OMR';
                      final String status = data['status'] ?? 'Available';
                      
                      // Retrieve the first image URL securely from the photos array
                      final String imageUrl = _getFirstImageUrl(data);

                      // Combine details into a clean subtitle list
                      final List<String> detailsList = [];
                      if (apartmentType.isNotEmpty) detailsList.add(apartmentType);
                      if (furnishing.isNotEmpty) detailsList.add(furnishing);
                      if (size.isNotEmpty) detailsList.add(size);
                      final String subtitleText = detailsList.join(' • ');

                      return GestureDetector(
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
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12.0),
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withAlpha(20),
                                blurRadius: 6,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: imageUrl.isNotEmpty
                                    ? Image.network(
                                        imageUrl,
                                        width: 75,
                                        height: 75,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            _buildPlaceholderImage(),
                                      )
                                    : _buildPlaceholderImage(),
                              ),
                              const SizedBox(width: 14),
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
                                      subtitleText.isNotEmpty ? subtitleText : 'No additional details',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$currency $price',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0D6338),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _getStatusColor(status),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Icon(Icons.chevron_right, color: Colors.grey),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 75,
      height: 75,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.apartment, color: Colors.grey, size: 30),
    );
  }  
}