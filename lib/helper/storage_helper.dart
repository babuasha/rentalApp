import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageHelper {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads a photo file to Firebase Storage and returns its download URL
  Future<String> uploadPhoto(File file, String apartmentId, int index) async {
    final String fileName = 'photo_${index}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final Reference ref = _storage.ref().child('apartments/$apartmentId/photos/$fileName');
    final UploadTask uploadTask = ref.putFile(file);
    final TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  /// Uploads a document file to Firebase Storage and returns its download URL
  Future<String> uploadDocument(File file, String apartmentId, String docType) async {
    final String sanitizedDocType = docType.toLowerCase().replaceAll(' ', '_');
    final String fileName = '${sanitizedDocType}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final Reference ref = _storage.ref().child('apartments/$apartmentId/documents/$fileName');
    final UploadTask uploadTask = ref.putFile(
      file,
      SettableMetadata(contentType: 'application/pdf'),
    );
    final TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }
}