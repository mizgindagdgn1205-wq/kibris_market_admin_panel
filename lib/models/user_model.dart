class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String phone;
  final bool isAdmin;
  final DateTime createdAt;
  final int listingCount;
  final String? photoUrl;
  final String? bio;
  final bool isBanned;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.phone,
    required this.isAdmin,
    required this.createdAt,
    this.listingCount = 0,
    this.photoUrl,
    this.bio,
    this.isBanned = false,
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      isAdmin: map['isAdmin'] as bool? ?? false,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      listingCount: map['listingCount'] as int? ?? 0,
      photoUrl: map['photoUrl'] as String?,
      bio: map['bio'] as String?,
      isBanned: map['isBanned'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'phone': phone,
        'isAdmin': isAdmin,
        'isBanned': isBanned,
        'createdAt': createdAt.toIso8601String(),
        'listingCount': listingCount,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (bio != null) 'bio': bio,
      };

  String get memberSince {
    final months = DateTime.now().difference(createdAt).inDays ~/ 30;
    if (months < 1) return 'Bu ay üye oldu';
    if (months < 12) return '$months aydır üye';
    final years = months ~/ 12;
    return '$years yıldır üye';
  }
}
