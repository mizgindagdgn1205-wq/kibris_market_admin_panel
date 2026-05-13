import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../models/listing.dart';
import '../models/filter.dart';

class ListingProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;

  List<Listing> _allListings = [];
  ListingFilter _filter = const ListingFilter();
  bool _loading = true;
  String? _error;

  StreamSubscription<QuerySnapshot>? _sub;

  ListingProvider() {
    _subscribe();
  }

  bool get loading => _loading;
  String? get error => _error;
  ListingFilter get filter => _filter;

  void _subscribe() {
    _sub?.cancel();
    _sub = _db
        .collection('listings')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
      (snap) {
        _allListings = snap.docs.map((d) => Listing.fromFirestore(d)).toList();
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _loading = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  List<Listing> get allListings => List.unmodifiable(_allListings);

  List<Listing> get filteredListings {
    var result = List<Listing>.from(_allListings);
    if (_filter.searchQuery?.isNotEmpty ?? false) {
      final q = _filter.searchQuery!.toLowerCase();
      result = result.where((l) =>
          l.title.toLowerCase().contains(q) ||
          l.description.toLowerCase().contains(q)).toList();
    }
    if (_filter.minPrice != null) {
      result = result.where((l) => l.price >= _filter.minPrice!).toList();
    }
    if (_filter.maxPrice != null) {
      result = result.where((l) => l.price <= _filter.maxPrice!).toList();
    }
    if (_filter.location != null) {
      result = result.where((l) => l.location == _filter.location).toList();
    }
    if (_filter.type != null) {
      result = result.where((l) => l.type == _filter.type).toList();
    }
    return result;
  }

  List<Listing> filteredListingsInCategory(String categoryId, String? subcategoryId) {
    var base = _allListings.where((l) => l.categoryId == categoryId).toList();
    if (subcategoryId != null) {
      base = base.where((l) => l.subcategoryId == subcategoryId).toList();
    }
    return base;
  }

  Future<void> setListingStatus(String id, ListingStatus status) async {
    final statusStr = switch (status) {
      ListingStatus.active  => 'active',
      ListingStatus.pending => 'pending',
      ListingStatus.sold    => 'sold',
      ListingStatus.expired => 'expired',
    };

    final listing = _allListings.firstWhere((l) => l.id == id);
    await _db.collection('listings').doc(id).update({'status': statusStr});

    // Onay / red durumunda kullanıcıya bildirim yaz
    if (status == ListingStatus.active || status == ListingStatus.expired) {
      final isApproved = status == ListingStatus.active;
      final notifRef = _db
          .collection('users')
          .doc(listing.sellerId)
          .collection('notifications')
          .doc();
      await notifRef.set({
        'id':        notifRef.id,
        'title':     isApproved ? 'İlanınız Onaylandı' : 'İlanınız Reddedildi',
        'body':      isApproved
            ? '"${listing.title}" başlıklı ilanınız yayına alındı.'
            : '"${listing.title}" başlıklı ilanınız admin tarafından reddedildi.',
        'type':      isApproved ? 'listing_approved' : 'listing_rejected',
        'listingId': listing.id,
        'isRead':    false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> toggleFeatured(String id) async {
    final listing = _allListings.firstWhere((l) => l.id == id);
    await _db.collection('listings').doc(id).update({'isFeatured': !listing.isFeatured});
  }

  Future<void> deleteListing(String id) async {
    // Storage klasörünü temizle (listings/{id}/*)
    try {
      final storageRef = FirebaseStorage.instance.ref('listings/$id');
      final list = await storageRef.listAll();
      await Future.wait(list.items.map((item) => item.delete()));
    } catch (_) {
      // Resim yoksa veya erişim hatası — devam et
    }
    await _db.collection('listings').doc(id).delete();
  }

  void updateFilter(ListingFilter f) {
    _filter = f;
    notifyListeners();
  }

  void resetFilter() {
    _filter = const ListingFilter();
    notifyListeners();
  }
}
