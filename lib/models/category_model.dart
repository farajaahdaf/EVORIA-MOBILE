class CategoryModel {
  final int id;
  final String name;
  final String? slug;
  final String? icon;

  CategoryModel({
    required this.id,
    required this.name,
    this.slug,
    this.icon,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
        id: json['id'] as int,
        name: json['name'] as String,
        slug: json['slug'] as String?,
        icon: json['icon'] as String?,
      );
}
