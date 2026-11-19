import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'auth_service.dart';
import 'models/app_services.dart';

const Color technicianPrimaryColor = Color(0xFF176B65);

class TechnicianApplicationPage extends StatefulWidget {
  const TechnicianApplicationPage({super.key});

  @override
  State<TechnicianApplicationPage> createState() =>
      _TechnicianApplicationPageState();
}

class _TechnicianApplicationPageState extends State<TechnicianApplicationPage> {
  final _formKey = GlobalKey<FormState>();

  final _phoneController = TextEditingController();
  final Set<String> _selectedServices = {};
  String _serviceArea = 'المنصورة';
  bool _isLoading = false;

  final List<String> _services = AppServices.allServices;

  SupabaseClient get supabase => Supabase.instance.client;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _openTechnicianLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  /// يقبل أرقام مصرية مثل 01012345678 أو +201012345678
  bool _isValidPhone(String value) {
    final cleaned = value.replaceAll(RegExp(r'[\s\-]'), '');
    return RegExp(r'^(\+20|0020|0)?1[0125][0-9]{8}$').hasMatch(cleaned);
  }

  Future<void> _submitApplicationWithGoogle() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedServices.isEmpty) {
      _showMessage('اختر تخصصًا واحدًا على الأقل');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final payload = await AuthService.signInWithGoogle();
      if (payload == null) return; // المستخدم ألغى العملية (finally يعيد الحالة)

      if (!mounted) return;

      final user = payload.authResponse.user!;
      final existingType = AuthService.accountTypeOf(user);

      if (existingType == 'customer') {
        await AuthService.signOut();
        throw Exception(
            'هذا البريد مسجل بالفعل كحساب عميل، يرجى استخدام بريد آخر للانضمام كفني.');
      }

      final fullName = payload.displayName ?? 'فني صيانة';

      // 1) حفظ طلب الانضمام في قاعدة البيانات
      await supabase.rpc(
        'submit_technician_application',
        params: {
          'p_full_name': fullName,
          'p_phone': _phoneController.text.trim(),
          'p_service_area': _serviceArea,
          'p_services': _selectedServices.toList(),
        },
      );

      // 2) تثبيت نوع الحساب كفني على الخادم (غير قابل للتعديل من العميل)
      await AuthService.claimTechnicianAccount();

      if (!mounted) return;

      _showMessage(
          'تم إرسال طلب الانضمام بنجاح، يمكنك متابعة حالة الطلب من حسابك.');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      // أي فشل بعد تسجيل الدخول: نخرج المستخدم حتى لا تبقى جلسة بحالة ناقصة.
      // لو كان الطلب محفوظًا فعلًا، فتسجيل الدخول كفني سيُكمل التثبيت تلقائيًا.
      await AuthService.signOut();
      if (mounted) {
        _showMessage(
            'حدث خطأ أثناء إرسال الطلب: ${AuthService.friendlyError(e)}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildServicesSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'التخصصات التي تعمل بها',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _services.map((service) {
            final selected = _selectedServices.contains(service);
            return FilterChip(
              label: Text(service),
              selected: selected,
              selectedColor: const Color(0xFFE3F3F0),
              checkmarkColor: technicianPrimaryColor,
              onSelected: (value) {
                setState(() {
                  if (value) {
                    _selectedServices.add(service);
                  } else {
                    _selectedServices.remove(service);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('طلب الانضمام كفني'),
          centerTitle: true,
          backgroundColor: technicianPrimaryColor,
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.handyman_rounded,
                    size: 58,
                    color: technicianPrimaryColor,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'انضم إلى فريق صيانتي',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: technicianPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'سجل بواسطة جوجل وأدخل تفاصيل تخصصك لإرسال طلب الانضمام',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 25),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      labelText: 'رقم الهاتف للتواصل',
                      prefixIcon: const Icon(Icons.phone_outlined,
                          color: technicianPrimaryColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'رقم الهاتف مطلوب';
                      }
                      if (!_isValidPhone(value.trim())) {
                        return 'أدخل رقم هاتف مصري صحيح';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'منطقة العمل',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _serviceArea,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.location_on_outlined,
                        color: technicianPrimaryColor,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'المنصورة', child: Text('المنصورة')),
                      DropdownMenuItem(value: 'طلخا', child: Text('طلخا')),
                      DropdownMenuItem(value: 'أجا', child: Text('أجا')),
                      DropdownMenuItem(value: 'شربين', child: Text('شربين')),
                      DropdownMenuItem(value: 'ميت غمر', child: Text('ميت غمر')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _serviceArea = value);
                      }
                    },
                  ),
                  const SizedBox(height: 22),
                  _buildServicesSelector(),
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed:
                          _isLoading ? null : _submitApplicationWithGoogle,
                      icon: const Icon(Icons.g_mobiledata,
                          size: 32, color: Colors.red),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.grey, width: 0.3),
                        ),
                      ),
                      label: _isLoading
                          ? const SizedBox(
                              width: 23,
                              height: 23,
                              child: CircularProgressIndicator(strokeWidth: 2.4),
                            )
                          : const Text(
                              'التسجيل وإرسال الطلب عبر Google',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('لديك حساب بالفعل؟'),
                      TextButton(
                        onPressed: _openTechnicianLogin,
                        child: const Text(
                          'تسجيل الدخول كفني',
                          style: TextStyle(
                            color: technicianPrimaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
