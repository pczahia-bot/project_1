
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_page.dart';

const Color technicianPrimaryColor = Color(0xFF176B65);

class TechnicianApplicationPage extends StatefulWidget {
  const TechnicianApplicationPage({super.key});

  @override
  State<TechnicianApplicationPage> createState() =>
      _TechnicianApplicationPageState();
}

class _TechnicianApplicationPageState
    extends State<TechnicianApplicationPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final Set<String> _selectedServices = {};

  String _serviceArea = 'المنصورة';
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  final List<String> _services = [
    'سباكة',
    'كهرباء',
    'نجارة',
    'نقاشة',
    'تكييف',
    'أجهزة منزلية',
    'تنظيف',
    'صيانة عامة',
  ];

  SupabaseClient get supabase => Supabase.instance.client;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
      MaterialPageRoute(
        builder: (context) => const LoginPage(),
      ),
    );
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedServices.isEmpty) {
      _showMessage('اختر تخصصًا واحدًا على الأقل');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {
          'full_name': _nameController.text.trim(),
          'account_type': 'technician',
          'phone': _phoneController.text.trim(),
          'service_area': _serviceArea,
          'technician_services': _selectedServices.toList(),
        },
      );

      if (!mounted) return;

      if (response.session == null) {
        _showMessage(
          'تم إنشاء الحساب وإرسال طلب الانضمام. أكّد بريدك الإلكتروني، وسيتم إبلاغك بعد مراجعة الإدارة.',
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }

      await supabase.rpc(
        'submit_technician_application',
        params: {
          'p_full_name': _nameController.text.trim(),
          'p_phone': _phoneController.text.trim(),
          'p_service_area': _serviceArea,
          'p_services': _selectedServices.toList(),
        },
      );

      if (!mounted) return;

      _showMessage('تم إرسال طلب الانضمام بنجاح، وسيتم مراجعته من الإدارة.');

      // الحساب لم يُعتمد بعد، فنسجّل الخروج ونرجع للشاشة الرئيسية
      await supabase.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (e) {
      if (mounted) _showMessage(e.message);
    } on PostgrestException catch (e) {
      if (mounted) {
        _showMessage('تم إنشاء الحساب، لكن تعذر حفظ طلب الانضمام: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('حدث خطأ أثناء إرسال الطلب: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool isConfirmPassword = false,
  }) {
    final obscure = isPassword
        ? !_showPassword
        : isConfirmPassword
            ? !_showConfirmPassword
            : false;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword || isConfirmPassword ? obscure : false,
      textDirection: TextDirection.rtl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: technicianPrimaryColor),
        suffixIcon: isPassword || isConfirmPassword
            ? IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    if (isPassword) {
                      _showPassword = !_showPassword;
                    } else {
                      _showConfirmPassword = !_showConfirmPassword;
                    }
                  });
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: technicianPrimaryColor,
            width: 1.5,
          ),
        ),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';

        if (text.isEmpty) return 'هذا الحقل مطلوب';

        if (controller == _emailController &&
            !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(text)) {
          return 'أدخل بريدًا إلكترونيًا صحيحًا';
        }

        if (isPassword && text.length < 6) {
          return 'كلمة المرور يجب ألا تقل عن 6 أحرف';
        }

        if (isConfirmPassword &&
            text != _passwordController.text) {
          return 'كلمتا المرور غير متطابقتين';
        }

        return null;
      },
    );
  }

  Widget _buildServicesSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'التخصصات التي تعمل بها',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
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
                    'أدخل بياناتك وتخصصاتك لإرسال طلب الانضمام',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 25),

                  _buildTextField(
                    controller: _nameController,
                    label: 'الاسم بالكامل',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _emailController,
                    label: 'البريد الإلكتروني',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _passwordController,
                    label: 'كلمة المرور',
                    icon: Icons.lock_outline,
                    isPassword: true,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _confirmPasswordController,
                    label: 'تأكيد كلمة المرور',
                    icon: Icons.lock_reset,
                    isConfirmPassword: true,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _phoneController,
                    label: 'رقم الهاتف للتواصل',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'منطقة العمل',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
                      DropdownMenuItem(
                        value: 'المنصورة',
                        child: Text('المنصورة'),
                      ),
                      DropdownMenuItem(
                        value: 'طلخا',
                        child: Text('طلخا'),
                      ),
                      DropdownMenuItem(
                        value: 'أجا',
                        child: Text('أجا'),
                      ),
                      DropdownMenuItem(
                        value: 'شربين',
                        child: Text('شربين'),
                      ),
                      DropdownMenuItem(
                        value: 'ميت غمر',
                        child: Text('ميت غمر'),
                      ),
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
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitApplication,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: technicianPrimaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text(
                              'إرسال طلب الانضمام',
                              style: TextStyle(
                                fontSize: 17,
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
