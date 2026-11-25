import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'home_widgets.dart';
import 'request_page.dart';

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
    Color color = AppTheme.primaryBlue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(title: title, subtitle: subtitle, icon: icon),
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
            return ServiceSquare(
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
        
        ],
      ),
    );
  }
}
