import 'package:flutter/material.dart';
import '../models/listing.dart';
import '../models/filter.dart';
import '../data/mock_data.dart';

class ListingProvider extends ChangeNotifier {
  final List<Listing> _allListings = List<Listing>.from(kMockListings);
  ListingFilter _filter = const ListingFilter();

  ListingFilter get filter => _filter;

  // HomeScreen ve SearchScreen için — kategori filtresi YOK, global filtreler uygulanır.
  List<Listing> get filteredListings => _applyGlobalFilters(_allListings);

  // CategoryScreen için — kategori yerel tutulur, global filtreler de uygulanır.
  List<Listing> filteredListingsInCategory(
      String categoryId, String? subcategoryId) {
    var base = _allListings.where((l) => l.categoryId == categoryId).toList();
    if (subcategoryId != null) {
      base = base.where((l) => l.subcategoryId == subcategoryId).toList();
    }
    return _applyGlobalFilters(base);
  }

  List<Listing> _applyGlobalFilters(List<Listing> source) {
    var result = List<Listing>.from(source);

    if (_filter.searchQuery?.isNotEmpty ?? false) {
      final q = _filter.searchQuery!.toLowerCase();
      result = result
          .where((l) =>
              l.title.toLowerCase().contains(q) ||
              l.description.toLowerCase().contains(q))
          .toList();
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

    switch (_filter.sortBy) {
      case 'oldest':
        result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case 'price_asc':
        result.sort((a, b) => a.price.compareTo(b.price));
      case 'price_desc':
        result.sort((a, b) => b.price.compareTo(a.price));
      default:
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return result;
  }

  List<Listing> get allListings => List.unmodifiable(_allListings);

  List<Listing> get featuredListings =>
      _allListings.where((l) => l.isFeatured).toList();

  void setListingStatus(String id, ListingStatus status) {
    final i = _allListings.indexWhere((l) => l.id == id);
    if (i == -1) return;
    final old = _allListings[i];
    _allListings[i] = Listing(
      id: old.id,
      title: old.title,
      description: old.description,
      price: old.price,
      currency: old.currency,
      categoryId: old.categoryId,
      subcategoryId: old.subcategoryId,
      location: old.location,
      district: old.district,
      imageUrls: old.imageUrls,
      createdAt: old.createdAt,
      status: status,
      type: old.type,
      attributes: old.attributes,
      isFeatured: old.isFeatured,
      viewCount: old.viewCount,
      sellerId: old.sellerId,
      sellerName: old.sellerName,
      sellerPhotoUrl: old.sellerPhotoUrl,
    );
    notifyListeners();
  }

  void toggleFeatured(String id) {
    final i = _allListings.indexWhere((l) => l.id == id);
    if (i == -1) return;
    final old = _allListings[i];
    _allListings[i] = Listing(
      id: old.id,
      title: old.title,
      description: old.description,
      price: old.price,
      currency: old.currency,
      categoryId: old.categoryId,
      subcategoryId: old.subcategoryId,
      location: old.location,
      district: old.district,
      imageUrls: old.imageUrls,
      createdAt: old.createdAt,
      status: old.status,
      type: old.type,
      attributes: old.attributes,
      isFeatured: !old.isFeatured,
      viewCount: old.viewCount,
      sellerId: old.sellerId,
      sellerName: old.sellerName,
      sellerPhotoUrl: old.sellerPhotoUrl,
    );
    notifyListeners();
  }

  void deleteListing(String id) {
    _allListings.removeWhere((l) => l.id == id);
    notifyListeners();
  }

  int countByCategory(String categoryId) =>
      _allListings.where((l) => l.categoryId == categoryId).length;

  int countBySubcategory(String subcategoryId) =>
      _allListings.where((l) => l.subcategoryId == subcategoryId).length;

  Listing? findById(String id) {
    try {
      return _allListings.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }

  void updateFilter(ListingFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  void resetFilter() {
    _filter = const ListingFilter();
    notifyListeners();
  }

  void setSearch(String query) {
    _filter = _filter.copyWith(searchQuery: query);
    notifyListeners();
  }

  void setSortBy(String sortBy) {
    _filter = _filter.copyWith(sortBy: sortBy);
    notifyListeners();
  }
}
