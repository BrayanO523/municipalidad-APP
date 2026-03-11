import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

void main() async {
  // Este script es para verificar los IDs de mercados y municipalidades actuales en Firestore.
  final db = FirebaseFirestore.instance;
  
  debugPrint('--- Municipalidades ---');
  final munSnap = await db.collection('municipalidades').get();
  for (var doc in munSnap.docs) {
    debugPrint('ID: ${doc.id}, Data: ${doc.data()}');
  }

  debugPrint('\n--- Mercados ---');
  final merSnap = await db.collection('mercados').get();
  for (var doc in merSnap.docs) {
    debugPrint('ID: ${doc.id}, Data: ${doc.data()}');
  }
}
