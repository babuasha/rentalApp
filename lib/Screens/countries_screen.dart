import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentalapp/Screens/addcountry_screen.dart';
import 'package:rentalapp/Screens/apartment_screen.dart';


class CountriesScreen extends StatelessWidget {
  const CountriesScreen({super.key});

  String _getFlagEmoji(String countryCode) {
    if (countryCode.length != 2) return '🌐';
    int firstLetter = countryCode.toUpperCase().codeUnitAt(0) - 0x41 + 0x1F1E6;
    int secondLetter = countryCode.toUpperCase().codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Countries',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 10.0, bottom: 10.0),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddCountryScreen()),
                );
              },
              icon: const Icon(Icons.add, size: 18, color: Colors.white),
              label: const Text(
                'Add Country',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D6338),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('countries')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF0D6338)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading countries: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No countries added yet.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          final countries = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            itemCount: countries.length,
            itemBuilder: (context, index) {
              final doc = countries[index];
              final data = doc.data() as Map<String, dynamic>;
              
              final countryId = doc.id;
              final name = data['countryName'] ?? '';
              final code = data['countryCode'] ?? '';
              final savedFlag = data['flagEmoji'];
              final apartmentCount = data['apartmentCount'] ?? 0;

              final flagEmoji = (savedFlag != null && savedFlag.toString().isNotEmpty)
                  ? savedFlag.toString()
                  : _getFlagEmoji(code);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: const Color(0xFFF2F5F3),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      // Navigate to details/apartments screen for the tapped country
                 Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ApartmentsScreen(
                            countryId: countryId,
                            countryName: name,
                          ),
                        ),
                      ); 

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Selected $name ($code)')),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black.withOpacity(0.04)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            flagEmoji,
                            style: const TextStyle(fontSize: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$apartmentCount ${apartmentCount == 1 ? 'Apartment' : 'Apartments'}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.black54,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}