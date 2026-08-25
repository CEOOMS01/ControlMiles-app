// Olympus Mont Systems LLC - ControlMiles
// lib/services/auth_service.dart - PRODUCTION READY

import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Iniciar sesión con Email y Contraseña
  Future<void> signIn(String email, String password) async {
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      // Error específico de Supabase Auth (ej: credenciales inválidas)
      throw Exception(e.message);
    } catch (e) {
      throw Exception("Login failed: ${e.toString()}");
    }
  }

  // Crear cuenta con Email y Contraseña + Metadatos
  // BUG FIX (pedido explícito): antes, si no llegaba firstName, se
  // fabricaba uno con el prefijo del email (split_part) -- el signup real
  // ni pedía nombre, así que SIEMPRE caía en ese fallback. El badge de
  // saludo del Dashboard terminaba mostrando "alsoler26" en vez de un
  // nombre real. Ahora login_screen.dart pide el nombre en el formulario
  // de registro y lo manda acá -- se quita el fallback fabricado, ya no
  // hace falta.
  Future<void> signUp(String email, String password, {String? firstName}) async {
    try {
      await _supabase.auth.signUp(
        email: email,
        password: password,
        // ENVIAR METADATOS: Esto ayuda a que el Trigger de la DB
        // cree el perfil con el nombre correcto desde el segundo 1.
        data: {
          'first_name': firstName ?? '',
        },
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception("Registration failed: ${e.toString()}");
    }
  }

  // ════════════════════════════════════════════════════════════
  // PASSWORD RESET (pedido explícito) — decisión: código OTP de 6 dígitos
  // por email, NO magic link. El proyecto no tiene deep-linking nativo
  // configurado hoy (sin app_links, sin intent-filter en Android, sin
  // URL scheme en iOS, sin Redirect URLs en el Dashboard de Supabase), y
  // agregar todo eso para el primer beta cerrado es más riesgo del que
  // vale la pena. verifyOTP con type: recovery no necesita nada de eso.
  //
  // Requiere UN paso manual en el Dashboard de Supabase (no lo puedo
  // hacer yo vía SQL/migración): Authentication → Email Templates →
  // Reset Password → agregar {{ .Token }} al cuerpo del email para que
  // llegue el código de 6 dígitos, no solo el link.
  // ════════════════════════════════════════════════════════════

  /// Paso 1: pide a Supabase que envíe el código de reseteo al email.
  Future<void> requestPasswordReset(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Password reset request failed: ${e.toString()}');
    }
  }

  /// Paso 2: verifica el código de 6 dígitos que llegó por email. Si es
  /// válido, Supabase abre una sesión de recuperación (recovery session)
  /// que habilita el paso 3 sin haber iniciado sesión normalmente.
  Future<void> verifyPasswordResetCode(String email, String code) async {
    try {
      await _supabase.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.recovery,
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Invalid or expired code: ${e.toString()}');
    }
  }

  /// Paso 3: con la sesión de recuperación ya activa (post paso 2), fija
  /// la nueva contraseña.
  Future<void> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Password update failed: ${e.toString()}');
    }
  }

  // ════════════════════════════════════════════════════════════
  // ACCOUNT DELETION (pedido explícito). Borrar de auth.users requiere
  // la service role key -- el cliente jamás la tiene, así que esto pasa
  // por la Edge Function delete-account (supabase/functions/delete-
  // account/index.ts), que verifica el JWT del que llama y solo puede
  // borrar SU PROPIA cuenta. Verificado en DB antes de escribir la
  // función: profiles.id -> auth.users(id) ON DELETE CASCADE, y de ahí
  // en cascada vehicles, sessions, session_sections, audit_events,
  // vehicle_maintenance_records, reports, etc. -- un solo delete limpia
  // todo.
  // ════════════════════════════════════════════════════════════
  Future<void> deleteAccount() async {
    try {
      final res = await _supabase.functions.invoke('delete-account');

      final body = res.data;
      final ok = body is Map && body['success'] == true;
      if (!ok) {
        final msg = (body is Map ? body['error'] as String? : null) ??
            'Account deletion failed';
        throw Exception(msg);
      }
    } on FunctionException catch (e) {
      final details = e.details;
      final msg = (details is Map ? details['error'] as String? : null) ??
          e.reasonPhrase ??
          e.toString();
      throw Exception(msg);
    } catch (e) {
      throw Exception('Account deletion failed: ${e.toString()}');
    }
  }

  // Cerrar sesión
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception("Logout failed");
    }
  }

  // Obtener el usuario actual (Auth UID)
  User? get currentUser => _supabase.auth.currentUser;

  // FUNCIÓN AUXILIAR: ¿Por qué es importante?
  // Nos permite saber el email rápidamente en la UI
  String? get userEmail => _supabase.auth.currentUser?.email;
}