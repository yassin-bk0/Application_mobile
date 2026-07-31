import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Service to migrate installations from root collection to user subcollection.
class MigrateService {
  static Future<void> migrateInstallations() async {
    final firestore = FirebaseFirestore.instance;
    debugPrint('[MigrateService] Starting migration...');

    try {
      // 1. Get all documents from the root 'installations' collection
      final querySnapshot = await firestore.collection('installations').get();

      if (querySnapshot.docs.isEmpty) {
        debugPrint('[MigrateService] No installations found in root collection.');
        return;
      }

      int count = 0;
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        
        // The root collection documents used userId as the document ID typically
        // but we ensure we grab it from the data or doc id.
        final userId = data['userId'] as String? ?? doc.id;

        // 2. Write each to the new subcollection
        final userInstallationsRef = firestore
            .collection('users')
            .doc(userId)
            .collection('installations');
            
        // We can reuse the same doc.id or generate a new one. 
        // We'll reuse the doc.id for consistency in migration, 
        // or just add it via .doc() to be clean.
        await userInstallationsRef.doc(doc.id).set(data);

        // Optional: Ensure latitude and longitude are also copied to the root user doc
        // for backward compatibility with WeatherProvider if needed
        if (data.containsKey('latitude') && data.containsKey('longitude')) {
          await firestore.collection('users').doc(userId).set({
            'latitude': data['latitude'],
            'longitude': data['longitude'],
          }, SetOptions(merge: true));
        }

        count++;
      }

      debugPrint('[MigrateService] Migration complete! Migrated $count installations.');
      
      // Note: We deliberately DO NOT delete the old 'installations' collection automatically 
      // just in case we need to verify the migration first.
      // Once verified, you can manually delete them from the Firebase Console.
      
    } catch (e) {
      debugPrint('[MigrateService] Error during migration: $e');
    }
  }
}
