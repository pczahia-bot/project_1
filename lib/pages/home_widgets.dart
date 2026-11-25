import 'dart:async';
import 'package:flutter/material.dart';
import '../app_theme.dart';

class ServiceSquare extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const ServiceSquare({
    super.key,
    required this.name,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: const Color(0xFFE7ECF4)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 27),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class AutoServicesRail extends StatefulWidget {
  final List<Map<String, dynamic>> services;
  final ValueChanged<String> onTap;

  const AutoServicesRail({
    super.key,
    required this.services,
    required this.onTap,
  });

  @override
  State<AutoServicesRail> createState() => _AutoServicesRailState();
}

class _AutoServicesRailState extends State<AutoServicesRail> {
  final ScrollController _scroll = ScrollController();
  Timer? _timer;
  bool _forward = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      if (pos.maxScrollExtent <= 0) return;
      if (_forward && pos.pixels >= pos.maxScrollExtent - 5) _forward = false;
      if (!_forward && pos.pixels <= 5) _forward = true;
      final target = (_forward ? pos.pixels + 125 : pos.pixels - 125)
          .clamp(0.0, pos.maxScrollExtent);
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 850),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 108,
        child: ListView.separated(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          itemCount: widget.services.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final item = widget.services[i];
            return SizedBox(
              width: 105,
              child: ServiceSquare(
                name: item['name'] as String,
                icon: item['icon'] as IconData,
                color: const Color(0xFF138A78),
                onTap: () => widget.onTap(item['name'] as String),
              ),
            );
          },
        ),
      );
}

class OffersCarousel extends StatefulWidget {
  const OffersCarousel({super.key});

  @override
  State<OffersCarousel> createState() => _OffersCarouselState();
}

class _OffersCarouselState extends State<OffersCarousel> {
  final PageController _page = PageController(viewportFraction: .88);
  Timer? _timer;
  int _index = 0;

  final offers = const [
    (
      'عروض صيانتي',
      'تابع العروض المتاحة على خدماتنا',
      Icons.local_offer_rounded,
      [Color(0xFF172554), Color(0xFF2563EB)]
    ),
    (
      'خدمات التنظيف',
      'حلول تساعدك تحافظ على بيتك مرتب',
      Icons.cleaning_services_rounded,
      [Color(0xFF064E3B), Color(0xFF10B981)]
    ),
    (
      'صيانة أسهل',
      'اختار الخدمة المناسبة وابدأ طلبك',
      Icons.home_repair_service_rounded,
      [Color(0xFF7C2D12), Color(0xFFF97316)]
    ),
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_page.hasClients) return;
      _page.animateToPage(
        (_index + 1) % offers.length,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutBack,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 174,
        child: PageView.builder(
          controller: _page,
          itemCount: offers.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (context, i) {
            final item = offers[i];
            final active = i == _index;
            return AnimatedScale(
              scale: active ? 1 : .92,
              duration: const Duration(milliseconds: 400),
              child: AnimatedOpacity(
                opacity: active ? 1 : .68,
                duration: const Duration(milliseconds: 350),
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: item.$4,
                    ),
                    borderRadius: BorderRadius.circular(23),
                    boxShadow: [
                      BoxShadow(
                        color: item.$4.first.withValues(alpha: .22),
                        blurRadius: 14,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: -12,
                        bottom: -35,
                        child: Icon(
                          item.$3,
                          size: 135,
                          color: Colors.white.withValues(alpha: .10),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .17),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'عرض مميز',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  item.$1,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item.$2,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: .9),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(item.$3, color: Colors.white, size: 48),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
}

class HomeFeaturesMagazine extends StatefulWidget {
  const HomeFeaturesMagazine({super.key});

  @override
  State<HomeFeaturesMagazine> createState() => _HomeFeaturesMagazineState();
}

class _HomeFeaturesMagazineState extends State<HomeFeaturesMagazine> {
  final PageController _controller = PageController();
  Timer? _timer;
  int _currentPage = 0;

  // الاعتماد على رسوميات وتدرجات محلية بالكامل لضمان السرعة وعدم التعطل بدون إنترنت
  final List<_MagazineSlide> _slides = const [
    _MagazineSlide(
      title: 'الصيانة بقت أسهل',
      subtitle: 'اطلب الخدمة اللي محتاجها بخطوات بسيطة',
      icon: Icons.home_repair_service_rounded,
      tag: 'صيانتي في خدمتك',
      colors: [Color(0xFF1769E0), Color(0xFF073B8A)],
    ),
    _MagazineSlide(
      title: 'كل الخدمات في مكان واحد',
      subtitle: 'كهرباء وسباكة وتكييف ونجارة وخدمات تانية',
      icon: Icons.handyman_rounded,
      tag: 'خدمات متنوعة',
      colors: [Color(0xFF087E8B), Color(0xFF064B65)],
    ),
    _MagazineSlide(
      title: 'حدد مكان الصيانة',
      subtitle: 'اختار موقعك على الخريطة لتوضيح مكان الخدمة',
      icon: Icons.location_on_rounded,
      tag: 'تحديد الموقع',
      colors: [Color(0xFF6C4AB6), Color(0xFF38206F)],
    ),
    _MagazineSlide(
      title: 'تابع طلب الصيانة',
      subtitle: 'راجع تفاصيل طلباتك وحالة كل طلب من التطبيق',
      icon: Icons.track_changes_rounded,
      tag: 'متابعة أسهل',
      colors: [Color(0xFFDB7A19), Color(0xFF93420B)],
    ),
    _MagazineSlide(
      title: 'وضح المشكلة بالصور',
      subtitle: 'أضف صور العطل لمساعدة الفني على فهم المشكلة',
      icon: Icons.add_a_photo_rounded,
      tag: 'طلب واضح ومنظم',
      colors: [Color(0xFF16845B), Color(0xFF07543C)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_currentPage + 1) % _slides.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.auto_awesome, color: AppTheme.primaryBlue, size: 20),
            SizedBox(width: 7),
            Text(
              'اكتشف مميزات صيانتي',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 190,
          child: PageView.builder(
            controller: _controller,
            itemCount: _slides.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final slide = _slides[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: slide.colors,
                          ),
                        ),
                      ),
                      Positioned(
                        left: -25,
                        top: -40,
                        child: Container(
                          width: 170,
                          height: 170,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                      Positioned(
                        left: -14,
                        bottom: -24,
                        child: Icon(
                          slide.icon,
                          size: 145,
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(17, 15, 17, 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Text(
                                      slide.tag,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    slide.title,
                                    maxLines: 2,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 19,
                                      height: 1.25,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    slide.subtitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.92),
                                      fontSize: 11,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.45),
                                ),
                              ),
                              child: Icon(slide.icon,
                                  color: Colors.white, size: 30),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        bottom: 10,
                        left: 14,
                        child: Row(
                          children: List.generate(_slides.length, (dotIndex) {
                            final selected = dotIndex == _currentPage;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: selected ? 19 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 7),
        const Center(
          child: Text(
            'اسحب لمشاهدة باقي المميزات',
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}

class _MagazineSlide {
  final String title;
  final String subtitle;
  final IconData icon;
  final String tag;
  final List<Color> colors;

  const _MagazineSlide({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tag,
    required this.colors,
  });
}

class PageHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const PageHeading({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppTheme.primaryBlue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      );
}
