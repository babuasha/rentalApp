import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';

class AddCountryScreen extends StatefulWidget {
  const AddCountryScreen({super.key});

  @override
  State<AddCountryScreen> createState() => _AddCountryScreenState();
}

class _AddCountryScreenState extends State<AddCountryScreen> {
  final TextEditingController _countryNameController = TextEditingController();
  final TextEditingController _countryCodeController = TextEditingController();

  String _flagEmoji = '🇴🇲'; // Default initial flag
  bool _isLoading = false;

  Future<void> _saveCountry() async {
    if (_countryNameController.text.isEmpty || _countryCodeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a country first')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('countries').add({
        'countryName': _countryNameController.text.trim(),
        'countryCode': _countryCodeController.text.trim(),
        'flagEmoji': _flagEmoji,
        'apartmentCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Country added successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add country: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: false, // Hides phone country code (e.g., +968)
      onSelect: (Country country) {
        setState(() {
          _countryNameController.text = country.name;
          _countryCodeController.text = country.countryCode; // 2-letter ISO code
          _flagEmoji = country.flagEmoji;
        });
      },
      countryListTheme: CountryListThemeData(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        inputDecoration: InputDecoration(
          labelText: 'Search',
          hintText: 'Start typing to search',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _countryNameController.dispose();
    _countryCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add Country',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),

              // Dynamic Flag Display
              Text(
                _flagEmoji,
                style: const TextStyle(fontSize: 64),
              ),
              const SizedBox(height: 24),

              // Country Name Field (Triggers Country Picker)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Country Name',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _countryNameController,
                readOnly: true,
                onTap: _openCountryPicker,
                decoration: InputDecoration(
                  hintText: 'Select Country',
                  suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Country Code Field (Auto-filled & Read-only)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Country Code',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _countryCodeController,
                readOnly: true,
                decoration: InputDecoration(
                  hintText: 'e.g. US',
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                ),
              ),

              const Spacer(),

              // Save Country Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveCountry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D6338),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Save Country',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}