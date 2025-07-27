import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/delivery_address.dart';

class AddressService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'addresses';

  // Create delivery address
  static Future<String> createAddress(DeliveryAddress address) async {
    try {
      final docRef = await _firestore.collection(_collection).add(address.toMap());
      
      // Update the document with its own ID
      await docRef.update({'id': docRef.id});
      
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create address: $e');
    }
  }

  // Get user addresses
  static Future<List<DeliveryAddress>> getUserAddresses(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('isDefault', descending: true)
          .orderBy('createdAt', descending: false)
          .get();

      return querySnapshot.docs
          .map((doc) => DeliveryAddress.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get user addresses: $e');
    }
  }

  // Get single address
  static Future<DeliveryAddress?> getAddress(String addressId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(addressId).get();
      if (doc.exists && doc.data() != null) {
        return DeliveryAddress.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get address: $e');
    }
  }

  // Update address
  static Future<void> updateAddress(DeliveryAddress address) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(address.id)
          .update(address.copyWith(updatedAt: DateTime.now()).toMap());
    } catch (e) {
      throw Exception('Failed to update address: $e');
    }
  }

  // Delete address
  static Future<void> deleteAddress(String addressId) async {
    try {
      await _firestore.collection(_collection).doc(addressId).delete();
    } catch (e) {
      throw Exception('Failed to delete address: $e');
    }
  }

  // Set default address
  static Future<void> setDefaultAddress(String userId, String addressId) async {
    try {
      final batch = _firestore.batch();

      // Remove default flag from all user addresses
      final userAddresses = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in userAddresses.docs) {
        batch.update(doc.reference, {
          'isDefault': false,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }

      // Set the specified address as default
      final addressRef = _firestore.collection(_collection).doc(addressId);
      batch.update(addressRef, {
        'isDefault': true,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to set default address: $e');
    }
  }

  // Get default address
  static Future<DeliveryAddress?> getDefaultAddress(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('isDefault', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return DeliveryAddress.fromMap(querySnapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get default address: $e');
    }
  }

  // Stream user addresses
  static Stream<List<DeliveryAddress>> streamUserAddresses(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('isDefault', descending: true)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DeliveryAddress.fromMap(doc.data()))
            .toList());
  }
}
