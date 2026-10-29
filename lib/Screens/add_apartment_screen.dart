import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rentalapp/helper/DocumentPickerHelper.dart';
import 'package:rentalapp/helper/ImagePickerHelper.dart';
import 'package:rentalapp/helper/storage_helper.dart';

class AddApartmentScreen extends StatefulWidget {
  final String? initialCountryId;
  final String? initialCountryName;
  final String? apartmentId;
  final Map<String, dynamic>? apartmentData;

  const AddApartmentScreen({
    super.key,
    this.initialCountryId,
    this.initialCountryName,
    this.apartmentId,
    this.apartmentData,
  });

  @override
  State<AddApartmentScreen> createState() => _AddApartmentScreenState();
}

class _AddApartmentScreenState extends State<AddApartmentScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _rentController = TextEditingController();
  final _serviceChargeController = TextEditingController();
  final _tenantNameController = TextEditingController();
  final _sizeController = TextEditingController();

  String? _selectedCountryId;
  String? _selectedCountryName;
  String _currency = 'OMR';
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _paymentType;
  String? _apartmentType;
  String? _furnished;
  String _status = 'Available';

  bool _isLoading = false;

  File? _photo1;
  File? _photo2;
  File? _photo3;
  File? _photo4;
  File? _photo5;

  final ImagePickerHelper _imagePickerHelper = ImagePickerHelper();
  final DocumentPickerHelper _documentPickerHelper = DocumentPickerHelper();
  final StorageHelper _storageHelper = StorageHelper();

  final List<String> _uploadedPhotos = [];
  final Map<String, String> _uploadedDocuments = {};

  bool get _isEditing => widget.apartmentId != null;

  final List<String> _paymentTypes = [
    'Monthly',
    'Quarterly',
    'Yearly',
    '2 Months',
    '3 Months',
    '4 Months',
    '5 Months',
    '6 Months'
  ];
  final List<String> _apartmentTypes = [
    '1BHK',
    '2BHK',
    '3BHK',
    'Studio',
    'Villa',
    'Shop',
    '1 Room',
    'Land'
  ];
  final List<String> _furnishedTypes = [
    'Fully Furnished',
    'Semi',
    'Unfurnished',
    'Fitout'
  ];

  final List<String> _documentTypes = [
    'Property Document',
    'Plan',
    'Tenancy Agreement',
    'Tenant ID',
    'Tenant Passport',
  ];

  final Map<String, String> _countryCurrencyMap = {
    'Oman': 'OMR',
    'United Arab Emirates': 'AED',
    'Saudi Arabia': 'SAR',
    'Qatar': 'QAR',
    'Bahrain': 'BHD',
    'Kuwait': 'KWD',
    'India': 'INR',
    'United States': 'USD',
    'United Kingdom': 'GBP',
    'Germany': 'EUR',
    'France': 'EUR',
    'Canada': 'CAD',
    'Australia': 'AUD',
    'Japan': 'JPY',
    'China': 'CNY',
    'Thailand': 'THB',
    'Turkey': 'TRY',
    'St. Kitts': 'XCD',
    'Lebanon': 'LBP',
  };

  Future<void> _pickPhoto(int photoIndex) async {
    final File? pickedImage =
        await _imagePickerHelper.pickImageFromGallery(context);
    if (pickedImage != null) {
      setState(() {
        if (_uploadedPhotos.length >= photoIndex) {
          _uploadedPhotos[photoIndex - 1] = '';
        }

        if (photoIndex == 1) {
          _photo1 = pickedImage;
        } else if (photoIndex == 2) {
          _photo2 = pickedImage;
        } else if (photoIndex == 3) {
          _photo3 = pickedImage;
        } else if (photoIndex == 4) {
          _photo4 = pickedImage;
        } else if (photoIndex == 5) {
          _photo5 = pickedImage;
        }
      });
    }
  }

  Future<void> _pickDocument(String docTitle) async {
    final File? pickedDoc = await _documentPickerHelper.pickPdfDocument(context);
    if (pickedDoc != null) {
      setState(() {
        _uploadedDocuments[docTitle] = pickedDoc.path;
      });
    }
  }

  void _removePhoto(int photoIndex) {
    setState(() {
      if (photoIndex == 1) {
        _photo1 = null;
      } else if (photoIndex == 2) {
        _photo2 = null;
      } else if (photoIndex == 3) {
        _photo3 = null;
      } else if (photoIndex == 4) {
        _photo4 = null;
      } else if (photoIndex == 5) {
        _photo5 = null;
      }

      if (_uploadedPhotos.length >= photoIndex) {
        _uploadedPhotos[photoIndex - 1] = '';
      }
    });
  }

  // Confirmation dialog when long-pressing a photo icon
  void _confirmDeletePhoto(int photoIndex) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Photo'),
          content: const Text('Do you want to delete this photo?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _removePhoto(photoIndex);
              },
              child: const Text('Yes', style: TextStyle(color: Color(0xFF0D6338))),
            ),
          ],
        );
      },
    );
  }

  String _getCurrencyCode(String? countryName, Map<String, dynamic>? countryData) {
    if (countryData != null && countryData['currency'] != null) {
      return countryData['currency'].toString();
    }
    if (countryName != null) {
      for (var entry in _countryCurrencyMap.entries) {
        if (entry.key.toLowerCase() == countryName.toLowerCase()) {
          return entry.value;
        }
      }
    }
    return 'OMR';
  }

  String get _currencyDisplaySymbol {
    try {
      final format = NumberFormat.simpleCurrency(name: _currency);
      return format.currencySymbol.isNotEmpty ? format.currencySymbol : _currency;
    } catch (_) {
      return _currency;
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedCountryId = widget.initialCountryId;
    _selectedCountryName = widget.initialCountryName;

    if (_isEditing && widget.apartmentData != null) {
      final data = widget.apartmentData!;
      _nameController.text = data['title'] ?? '';
      _rentController.text = (data['price'] ?? '').toString();
      _serviceChargeController.text = (data['serviceCharge'] ?? '').toString();
      _tenantNameController.text = data['tenantName'] ?? '';
      _sizeController.text = data['size'] ?? '';
      _selectedCountryId = data['countryId'] ?? widget.initialCountryId;
      _selectedCountryName = data['countryName'] ?? widget.initialCountryName;
      
      final derivedCurrency = _getCurrencyCode(_selectedCountryName, null);
      if (derivedCurrency != 'OMR') {
        _currency = derivedCurrency;
      } else {
        final savedCurrency = data['currency']?.toString();
        _currency = (savedCurrency != null && savedCurrency.isNotEmpty) ? savedCurrency : 'OMR';
      }

      _paymentType = data['paymentType'];
      _apartmentType = data['bhk'];
      _furnished = data['type'];
      _status = data['status'] ?? 'Available';

      if (data['fromDate'] is Timestamp) {
        _fromDate = (data['fromDate'] as Timestamp).toDate();
      }
      if (data['toDate'] is Timestamp) {
        _toDate = (data['toDate'] as Timestamp).toDate();
      }

      if (data['photos'] is List) {
        _uploadedPhotos.addAll(List<String>.from(data['photos']));
      }
      if (data['documents'] is Map) {
        _uploadedDocuments.addAll(Map<String, String>.from(data['documents']));
      }
    } else {
      _currency = _getCurrencyCode(_selectedCountryName, null);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rentController.dispose();
    _serviceChargeController.dispose();
    _tenantNameController.dispose();
    _sizeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: (isFromDate ? _fromDate : _toDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF0D6338)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  Future<void> _saveOrUpdateApartment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCountryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a country')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final docRef = _isEditing
          ? FirebaseFirestore.instance.collection('apartments').doc(widget.apartmentId)
          : FirebaseFirestore.instance.collection('apartments').doc();

      final String targetId = docRef.id;

      final List<String> finalPhotoUrls = [];
      
      if (_photo1 != null) {
        final url1 = await _storageHelper.uploadPhoto(_photo1!, targetId, 1);
        finalPhotoUrls.add(url1);
      } else if (_uploadedPhotos.length >= 1 && _uploadedPhotos[0].isNotEmpty) {
        finalPhotoUrls.add(_uploadedPhotos[0]);
      }

      if (_photo2 != null) {
        final url2 = await _storageHelper.uploadPhoto(_photo2!, targetId, 2);
        finalPhotoUrls.add(url2);
      } else if (_uploadedPhotos.length >= 2 && _uploadedPhotos[1].isNotEmpty) {
        finalPhotoUrls.add(_uploadedPhotos[1]);
      }

      if (_photo3 != null) {
        final url3 = await _storageHelper.uploadPhoto(_photo3!, targetId, 3);
        finalPhotoUrls.add(url3);
      } else if (_uploadedPhotos.length >= 3 && _uploadedPhotos[2].isNotEmpty) {
        finalPhotoUrls.add(_uploadedPhotos[2]);
      }

      if (_photo4 != null) {
        final url4 = await _storageHelper.uploadPhoto(_photo4!, targetId, 4);
        finalPhotoUrls.add(url4);
      } else if (_uploadedPhotos.length >= 4 && _uploadedPhotos[3].isNotEmpty) {
        finalPhotoUrls.add(_uploadedPhotos[3]);
      }

      if (_photo5 != null) {
        final url5 = await _storageHelper.uploadPhoto(_photo5!, targetId, 5);
        finalPhotoUrls.add(url5);
      } else if (_uploadedPhotos.length >= 5 && _uploadedPhotos[4].isNotEmpty) {
        finalPhotoUrls.add(_uploadedPhotos[4]);
      }

      final Map<String, String> finalDocumentUrls = {};
      for (final entry in _uploadedDocuments.entries) {
        if (entry.value.startsWith('http://') || entry.value.startsWith('https://')) {
          finalDocumentUrls[entry.key] = entry.value;
        } else {
          final file = File(entry.value);
          if (await file.exists()) {
            final url = await _storageHelper.uploadDocument(file, targetId, entry.key);
            finalDocumentUrls[entry.key] = url;
          }
        }
      }

      final payload = {
        'countryId': _selectedCountryId,
        'countryName': _selectedCountryName,
        'title': _nameController.text.trim(),
        'size': _sizeController.text.trim(),
        'fromDate': _fromDate != null ? Timestamp.fromDate(_fromDate!) : null,
        'toDate': _toDate != null ? Timestamp.fromDate(_toDate!) : null,
        'paymentType': _paymentType,
        'bhk': _apartmentType,
        'type': _furnished,
        'price': double.tryParse(_rentController.text.trim()) ?? 0,
        'serviceCharge': double.tryParse(_serviceChargeController.text.trim()) ?? 0,
        'currency': _currency,
        'status': _status,
        'tenantName': _tenantNameController.text.trim(),
        'photos': finalPhotoUrls,
        'documents': finalDocumentUrls,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_isEditing) {
        await docRef.update(payload);
      } else {
        payload['createdAt'] = FieldValue.serverTimestamp();
        await docRef.set(payload);

        await FirebaseFirestore.instance
            .collection('countries')
            .doc(_selectedCountryId)
            .update({'apartmentCount': FieldValue.increment(1)});
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving apartment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Edit Apartment' : 'Add Apartment',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF0D6338),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Country'),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('countries').snapshots(),
                      builder: (context, snapshot) {
                        List<DropdownMenuItem<String>> items = [];
                        if (snapshot.hasData) {
                          items = snapshot.data!.docs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return DropdownMenuItem<String>(
                              value: doc.id,
                              child: Text(data['countryName'] ?? ''),
                            );
                          }).toList();
                        }

                        final bool valueExists = items.any((item) => item.value == _selectedCountryId);

                        return DropdownButtonFormField<String>(
                          value: valueExists ? _selectedCountryId : null,
                          hint: const Text('Select Country'),
                          decoration: _inputDecoration(),
                          items: items,
                          onChanged: (val) {
                            setState(() {
                              _selectedCountryId = val;
                              final doc = snapshot.data?.docs.firstWhere((d) => d.id == val);
                              if (doc != null) {
                                final countryData = doc.data() as Map<String, dynamic>;
                                _selectedCountryName = countryData['countryName'];
                                _currency = _getCurrencyCode(_selectedCountryName, countryData);
                              }
                            });
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Apartment Name'),
                    TextFormField(
                      controller: _nameController,
                      decoration: _inputDecoration(hintText: 'Enter apartment name'),
                      validator: (val) => val == null || val.isEmpty ? 'Field required' : null,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('From Date'),
                              InkWell(
                                onTap: () => _selectDate(context, true),
                                child: Container(
                                  height: 52,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: _boxDecoration(),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _fromDate == null
                                            ? 'Date Picker'
                                            : dateFormat.format(_fromDate!),
                                        style: TextStyle(
                                          color: _fromDate == null
                                              ? Colors.grey.shade600
                                              : Colors.black,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('To Date'),
                              InkWell(
                                onTap: () => _selectDate(context, false),
                                child: Container(
                                  height: 52,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: _boxDecoration(),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _toDate == null
                                            ? 'Date Picker'
                                            : dateFormat.format(_toDate!),
                                        style: TextStyle(
                                          color: _toDate == null
                                              ? Colors.grey.shade600
                                              : Colors.black,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Payment Type'),
                    DropdownButtonFormField<String>(
                      value: _paymentTypes.contains(_paymentType) ? _paymentType : null,
                      hint: const Text('Select Payment Type'),
                      decoration: _inputDecoration(),
                      items: _paymentTypes
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) => setState(() => _paymentType = val),
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Apartment Type'),
                    DropdownButtonFormField<String>(
                      value: _apartmentTypes.contains(_apartmentType) ? _apartmentType : null,
                      hint: const Text('Select Apartment Type'),
                      decoration: _inputDecoration(),
                      items: _apartmentTypes
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) => setState(() => _apartmentType = val),
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Apartment Size'),
                    TextFormField(
                      controller: _sizeController,
                      decoration: _inputDecoration(hintText: 'Enter apartment size (e.g., 1200 sqft)'),
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Furnished'),
                    DropdownButtonFormField<String>(
                      value: _furnishedTypes.contains(_furnished) ? _furnished : null,
                      hint: const Text('Select Furnished Status'),
                      decoration: _inputDecoration(),
                      items: _furnishedTypes
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) => setState(() => _furnished = val),
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Rent ($_currencyDisplaySymbol)'),
                    TextFormField(
                      controller: _rentController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(hintText: 'Enter rent'),
                      validator: (val) => val == null || val.isEmpty ? 'Field required' : null,
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Service Charge ($_currencyDisplaySymbol)'),
                    TextFormField(
                      controller: _serviceChargeController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(hintText: 'Enter service charge'),
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Status'),
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildStatusButton('Available', const Color(0xFF0D6338))),
                            const SizedBox(width: 8),
                            Expanded(child: _buildStatusButton('Rented', const Color(0xFFD9534F))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _buildStatusButton('OwnUse', Colors.blue.shade700)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildStatusButton('Under Construction', Colors.orange.shade800)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _buildLabel('Tenant Details:'),
                    TextFormField(
                      controller: _tenantNameController,
                      decoration: _inputDecoration(hintText: 'Enter Tenant Name'),
                    ),
                    const SizedBox(height: 20),

                    _buildLabel('Upload Photos :-'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildPhotoBox(1, _photo1),
                        _buildPhotoBox(2, _photo2),
                        _buildPhotoBox(3, _photo3),
                        _buildPhotoBox(4, _photo4),
                        _buildPhotoBox(5, _photo5),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Column(
                      children: _documentTypes
                          .map((docType) => _buildDocumentRow(docType))
                          .toList(),
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saveOrUpdateApartment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D6338),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _isEditing ? 'Update Apartment' : 'Save Apartment',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatusButton(String statusValue, Color activeColor) {
    final bool isSelected = _status == statusValue;
    return GestureDetector(
      onTap: () => setState(() => _status = statusValue),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? activeColor : const Color(0xFFEFEFEF),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          statusValue,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoBox(int photoIndex, File? imageFile) {
    String? existingUrl;
    if (imageFile == null && _uploadedPhotos.length >= photoIndex) {
      final url = _uploadedPhotos[photoIndex - 1];
      if (url.isNotEmpty) {
        existingUrl = url;
      }
    }

    final bool hasImage = imageFile != null || existingUrl != null;

    return GestureDetector(
      onTap: () => _pickPhoto(photoIndex),
      onLongPress: hasImage ? () => _confirmDeletePhoto(photoIndex) : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade400),
              image: imageFile != null
                  ? DecorationImage(
                      image: FileImage(imageFile),
                      fit: BoxFit.cover,
                    )
                  : (existingUrl != null
                      ? DecorationImage(
                          image: NetworkImage(existingUrl),
                          fit: BoxFit.cover,
                        )
                      : null),
            ),
            child: !hasImage
                ? Icon(
                    Icons.add_a_photo_outlined,
                    color: Colors.grey.shade600,
                    size: 22,
                  )
                : null,
          ),
          if (hasImage)
            Positioned(
              top: -6,
              right: -6,
              child: GestureDetector(
                onTap: () => _removePhoto(photoIndex),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentRow(String title) {
    final bool isUploaded = _uploadedDocuments.containsKey(title);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$title :-',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          OutlinedButton(
            onPressed: () => _pickDocument(title),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade500),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              isUploaded ? 'Uploaded' : 'Upload',
              style: TextStyle(
                color: isUploaded ? const Color(0xFF0D6338) : Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 32,
            height: 32,
            child: isUploaded
                ? const Icon(
                    Icons.insert_drive_file,
                    color: Color(0xFF0D6338),
                    size: 32,
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade400),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade400),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF0D6338), width: 1.5),
      ),
    );
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey.shade400),
    );
  }
}