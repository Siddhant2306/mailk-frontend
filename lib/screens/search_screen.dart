import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../widgets/search/catalog_search_field.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();

  static const _suggestions = ['ESH', 'Hyundai', 'Toyota', 'OEM', 'India'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _useSuggestion(String value) {
    _searchController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MALIK ENTERPRISES',
            style: TextStyle(
              color: AppColors.accent,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Search',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          CatalogSearchField(
            controller: _searchController,
            hintText: 'Search code, marking, make, model',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 18),
          const Text(
            'TRY SEARCHING',
            style: TextStyle(
              color: Color(0xFF7D8794),
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.05,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final suggestion in _suggestions)
                _SuggestionChip(
                  label: suggestion,
                  onTap: () => _useSuggestion(suggestion),
                ),
            ],
          ),
          const SizedBox(height: 15),
          const _SearchHelpCard(),
          const Spacer(),
          const Align(alignment: Alignment.centerRight, child: _SettingsButton()),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1A202B),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF242D3A)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search, color: Color(0xFF99A4B1), size: 13),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(color: Color(0xFFC3CBD5), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchHelpCard extends StatelessWidget {
  const _SearchHelpCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF20180B),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFF49340F)),
      ),
      child: const Padding(
        padding: EdgeInsets.all(13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline, color: AppColors.accent, size: 18),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Search matches converter code, marking,\nmake and model. Matching markings are\nhighlighted in the results.',
                style: TextStyle(
                  color: Color(0xFFE0B75F),
                  fontSize: 10,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF222935),
        shape: BoxShape.circle,
      ),
      child: const SizedBox(
        width: 40,
        height: 40,
        child: Icon(Icons.settings, color: Color(0xFFD0D6DE), size: 21),
      ),
    );
  }
}
