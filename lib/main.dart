import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'auth_service.dart';
import 'models/app_services.dart';
import 'pages/account_page.dart';
import 'pages/home_widgets.dart';
import 'pages/my_requests_page.dart';
import 'pages/offers_page.dart';
import 'pages/request_helpers.dart';
import 'pages/request_page.dart';
import 'pages/services_page.dart';
import 'pages/technician_requests_page.dart';
import 'technician_application_page.dart';

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
      theme: AppTheme.lightTheme,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentIndex = 0;
  bool _isSideMenuOpen = false;
  // غيّرها إلى true لإرجاع صفحة العروض، وfalse لإخفائها
  final bool _hasOffers = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<AuthState>? _homeAuthSub;

  RealtimeChannel? _notifChannel;
  final List<Map<String, String>> _notifications = [];
  int _unreadNotifications = 0;

  bool get _isTechnician {
    final user = Supabase.instance.client.auth.currentUser;
    return user != null && AuthService.accountTypeOf(user) == 'technician';
  }

  int _maxIndexFor({required bool isTech, required bool hasOffers}) {
    if (isTech) return 2;
    return hasOffers ? 4 : 3;
  }

  final GlobalKey<TechnicianRequestsPageState> _availableKey =
      GlobalKey<TechnicianRequestsPageState>();
  final GlobalKey<TechnicianRequestsPageState> _ongoingKey =
      GlobalKey<TechnicianRequestsPageState>();
  final GlobalKey<MyRequestsPageState> _myRequestsKey =
      GlobalKey<MyRequestsPageState>();

  @override
  void initState() {
    super.initState();
    _setupNotificationsListener();
    _homeAuthSub =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;

      final isAuthRefresh = data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.signedOut ||
          data.event == AuthChangeEvent.tokenRefreshed ||
          data.event == AuthChangeEvent.userUpdated;

      if (isAuthRefresh) {
        final user = Supabase.instance.client.auth.currentUser;
        final isTech =
            user != null && AuthService.accountTypeOf(user) == 'technician';
        final maxIdx = _maxIndexFor(isTech: isTech, hasOffers: _hasOffers);
        setState(() {
          if (data.event == AuthChangeEvent.signedOut) {
            currentIndex = 0;
            _notifications.clear();
            _unreadNotifications = 0;
          } else if (isTech) {
            currentIndex = 0;
          } else {
            currentIndex = currentIndex.clamp(0, maxIdx);
          }
          _isSideMenuOpen = false;
        });
        _setupNotificationsListener();
      }
    });
  }

  void _setupNotificationsListener() {
    _notifChannel?.unsubscribe();
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    _notifChannel = supabase
        .channel('home_notifications_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'service_requests',
          callback: (payload) {
            if (!mounted) return;
            final record = payload.newRecord;
            final isRelevant = record['customer_id'] == user.id ||
                record['technician_id'] == user.id;
            if (!isRelevant) return;

            final service = record['service_type']?.toString() ?? 'طلب صيانة';
            final statusAr =
                arabicRequestStatus(record['status']?.toString());
            final now = DateTime.now();
            final timeStr =
                '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

            setState(() {
              _notifications.insert(0, {
                'title': 'تحديث في طلب $service',
                'body': 'أصبحت حالة الطلب: $statusAr',
                'time': timeStr,
              });
              if (_notifications.length > 20) {
                _notifications.removeLast();
              }
              _unreadNotifications++;
            });
          },
        )
        .subscribe();
  }

  void _openNotificationsSheet() {
    setState(() => _unreadNotifications = 0);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined,
                        color: AppTheme.primaryBlue),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'الإشعارات',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (_notifications.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() => _notifications.clear());
                          Navigator.pop(ctx);
                        },
                        child: const Text('مسح الكل'),
                      ),
                  ],
                ),
                const Divider(),
                if (_notifications.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'لا توجد إشعارات جديدة حاليًا',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _notifications.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final item = _notifications[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFEAF1FF),
                            child: Icon(Icons.info_outline,
                                color: AppTheme.primaryBlue),
                          ),
                          title: Text(
                            item['title'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(item['body'] ?? ''),
                          trailing: Text(
                            item['time'] ?? '',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notifChannel?.unsubscribe();
    _searchController.dispose();
    _homeAuthSub?.cancel();
    super.dispose();
  }

  void _selectTab(int index) {
    final maxIdx = _maxIndexFor(isTech: _isTechnician, hasOffers: _hasOffers);
    final safeIndex = index.clamp(0, maxIdx);
    setState(() {
      currentIndex = safeIndex;
      _isSideMenuOpen = false;
    });
    if (_isTechnician) {
      if (safeIndex == 0) _availableKey.currentState?.reload();
      if (safeIndex == 2) _ongoingKey.currentState?.reload();
    } else {
      final myRequestsTabIndex = _hasOffers ? 3 : 2;
      if (safeIndex == myRequestsTabIndex) {
        _myRequestsKey.currentState?.loadRequests();
      }
    }
  }

  void openRequest(BuildContext context, {String? service}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RequestPage(initialService: service)),
    );
  }

  Future<void> _openConvertToTechnician() async {
    setState(() => _isSideMenuOpen = false);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TechnicianApplicationPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final drawerWidth = MediaQuery.of(context).size.width * .78 > 320
        ? 320.0
        : MediaQuery.of(context).size.width * .78;

    final pages = _isTechnician
        ? <Widget>[
            TechnicianRequestsPage(
              key: _availableKey,
              showAvailable: true,
              onAccepted: () => _selectTab(2),
            ),
            AccountPage(
              onOpenAvailable: () => _selectTab(0),
              onOpenOngoing: () => _selectTab(2),
            ),
            TechnicianRequestsPage(key: _ongoingKey, showAvailable: false),
          ]
        : <Widget>[
            _buildHomeContent(),
            const ServicesPage(),
            if (_hasOffers) const OffersPage(),
            MyRequestsPage(key: _myRequestsKey),
            AccountPage(
              onOpenRequests: () => _selectTab(_hasOffers ? 3 : 2),
            ),
          ];

    final safeIndex = currentIndex.clamp(0, pages.length - 1);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
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
                  child: IndexedStack(index: safeIndex, children: pages),
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
                child: _buildSideMenu(safeIndex),
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: safeIndex,
          onTap: _selectTab,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 12,
          selectedItemColor: AppTheme.primaryBlue,
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
              : [
                  const BottomNavigationBarItem(
                      icon: Icon(Icons.home), label: 'الرئيسية'),
                  const BottomNavigationBarItem(
                      icon: Icon(Icons.grid_view_rounded), label: 'الخدمات'),
                  if (_hasOffers)
                    const BottomNavigationBarItem(
                        icon: Icon(Icons.local_offer_outlined),
                        label: 'العروض'),
                  const BottomNavigationBarItem(
                      icon: Icon(Icons.receipt_long), label: 'طلباتي'),
                  const BottomNavigationBarItem(
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
                      color: AppTheme.primaryBlue, size: 25),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: SizedBox(
                height: 48,
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.trim();
                      if (!_isTechnician &&
                          _searchQuery.isNotEmpty &&
                          currentIndex != 0) {
                        currentIndex = 0;
                      }
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'بتدور على خدمة إيه؟',
                    prefixIcon:
                        const Icon(Icons.search, color: AppTheme.primaryBlue),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 19),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
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
                onTap: _openNotificationsSheet,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.notifications_none_rounded,
                          color: AppTheme.primaryBlue, size: 25),
                      if (_unreadNotifications > 0)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              _unreadNotifications > 9
                                  ? '9+'
                                  : '$_unreadNotifications',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideMenu(int safeIndex) {
    final menuItems = _isTechnician
        ? const [
            ('الطلبات المتاحة', Icons.inbox_outlined, 0),
            ('حسابي', Icons.person_outline_rounded, 1),
            ('الطلبات الجارية', Icons.handyman_outlined, 2),
          ]
        : [
            ('حسابي', Icons.person_outline_rounded, _hasOffers ? 4 : 3),
            ('الرئيسية', Icons.home_rounded, 0),
            ('الخدمات', Icons.grid_view_rounded, 1),
            if (_hasOffers) ('العروض', Icons.local_offer_rounded, 2),
            ('طلباتي', Icons.receipt_long_rounded, _hasOffers ? 3 : 2),
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
                    color: safeIndex == item.$3
                        ? AppTheme.primaryBlue
                        : Colors.blueGrey),
                title: Text(item.$1),
                selected: safeIndex == item.$3,
                selectedTileColor: const Color(0xFFEAF1FF),
                onTap: () => _selectTab(item.$3),
              ),
            if (!_isTechnician) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.handyman_outlined,
                    color: AppTheme.greenPrimary),
                title: const Text('التحويل إلى حساب فني'),
                onTap: _openConvertToTechnician,
              ),
            ],
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
    if (_searchQuery.isNotEmpty) {
      final matches = AppServices.searchServices(_searchQuery);
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'نتائج البحث عن "$_searchQuery" (${matches.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            if (matches.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.search_off_rounded,
                        size: 46, color: Colors.grey),
                    const SizedBox(height: 10),
                    const Text(
                      'لم نجد خدمة مطابقة لبحثك',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () =>
                          openRequest(context, service: 'خدمات أخرى'),
                      child: const Text('اطلب خدمة مخصصة'),
                    ),
                  ],
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: matches.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 11,
                  crossAxisSpacing: 11,
                  childAspectRatio: 1.12,
                ),
                itemBuilder: (context, index) {
                  final serviceName = matches[index];
                  return ServiceSquare(
                    name: serviceName,
                    icon: AppServices.iconForService(serviceName),
                    color: AppTheme.primaryBlue,
                    onTap: () => openRequest(context, service: serviceName),
                  );
                },
              ),
          ],
        ),
      );
    }

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
                color: AppTheme.primaryBlue, size: 18),
            SizedBox(width: 5),
            Text('نطاق الخدمة: المنصورة والدقهلية',
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
              return ServiceSquare(
                name: item['name'] as String,
                icon: item['icon'] as IconData,
                color: AppTheme.primaryBlue,
                onTap: () =>
                    openRequest(context, service: item['name'] as String),
              );
            },
          ),
          const SizedBox(height: 25),
          _sectionTitle(
              'خدمات أخرى', 'خدمات يومية ومساعدة إضافية', Icons.widgets_rounded),
          const SizedBox(height: 12),
          AutoServicesRail(
            services: daily,
            onTap: (name) => openRequest(context, service: name),
          ),
          const SizedBox(height: 27),
          _sectionTitle('عروض صيانتي', 'اكتشف العروض والخدمات المميزة',
              Icons.local_offer_rounded),
          const SizedBox(height: 12),
          const OffersCarousel(),
          const SizedBox(height: 27),
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
        child: Icon(icon, color: AppTheme.primaryBlue, size: 21),
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
