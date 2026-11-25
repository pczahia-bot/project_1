import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_theme.dart';
import '../auth_service.dart';
import '../models/app_services.dart';
import '../models/maintenance_request.dart';
import 'request_details_page.dart';
import 'request_helpers.dart';

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

  final List<String> services = List<String>.from(AppServices.allServices);

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
  final Set<String> markedForRemovalPaths = {};
  final Map<String, String> existingImageSignedUrls = {};

  bool get isEditMode => widget.editRequest != null;

  List<String> get visibleExistingPaths => existingImagePaths
      .where((p) => !markedForRemovalPaths.contains(p))
      .toList();

  Future<void> _loadExistingImageUrls() async {
    final storage = Supabase.instance.client.storage.from('service-images');
    final entries = await Future.wait<MapEntry<String, String>?>(
      existingImagePaths.map((path) async {
        try {
          final url = await storage.createSignedUrl(path, 3600);
          return MapEntry(path, url);
        } catch (_) {
          return null;
        }
      }),
    );
    if (!mounted) return;
    setState(() {
      for (final entry in entries) {
        if (entry != null) {
          existingImageSignedUrls[entry.key] = entry.value;
        }
      }
    });
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
        throw Exception(
            'يرجى السماح بصلاحية الموقع من إعدادات الجهاز أو المتصفح');
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
      final msg = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تحديد الموقع: $msg'),
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

  Future<void> _cleanupUploadedImages(
      SupabaseClient supabase, List<String> paths) async {
    if (paths.isEmpty) return;
    try {
      await supabase.storage.from('service-images').remove(paths);
    } catch (_) {}
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

    if (AuthService.accountTypeOf(user) != 'customer') {
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

    final newlyUploadedPaths = <String>[];
    MaintenanceRequest? createdRequest;

    try {
      for (int i = 0; i < selectedImages.length; i++) {
        final image = selectedImages[i];
        final bytes = await image.readAsBytes();

        final extension = image.name.contains('.')
            ? image.name.split('.').last.toLowerCase()
            : 'jpg';
        final safeExtension = ['jpg', 'jpeg', 'png', 'webp'].contains(extension)
            ? extension
            : 'jpg';
        final fileName =
            '${DateTime.now().microsecondsSinceEpoch}_$i.$safeExtension';
        final imagePath = '${user.id}/$fileName';

        String contentType = 'image/jpeg';
        if (safeExtension == 'png') {
          contentType = 'image/png';
        } else if (safeExtension == 'webp') {
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

        newlyUploadedPaths.add(imagePath);
      }

      final keptExistingPaths = visibleExistingPaths;
      final allImagePaths = <String>[
        ...keptExistingPaths,
        ...newlyUploadedPaths,
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

        // حذف الصور القديمة المزالة يتم فقط بعد نجاح تحديث قاعدة البيانات
        if (markedForRemovalPaths.isNotEmpty) {
          await _cleanupUploadedImages(
              supabase, markedForRemovalPaths.toList());
        }
      } else {
        final requestData = {
          'customer_id': user.id,
          'customer_phone':
              user.phone ?? user.userMetadata?['phone']?.toString(),
          'service_type': selectedService!,
          'description': descriptionController.text.trim(),
          'address': addressController.text.trim(),
          'latitude': selectedLocation!.latitude,
          'longitude': selectedLocation!.longitude,
          'visit_at': appointment?.toUtc().toIso8601String(),
          'image_urls': allImagePaths,
          'status': 'pending',
        };
        final inserted = await supabase
            .from('service_requests')
            .insert(requestData)
            .select()
            .single();
        createdRequest =
            maintenanceRequestFromRow(Map<String, dynamic>.from(inserted));
      }

      if (!mounted) return;

      final created = createdRequest;
      if (!isEditMode && created != null) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => RequestDetailsPage(request: created),
          ),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('تم إرسال طلبك بنجاح'),
              duration: Duration(seconds: 3),
            ),
          );
        });
        return;
      }

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
        builder: (dialogContext) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(
                isEditMode ? 'تم تعديل طلبك بنجاح' : 'تم إرسال طلبك بنجاح'),
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
        ),
      );
    } catch (error) {
      // في حالة الفشل نحذف فقط الصور الجديدة التي رُفعت في هذه المحاولة دون المساس بالصور الأصلية
      await _cleanupUploadedImages(supabase, newlyUploadedPaths);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إرسال الطلب: ${AuthService.friendlyError(error)}'),
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
    final activeExistingPaths = visibleExistingPaths;

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
              RadioGroup<String>(
                groupValue: visitType,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      visitType = value;
                    });
                  }
                },
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: visitType == 'scheduled'
                              ? AppTheme.primaryBlue
                              : const Color(0xFFD8E0EC),
                          width: visitType == 'scheduled' ? 1.5 : 1,
                        ),
                      ),
                      child: const RadioListTile<String>(
                        value: 'scheduled',
                        activeColor: AppTheme.primaryBlue,
                        title: Text(
                          'تحديد موعد زيارة',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'اختار اليوم والساعة المناسبة لزيارة الفني',
                        ),
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
                      child: const RadioListTile<String>(
                        value: 'emergency',
                        activeColor: Colors.red,
                        title: Text(
                          'زيارة طارئة الآن',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'إرسال طلب فوري للبحث عن فني متاح',
                        ),
                      ),
                    ),
                  ],
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
                        color: AppTheme.primaryBlue,
                        size: 30,
                      ),
                      SizedBox(height: 8),
                      Text('اضغط لإضافة صورة'),
                    ],
                  ),
                ),
              ),
              if (activeExistingPaths.isNotEmpty) ...[
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
                    itemCount: activeExistingPaths.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final path = activeExistingPaths[index];
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
                                  : () => setState(() {
                                        markedForRemovalPaths.add(path);
                                      }),
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
                                    return const Icon(Icons.broken_image);
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
                                  const latlong.LatLng(31.0409, 31.3785),
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
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: isSubmitting
                      ? const Row(
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
                            Text('جاري حفظ البيانات...'),
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
