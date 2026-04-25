import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/garage_vehicle.dart';

class GarageService {
  static final GarageService _instance = GarageService._internal();
  factory GarageService() => _instance;
  GarageService._internal();

  CollectionReference _garageCollection(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('garage');

  Stream<List<GarageVehicle>> watchGarage(String uid) {
    return _garageCollection(uid)
        .orderBy('added_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GarageVehicle.fromFirestore(doc))
            .toList());
  }

  Future<List<GarageVehicle>> fetchAll(String uid) async {
    final snapshot = await _garageCollection(uid)
        .orderBy('added_at', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => GarageVehicle.fromFirestore(doc))
        .toList();
  }

  Future<void> deleteVehicle(String uid, String docId) async {
    await _garageCollection(uid).doc(docId).delete();
  }
}
