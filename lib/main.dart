import 'package:flutter/material.dart';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'register_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://uljmzaeiutddxbhgijzk.supabase.co',
    anonKey: 'sb_publishable_r_VGKOFSbHllejmFyAKiWQ_OBOOmpPe',
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
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F8FC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1769E0),
        ),
      ),
      home: const HomePage(),
    );
  }
}

// بيانات الطلبات التجريبية - سيتم استبدالها ببيانات Supabase لاحقًا
final List<MaintenanceRequest> demoRequests = [];

class MaintenanceRequest {
  final String number;
  final String service;
  final String description;
  final String address;
  final String visitType;
  final DateTime? visitDateTime;
  final int imagesCount;
  final DateTime createdAt;
  String status;

  MaintenanceRequest({
    required this.number,
    required this.service,
    required this.description,
    required this.address,
    required this.visitType,
    required this.visitDateTime,
    required this.imagesCount,
    required this.createdAt,
    this.status = 'بانتظار قبول فني',
  });
}

// الصفحة الرئيسية والتنقل بين أقسام التطبيق
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentIndex = 0;

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
    final pages = [
      _buildHomeContent(),
      const MyRequestsPage(),
      const SimpleSectionPage(
        title: 'الفنيين',
        message: 'قريبًا هتقدر تشوف الفنيين وتخصصاتهم وتقييماتهم.',
        icon: Icons.engineering,
      ),
      const AccountPage(),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('صباح الخير 👋',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              Text(
                currentIndex == 0
                    ? 'أهلاً بك في صيانتي'
                    : ['الرئيسية', 'طلباتي', 'الفنيين', 'حسابي'][currentIndex],
                style: const TextStyle(
                    fontSize: 19, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_none),
            ),
          ],
        ),
        body: IndexedStack(index: currentIndex, children: pages),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) => setState(() => currentIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF1769E0),
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home), label: 'الرئيسية'),
            BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long), label: 'طلباتي'),
            BottomNavigationBarItem(
                icon: Icon(Icons.engineering), label: 'الفنيين'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_outline), label: 'حسابي'),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on, color: Color(0xFF1769E0)),
              SizedBox(width: 6),
              Text('موقعك الحالي: المنصورة، مصر'),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            decoration: InputDecoration(
              hintText: 'بتدور على خدمة صيانة إيه؟',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1769E0), Color(0xFF1046A0)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الصيانة بقت أسهل!',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('اطلب فني متخصص لحد باب بيتك',
                    style: TextStyle(color: Colors.white)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => openRequest(context),
                  child: const Text('اطلب خدمة الآن'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          const Text('خدمات الصيانة',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: services.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 14,
              crossAxisSpacing: 10,
              childAspectRatio: 0.85,
            ),
            itemBuilder: (context, index) {
              final service = services[index];
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => openRequest(
                  context,
                  service: service['name'] as String,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(service['icon'] as IconData,
                          color: const Color(0xFF1769E0), size: 30),
                      const SizedBox(height: 9),
                      Text(service['name'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('محتاج صيانة؟',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text(
                  'اختار الخدمة، اشرح المشكلة، واستقبل الفنيين المتخصصين.',
                  style: TextStyle(color: Colors.grey, height: 1.6),
                ),
              ],
            ),
          ),
        ],
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

  List<MaintenanceRequest> get filteredRequests {
    final statuses = [
      ['بانتظار قبول فني', 'تم قبول الطلب', 'الفني في الطريق', 'جاري التنفيذ'],
      ['مكتمل'],
      ['ملغي'],
    ];
    return demoRequests
        .where((request) => statuses[selectedTab].contains(request.status))
        .toList()
        .reversed
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

  @override
  Widget build(BuildContext context) {
    final requests = filteredRequests;
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
                      child: Text(tabs[index], textAlign: TextAlign.center),
                    ),
                    selected: isSelected,
                    onSelected: (_) => setState(() => selectedTab = index),
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
          child: requests.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 14),
                        Text('مفيش طلبات ${tabs[selectedTab]} حاليًا',
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text(
                          'لما تبعت طلب صيانة جديد هتلاقيه ظاهر هنا.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: requests.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    final color = statusColor(request.status);
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              RequestDetailsPage(request: request),
                        ),
                      ),
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
                                  child: Text(request.service,
                                      style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(request.status,
                                      style: TextStyle(
                                          color: color,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text('رقم الطلب: ${request.number}',
                                style: const TextStyle(color: Colors.grey)),
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
                                Text('عرض التفاصيل',
                                    style: TextStyle(
                                        color: Color(0xFF1769E0),
                                        fontWeight: FontWeight.bold)),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_back_ios,
                                    size: 13, color: Color(0xFF1769E0)),
                              ],
                            ),
                          ],
                        ),
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
  final date =
      '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$date - $hour:$minute';
}

class RequestDetailsPage extends StatelessWidget {
  final MaintenanceRequest request;

  const RequestDetailsPage({super.key, required this.request});

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
                  Text(request.service,
                      style: const TextStyle(
                          fontSize: 21, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('رقم الطلب: ${request.number}',
                      style: const TextStyle(color: Colors.grey)),
                  const Divider(height: 28),
                  _detailRow('حالة الطلب', request.status),
                  _detailRow(
                      'نوع الزيارة',
                      request.visitType == 'emergency'
                          ? 'طارئة الآن'
                          : 'زيارة بموعد'),
                  _detailRow('موعد الزيارة',
                      request.visitType == 'emergency'
                          ? 'في أقرب وقت'
                          : _formatDateTime(request.visitDateTime)),
                  _detailRow('العنوان', request.address),
                  _detailRow('وصف المشكلة', request.description),
                  _detailRow('الصور المرفقة', '${request.imagesCount} صورة'),
                  _detailRow('تاريخ إنشاء الطلب',
                      _formatDateTime(request.createdAt)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16)),
              child: const Text(
                'سيتم إضافة بيانات الفني ومتابعة مراحل التنفيذ عند ربط التطبيق بالنظام وقاعدة البيانات.',
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


class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: StreamBuilder<AuthState>(
        stream: supabase.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final user = supabase.auth.currentUser;

          if (user == null) {
            return _buildGuestAccount(context);
          }

         return FutureBuilder(
  future: supabase
      .from('sayanti')
      .select('full_name, phone, email')
      .eq('id', user.id)
      .maybeSingle(),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final profile = profileSnapshot.data ?? {};

              final name =
                  profile['full_name'] ?? user.email ?? 'مستخدم صيانتي';
              final phone = profile['phone'] ?? 'غير مضاف';
              final email = user.email ?? '';

              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircleAvatar(
                        radius: 45,
                        backgroundColor: Color(0xFFDCE9FF),
                        child: Icon(
                          Icons.person,
                          size: 55,
                          color: Color(0xFF1769E0),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'أهلاً $name',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 22),
                      _accountInfo(Icons.email, email),
                      _accountInfo(Icons.phone, phone),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await supabase.auth.signOut();
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('تسجيل الخروج'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildGuestAccount(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_outline,
              size: 75,
              color: Color(0xFF1769E0),
            ),
            const SizedBox(height: 16),
            const Text(
              'أهلاً بيك في صيانتي',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'سجل حساب جديد عشان تقدر تطلب خدمات الصيانة وتتابع طلباتك.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.person_add),
                label: const Text('إنشاء حساب جديد'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegisterPage(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1769E0),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountInfo(IconData icon, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1769E0)),
          const SizedBox(width: 12),
          Expanded(child: Text(value)),
        ],
      ),
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

// صفحة طلب الصيانة
class RequestPage extends StatefulWidget {
  final String? initialService;

  const RequestPage({super.key, this.initialService});

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
    'أجهزة منزلية',
    'نقاشة',
    'تنظيف',
    'خدمات أخرى',
  ];

  String? selectedService;

  // نوع الزيارة والموعد المختار
  String visitType = 'scheduled';
  DateTime? selectedVisitDate;
  TimeOfDay? selectedVisitTime;

  // بيانات الموقع الجغرافي
Position? currentPosition;
// متحكم الخريطة والموقع المختار
final MapController mapController = MapController();

LatLng? selectedLocation;

void updateMapLocation(LatLng location) {
  setState(() {
    selectedLocation = location;
  });
}
bool isGettingLocation = false;

// تحديد الموقع الحالي باستخدام GPS
Future<void> getCurrentLocation() async {
  setState(() {
    isGettingLocation = true;
  });

  try {
    bool serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception('خدمة الموقع غير مفعلة');
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

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

    final location = LatLng(
  position.latitude,
  position.longitude,
);

setState(() {
  currentPosition = position;
  selectedLocation = location;
});

mapController.move(location, 16);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تحديد موقعك بنجاح')),
    );
  } catch (error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تعذر تحديد الموقع: $error')),
    );
  } finally {
    if (mounted) {
      setState(() {
        isGettingLocation = false;
      });
    }
  }
}
  

  // خاصية الصور
  final ImagePicker imagePicker = ImagePicker();
  final List<XFile> selectedImages = [];

  // اختيار صورة من المعرض أو الكاميرا
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

  // إظهار خيارات الصور
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
    selectedService = widget.initialService;
  }

  @override
  void dispose() {
    descriptionController.dispose();
    addressController.dispose();
    super.dispose();
  }

  // اختيار تاريخ الزيارة
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

  // اختيار وقت الزيارة
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

  // إرسال طلب الصيانة
  void submitRequest() {
    if (selectedService == null ||
        descriptionController.text.trim().isEmpty ||
        addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('من فضلك أكمل نوع الخدمة والوصف والعنوان'),
        ),
      );
      return;
    }

    if (visitType == 'scheduled') {
      if (selectedVisitDate == null || selectedVisitTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('من فضلك اختار تاريخ ووقت الزيارة'),
          ),
        );
        return;
      }

      final now = DateTime.now();
      final appointment = DateTime(
        selectedVisitDate!.year,
        selectedVisitDate!.month,
        selectedVisitDate!.day,
        selectedVisitTime!.hour,
        selectedVisitTime!.minute,
      );

      if (appointment.isBefore(now)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('موعد الزيارة لازم يكون في وقت لاحق'),
          ),
        );
        return;
      }
    }

    final appointment = visitType == 'scheduled'
        ? DateTime(
            selectedVisitDate!.year,
            selectedVisitDate!.month,
            selectedVisitDate!.day,
            selectedVisitTime!.hour,
            selectedVisitTime!.minute,
          )
        : null;

    final newRequest = MaintenanceRequest(
      number: 'SY-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      service: selectedService!,
      description: descriptionController.text.trim(),
      address: addressController.text.trim(),
      visitType: visitType,
      visitDateTime: appointment,
      imagesCount: selectedImages.length,
      createdAt: DateTime.now(),
    );
    demoRequests.add(newRequest);

    final visitDetails = visitType == 'emergency'
        ? 'نوع الزيارة: طارئة الآن'
        : 'موعد الزيارة: ${selectedVisitDate!.day}/${selectedVisitDate!.month}/${selectedVisitDate!.year} - ${selectedVisitTime!.format(context)}';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تم تجهيز طلبك بنجاح'),
        content: Text(
          '$visitDetails\n\nدي نسخة تجريبية. لسه هنربط الطلب بقاعدة البيانات والفنيين.',
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
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'طلب صيانة جديد',
            style: TextStyle(fontWeight: FontWeight.bold),
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

              // نوع الصيانة
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

              // وصف المشكلة
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

              // اختيار نوع الزيارة
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
                              : '${selectedVisitDate!.day}/${selectedVisitDate!.month}/${selectedVisitDate!.year}',
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

              // إضافة صور العطل
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

              // عرض الصور المختارة
              if (selectedImages.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 105,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: selectedImages.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final image = selectedImages[index];

                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 105,
                              height: 105,
                              child: FutureBuilder<List<int>>(
                                future: image.readAsBytes(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    return Image.memory(
                                      Uint8List.fromList(snapshot.data!),
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
                              onPressed: () {
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

              // عنوان تنفيذ الصيانة
              const Text(
                'عنوان تنفيذ الصيانة',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

SizedBox(
  width: double.infinity,
  height: 50,
  child: OutlinedButton.icon(
    onPressed: isGettingLocation ? null : getCurrentLocation,
    icon: isGettingLocation
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
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
  Text(
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
            initialCenter: LatLng(31.0409, 31.3785),
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
                    LatLng(31.0409, 31.3785),
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

              // زر إرسال الطلب
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1769E0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: const Text(
                    'إرسال طلب الصيانة',
                    style: TextStyle(
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
