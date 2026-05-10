import 'listing.dart';

class ListingFilter {
  final String? categoryId;
  final String? subcategoryId;
  final double? minPrice;
  final double? maxPrice;
  final String? location;
  final String? searchQuery;
  final ListingType? type;
  final String? sortBy;
  final Map<String, String> attributes;

  const ListingFilter({
    this.categoryId,
    this.subcategoryId,
    this.minPrice,
    this.maxPrice,
    this.location,
    this.searchQuery,
    this.type,
    this.sortBy = 'newest',
    this.attributes = const {},
  });

  ListingFilter copyWith({
    String? categoryId,
    String? subcategoryId,
    double? minPrice,
    double? maxPrice,
    String? location,
    String? searchQuery,
    ListingType? type,
    String? sortBy,
    Map<String, String>? attributes,
    bool clearCategory = false,
    bool clearSubcategory = false,
    bool clearPrice = false,
    bool clearLocation = false,
    bool clearType = false,
  }) {
    return ListingFilter(
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      subcategoryId: clearSubcategory ? null : (subcategoryId ?? this.subcategoryId),
      minPrice: clearPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearPrice ? null : (maxPrice ?? this.maxPrice),
      location: clearLocation ? null : (location ?? this.location),
      searchQuery: searchQuery ?? this.searchQuery,
      type: clearType ? null : (type ?? this.type),
      sortBy: sortBy ?? this.sortBy,
      attributes: attributes ?? this.attributes,
    );
  }

  bool get hasActiveFilters =>
      categoryId != null ||
      subcategoryId != null ||
      minPrice != null ||
      maxPrice != null ||
      location != null ||
      (searchQuery?.isNotEmpty ?? false) ||
      type != null;

  int get activeFilterCount {
    int count = 0;
    if (categoryId != null) count++;
    if (minPrice != null || maxPrice != null) count++;
    if (location != null) count++;
    if (type != null) count++;
    return count;
  }
}

const List<String> kSortOptions = [
  'newest',
  'oldest',
  'price_asc',
  'price_desc',
];

const Map<String, String> kSortLabels = {
  'newest': 'En Yeni',
  'oldest': 'En Eski',
  'price_asc': 'Fiyat (Artan)',
  'price_desc': 'Fiyat (Azalan)',
};
