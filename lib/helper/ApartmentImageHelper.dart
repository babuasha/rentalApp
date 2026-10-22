import 'package:flutter/material.dart';

class ApartmentImageHelper {
  /// Extracts the list of photo URLs from Firestore data.
  /// Falls back to legacy single image keys if the list is empty.
  List<String> getPhotoUrls(Map<String, dynamic> data) {
    List<String> photoUrls = [];
    if (data['photos'] is List) {
      photoUrls = List<String>.from(
        data['photos'].where((p) => p != null && p.toString().isNotEmpty),
      );
    }
    if (photoUrls.isEmpty) {
      final singleImg = (data['imageUrl'] ?? data['image'] ?? '').toString();
      if (singleImg.isNotEmpty) {
        photoUrls.add(singleImg);
      }
    }
    return photoUrls;
  }

  /// Builds the local asset or web fallback image widget.
  Widget buildFallbackImage(String defaultWebUrl) {
    return Image.asset(
      'assets/apartment.jpg',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Image.network(
        defaultWebUrl,
        fit: BoxFit.cover,
      ),
    );
  }
}