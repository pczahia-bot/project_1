import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GoogleSignInPayload {
  final AuthResponse authResponse;
  final String? displayName;

  const GoogleSignInPayload({
    required this.authResponse,
    this.displayName,
  });
}

class AuthService {
  static SupabaseClient get _supabase => Supabase.instance.client;

  static const String _googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '171719716098-nb5akmdb4b3oomge06p061eq80qmvo2k.apps.googleusercontent.com',
  );

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: _googleServerClientId,
  );

  /// نوع الحساب يُقرأ من app_metadata فقط (لا يستطيع المستخدم تعديله).
  static String? accountTypeOf(User? user) {
    final type = user?.appMetadata['account_type'];
    return type is String ? type : null;
  }

  /// تسجيل الدخول عبر جوجل وإرجاع استجابة Supabase مع اسم العرض من جوجل
  static Future<GoogleSignInPayload?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final accessToken = googleAuth.accessToken;
    final idToken = googleAuth.idToken;

    if (accessToken == null || idToken == null) {
      throw Exception('فشل في جلب بيانات المصادقة من جوجل');
    }

    final response = await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );

    if (response.user == null) {
      throw Exception('تعذر الحصول على بيانات الحساب من الخادم');
    }

    return GoogleSignInPayload(
      authResponse: response,
      displayName: googleUser.displayName,
    );
  }

  /// تثبيت الحساب كعميل (على الخادم) وإرجاع نوع الحساب النهائي
  static Future<String> claimCustomerAccount({String? fullName}) async {
    final result = await _supabase.rpc(
      'claim_customer_account',
      params: {'p_full_name': fullName},
    );
    await _supabase.auth.refreshSession();
    return result?.toString() ?? 'customer';
  }

  /// تثبيت الحساب كفني (على الخادم) بعد وجود طلب انضمام
  static Future<String> claimTechnicianAccount() async {
    final result = await _supabase.rpc('claim_technician_account');
    await _supabase.auth.refreshSession();
    return result?.toString() ?? 'technician';
  }

  /// هل الفني الحالي معتمد من الإدارة؟
  static Future<bool> isTechnicianApproved() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;
    final profile = await _supabase
        .from('technician_profiles')
        .select('is_approved')
        .eq('user_id', user.id)
        .maybeSingle();
    return profile?['is_approved'] == true;
  }

  /// تحويل أي خطأ إلى رسالة مقروءة للمستخدم
  static String friendlyError(Object error) {
    if (error is PostgrestException) return error.message;
    if (error is AuthException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  /// حذف حساب المستخدم الحالي نهائيًا (عميل أو فني) وتنظيف الجلسة
  static Future<void> deleteAccount() async {
    await _supabase.rpc('delete_my_account');
    await signOut();
  }

  /// تسجيل الخروج الآمن بالكامل (من Supabase ومن Google) دون إبقاء جلسة معلّقة
  static Future<void> signOut() async {
    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }
    try {
      await _supabase.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}
  }
}
