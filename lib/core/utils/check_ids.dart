import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  // Este script es para verificar los IDs de mercados y municipalidades actuales en Firestore.
  final db = FirebaseFirestore.instance;
  
  print('--- Municipalidades ---');
  final munSnap = await db.collection('municipalidades').get();
  for (var doc in munSnap.docs) {
    print('ID: ${doc.id}, Data: ${doc.data()}');
  }

  print('\n--- Mercados ---');
  final merSnap = await db.collection('mercados').get();
  for (var doc in merSnap.docs) {
    print('ID: ${doc.id}, Data: ${doc.data()}');
  }
}
