import 'package:cloud_firestore/cloud_firestore.dart';

enum ListingStatus { active, pending, sold, expired }
enum ListingType { sell, rent, wanted }

class Listing {
  final String id;
  final String title;
  final String description;
  final double price;
  final String currency;
  final String categoryId;
  final String subcategoryId;
  final String location;
  final String district;
  final List<String> imageUrls;
  final DateTime createdAt;
  final ListingStatus status;
  final ListingType type;
  final Map<String, String> attributes;
  final bool isFeatured;
  final int viewCount;
  final String sellerId;
  final String? sellerName;
  final String? sellerPhotoUrl;

  const Listing({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    this.currency = '£',
    required this.categoryId,
    required this.subcategoryId,
    required this.location,
    required this.district,
    this.imageUrls = const [],
    required this.createdAt,
    this.status = ListingStatus.active,
    this.type = ListingType.sell,
    this.attributes = const {},
    this.isFeatured = false,
    this.viewCount = 0,
    required this.sellerId,
    this.sellerName,
    this.sellerPhotoUrl,
  });

  factory Listing.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Listing(
      id:            doc.id,
      title:         d['title'] as String? ?? '',
      description:   d['description'] as String? ?? '',
      price:         (d['price'] as num?)?.toDouble() ?? 0,
      currency:      d['currency'] as String? ?? '£',
      categoryId:    d['categoryId'] as String? ?? '',
      subcategoryId: d['subcategoryId'] as String? ?? '',
      location:      d['location'] as String? ?? '',
      district:      d['district'] as String? ?? '',
      imageUrls:     List<String>.from(d['imageUrls'] ?? []),
      createdAt:     (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status:        _parseStatus(d['status']),
      type:          _parseType(d['type']),
      attributes:    Map<String, String>.from(
                       (d['attributes'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? {}),
      isFeatured:    d['isFeatured'] as bool? ?? false,
      viewCount:     d['viewCount'] as int? ?? 0,
      sellerId:      d['sellerId'] as String? ?? '',
      sellerName:    d['sellerName'] as String?,
      sellerPhotoUrl: d['sellerPhotoUrl'] as String?,
    );
  }

  static ListingStatus _parseStatus(dynamic v) => switch (v) {
    'active'  => ListingStatus.active,
    'pending' => ListingStatus.pending,
    'sold'    => ListingStatus.sold,
    'expired' => ListingStatus.expired,
    _         => ListingStatus.pending,
  };

  static ListingType _parseType(dynamic v) => switch (v) {
    'sell'   => ListingType.sell,
    'rent'   => ListingType.rent,
    'wanted' => ListingType.wanted,
    _        => ListingType.sell,
  };

  Listing copyWith({
    ListingStatus? status,
    bool? isFeatured,
  }) {
    return Listing(
      id: id, title: title, description: description,
      price: price, currency: currency,
      categoryId: categoryId, subcategoryId: subcategoryId,
      location: location, district: district,
      imageUrls: imageUrls, createdAt: createdAt,
      status: status ?? this.status,
      type: type, attributes: attributes,
      isFeatured: isFeatured ?? this.isFeatured,
      viewCount: viewCount, sellerId: sellerId,
      sellerName: sellerName, sellerPhotoUrl: sellerPhotoUrl,
    );
  }

  String get formattedPrice {
    if (price == 0) return 'Ücretsiz';
    final formatted = price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return '$formatted $currency';
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return '${createdAt.day}.${createdAt.month}.${createdAt.year}';
  }
}
