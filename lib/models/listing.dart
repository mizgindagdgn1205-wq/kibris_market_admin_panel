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
    this.currency = '₺',
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
