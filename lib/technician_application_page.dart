import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'login_page.dart';
import 'auth_service.dart';
import 'models/app_services.dart';

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
  User? get _currentUser => supabase.auth.currentUser;

  @override
  void initState() {
    super.initState();
    final existingPhone = _currentUser?.userMetadata?['phone']?.toString();
    if (existingPhone != null && existingPhone.isNotEmpty) {
      _phoneController.text = existingPhone;
    }
  }

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

  Future<void> _submitApplication() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    if (_selectedServices.isEmpty) {
      _showMessage('اختر تخصصًا واحدًا على الأقل');
      return;
    }

    setState(() => _isLoading = true);
    final signedInBefore = _currentUser;

    try {
      String fullName;

      if (signedInBefore == null) {
        final payload = await AuthService.signInWithGoogle();
        if (payload == null) return;

        final user = payload.authResponse.user!;
        final existingType = AuthService.accountTypeOf(user);

        if (existingType == 'technician') {
          await AuthService.signOut();
          throw Exception(
              'هذا الحساب مسجل كفني بالفعل، يرجى تسجيل الدخول من صفحة الفنيين.');
        }

        fullName = payload.displayName ??
            user.userMetadata?['full_name']?.toString() ??
            'فني صيانة';
      } else {
        final existingType = AuthService.accountTypeOf(signedInBefore);
        if (existingType == 'technician') {
          throw Exception('حسابك مسجل كفني بالفعل.');
        }

        fullName = signedInBefore.userMetadata?['full_name']?.toString() ??
            signedInBefore.email?.split('@').first ??
            'فني صيانة';
      }

      await supabase.rpc(
        'submit_technician_application',
        params: {
          'p_full_name': fullName,
          'p_phone': _phoneController.text.trim(),
          'p_service_area': _serviceArea,
          'p_services': _selectedServices.toList(),
        },
      );

      await AuthService.claimTechnicianAccount();

      if (!mounted) return;

      _showMessage(
          'تم إرسال طلب الانضمام بنجاح، يمكنك متابعة حالة الطلب من حسابك.');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (signedInBefore == null) {
        await AuthService.signOut();
      }
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
              checkmarkColor: AppTheme.greenPrimary,
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
    final isLoggedInCustomer = _currentUser != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isLoggedInCustomer ? 'التحويل إلى حساب فني' : 'طلب الانضمام كفني',
          ),
          centerTitle: true,
          backgroundColor: AppTheme.greenPrimary,
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
                    color: AppTheme.greenPrimary,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'انضم إلى فريق صيانتي',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.greenPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isLoggedInCustomer
                        ? 'أكمل بيانات تخصصك لتحويل حسابك الحالي (${_currentUser?.email ?? ''}) إلى حساب فني'
                        : 'سجل بواسطة جوجل وأدخل تفاصيل تخصصك لإرسال طلب الانضمام',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 25),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      labelText: 'رقم الهاتف للتواصل',
                      prefixIcon: const Icon(Icons.phone_outlined,
                          color: AppTheme.greenPrimary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'رقم الهاتف مطلوب';
                      }
                      if (!AppServices.isValidEgyptianPhone(value.trim())) {
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
                        color: AppTheme.greenPrimary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'المنصورة', child: Text('المنصورة')),
                      DropdownMenuItem(value: 'طلخا', child: Text('طلخا')),
                      DropdownMenuItem(value: 'أجا', child: Text('أجا')),
                      DropdownMenuItem(value: 'شربين', child: Text('شربين')),
                      DropdownMenuItem(
                          value: 'ميت غمر', child: Text('ميت غمر')),
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
                    child: isLoggedInCustomer
                        ? ElevatedButton.icon(
                            onPressed: _isLoading ? null : _submitApplication,
                            icon: const Icon(Icons.check_circle_outline),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.greenPrimary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            label: _isLoading
                                ? const SizedBox(
                                    width: 23,
                                    height: 23,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'إرسال طلب التحويل إلى فني',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          )
                        : ElevatedButton.icon(
                            onPressed: _isLoading ? null : _submitApplication,
                            icon: const Icon(Icons.g_mobiledata,
                                size: 32, color: Colors.red),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(
                                    color: Colors.grey, width: 0.3),
                              ),
                            ),
                            label: _isLoading
                                ? const SizedBox(
                                    width: 23,
                                    height: 23,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.4),
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
                  if (!isLoggedInCustomer) ...[
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
                              color: AppTheme.greenPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
