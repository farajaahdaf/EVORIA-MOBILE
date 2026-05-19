class UserModel {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? profilePhotoPath;
  final double? balance;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.profilePhotoPath,
    this.balance,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as int,
        name: json['name'] as String,
        email: json['email'] as String,
        role: json['role'] as String? ?? 'attendee',
        profilePhotoPath: json['profile_photo_path'] as String?,
        balance: json['balance'] != null
            ? double.tryParse(json['balance'].toString())
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'profile_photo_path': profilePhotoPath,
        'balance': balance,
      };

  String get avatarUrl {
    if (profilePhotoPath != null && profilePhotoPath!.isNotEmpty) {
      final p = profilePhotoPath!;
      if (p.startsWith('http')) return p;
      final cleaned = p.replaceFirst(RegExp(r'^/?storage/'), '');
      return 'https://evoria.life/storage/$cleaned';
    }
    final encoded = Uri.encodeComponent(name);
    return 'https://ui-avatars.com/api/?name=$encoded&background=2563EB&color=ffffff&size=128';
  }
}
