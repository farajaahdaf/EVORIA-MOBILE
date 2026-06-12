import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Baris kategori horizontal dengan ikon — gabungan dari "Kategori Event"
/// di web + fungsi filter cepat di mobile.
class CategorySelector extends StatelessWidget {
  final List<(int, String)> categories;
  final int? selectedId;
  final ValueChanged<int?> onSelect;

  const CategorySelector({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => Gap.w12,
        itemBuilder: (_, i) {
          if (i == 0) {
            return _CategoryCard(
              icon: Icons.grid_view_rounded,
              label: 'Semua',
              selected: selectedId == null,
              onTap: () => onSelect(null),
            );
          }
          final (id, name) = categories[i - 1];
          return _CategoryCard(
            icon: categoryIcon(name),
            label: name,
            selected: selectedId == id,
            onTap: () => onSelect(selectedId == id ? null : id),
          );
        },
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                gradient: selected ? AppGradients.brand : null,
                color: selected ? null : AppColors.surface,
                borderRadius: AppRadius.rMd,
                border: selected
                    ? null
                    : Border.all(color: AppColors.border),
                boxShadow: selected
                    ? AppShadows.glow(AppColors.primary, opacity: 0.28)
                    : AppShadows.soft,
              ),
              child: Icon(
                icon,
                size: 26,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            Gap.h6,
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
