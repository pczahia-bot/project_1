import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:image_picker/image_picker.dart';

import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'register_page.dart';
import 'customer_login_page.dart';
import 'login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://uljmzaeiutddxbhgijzk.supabase.co',
    publishableKey: 'sb_publishable_r_VGKOFSbHllejmFyAKiWQ_OBOOmpPe',
  );
  runApp(const SayantiApp());
}

class SayantiApp extends StatelessWidget {
  const SayantiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'صيانتي',
      builder: (context, child) {
        if (!kIsWeb) return child ?? const SizedBox.shrink();
        return ColoredBox(
          color: const Color(0xFFD9E2EE),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ClipRect(child: child ?? const SizedBox.shrink()),
            ),
          ),
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFEAF1FA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1769E0),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class MaintenanceRequest {
  final String id;
  final String number;
  final String service;
  final String description;
  final String address;
  final String visitType;
  final DateTime? visitDateTime;
  final int imagesCount;
  final List<String> imageUrls;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;
  String status;

  MaintenanceRequest({
    this.id = '',
    required this.number,
    required this.service,
    required this.description,
    required this.address,
    required this.visitType,
    required this.visitDateTime,
    required this.imagesCount,
    this.imageUrls = const [],
    required this.createdAt,
    this.latitude,
    this.longitude,
    this.status = 'بانتظار قبول فني',
  });
}

class _ModernBackgroundHeader extends StatelessWidget {
  const _ModernBackgroundHeader();

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _SoftWaveClipper(),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color(0xFF0D47A1),
              Color(0xFF1769E0),
              Color(0xFF5B9BFA),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -55,
              right: -35,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .08),
                ),
              ),
            ),
            Positioned(
              top: 55,
              left: -45,
              child: Container(
                width: 135,
                height: 135,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .07),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(0, size.height - 38)
      ..quadraticBezierTo(
        size.width * .48,
        size.height + 30,
        size.width,
        size.height - 30,
      )
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentIndex = 0;
  bool _isSideMenuOpen = false;
  StreamSubscription<AuthState>? _homeAuthSub;
  bool get _isTechnician =>
      Supabase.instance.client.auth.currentUser?.userMetadata?['account_type'] ==
      'technician';
  final GlobalKey<_TechnicianRequestsPageState> _availableKey =
      GlobalKey<_TechnicianRequestsPageState>();
  final GlobalKey<_TechnicianRequestsPageState> _ongoingKey =
      GlobalKey<_TechnicianRequestsPageState>();
  final GlobalKey<_MyRequestsPageState> _myRequestsKey =
      GlobalKey<_MyRequestsPageState>();

  @override
  void initState() {
    super.initState();
    _homeAuthSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (!mounted) return;
      final isTech = Supabase.instance.client.auth.currentUser
              ?.userMetadata?['account_type'] ==
          'technician';
      setState(() {
        currentIndex = Supabase.instance.client.auth.currentUser == null
            ? 0
            : (isTech ? 0 : 4);
      });
    });
  }

  @override
  void dispose() {
    _homeAuthSub?.cancel();
    super.dispose();
  }

  void _selectTab(int index) {
    setState(() {
      currentIndex = index;
      _isSideMenuOpen = false;
    });
    if (_isTechnician) {
      if (index == 0) _availableKey.currentState?.reload();
      if (index == 2) _ongoingKey.currentState?.reload();
    } else if (index == 3) {
      _myRequestsKey.currentState?.loadRequests();
    }
  }

  final List<Map<String, dynamic>> services = const [
    {'name': 'كهرباء', 'icon': Icons.electrical_services},
    {'name': 'سباكة', 'icon': Icons.plumbing},
    {'name': 'تكييف', 'icon': Icons.ac_unit},
    {'name': 'نجارة', 'icon': Icons.carpenter},
    {'name': 'أجهزة منزلية', 'icon': Icons.kitchen},
    {'name': 'نقاشة', 'icon': Icons.format_paint},
    {'name': 'تنظيف', 'icon': Icons.cleaning_services},
    {'name': 'خدمات أخرى', 'icon': Icons.more_horiz},
  ];

  void openRequest(BuildContext context, {String? service}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RequestPage(initialService: service)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final drawerWidth = MediaQuery.of(context).size.width * .78 > 320
        ? 320.0
        : MediaQuery.of(context).size.width * .78;
    final pages = _isTechnician
        ? <Widget>[
            TechnicianRequestsPage(key: _availableKey, showAvailable: true),
            AccountPage(
              onOpenAvailable: () => _selectTab(0),
              onOpenOngoing: () => _selectTab(2),
            ),
            TechnicianRequestsPage(key: _ongoingKey, showAvailable: false),
          ]
        : <Widget>[
            _buildHomeContent(),
            const ServicesPage(),
            const OffersPage(),
            MyRequestsPage(key: _myRequestsKey),
            AccountPage(onOpenRequests: () => _selectTab(3)),
          ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFEAF1FA),
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/sayanti_background.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: IndexedStack(index: currentIndex, children: pages),
                ),
              ],
            ),
            if (_isSideMenuOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _isSideMenuOpen = false),
                  child: Container(color: Colors.black.withValues(alpha: .38)),
                ),
              ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              top: 0,
              bottom: 0,
              right: _isSideMenuOpen ? 0 : -drawerWidth,
              width: drawerWidth,
              child: IgnorePointer(
                ignoring: !_isSideMenuOpen,
                child: _buildSideMenu(),
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: _selectTab,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 12,
          selectedItemColor: const Color(0xFF1769E0),
          unselectedItemColor: Colors.grey,
          items: _isTechnician
              ? const [
                  BottomNavigationBarItem(
                      icon: Icon(Icons.inbox_outlined), label: 'المتاحة'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.person_outline), label: 'حسابي'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.handyman_outlined), label: 'الجارية'),
                ]
              : const [
                  BottomNavigationBarItem(
                      icon: Icon(Icons.home), label: 'الرئيسية'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.grid_view_rounded), label: 'الخدمات'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.local_offer_outlined), label: 'العروض'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.receipt_long), label: 'طلباتي'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.person_outline_rounded), label: 'حسابي'),
                ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Row(
          children: [
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              child: InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: () => setState(() => _isSideMenuOpen = true),
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Icons.menu_rounded,
                      color: Color(0xFF1769E0), size: 25),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: SizedBox(
                height: 48,
                child: TextField(
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'بتدور على خدمة إيه؟',
                    prefixIcon:
                        const Icon(Icons.search, color: Color(0xFF1769E0)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Color(0xFFE8EDF5)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              child: InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('لا توجد إشعارات جديدة')),
                  );
                },
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Icons.notifications_none_rounded,
                      color: Color(0xFF1769E0), size: 25),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideMenu() {
    final menuItems = _isTechnician
        ? const [
            ('الطلبات المتاحة', Icons.inbox_outlined, 0),
            ('حسابي', Icons.person_outline_rounded, 1),
            ('الطلبات الجارية', Icons.handyman_outlined, 2),
          ]
        : const [
            ('حسابي', Icons.person_outline_rounded, 4),
            ('الرئيسية', Icons.home_rounded, 0),
            ('الخدمات', Icons.grid_view_rounded, 1),
            ('العروض', Icons.local_offer_rounded, 2),
            ('طلباتي', Icons.receipt_long_rounded, 3),
          ];

    return Material(
      color: Colors.white,
      elevation: 20,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('قائمة صيانتي',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    tooltip: 'إغلاق القائمة',
                    onPressed: () => setState(() => _isSideMenuOpen = false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            for (final item in menuItems)
              ListTile(
                leading: Icon(item.$2,
                    color: currentIndex == item.$3
                        ? const Color(0xFF1769E0)
                        : Colors.blueGrey),
                title: Text(item.$1),
                selected: currentIndex == item.$3,
                selectedTileColor: const Color(0xFFEAF1FF),
                onTap: () => _selectTab(item.$3),
              ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text('صيانتي • خدمات الصيانة في مكان واحد',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    final technical = <Map<String, dynamic>>[
      {'name': 'كهرباء', 'icon': Icons.electrical_services_rounded},
      {'name': 'سباكة', 'icon': Icons.plumbing_rounded},
      {'name': 'تكييف', 'icon': Icons.ac_unit_rounded},
      {'name': 'نجارة', 'icon': Icons.carpenter_rounded},
      {'name': 'أجهزة منزلية', 'icon': Icons.kitchen_rounded},
      {'name': 'نقاشة', 'icon': Icons.format_paint_rounded},
    ];
    final daily = <Map<String, dynamic>>[
      {'name': 'تنظيف', 'icon': Icons.cleaning_services_rounded},
      {'name': 'نقل أثاث', 'icon': Icons.local_shipping_rounded},
      {'name': 'مكافحة حشرات', 'icon': Icons.pest_control_rounded},
      {'name': 'تعقيم', 'icon': Icons.sanitizer_rounded},
      {'name': 'تركيب', 'icon': Icons.build_circle_rounded},
      {'name': 'خدمات أخرى', 'icon': Icons.more_horiz_rounded},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.location_on_outlined,
                color: Color(0xFF1769E0), size: 18),
            SizedBox(width: 5),
            Text('موقعك الحالي: المنصورة، مصر',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
          const SizedBox(height: 18),
          const HomeFeaturesMagazine(),
          const SizedBox(height: 25),
          _sectionTitle('الصيانات الفنية', 'خدمات الفنيين المتخصصين',
              Icons.home_repair_service_rounded),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: technical.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 11,
              crossAxisSpacing: 11,
              childAspectRatio: 1.12,
            ),
            itemBuilder: (context, index) {
              final item = technical[index];
              return _ServiceSquare(
                name: item['name'] as String,
                icon: item['icon'] as IconData,
                color: const Color(0xFF1769E0),
                onTap: () =>
                    openRequest(context, service: item['name'] as String),
              );
            },
          ),
          const SizedBox(height: 25),
          _sectionTitle(
              'خدمات أخرى', 'خدمات يومية ومساعدة إضافية', Icons.widgets_rounded),
          const SizedBox(height: 12),
          _AutoServicesRail(
            services: daily,
            onTap: (name) => openRequest(context, service: name),
          ),
          const SizedBox(height: 27),
          _sectionTitle('عروض صيانتي', 'اكتشف العروض والخدمات المميزة',
              Icons.local_offer_rounded),
          const SizedBox(height: 12),
          const _OffersCarousel(),
          const SizedBox(height: 27),
          _sectionTitle(
              'آراء العملاء', 'تجارب العملاء مع صيانتي', Icons.forum_rounded),
          const SizedBox(height: 12),
          const _ReviewsRail(),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle, IconData icon) {
    return Row(children: [
      Container(
        width: 39,
        height: 39,
        decoration: BoxDecoration(
          color: const Color(0xFFEAF1FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF1769E0), size: 21),
      ),
      const SizedBox(width: 10),
      Expanded(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      )),
    ]);
  }
}

class _ServiceSquare extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ServiceSquare(
      {required this.name,
      required this.icon,
      required this.color,
      required this.onTap});

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
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color, size: 27),
              ),
              const SizedBox(height: 8),
              Text(name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      );
}

class _AutoServicesRail extends StatefulWidget {
  final List<Map<String, dynamic>> services;
  final ValueChanged<String> onTap;
  const _AutoServicesRail({required this.services, required this.onTap});
  @override
  State<_AutoServicesRail> createState() => _AutoServicesRailState();
}

class _AutoServicesRailState extends State<_AutoServicesRail> {
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
      _scroll.animateTo(target,
          duration: const Duration(milliseconds: 850),
          curve: Curves.easeInOutCubic);
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
              child: _ServiceSquare(
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

class _OffersCarousel extends StatefulWidget {
  const _OffersCarousel();
  @override
  State<_OffersCarousel> createState() => _OffersCarouselState();
}

class _OffersCarouselState extends State<_OffersCarousel> {
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
      _page.animateToPage((_index + 1) % offers.length,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutBack);
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
                        colors: item.$4),
                    borderRadius: BorderRadius.circular(23),
                    boxShadow: [
                      BoxShadow(
                          color: item.$4.first.withValues(alpha: .22),
                          blurRadius: 14,
                          offset: const Offset(0, 7))
                    ],
                  ),
                  child: Stack(children: [
                    Positioned(
                        left: -12,
                        bottom: -35,
                        child: Icon(item.$3,
                            size: 135,
                            color: Colors.white.withValues(alpha: .10))),
                    Row(children: [
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
                                borderRadius: BorderRadius.circular(20)),
                            child: const Text('عرض مميز',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 12),
                          Text(item.$1,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(item.$2,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: .9),
                                  fontSize: 11)),
                        ],
                      )),
                      const SizedBox(width: 8),
                      Icon(item.$3, color: Colors.white, size: 48),
                    ]),
                  ]),
                ),
              ),
            );
          },
        ),
      );
}

class _ReviewsRail extends StatelessWidget {
  const _ReviewsRail();
  static const reviews = [
    ('عميل صيانتي', 'خدمة الصيانة', 'هنا سيظهر رأي العميل بعد تنفيذ الخدمة.', 5),
    ('عميل صيانتي', 'خدمة منزلية', 'سيتم عرض تجربة العميل وتقييمه هنا.', 5),
    (
      'عميل صيانتي',
      'طلب صيانة',
      'التقييمات الحقيقية ستظهر بعد ربط قاعدة البيانات.',
      4
    ),
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 155,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: reviews.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final r = reviews[i];
            return Container(
              width: 260,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: const Color(0xFFE7ECF4))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const CircleAvatar(
                          backgroundColor: Color(0xFFEAF1FF),
                          child: Icon(Icons.person, color: Color(0xFF1769E0))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(r.$1,
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold)),
                            Text(r.$2,
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey)),
                          ])),
                      Row(
                          children: List.generate(
                              5,
                              (n) => Icon(Icons.star_rounded,
                                  size: 13,
                                  color: n < r.$4
                                      ? const Color(0xFFFFB323)
                                      : Colors.black12))),
                    ]),
                    const SizedBox(height: 12),
                    Text('“${r.$3}”',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: Color(0xFF596579))),
                    const Spacer(),
                    const Text('محتوى تجريبي للواجهة',
                        style: TextStyle(fontSize: 9, color: Colors.grey)),
                  ]),
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

  final List<_MagazineSlide> _slides = const [
    _MagazineSlide(
      title: 'الصيانة بقت أسهل',
      subtitle: 'اطلب الخدمة اللي محتاجها بخطوات بسيطة',
      imageUrl: 'https://images.unsplash.com/photo-1581578731548-c64695cc6952',
      icon: Icons.home_repair_service_rounded,
      tag: 'صيانتي في خدمتك',
      colors: [Color(0xFF1769E0), Color(0xFF073B8A)],
    ),
    _MagazineSlide(
      title: 'كل الخدمات في مكان واحد',
      subtitle: 'كهرباء وسباكة وتكييف ونجارة وخدمات تانية',
      imageUrl: 'https://images.unsplash.com/photo-1621905251918-48416bd8575a',
      icon: Icons.handyman_rounded,
      tag: 'خدمات متنوعة',
      colors: [Color(0xFF087E8B), Color(0xFF064B65)],
    ),
    _MagazineSlide(
      title: 'حدد مكان الصيانة',
      subtitle: 'اختار موقعك على الخريطة لتوضيح مكان الخدمة',
      imageUrl: 'https://images.unsplash.com/photo-1524666041070-9b8767612f5e',
      icon: Icons.location_on_rounded,
      tag: 'تحديد الموقع',
      colors: [Color(0xFF6C4AB6), Color(0xFF38206F)],
    ),
    _MagazineSlide(
      title: 'تابع طلب الصيانة',
      subtitle: 'راجع تفاصيل طلباتك وحالة كل طلب من التطبيق',
      imageUrl: 'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d',
      icon: Icons.track_changes_rounded,
      tag: 'متابعة أسهل',
      colors: [Color(0xFFDB7A19), Color(0xFF93420B)],
    ),
    _MagazineSlide(
      title: 'وضح المشكلة بالصور',
      subtitle: 'أضف صور العطل لمساعدة الفني على فهم المشكلة',
      imageUrl: 'https://images.unsplash.com/photo-1581092160562-40aa08e78837',
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
            Icon(Icons.auto_awesome, color: Color(0xFF1769E0), size: 20),
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
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: 145,
                        child: Image.network(
                          slide.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: 205,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                slide.colors.first.withValues(alpha: 0.02),
                                slide.colors.first.withValues(alpha: 0.88),
                                slide.colors.first,
                              ],
                            ),
                          ),
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
  final String imageUrl;
  final IconData icon;
  final String tag;
  final List<Color> colors;

  const _MagazineSlide({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.icon,
    required this.tag,
    required this.colors,
  });
}

class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key});

  static const List<Map<String, dynamic>> technicalServices = [
    {'name': 'كهرباء', 'icon': Icons.electrical_services_rounded},
    {'name': 'سباكة', 'icon': Icons.plumbing_rounded},
    {'name': 'تكييف', 'icon': Icons.ac_unit_rounded},
    {'name': 'نجارة', 'icon': Icons.carpenter_rounded},
    {'name': 'نقاشة', 'icon': Icons.format_paint_rounded},
  ];

  static const List<Map<String, dynamic>> applianceServices = [
    {'name': 'غسالات', 'icon': Icons.local_laundry_service_rounded},
    {'name': 'ثلاجات', 'icon': Icons.kitchen_rounded},
    {'name': 'ديب فريزر', 'icon': Icons.ac_unit_rounded},
    {'name': 'تكييفات', 'icon': Icons.ac_unit_rounded},
    {'name': 'شاشات وتليفزيونات', 'icon': Icons.tv_rounded},
    {'name': 'بوتاجازات وأفران', 'icon': Icons.microwave_rounded},
    {'name': 'سخانات كهرباء وغاز', 'icon': Icons.local_fire_department_rounded},
    {'name': 'ميكروويف', 'icon': Icons.microwave_rounded},
    {'name': 'غسالات أطباق', 'icon': Icons.kitchen_rounded},
    {'name': 'كولدير ومبرد مياه', 'icon': Icons.water_drop_rounded},
    {'name': 'خلاطات', 'icon': Icons.blender_rounded},
    {'name': 'مراوح', 'icon': Icons.toys_rounded},
    {'name': 'مكانس كهربائية', 'icon': Icons.cleaning_services_rounded},
  ];

  static const List<Map<String, dynamic>> cleaningServices = [
    {'name': 'تنظيف', 'icon': Icons.cleaning_services_rounded},
    {'name': 'مكافحة حشرات', 'icon': Icons.pest_control_rounded},
    {'name': 'تعقيم', 'icon': Icons.sanitizer_rounded},
  ];

  static const List<Map<String, dynamic>> movingServices = [
    {'name': 'نقل أثاث', 'icon': Icons.local_shipping_rounded},
    {'name': 'فك وتركيب أثاث', 'icon': Icons.chair_alt_rounded},
    {'name': 'تركيب أجهزة ومعدات', 'icon': Icons.build_circle_rounded},
  ];

  static const List<Map<String, dynamic>> otherServices = [
    {'name': 'خدمات أخرى', 'icon': Icons.more_horiz_rounded},
  ];

  Widget _buildServiceSection(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Map<String, dynamic>> services,
    Color color = const Color(0xFF1769E0),
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeading(title: title, subtitle: subtitle, icon: icon),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: services.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 11,
            crossAxisSpacing: 11,
            childAspectRatio: 1.12,
          ),
          itemBuilder: (context, index) {
            final item = services[index];
            return _ServiceSquare(
              name: item['name'] as String,
              icon: item['icon'] as IconData,
              color: color,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RequestPage(
                    initialService: item['name'] as String,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PageHeading(
            title: 'كل الخدمات',
            subtitle: 'اختار القسم ثم الخدمة اللي محتاجها',
            icon: Icons.grid_view_rounded,
          ),
          const SizedBox(height: 22),
          _buildServiceSection(
            context,
            title: 'الصيانات الفنية',
            subtitle: 'أعمال الصيانة والإصلاحات المنزلية',
            icon: Icons.home_repair_service_rounded,
            services: technicalServices,
          ),
          const SizedBox(height: 25),
          _buildServiceSection(
            context,
            title: 'صيانة الأجهزة المنزلية',
            subtitle: 'اختار نوع الجهاز اللي محتاج صيانة',
            icon: Icons.kitchen_rounded,
            services: applianceServices,
            color: const Color(0xFF7556B8),
          ),
          const SizedBox(height: 25),
          _buildServiceSection(
            context,
            title: 'خدمات النظافة والعناية',
            subtitle: 'تنظيف وتعقيم ومكافحة الحشرات',
            icon: Icons.cleaning_services_rounded,
            services: cleaningServices,
            color: const Color(0xFF138A78),
          ),
          const SizedBox(height: 25),
          _buildServiceSection(
            context,
            title: 'النقل والتركيب',
            subtitle: 'نقل الأثاث وفك وتركيب الأجهزة',
            icon: Icons.local_shipping_rounded,
            services: movingServices,
            color: const Color(0xFFB7791F),
          ),
          const SizedBox(height: 25),
          _buildServiceSection(
            context,
            title: 'خدمات متنوعة',
            subtitle: 'لو الخدمة اللي محتاجها مش موجودة',
            icon: Icons.widgets_rounded,
            services: otherServices,
            color: const Color(0xFF64748B),
          ),
          const SizedBox(height: 28),
          const _PageHeading(
            title: 'آراء العملاء',
            subtitle: 'تجارب العملاء مع خدمات صيانتي',
            icon: Icons.forum_rounded,
          ),
          const SizedBox(height: 12),
          const _ReviewsRail(),
        ],
      ),
    );
  }
}

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

  void _goToOffer(int index) {
    setState(() => _selectedIndex = index);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = _offerKeys[index].currentContext;

      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeInOutCubic,
          alignment: 0.05,
        );
      }
    });
  }

  @override
  void dispose() {
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
          const _PageHeading(
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
                  selectedColor: const Color(0xFF1769E0),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: selected
                        ? const Color(0xFF1769E0)
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

class _PageHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const _PageHeading(
      {required this.title, required this.subtitle, required this.icon});

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
            child: Icon(icon, color: const Color(0xFF1769E0)),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          )),
        ],
      );
}

String _arabicRequestStatus(String? status) {
  switch (status) {
    case 'pending':
      return 'بانتظار قبول فني';
    case 'accepted':
      return 'تم قبول الطلب';
    case 'on_the_way':
      return 'الفني في الطريق';
    case 'in_progress':
      return 'جاري التنفيذ';
    case 'completed':
      return 'مكتمل';
    case 'cancelled':
      return 'ملغي';
    default:
      return status ?? '';
  }
}

class TechnicianRequestsPage extends StatefulWidget {
  final bool showAvailable;
  const TechnicianRequestsPage({super.key, required this.showAvailable});

  @override
  State<TechnicianRequestsPage> createState() =>
      _TechnicianRequestsPageState();
}

class _TechnicianRequestsPageState extends State<TechnicianRequestsPage> {
  static const categories = [
    'الكل',
    'كهرباء',
    'سباكة',
    'تكييف',
    'نجارة',
    'أجهزة منزلية',
    'نقاشة',
    'تنظيف',
    'نقل أثاث',
    'خدمات أخرى',
  ];

  bool get _showAvailable => widget.showAvailable;
  String _selectedCategory = 'الكل';
  bool _loading = true;
  String? _error;
  String? _acceptingId;
  String? _advancingId;
  final Set<String> _expandedIds = {};
  List<Map<String, dynamic>> _rows = [];
  RealtimeChannel? _techChannel;

  SupabaseClient get _supabase => Supabase.instance.client;
  String? get _uid => _supabase.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
    _listenRealtime();
  }

  @override
  void dispose() {
    _techChannel?.unsubscribe();
    super.dispose();
  }

  void _listenRealtime() {
    _techChannel = _supabase
        .channel('public:service_requests_tech')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'service_requests',
          callback: (payload) {
            if (mounted) _load();
          },
        )
        .subscribe();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _supabase
          .from('service_requests')
          .select()
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _rows = (data as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> reload() => _load();

  List<Map<String, dynamic>> get _available => _rows
      .where((r) =>
          r['status'] == 'pending' &&
          r['technician_id'] == null &&
          r['customer_id'] != _uid)
      .toList();

  List<Map<String, dynamic>> get _mine => _rows
      .where((r) =>
          r['technician_id'] == _uid &&
          const ['accepted', 'on_the_way', 'in_progress', 'completed']
              .contains(r['status']))
      .toList();

  List<Map<String, dynamic>> get _visible {
    final base = _showAvailable ? _available : _mine;
    if (_selectedCategory == 'الكل') return base;
    return base.where((r) {
      final service = r['service_type']?.toString() ?? '';
      if (_selectedCategory == 'خدمات أخرى') {
        return !categories
            .skip(1)
            .take(categories.length - 2)
            .any((c) => service.contains(c));
      }
      return service.contains(_selectedCategory);
    }).toList();
  }

  Future<void> _accept(String id) async {
    setState(() => _acceptingId = id);
    try {
      await _supabase.rpc('accept_service_request', params: {'request_id': id});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم قبول الطلب بنجاح')),
      );
      await _load();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر قبول الطلب: $e')),
      );
    } finally {
      if (mounted) setState(() => _acceptingId = null);
    }
  }

  Future<void> _advanceStatus(String id) async {
    setState(() => _advancingId = id);
    try {
      final res = await _supabase.rpc('advance_request_status', params: {'p_request_id': id});
      if (!mounted) return;
      if (res is Map && res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم الانتقال للمرحلة التالية بنجاح')),
        );
        await _load();
      } else {
        throw Exception(res?['message'] ?? 'تعذر تحديث الحالة');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    } finally {
      if (mounted) setState(() => _advancingId = null);
    }
  }

  String _visitText(Map<String, dynamic> r) {
    final visitAt = r['visit_at'];
    if (visitAt == null) return 'زيارة طارئة الآن';
    return 'موعد الزيارة: ${_formatDateTime(DateTime.tryParse(visitAt.toString())?.toLocal())}';
  }

  Widget _detailLine(IconData icon, String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1769E0)),
          const SizedBox(width: 8),
          Expanded(
            child: Text('$label: $value',
                style: const TextStyle(color: Colors.black87, height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _progressView(String? status) {
    const stages = ['accepted', 'on_the_way', 'in_progress', 'completed'];
    final current = stages.indexOf(status ?? '');
    final safeCurrent = current < 0 ? 0 : current;
    const labels = ['تم القبول', 'في الطريق', 'جاري التنفيذ', 'مكتمل'];
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Row(
        children: List.generate(stages.length, (i) {
          final done = i <= safeCurrent;
          return Expanded(
            child: Column(
              children: [
                Row(children: [
                  Expanded(
                    child: Container(
                      height: 4,
                      color: i == 0
                          ? Colors.transparent
                          : (done ? const Color(0xFF1769E0) : Colors.grey.shade300),
                    ),
                  ),
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: done
                        ? const Color(0xFF1769E0)
                        : Colors.grey.shade300,
                    child: Icon(
                      done ? Icons.check : Icons.circle,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 4,
                      color: i == stages.length - 1
                          ? Colors.transparent
                          : (i < safeCurrent
                              ? const Color(0xFF1769E0)
                              : Colors.grey.shade300),
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: done ? const Color(0xFF1769E0) : Colors.grey,
                      fontWeight: done ? FontWeight.bold : FontWeight.normal,
                    )),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _card(Map<String, dynamic> r) {
    final id = r['id'].toString();
    final imagesCount = (r['image_urls'] as List?)?.length ?? 0;
    final canAccept = _showAvailable;
    final accepting = _acceptingId == id;
    final advancing = _advancingId == id;
    final expanded = _expandedIds.contains(id);
    final latitude = r['latitude']?.toString() ?? '';
    final longitude = r['longitude']?.toString() ?? '';
    final hasCoordinates = latitude.isNotEmpty && longitude.isNotEmpty;
    final phone =
        r['customer_phone']?.toString() ?? r['phone']?.toString() ?? '';
    final customerName =
        r['customer_name']?.toString() ?? r['full_name']?.toString() ?? '';
    final status = r['status']?.toString();

    String nextButtonLabel = 'الانتقال للمرحلة التالية';
    if (status == 'accepted') {
      nextButtonLabel = 'الانتقال إلى: الفني في الطريق';
    } else if (status == 'on_the_way') {
      nextButtonLabel = 'الانتقال إلى: جاري التنفيذ';
    } else if (status == 'in_progress') {
      nextButtonLabel = 'إنهاء وتكتمل الخدمة';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                r['service_type']?.toString() ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
            Text(
              'SY-${id.substring(0, id.length < 8 ? id.length : 8).toUpperCase()}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            'الحالة: ${_arabicRequestStatus(status)}',
            style: const TextStyle(
                color: Color(0xFF1769E0), fontWeight: FontWeight.w600),
          ),
          if (!_showAvailable) _progressView(status),
          const SizedBox(height: 8),
          Text(
            r['description']?.toString().isNotEmpty == true
                ? r['description'].toString()
                : 'لا يوجد وصف إضافي للعطل',
            maxLines: expanded ? null : 2,
            overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          _detailLine(Icons.location_on_outlined, 'العنوان',
              r['address']?.toString() ?? ''),
          _detailLine(Icons.event_outlined, 'موعد الزيارة', _visitText(r)),
          if (expanded) ...[
            _detailLine(Icons.person_outline, 'اسم العميل', customerName),
            _detailLine(Icons.phone_outlined, 'هاتف العميل', phone),
            if (hasCoordinates)
              _detailLine(
                  Icons.map_outlined, 'الإحداثيات', '$latitude, $longitude'),
            _detailLine(
                Icons.calendar_today_outlined,
                'تاريخ الطلب',
                r['created_at'] == null
                    ? ''
                    : _formatDateTime(
                        DateTime.tryParse(r['created_at'].toString())
                            ?.toLocal())),
            if (imagesCount > 0)
              _detailLine(Icons.photo_library_outlined, 'الصور المرفقة',
                  '$imagesCount صورة مرفقة بالطلب'),
            if (r['notes'] != null)
              _detailLine(
                  Icons.notes_outlined, 'ملاحظات', r['notes'].toString()),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => setState(() {
              if (expanded) {
                _expandedIds.remove(id);
              } else {
                _expandedIds.add(id);
              }
            }),
            icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
            label: Text(expanded ? 'إخفاء التفاصيل' : 'تفاصيل الطلب'),
          ),
          if (expanded && r['address'] != null) ...[
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                    ClipboardData(text: r['address'].toString()));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم نسخ العنوان')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('نسخ العنوان'),
            ),
          ],
          if (canAccept) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _acceptingId != null ? null : () => _accept(id),
                icon: accepting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(accepting ? 'جاري القبول...' : 'قبول الطلب'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1769E0),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ] else if (status != 'completed') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _advancingId != null ? null : () => _advanceStatus(id),
                icon: advancing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.arrow_forward_rounded),
                label: Text(advancing ? 'جاري التحديث...' : nextButtonLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1769E0),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _empty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.inbox_rounded, size: 62, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Center(
          child: Text(
            _showAvailable
                ? 'لا توجد طلبات متاحة لتخصصاتك حاليًا'
                : 'لم تقبل أي طلب بعد',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        if (_showAvailable)
          const Padding(
            padding: EdgeInsets.fromLTRB(32, 10, 32, 0),
            child: Text(
              'تظهر لك الطلبات التي تطابق تخصصاتك فقط، وبشرط أن يكون حسابك معتمدًا من الإدارة. اسحب للأسفل للتحديث.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.6),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFEAF1FA),
        appBar: AppBar(
          title: Text(_showAvailable ? 'الطلبات المتاحة' : 'الطلبات الجارية',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Column(children: [
          const SizedBox(height: 10),
          SizedBox(
            height: 58,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final category = categories[index];
                return ChoiceChip(
                  label: Text(category),
                  selected: _selectedCategory == category,
                  onSelected: (_) =>
                      setState(() => _selectedCategory = category),
                  selectedColor: const Color(0xFFDCE9FF),
                  labelStyle: TextStyle(
                    color: _selectedCategory == category
                        ? const Color(0xFF1769E0)
                        : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Colors.red, size: 50),
                              const SizedBox(height: 12),
                              const Text('تعذر تحميل الطلبات',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text(_error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.grey)),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _load,
                                icon: const Icon(Icons.refresh),
                                label: const Text('إعادة المحاولة'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: visible.isEmpty
                            ? _empty()
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(16),
                                itemCount: visible.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, i) => _card(visible[i]),
                              ),
                      ),
          ),
        ]),
      ),
    );
  }
}

class MyRequestsPage extends StatefulWidget {
  const MyRequestsPage({super.key});

  @override
  State<MyRequestsPage> createState() => _MyRequestsPageState();
}

class _MyRequestsPageState extends State<MyRequestsPage> {
  int selectedTab = 0;
  final tabs = const ['الجارية', 'المكتملة', 'الملغاة'];

  bool isLoading = true;
  bool needsLogin = false;
  String? errorMessage;

  List<MaintenanceRequest> requests = [];
  StreamSubscription<AuthState>? _authSub;
  RealtimeChannel? _requestsChannel;

  @override
  void initState() {
    super.initState();
    loadRequests();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.signedOut) {
        loadRequests();
      }
    });

    final supabase = Supabase.instance.client;
    _requestsChannel = supabase
        .channel('public:service_requests_customer')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'service_requests',
          callback: (payload) {
            if (mounted) loadRequests();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _requestsChannel?.unsubscribe();
    _authSub?.cancel();
    super.dispose();
  }

  String translateStatus(String? status) {
    switch (status) {
      case 'pending':
        return 'بانتظار قبول فني';
      case 'accepted':
        return 'تم قبول الطلب';
      case 'on_the_way':
        return 'الفني في الطريق';
      case 'in_progress':
        return 'جاري التنفيذ';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      default:
        return status ?? 'بانتظار قبول فني';
    }
  }

  Future<void> loadRequests() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      needsLogin = false;
      errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        setState(() {
          requests = [];
          needsLogin = true;
          isLoading = false;
        });
        return;
      }

      final data = await supabase
          .from('service_requests')
          .select()
          .eq('customer_id', user.id)
          .order('created_at', ascending: false);

      final loadedRequests = (data as List).map((item) {
        final row = Map<String, dynamic>.from(item);

        final requestId = row['id'].toString();
        final visitAt = row['visit_at'];

        final imageUrls = row['image_urls'] as List? ?? [];

        final createdAt = DateTime.tryParse(
              row['created_at']?.toString() ?? '',
            ) ??
            DateTime.now();

        final visitDateTime = visitAt == null
            ? null
            : DateTime.tryParse(visitAt.toString())?.toLocal();

        return MaintenanceRequest(
          id: requestId,
          number: 'SY-${requestId.substring(0, 8).toUpperCase()}',
          service: row['service_type']?.toString() ?? '',
          description: row['description']?.toString() ?? '',
          address: row['address']?.toString() ?? '',
          visitType: visitAt == null ? 'emergency' : 'scheduled',
          visitDateTime: visitDateTime,
          imagesCount: imageUrls.length,
          imageUrls: imageUrls.map((e) => e.toString()).toList(),
          createdAt: createdAt.toLocal(),
          latitude: (row['latitude'] as num?)?.toDouble(),
          longitude: (row['longitude'] as num?)?.toDouble(),
          status: translateStatus(row['status']?.toString()),
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        requests = loadedRequests;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = error.toString();
      });
    }
  }

  List<MaintenanceRequest> get filteredRequests {
    final statuses = [
      [
        'بانتظار قبول فني',
        'تم قبول الطلب',
        'الفني في الطريق',
        'جاري التنفيذ',
      ],
      ['مكتمل'],
      ['ملغي'],
    ];

    return requests
        .where(
          (request) => statuses[selectedTab].contains(request.status),
        )
        .toList();
  }

  Color statusColor(String status) {
    if (status == 'مكتمل') return Colors.green;
    if (status == 'ملغي') return Colors.red;

    if (status == 'جاري التنفيذ' || status == 'الفني في الطريق') {
      return Colors.orange;
    }

    return const Color(0xFF1769E0);
  }

  bool canCustomerManage(MaintenanceRequest request) {
    return [
      'بانتظار قبول فني',
      'تم قبول الطلب',
      'الفني في الطريق',
    ].contains(request.status);
  }

  Future<void> editRequest(MaintenanceRequest request) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RequestPage(editRequest: request),
      ),
    );
    if (mounted) await loadRequests();
  }

  Future<void> cancelRequest(MaintenanceRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إلغاء طلب الصيانة'),
        content: const Text(
          'هل أنت متأكد من إلغاء هذا الطلب؟ لا يمكن التراجع عن الإلغاء من التطبيق.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await Supabase.instance.client.rpc(
        'customer_cancel_service_request',
        params: {'p_request_id': request.id},
      );
      final ok = result is Map && result['success'] == true;
      if (!ok) {
        throw Exception(result is Map
            ? result['message']?.toString() ?? 'تعذر إلغاء الطلب'
            : 'تعذر إلغاء الطلب');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء الطلب')),
      );
      await loadRequests();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إلغاء الطلب: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayedRequests = filteredRequests;

    return Column(
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: List.generate(tabs.length, (index) {
              final isSelected = selectedTab == index;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: SizedBox(
                      width: double.infinity,
                      child: Text(
                        tabs[index],
                        textAlign: TextAlign.center,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        selectedTab = index;
                      });
                    },
                    selectedColor: const Color(0xFFDCE9FF),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? const Color(0xFF1769E0)
                          : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Builder(
            builder: (context) {
              if (isLoading) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF1769E0),
                  ),
                );
              }

              if (needsLogin) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 60,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'سجّل دخولك لمتابعة طلباتك',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'بعد تسجيل الدخول هتلاقي طلباتك هنا.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (errorMessage != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 50,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'تعذر تحميل طلباتك',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: loadRequests,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (displayedRequests.isEmpty) {
                return RefreshIndicator(
                  onRefresh: loadRequests,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: 350,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'مفيش طلبات ${tabs[selectedTab]} حاليًا',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'لما تبعت طلب صيانة جديد هتلاقيه ظاهر هنا.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: loadRequests,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: displayedRequests.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final request = displayedRequests[index];
                    final color = statusColor(request.status);

                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RequestDetailsPage(
                              request: request,
                              onEdit: canCustomerManage(request)
                                  ? () => editRequest(request)
                                  : null,
                              onCancel: canCustomerManage(request)
                                  ? () => cancelRequest(request)
                                  : null,
                            ),
                          ),
                        ).then((_) => loadRequests());
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    request.service,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    request.status,
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'رقم الطلب: ${request.number}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              request.visitType == 'emergency'
                                  ? 'زيارة طارئة الآن'
                                  : 'موعد الزيارة: ${_formatDateTime(request.visitDateTime)}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'عرض التفاصيل',
                                  style: TextStyle(
                                    color: Color(0xFF1769E0),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_back_ios,
                                  size: 13,
                                  color: Color(0xFF1769E0),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

String _formatDateTime(DateTime? dateTime) {
  if (dateTime == null) return 'لم يتم تحديد موعد';

  final date = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');

  return '$date - $hour:$minute';
}

class RequestDetailsPage extends StatefulWidget {
  final MaintenanceRequest request;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;

  const RequestDetailsPage({
    super.key,
    required this.request,
    this.onEdit,
    this.onCancel,
  });

  @override
  State<RequestDetailsPage> createState() => _RequestDetailsPageState();
}

class _RequestDetailsPageState extends State<RequestDetailsPage> {
  late String currentStatus;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    currentStatus = widget.request.status;
    _listenRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  void _listenRealtime() {
    final supabase = Supabase.instance.client;
    _channel = supabase
        .channel('request_details_${widget.request.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'service_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.request.id,
          ),
          callback: (payload) {
            if (!mounted) return;
            setState(() {
              final newDbStatus = payload.newRecord['status']?.toString();
              currentStatus = _translateStatus(newDbStatus);
            });
          },
        )
        .subscribe();
  }

  String _translateStatus(String? status) {
    switch (status) {
      case 'pending':
        return 'بانتظار قبول فني';
      case 'accepted':
        return 'تم قبول الطلب';
      case 'on_the_way':
        return 'الفني في الطريق';
      case 'in_progress':
        return 'جاري التنفيذ';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      default:
        return status ?? 'بانتظار قبول فني';
    }
  }

  Widget _progressView(String status) {
    const stages = ['accepted', 'on_the_way', 'in_progress', 'completed'];

    String dbKey = 'accepted';
    if (status == 'الفني في الطريق') dbKey = 'on_the_way';
    if (status == 'جاري التنفيذ') dbKey = 'in_progress';
    if (status == 'مكتمل') dbKey = 'completed';

    final current = stages.indexOf(dbKey);
    final safeCurrent = current < 0 ? 0 : current;
    const labels = ['تم القبول', 'في الطريق', 'جاري التنفيذ', 'مكتمل'];

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 10),
      child: Row(
        children: List.generate(stages.length, (i) {
          final done = i <= safeCurrent;
          return Expanded(
            child: Column(
              children: [
                Row(children: [
                  Expanded(
                    child: Container(
                      height: 4,
                      color: i == 0
                          ? Colors.transparent
                          : (done ? const Color(0xFF1769E0) : Colors.grey.shade300),
                    ),
                  ),
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: done
                        ? const Color(0xFF1769E0)
                        : Colors.grey.shade300,
                    child: Icon(
                      done ? Icons.check : Icons.circle,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 4,
                      color: i == stages.length - 1
                          ? Colors.transparent
                          : (i < safeCurrent
                              ? const Color(0xFF1769E0)
                              : Colors.grey.shade300),
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: done ? const Color(0xFF1769E0) : Colors.grey,
                      fontWeight: done ? FontWeight.bold : FontWeight.normal,
                    )),
              ],
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8FC),
        appBar: AppBar(
          title: const Text('تفاصيل الطلب'),
          backgroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.request.service,
                      style: const TextStyle(
                          fontSize: 21, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('رقم الطلب: ${widget.request.number}',
                      style: const TextStyle(color: Colors.grey)),
                  const Divider(height: 28),
                  _detailRow('حالة الطلب', currentStatus),
                  if (currentStatus != 'بانتظار قبول فني' &&
                      currentStatus != 'ملغي')
                    _progressView(currentStatus),
                  _detailRow(
                      'نوع الزيارة',
                      widget.request.visitType == 'emergency'
                          ? 'طارئة الآن'
                          : 'زيارة بموعد'),
                  _detailRow(
                      'موعد الزيارة',
                      widget.request.visitType == 'emergency'
                          ? 'في أقرب وقت'
                          : _formatDateTime(widget.request.visitDateTime)),
                  _detailRow('العنوان', widget.request.address),
                  _detailRow('وصف المشكلة', widget.request.description),
                  _detailRow('الصور المرفقة', '${widget.request.imagesCount} صورة'),
                  _detailRow('تاريخ إنشاء الطلب',
                      _formatDateTime(widget.request.createdAt)),
                ],
              ),
            ),
            if (widget.onEdit != null || widget.onCancel != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (widget.onEdit != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onEdit,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('تعديل الطلب'),
                      ),
                    ),
                  if (widget.onEdit != null && widget.onCancel != null)
                    const SizedBox(width: 10),
                  if (widget.onCancel != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onCancel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('إلغاء الطلب'),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16)),
              child: const Text(
                'يتم تحديث مرحلة تنفيذ طلبك لحظياً بمجرد قيام الفني بالتنقل إلى الخطوة التالية.',
                style: TextStyle(color: Colors.grey, height: 1.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class AccountPage extends StatefulWidget {
  const AccountPage(
      {super.key,
      this.onOpenRequests,
      this.onOpenAvailable,
      this.onOpenOngoing});

  final VoidCallback? onOpenRequests;
  final VoidCallback? onOpenAvailable;
  final VoidCallback? onOpenOngoing;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  static const Color _blue = Color(0xFF1769E0);
  static const Color _darkBlue = Color(0xFF0B4DB0);
  static const Color _pageBg = Color(0xFFF3F6FB);

  StreamSubscription<AuthState>? _authSub;

  bool _loadingData = false;
  bool _uploadingAvatar = false;
  int _total = 0;
  int _active = 0;
  int _completed = 0;
  Map<String, dynamic>? _techProfile;
  List<String> _techServices = [];

  SupabaseClient get _supabase => Supabase.instance.client;
  User? get _user => _supabase.auth.currentUser;
  bool get _isLoggedIn => _user != null;
  bool get _isTechnician =>
      _user?.userMetadata?['account_type'] == 'technician';

  String get _displayName {
    final name = _user?.userMetadata?['full_name']?.toString().trim();
    if (name == null || name.isEmpty) {
      return _isTechnician ? 'فني صيانتي' : 'عميل صيانتي';
    }
    return name;
  }

  String get _roleLabel {
    if (!_isTechnician) return 'عميل';
    final p = _techProfile;
    if (p == null) return 'فني';
    if (p['is_approved'] == true) return 'فني معتمد';
    if (p['application_status'] == 'rejected') return 'فني · طلب مرفوض';
    return 'فني · قيد المراجعة';
  }

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _authSub = _supabase.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      setState(() {});
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.signedOut ||
          data.event == AuthChangeEvent.userUpdated) {
        _loadProfileData();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final user = _user;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _total = 0;
        _active = 0;
        _completed = 0;
        _techProfile = null;
        _techServices = [];
        _loadingData = false;
      });
      return;
    }

    if (mounted) setState(() => _loadingData = true);

    try {
      final isTech = _isTechnician;

      final rows = await _supabase
          .from('service_requests')
          .select('status')
          .eq(isTech ? 'technician_id' : 'customer_id', user.id);

      final statuses = (rows as List)
          .map((e) => (e as Map)['status']?.toString() ?? '')
          .toList();

      Map<String, dynamic>? profile;
      List<String> services = [];

      if (isTech) {
        final p = await _supabase
            .from('technician_profiles')
            .select(
                'is_approved, application_status, service_area, rejection_reason')
            .eq('user_id', user.id)
            .maybeSingle();
        profile = p == null ? null : Map<String, dynamic>.from(p);

        final sv = await _supabase
            .from('technician_services')
            .select('service_type')
            .eq('technician_id', user.id);
        services = (sv as List)
            .map((e) => (e as Map)['service_type'].toString())
            .toList();
      }

      if (!mounted) return;
      setState(() {
        _total = statuses.length;
        _completed = statuses.where((e) => e == 'completed').length;
        _active = statuses
            .where((e) => (_isTechnician
                ? const ['accepted', 'on_the_way', 'in_progress']
                : const ['pending', 'accepted', 'on_the_way', 'in_progress'])
                .contains(e))
            .length;
        _techProfile = profile;
        _techServices = services;
        _loadingData = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  Future<void> _openCustomerLogin() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CustomerLoginPage()),
    );
  }

  Future<void> _openTechnicianLogin() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  Future<void> _openRegister() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );
  }

  Future<void> _editName() async {
    final current = _user?.userMetadata?['full_name']?.toString().trim() ?? '';
    final controller = TextEditingController(text: current);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تعديل الاسم'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'الاسم بالكامل',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(milliseconds: 400), controller.dispose);

    if (newName == null || newName.isEmpty || newName == current) return;

    try {
      await _supabase.auth.updateUser(
        UserAttributes(data: {'full_name': newName}),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث الاسم')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحديث الاسم: $e')),
      );
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تسجيل الخروج'),
          content: const Text('هل تريد تسجيل الخروج من حسابك؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('خروج'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) await _logout();
  }

  Future<void> _logout() async {
    try {
      await _supabase.auth.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل الخروج بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تسجيل الخروج: $e')),
      );
    }
  }

  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) {
    return Material(
      color: Colors.white,
      elevation: 1.5,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: padding == null ? child : Padding(padding: padding, child: child),
    );
  }

  Widget _roleBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isTechnician ? Icons.handyman_rounded : Icons.person_rounded,
            color: Colors.white,
            size: 15,
          ),
          const SizedBox(width: 6),
          Text(
            _roleLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeTechnicianAvatar() async {
    if (!_isTechnician || _user == null || _uploadingAvatar) return;

    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1200,
      );
      if (image == null) return;

      setState(() => _uploadingAvatar = true);

      final userId = _user!.id;
      final extension = image.name.contains('.')
          ? image.name.split('.').last.toLowerCase()
          : 'jpg';
      final safeExtension = ['jpg', 'jpeg', 'png', 'webp'].contains(extension)
          ? extension
          : 'jpg';
      final path =
          '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$safeExtension';
      final bytes = await image.readAsBytes();

      await _supabase.storage.from('profile-images').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: image.mimeType ??
                  (safeExtension == 'png'
                      ? 'image/png'
                      : safeExtension == 'webp'
                          ? 'image/webp'
                          : 'image/jpeg'),
              upsert: true,
            ),
          );

      final publicUrl =
          _supabase.storage.from('profile-images').getPublicUrl(path);

      await _supabase.auth.updateUser(
        UserAttributes(data: {'avatar_url': publicUrl}),
      );

      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث الصورة الشخصية بنجاح')),
      );
    } on StorageException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر رفع الصورة: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تغيير الصورة: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Widget _headerCard() {
    final name = _displayName;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 10, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_blue, _darkBlue],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _blue.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Colors.white,
                backgroundImage: (_user?.userMetadata?['avatar_url']
                            is String &&
                        (_user!.userMetadata!['avatar_url'] as String)
                            .isNotEmpty)
                    ? NetworkImage(_user!.userMetadata!['avatar_url'] as String)
                    : null,
                child: (_user?.userMetadata?['avatar_url'] is String &&
                        (_user!.userMetadata!['avatar_url'] as String)
                            .isNotEmpty)
                    ? null
                    : Text(
                        name.isEmpty
                            ? 'ص'
                            : String.fromCharCode(name.runes.first),
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: _blue),
                      ),
              ),
              if (_isTechnician)
                Positioned(
                  bottom: -3,
                  right: -3,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _uploadingAvatar ? null : _changeTechnicianAvatar,
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: _uploadingAvatar
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.camera_alt,
                                size: 16, color: _blue),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _user?.email ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 10),
                _roleBadge(),
              ],
            ),
          ),
          IconButton(
            tooltip: 'تعديل الاسم',
            onPressed: _editName,
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, int value, IconData icon, Color color) {
    return Expanded(
      child: _card(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              _loadingData ? '…' : '$value',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsRow() {
    return Row(
      children: [
        _statBox(
          _isTechnician ? 'الطلبات المقبولة' : 'إجمالي الطلبات',
          _total,
          Icons.assignment_outlined,
          _blue,
        ),
        const SizedBox(width: 10),
        _statBox('جارية', _active, Icons.timelapse_rounded, Colors.orange),
        const SizedBox(width: 10),
        _statBox(
            'مكتملة', _completed, Icons.check_circle_outline, Colors.green),
      ],
    );
  }

  Widget _technicianStatusCard() {
    final p = _techProfile;
    final approved = p?['is_approved'] == true;
    final rejected = p?['application_status'] == 'rejected';
    final color =
        approved ? Colors.green : (rejected ? Colors.red : Colors.orange);
    final icon = approved
        ? Icons.verified_rounded
        : (rejected ? Icons.cancel_rounded : Icons.hourglass_top_rounded);
    final title = p == null
        ? 'لم يتم العثور على طلب الانضمام'
        : approved
            ? 'حسابك معتمد'
            : rejected
                ? 'تم رفض طلب الانضمام'
                : 'طلب الانضمام قيد المراجعة';
    final reason = rejected ? (p?['rejection_reason']?.toString()) : null;
    final area = p?['service_area']?.toString();

    return _card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (p != null && !approved && !rejected)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'ستتمكن من استلام الطلبات بعد اعتماد الإدارة لحسابك.',
                style: TextStyle(color: Colors.grey, height: 1.5),
              ),
            ),
          if (reason != null && reason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('السبب: $reason'),
            ),
          if (area != null && area.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text('منطقة العمل: $area'),
                ],
              ),
            ),
          if (_techServices.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _techServices
                    .map(
                      (service) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF1FA),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          service,
                          style: const TextStyle(
                            color: _blue,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(icon, color: _blue, size: 22),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard() {
    final phone = _user?.userMetadata?['phone']?.toString();
    final created = DateTime.tryParse(_user?.createdAt ?? '')?.toLocal();
    return _card(
      child: Column(
        children: [
          _infoRow(
              Icons.email_outlined, 'البريد الإلكتروني', _user?.email ?? '-'),
          if (phone != null && phone.isNotEmpty) ...[
            const Divider(height: 1),
            _infoRow(Icons.phone_outlined, 'رقم الهاتف', phone),
          ],
          if (created != null) ...[
            const Divider(height: 1),
            _infoRow(
              Icons.calendar_month_outlined,
              'عضو منذ',
              '${created.year}/${created.month.toString().padLeft(2, '0')}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = _blue,
    bool showArrow = true,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: color == _blue ? Colors.black87 : color,
        ),
      ),
      trailing: showArrow
          ? Icon(Icons.chevron_left, color: Colors.grey.shade500)
          : null,
    );
  }

  Widget _menuCard() {
    final tiles = <Widget>[
      if (_isTechnician) ...[
        if (widget.onOpenAvailable != null)
          _menuTile(
              icon: Icons.inbox_outlined,
              title: 'الطلبات المتاحة',
              onTap: widget.onOpenAvailable!),
        if (widget.onOpenOngoing != null)
          _menuTile(
              icon: Icons.handyman_outlined,
              title: 'الطلبات الجارية',
              onTap: widget.onOpenOngoing!),
      ] else if (widget.onOpenRequests != null)
        _menuTile(
          icon: Icons.receipt_long_outlined,
          title: 'طلباتي',
          onTap: widget.onOpenRequests!,
        ),
      _menuTile(
        icon: Icons.edit_outlined,
        title: 'تعديل الاسم',
        onTap: _editName,
      ),
      _menuTile(
        icon: Icons.logout_rounded,
        title: 'تسجيل الخروج',
        color: Colors.red,
        showArrow: false,
        onTap: _confirmLogout,
      ),
    ];

    final children = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      if (i > 0) children.add(const Divider(height: 1));
      children.add(tiles[i]);
    }

    return _card(child: Column(children: children));
  }

  Widget _buildProfile() {
    return ColoredBox(
      color: _pageBg,
      child: RefreshIndicator(
        onRefresh: _loadProfileData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _headerCard(),
            const SizedBox(height: 16),
            _statsRow(),
            if (_isTechnician) ...[
              const SizedBox(height: 16),
              _technicianStatusCard(),
            ],
            const SizedBox(height: 16),
            _infoCard(),
            const SizedBox(height: 16),
            _menuCard(),
          ],
        ),
      ),
    );
  }

  Widget _technicianEntry() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: const Color(0xFFEAF1FA),
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: _openTechnicianLogin,
            child: const SizedBox(
              width: 43,
              height: 43,
              child: Icon(
                Icons.handyman_rounded,
                color: _blue,
                size: 23,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'دخول الفنيين',
          style: TextStyle(
            color: _blue,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLoggedOut() {
    return Stack(
      children: [
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 43,
                  backgroundColor: Color(0xFFEAF1FA),
                  child: Icon(Icons.person_outline, size: 52, color: _blue),
                ),
                const SizedBox(height: 16),
                const Text(
                  'أهلاً بيك في صيانتي',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'سجل دخولك أو أنشئ حساب جديد عشان تقدر تطلب خدمات الصيانة وتتابع طلباتك.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.login),
                    label: const Text('تسجيل الدخول'),
                    onPressed: _openCustomerLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text('إنشاء حساب جديد'),
                    onPressed: _openRegister,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _blue,
                      side: const BorderSide(color: _blue),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 10,
          left: 14,
          child: _technicianEntry(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: _isLoggedIn ? _buildProfile() : _buildLoggedOut(),
    );
  }
}

class SimpleSectionPage extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const SimpleSectionPage({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: const Color(0xFF1769E0)),
            const SizedBox(height: 14),
            Text(title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class RequestPage extends StatefulWidget {
  final String? initialService;
  final MaintenanceRequest? editRequest;

  const RequestPage({super.key, this.initialService, this.editRequest});

  @override
  State<RequestPage> createState() => _RequestPageState();
}

class _RequestPageState extends State<RequestPage> {
  final descriptionController = TextEditingController();
  final addressController = TextEditingController();

  final List<String> services = [
    'كهرباء',
    'سباكة',
    'تكييف',
    'نجارة',
    'نقاشة',
    'أجهزة منزلية',
    'غسالات',
    'ثلاجات',
    'ديب فريزر',
    'تكييفات',
    'شاشات وتليفزيونات',
    'بوتاجازات وأفران',
    'سخانات كهرباء وغاز',
    'ميكروويف',
    'غسالات أطباق',
    'كولدير ومبرد مياه',
    'خلاطات',
    'مراوح',
    'مكانس كهربائية',
    'تنظيف',
    'مكافحة حشرات',
    'تعقيم',
    'نقل أثاث',
    'فك وتركيب أثاث',
    'تركيب',
    'تركيب أجهزة ومعدات',
    'خدمات أخرى',
  ];

  String? selectedService;
  String visitType = 'scheduled';
  DateTime? selectedVisitDate;
  TimeOfDay? selectedVisitTime;

  Position? currentPosition;
  final MapController mapController = MapController();

  latlong.LatLng? selectedLocation;

  bool isGettingLocation = false;
  bool isSubmitting = false;

  final ImagePicker imagePicker = ImagePicker();
  final List<XFile> selectedImages = [];
  final List<String> existingImagePaths = [];
  final Map<String, String> existingImageSignedUrls = {};

  bool get isEditMode => widget.editRequest != null;

  Future<void> _loadExistingImageUrls() async {
    final storage = Supabase.instance.client.storage.from('service-images');
    for (final path in existingImagePaths) {
      try {
        final url = await storage.createSignedUrl(path, 3600);
        if (!mounted) return;
        setState(() => existingImageSignedUrls[path] = url);
      } catch (_) {}
    }
  }

  void updateMapLocation(latlong.LatLng location) {
    setState(() {
      selectedLocation = location;
    });
  }

  Future<void> getCurrentLocation() async {
    setState(() {
      isGettingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('خدمة الموقع غير مفعلة');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception('لم يتم السماح بالوصول للموقع');
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('يرجى السماح للموقع من إعدادات المتصفح');
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      final location = latlong.LatLng(
        position.latitude,
        position.longitude,
      );

      setState(() {
        currentPosition = position;
        selectedLocation = location;
      });

      mapController.move(location, 16);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديد موقعك بنجاح'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تحديد الموقع: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isGettingLocation = false;
        });
      }
    }
  }

  Future<void> addImage(ImageSource source) async {
    try {
      final XFile? image = await imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
      );

      if (image != null && mounted) {
        setState(() {
          selectedImages.add(image);
        });
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر اختيار الصورة: $error'),
        ),
      );
    }
  }

  void showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('اختيار من المعرض'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  addImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('التقاط صورة بالكاميرا'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  addImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialService;
    if (initial != null && !services.contains(initial)) {
      services.add(initial);
    }
    final request = widget.editRequest;
    if (request != null) {
      if (!services.contains(request.service)) services.add(request.service);
      selectedService = request.service;
      descriptionController.text = request.description;
      addressController.text = request.address;
      selectedLocation = request.latitude != null && request.longitude != null
          ? latlong.LatLng(request.latitude!, request.longitude!)
          : null;
      visitType = request.visitType;
      if (request.visitDateTime != null) {
        selectedVisitDate = DateTime(
          request.visitDateTime!.year,
          request.visitDateTime!.month,
          request.visitDateTime!.day,
        );
        selectedVisitTime = TimeOfDay.fromDateTime(request.visitDateTime!);
      }
      existingImagePaths.addAll(request.imageUrls);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && selectedLocation != null) {
          mapController.move(selectedLocation!, 15);
        }
      });
      _loadExistingImageUrls();
    } else {
      selectedService = initial;
    }
  }

  @override
  void dispose() {
    descriptionController.dispose();
    addressController.dispose();
    super.dispose();
  }

  Future<void> selectVisitDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: selectedVisitDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2, now.month, now.day),
      helpText: 'اختر تاريخ الزيارة',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
    );

    if (date != null && mounted) {
      setState(() {
        selectedVisitDate = date;
      });
    }
  }

  Future<void> selectVisitTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: selectedVisitTime ?? TimeOfDay.now(),
      helpText: 'اختر وقت الزيارة',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
    );

    if (time != null && mounted) {
      setState(() {
        selectedVisitTime = time;
      });
    }
  }

  Future<void> submitRequest() async {
    if (isSubmitting) return;

    if (selectedService == null ||
        descriptionController.text.trim().isEmpty ||
        addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'من فضلك أكمل نوع الخدمة والوصف والعنوان',
          ),
        ),
      );
      return;
    }

    if (selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('من فضلك حدد موقع الصيانة على الخريطة'),
        ),
      );
      return;
    }

    DateTime? appointment;

    if (visitType == 'scheduled') {
      if (selectedVisitDate == null || selectedVisitTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('من فضلك اختار تاريخ ووقت الزيارة'),
          ),
        );
        return;
      }

      appointment = DateTime(
        selectedVisitDate!.year,
        selectedVisitDate!.month,
        selectedVisitDate!.day,
        selectedVisitTime!.hour,
        selectedVisitTime!.minute,
      );

      if (!appointment.isAfter(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('موعد الزيارة لازم يكون في وقت لاحق'),
          ),
        );
        return;
      }
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('من فضلك سجل الدخول أولاً'),
        ),
      );
      return;
    }

    if (user.userMetadata?['account_type'] != 'customer') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب تسجيل الدخول بحساب عميل لإرسال الطلب'),
        ),
      );
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    final uploadedPaths = <String>[];

    try {
      for (int i = 0; i < selectedImages.length; i++) {
        final image = selectedImages[i];
        final bytes = await image.readAsBytes();

        final extension = image.name.contains('.')
            ? image.name.split('.').last.toLowerCase()
            : 'jpg';
        final fileName =
            '${DateTime.now().microsecondsSinceEpoch}_$i.$extension';
        final imagePath = '${user.id}/$fileName';

        String contentType = 'image/jpeg';
        if (extension == 'png') {
          contentType = 'image/png';
        } else if (extension == 'webp') {
          contentType = 'image/webp';
        }

        await supabase.storage.from('service-images').uploadBinary(
              imagePath,
              bytes,
              fileOptions: FileOptions(
                contentType: contentType,
                upsert: false,
              ),
            );

        uploadedPaths.add(imagePath);
      }

      final allImagePaths = <String>[
        ...existingImagePaths,
        ...uploadedPaths,
      ];

      if (isEditMode) {
        final result = await supabase.rpc(
          'customer_update_service_request',
          params: {
            'p_request_id': widget.editRequest!.id,
            'p_service_type': selectedService!,
            'p_description': descriptionController.text.trim(),
            'p_address': addressController.text.trim(),
            'p_latitude': selectedLocation!.latitude,
            'p_longitude': selectedLocation!.longitude,
            'p_visit_at': appointment?.toUtc().toIso8601String(),
            'p_image_urls': allImagePaths,
          },
        );
        final ok = result is Map && result['success'] == true;
        if (!ok) {
          throw Exception(result is Map
              ? result['message']?.toString() ?? 'تعذر تعديل الطلب'
              : 'تعذر تعديل الطلب');
        }
      } else {
        final requestData = {
          'customer_id': user.id,
          'service_type': selectedService!,
          'description': descriptionController.text.trim(),
          'address': addressController.text.trim(),
          'latitude': selectedLocation!.latitude,
          'longitude': selectedLocation!.longitude,
          'visit_at': appointment?.toUtc().toIso8601String(),
          'image_urls': allImagePaths,
          'status': 'pending',
        };
        await supabase.from('service_requests').insert(requestData);
      }

      if (!mounted) return;

      final visitDetails = visitType == 'emergency'
          ? 'نوع الزيارة: طارئة الآن'
          : 'موعد الزيارة: '
              '${selectedVisitDate!.day}/'
              '${selectedVisitDate!.month}/'
              '${selectedVisitDate!.year}'
              ' - ${selectedVisitTime!.format(context)}';

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(isEditMode ? 'تم تعديل طلبك بنجاح' : 'تم إرسال طلبك بنجاح'),
          content: Text(
            '${isEditMode ? 'تم تحديث بيانات طلب الصيانة بنجاح.' : 'تم تسجيل طلب الصيانة في النظام بنجاح.'}\n\n'
            '$visitDetails\n\n'
            '${isEditMode ? 'تم حفظ التعديلات على طلبك.' : 'سيتمكن الفنيون المناسبون من الاطلاع على طلبك.'}',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pop(context);
              },
              child: const Text('حسنًا'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إرسال الطلب: $error'),
          duration: const Duration(seconds: 7),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isEditMode ? 'تعديل طلب الصيانة' : 'طلب صيانة جديد',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'خلينا نساعدك في حل المشكلة',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'املأ البيانات التالية عشان نقدر نوصلّك بالفني المناسب.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 25),
              const Text(
                'نوع الصيانة',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: selectedService,
                decoration: InputDecoration(
                  hintText: 'اختار نوع الصيانة',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: services.map((service) {
                  return DropdownMenuItem(
                    value: service,
                    child: Text(service),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedService = value;
                  });
                },
              ),
              const SizedBox(height: 22),
              const Text(
                'وصف المشكلة',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'اشرح لنا المشكلة بالتفصيل...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'موعد الزيارة',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: visitType == 'scheduled'
                        ? const Color(0xFF1769E0)
                        : const Color(0xFFD8E0EC),
                    width: visitType == 'scheduled' ? 1.5 : 1,
                  ),
                ),
                child: RadioListTile<String>(
                  value: 'scheduled',
                  groupValue: visitType,
                  activeColor: const Color(0xFF1769E0),
                  title: const Text(
                    'تحديد موعد زيارة',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'اختار اليوم والساعة المناسبة لزيارة الفني',
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        visitType = value;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: visitType == 'emergency'
                        ? Colors.red
                        : const Color(0xFFD8E0EC),
                    width: visitType == 'emergency' ? 1.5 : 1,
                  ),
                ),
                child: RadioListTile<String>(
                  value: 'emergency',
                  groupValue: visitType,
                  activeColor: Colors.red,
                  title: const Text(
                    'زيارة طارئة الآن',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'إرسال طلب فوري للبحث عن فني متاح',
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        visitType = value;
                      });
                    }
                  },
                ),
              ),
              if (visitType == 'scheduled') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: selectVisitDate,
                        icon: const Icon(Icons.calendar_month),
                        label: Text(
                          selectedVisitDate == null
                              ? 'اختيار اليوم'
                              : '${selectedVisitDate!.day}/'
                                  '${selectedVisitDate!.month}/'
                                  '${selectedVisitDate!.year}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: selectVisitTime,
                        icon: const Icon(Icons.access_time),
                        label: Text(
                          selectedVisitTime == null
                              ? 'اختيار الساعة'
                              : selectedVisitTime!.format(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 22),
              const Text(
                'صور العطل (اختياري)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'أضف صورًا توضح المشكلة ليسهل على الفني فهمها.',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: showImageSourceOptions,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: const Color(0xFFD8E0EC),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        color: Color(0xFF1769E0),
                        size: 30,
                      ),
                      SizedBox(height: 8),
                      Text('اضغط لإضافة صورة'),
                    ],
                  ),
                ),
              ),
              if (existingImagePaths.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'الصور الحالية — اضغط × لإزالتها',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 105,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: existingImagePaths.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final path = existingImagePaths[index];
                      final url = existingImageSignedUrls[path];
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 105,
                              height: 105,
                              child: url == null
                                  ? const ColoredBox(
                                      color: Color(0xFFE8EDF5),
                                      child: Center(
                                        child: Icon(Icons.image_outlined),
                                      ),
                                    )
                                  : Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          const Icon(Icons.broken_image),
                                    ),
                            ),
                          ),
                          Positioned(
                            top: 3,
                            left: 3,
                            child: IconButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () => setState(
                                        () => existingImagePaths.remove(path),
                                      ),
                              icon: const Icon(Icons.close),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.red,
                                padding: const EdgeInsets.all(4),
                                minimumSize: const Size(30, 30),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
              if (selectedImages.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 105,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: selectedImages.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final image = selectedImages[index];
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 105,
                              height: 105,
                              child: FutureBuilder<Uint8List>(
                                future: image.readAsBytes(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    return Image.memory(
                                      snapshot.data!,
                                      fit: BoxFit.cover,
                                    );
                                  }
                                  if (snapshot.hasError) {
                                    return const Icon(
                                      Icons.broken_image,
                                    );
                                  }
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                },
                              ),
                            ),
                          ),
                          Positioned(
                            top: 3,
                            left: 3,
                            child: IconButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () {
                                      setState(() {
                                        selectedImages.removeAt(index);
                                      });
                                    },
                              icon: const Icon(Icons.close),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.red,
                                padding: const EdgeInsets.all(4),
                                minimumSize: const Size(30, 30),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 22),
              const Text(
                'عنوان تنفيذ الصيانة',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: isGettingLocation || isSubmitting
                      ? null
                      : getCurrentLocation,
                  icon: isGettingLocation
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.my_location),
                  label: Text(
                    isGettingLocation
                        ? 'جاري تحديد موقعك...'
                        : 'حدد موقعي الحالي',
                  ),
                ),
              ),
              if (currentPosition != null) ...[
                const SizedBox(height: 10),
                const Text(
                  'تم تحديد الموقع بنجاح',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Text(
                'حدد مكان الصيانة على الخريطة',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 300,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: mapController,
                        options: MapOptions(
                          initialCenter: selectedLocation ??
                              const latlong.LatLng(31.0409, 31.3785),
                          initialZoom: 13,
                          onTap: (tapPosition, point) {
                            updateMapLocation(point);
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'project_1',
                            maxZoom: 19,
                          ),
                          MarkerLayer(
                            markers: selectedLocation == null
                                ? []
                                : [
                                    Marker(
                                      point: selectedLocation!,
                                      width: 45,
                                      height: 45,
                                      child: const Icon(
                                        Icons.location_pin,
                                        color: Colors.red,
                                        size: 45,
                                      ),
                                    ),
                                  ],
                          ),
                          RichAttributionWidget(
                            attributions: [
                              TextSourceAttribution(
                                'OpenStreetMap contributors',
                                onTap: () {},
                              ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        left: 10,
                        top: 10,
                        child: Column(
                          children: [
                            FloatingActionButton.small(
                              heroTag: 'zoom_in',
                              onPressed: () {
                                mapController.move(
                                  mapController.camera.center,
                                  mapController.camera.zoom + 1,
                                );
                              },
                              child: const Icon(Icons.add),
                            ),
                            const SizedBox(height: 8),
                            FloatingActionButton.small(
                              heroTag: 'zoom_out',
                              onPressed: () {
                                mapController.move(
                                  mapController.camera.center,
                                  mapController.camera.zoom - 1,
                                );
                              },
                              child: const Icon(Icons.remove),
                            ),
                            const SizedBox(height: 8),
                            FloatingActionButton.small(
                              heroTag: 'home_map',
                              onPressed: () {
                                mapController.move(
                                  latlong.LatLng(31.0409, 31.3785),
                                  13,
                                );
                              },
                              child: const Icon(Icons.home),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                selectedLocation == null
                    ? 'اضغط على الخريطة لتحديد مكان الصيانة'
                    : 'تم اختيار الموقع بنجاح',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addressController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'اكتب العنوان بالتفصيل...',
                  prefixIcon: const Icon(
                    Icons.location_on_outlined,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1769E0),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: isSubmitting
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 21,
                              height: 21,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(isEditMode
                                ? 'جاري حفظ التعديلات...'
                                : 'جاري إرسال الطلب...'),
                          ],
                        )
                      : Text(
                          isEditMode ? 'حفظ التعديلات' : 'إرسال طلب الصيانة',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}