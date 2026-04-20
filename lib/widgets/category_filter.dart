import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/category.dart';
import '../utils/app_localizations.dart';

class CategoryFilter extends StatelessWidget {
  final List<CropCategory> categories;
  final int? selectedCategoryId;
  final Function(int?) onCategorySelected;

  const CategoryFilter({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    const darkGreen = Color(0xFF005E4D);
    const primaryGreen = Color(0xFF00C897);

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final category = isAll ? null : categories[index - 1];
          final isSelected = isAll 
              ? selectedCategoryId == null 
              : selectedCategoryId == category?.id;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                isAll ? l10n.translate('all_categories') : category!.getName(lang),
                style: GoogleFonts.cairo(
                  color: isSelected ? Colors.white : darkGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
              selected: isSelected,
              onSelected: (_) => onCategorySelected(category?.id),
              selectedColor: primaryGreen,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isSelected ? primaryGreen : Colors.grey.shade300),
              ),
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }
}
