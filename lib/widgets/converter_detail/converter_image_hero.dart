import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../core/theme/app_palette.dart';

/// A full-bleed gallery with gesture paging and overlay actions.
class ConverterImageHero extends StatefulWidget {
  const ConverterImageHero({
    required this.images,
    required this.isAdmin,
    required this.onBack,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final List<String> images;
  final bool isAdmin;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<ConverterImageHero> createState() => _ConverterImageHeroState();
}

class _ConverterImageHeroState extends State<ConverterImageHero> {
  final _pageController = PageController();
  var _imageIndex = 0;

  @override
  void didUpdateWidget(covariant ConverterImageHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_imageIndex < widget.images.length) {
      return;
    }
    _imageIndex = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final imageUrls = widget.images
        .map(_resolveImageUrl)
        .whereType<String>()
        .toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = (constraints.maxWidth * .84)
            .clamp(300.0, 440.0)
            .toDouble();
        return SizedBox(
          key: const ValueKey('converter-detail-image-hero'),
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: palette.surfaceElevated,
                child: imageUrls.isEmpty
                    ? Icon(
                        Icons.precision_manufacturing_outlined,
                        color: palette.textMuted,
                        size: 48,
                      )
                    : PageView.builder(
                        controller: _pageController,
                        itemCount: imageUrls.length,
                        onPageChanged: (index) {
                          setState(() => _imageIndex = index);
                        },
                        itemBuilder: (context, index) => Image.network(
                          imageUrls[index],
                          key: ValueKey(imageUrls[index]),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: palette.surfaceSubtle,
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: palette.textMuted,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
              ),
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x99000000), Color(0x20000000)],
                      stops: [0, .65],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                top: 0,
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      _HeroActionButton(
                        tooltip: 'Back',
                        icon: Icons.arrow_back_rounded,
                        onPressed: widget.onBack,
                      ),
                      const Spacer(),
                      if (widget.isAdmin) ...[
                        _HeroActionButton(
                          tooltip: 'Edit converter',
                          icon: Icons.edit_outlined,
                          onPressed: widget.onEdit,
                        ),
                        const SizedBox(width: 8),
                        _HeroActionButton(
                          tooltip: 'Delete converter',
                          icon: Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                          onPressed: widget.onDelete,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (imageUrls.length > 1)
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xB3000000),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Text(
                        '${_imageIndex + 1}/${imageUrls.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  const _HeroActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color = Colors.white,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xB3000000),
        foregroundColor: color,
        shape: const CircleBorder(),
      ),
      icon: Icon(icon),
    );
  }
}

String? _resolveImageUrl(String value) {
  final trimmed = value.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null || trimmed.isEmpty) return null;
  return uri.hasScheme
      ? uri.toString()
      : Uri.parse(ApiConfig.baseUrl).resolveUri(uri).toString();
}
