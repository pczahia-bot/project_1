import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'home_widgets.dart';

class OffersPage extends StatefulWidget {
  const OffersPage({super.key});

  @override
  State<OffersPage> createState() => _OffersPageState();
}

class _OffersPageState extends State<OffersPage> {
  static const List<Map<String, dynamic>> offers = [
    {
      'title': 'النظافة',
      'icon': Icons.cleaning_services_rounded,
      'color': Color(0xFF159B76),
      'light': Color(0xFFE3F5EF),
      'images': [
        'assets/images/cleaning1.jpg',
        'assets/images/cleaning2.jpg',
      ],
    },
    {
      'title': 'السباكة',
      'icon': Icons.plumbing_rounded,
      'color': Color(0xFF1687C9),
      'light': Color(0xFFE5F3FC),
      'images': [
        'assets/images/plumbing1.jpg',
        'assets/images/plumbing2.jpg',
      ],
    },
    {
      'title': 'الأجهزة المنزلية',
      'icon': Icons.kitchen_rounded,
      'color': Color(0xFF7556B8),
      'light': Color(0xFFF0EAF9),
      'images': [
        'assets/images/appliances1.jpg',
        'assets/images/appliances2.jpg',
      ],
    },
    {
      'title': 'النقاشة',
      'icon': Icons.format_paint_rounded,
      'color': Color(0xFFD16A9B),
      'light': Color(0xFFFBEAF2),
      'images': [
        'assets/images/painting1.jpg',
        'assets/images/painting2.jpg',
      ],
    },
  ];

  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _offerKeys =
      List.generate(offers.length, (_) => GlobalKey());

  int _selectedIndex = 0;
  bool _isProgrammaticScroll = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onManualScroll);
  }

  void _onManualScroll() {
    if (_isProgrammaticScroll || !_scrollController.hasClients) return;

    int closestIndex = _selectedIndex;
    double minDistance = double.infinity;

    for (int i = 0; i < _offerKeys.length; i++) {
      final ctx = _offerKeys[i].currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final offsetY = box.localToGlobal(Offset.zero).dy;
      final distance = (offsetY - 140).abs();
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    if (closestIndex != _selectedIndex && mounted) {
      setState(() => _selectedIndex = closestIndex);
    }
  }

  void _goToOffer(int index) {
    setState(() {
      _selectedIndex = index;
      _isProgrammaticScroll = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final targetContext = _offerKeys[index].currentContext;
      if (targetContext != null) {
        await Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeInOutCubic,
          alignment: 0.05,
        );
      }
      if (mounted) {
        _isProgrammaticScroll = false;
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onManualScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildOfferSection(int index) {
    final offer = offers[index];
    final color = offer['color'] as Color;
    final light = offer['light'] as Color;
    final images = offer['images'] as List<String>;

    return Column(
      key: _offerKeys[index],
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 5,
              height: 25,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(width: 9),
            Icon(
              offer['icon'] as IconData,
              color: color,
              size: 22,
            ),
            const SizedBox(width: 7),
            Text(
              offer['title'] as String,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF172554),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(images.length, (imageIndex) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: light,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: color.withValues(alpha: .18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                images[imageIndex],
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Icon(
                      offer['icon'] as IconData,
                      color: color,
                      size: 45,
                    ),
                  );
                },
              ),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeading(
            title: 'عروض صيانتي',
            subtitle: 'اختار القسم وشوف العروض المتاحة',
            icon: Icons.local_offer_rounded,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: offers.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final offer = offers[index];
                final color = offer['color'] as Color;
                final selected = _selectedIndex == index;

                return ChoiceChip(
                  selected: selected,
                  showCheckmark: false,
                  avatar: Icon(
                    offer['icon'] as IconData,
                    size: 18,
                    color: selected ? Colors.white : color,
                  ),
                  label: Text(offer['title'] as String),
                  selectedColor: AppTheme.primaryBlue,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: selected
                        ? AppTheme.primaryBlue
                        : const Color(0xFFE1E8F0),
                  ),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF26364A),
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) => _goToOffer(index),
                );
              },
            ),
          ),
          const SizedBox(height: 25),
          ...List.generate(offers.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 25),
              child: _buildOfferSection(index),
            );
          }),
        ],
      ),
    );
  }
}
