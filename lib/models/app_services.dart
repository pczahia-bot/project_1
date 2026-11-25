import 'package:flutter/material.dart';

class AppServices {
  // القائمة الكاملة الموحدة لجميع خدمات التطبيق (للعملاء والفنيين)
  static const List<String> allServices = [
    // الصيانات الفنية الأساسية
    'كهرباء',
    'سباكة',
    'تكييف',
    'نجارة',
    'نقاشة',

    // الأجهزة المنزلية
    'أجهزة منزلية',
    'غسالات',
    'ثلاجات',
    'ديب فريزر',
    'شاشات وتليفزيونات',
    'بوتاجازات وأفران',
    'سخانات كهرباء وغاز',
    'ميكروويف',
    'غسالات أطباق',
    'كولدير ومبرد مياه',
    'خلاطات',
    'مراوح',
    'مكانس كهربائية',

    // خدمات النظافة والعناية
    'تنظيف',
    'مكافحة حشرات',
    'تعقيم',

    // النقل والتركيب
    'نقل أثاث',
    'فك وتركيب أثاث',
    'تركيب',
    'تركيب أجهزة ومعدات',

    // خدمات عامة وأخرى
    'صيانة عامة',
    'خدمات أخرى',
  ];

  // التصنيفات الخاصة بفلترة الفنيين
  static const List<String> technicianCategories = [
    'الكل',
    'كهرباء',
    'سباكة',
    'تكييف',
    'نجارة',
    'نقاشة',
    'أجهزة منزلية',
    'تنظيف',
    'نقل أثاث',
    'خدمات أخرى',
  ];

  static const Set<String> applianceServicesSet = {
    'أجهزة منزلية',
    'غسالات',
    'ثلاجات',
    'ديب فريزر',
    'شاشات وتليفزيونات',
    'بوتاجازات وأفران',
    'سخانات كهرباء وغاز',
    'ميكروويف',
    'غسالات أطباق',
    'كولدير ومبرد مياه',
    'خلاطات',
    'مراوح',
    'مكانس كهربائية',
  };

  /// تطبيع النص العربي لتسهيل البحث (إزالة الهمزات والتشكيل وتوحيد التاء المربوطة/الهاء والياء)
  static String normalizeArabic(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
        .replaceAll(RegExp(r'[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');
  }

  /// البحث الذكي في قائمة الخدمات
  static List<String> searchServices(String query) {
    final normalizedQuery = normalizeArabic(query);
    if (normalizedQuery.isEmpty) return [];
    return allServices
        .where((s) => normalizeArabic(s).contains(normalizedQuery))
        .toList();
  }

  /// أيقونة مناسبة لكل خدمة
  static IconData iconForService(String service) {
    if (service.contains('كهرب')) return Icons.electrical_services_rounded;
    if (service.contains('سباك')) return Icons.plumbing_rounded;
    if (service.contains('تكييف')) return Icons.ac_unit_rounded;
    if (service.contains('نجار')) return Icons.carpenter_rounded;
    if (service.contains('نقاش')) return Icons.format_paint_rounded;
    if (service.contains('غسالات أطباق')) return Icons.kitchen_rounded;
    if (service.contains('غسال')) return Icons.local_laundry_service_rounded;
    if (service.contains('ثلاج') || service.contains('فريزر')) {
      return Icons.kitchen_rounded;
    }
    if (service.contains('شاش')) return Icons.tv_rounded;
    if (service.contains('بوتاجاز') || service.contains('ميكروويف')) {
      return Icons.microwave_rounded;
    }
    if (service.contains('سخان')) return Icons.local_fire_department_rounded;
    if (service.contains('كولدير')) return Icons.water_drop_rounded;
    if (service.contains('خلاط')) return Icons.blender_rounded;
    if (service.contains('مراوح')) return Icons.toys_rounded;
    if (service.contains('مكانس') || service.contains('تنظيف')) {
      return Icons.cleaning_services_rounded;
    }
    if (service.contains('حشرات')) return Icons.pest_control_rounded;
    if (service.contains('تعقيم')) return Icons.sanitizer_rounded;
    if (service.contains('نقل')) return Icons.local_shipping_rounded;
    if (service.contains('فك وتركيب')) return Icons.chair_alt_rounded;
    if (service.contains('تركيب')) return Icons.build_circle_rounded;
    if (service.contains('أجهزة')) return Icons.kitchen_rounded;
    if (service.contains('أخرى')) return Icons.more_horiz_rounded;
    return Icons.home_repair_service_rounded;
  }

  /// مطابقة تخصص الفني مع نوع الخدمة المطلوبة بدقة (بدون تطابق جزئي مضلل)
  static bool matchesSpecialty(
      List<String> technicianServices, String requestedService) {
    if (technicianServices.isEmpty) return true;
    if (technicianServices.contains(requestedService)) return true;

    // إذا كان الفني مسجل تحت "أجهزة منزلية" فيمكنه استقبال أي جهاز منزلي
    if (technicianServices.contains('أجهزة منزلية') &&
        applianceServicesSet.contains(requestedService)) {
      return true;
    }

    // إذا كان الفني مسجل تحت "صيانة عامة" فيمكنه استقبال الصيانات العامة والأخرى
    if (technicianServices.contains('صيانة عامة') &&
        (requestedService == 'صيانة عامة' || requestedService == 'خدمات أخرى')) {
      return true;
    }

    return false;
  }

  /// التحقق من صحة رقم الهاتف المصري
  static bool isValidEgyptianPhone(String value) {
    final cleaned = value.replaceAll(RegExp(r'[\s\-]'), '');
    return RegExp(r'^(\+20|0020|0)?1[0125][0-9]{8}$').hasMatch(cleaned);
  }
}
