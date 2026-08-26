// Olympus Mont Systems LLC - ControlMiles
// lib/screens/profile_screen.dart - FULL I18N + DARK MODE
//
// BUG FIX (pedido explícito): la gestión de vehículo (antes "VEHICLE MGMT"
// en este archivo) se movió a su propia pantalla — ver lib/screens/
// vehicle_screen.dart y AppRoutes.vehicle. Profile ya no importa
// VehicleService ni el catálogo de marcas.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../logic/app_state.dart';
import '../routes/app_routes.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final SupabaseClient _supabase = Supabase.instance.client;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // BUG FIX (pedido explícito, "el nombre aparenta no estar conectado a
  // nada"): esta pantalla llenaba el formulario desde
  // user.userMetadata (auth.users.raw_user_meta_data) -- una copia
  // separada del nombre, escrita una sola vez en el registro y nunca
  // sincronizada de vuelta. AppState/el saludo del Dashboard/reports leen
  // de public.profiles.first_name en cambio (la fuente real desde el
  // fix del saludo). Las dos podían quedar desincronizadas sin que nada lo
  // avisara -- exactamente lo que pasó (metadata tenía "CEO" de una prueba
  // vieja, profiles ya tenía el nombre real). Ahora esta pantalla lee de
  // profiles directamente, la misma fuente que el resto de la app ya usa.
  Future<void> _loadUserProfile() async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      final data = await _supabase
          .from('profiles')
          .select('first_name, last_name')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _nameController.text = (data?['first_name'] as String?) ?? '';
        _lastNameController.text = (data?['last_name'] as String?) ?? '';
        _emailController.text = user.email ?? '';
      });
    } catch (e) {
      debugPrint('[ProfileScreen] Failed to load profile: $e');
      if (mounted) {
        setState(() => _emailController.text = user.email ?? '');
      }
    }
  }

  Future<void> _saveProfile(AppState appState) async {
    setState(() => _isLoading = true);

    try {
      final user = _authService.currentUser;
      if (user == null) return;

      final firstName = _nameController.text.trim();
      final lastName = _lastNameController.text.trim();

      await _supabase.auth.updateUser(
        UserAttributes(
          email: _emailController.text.trim(),
          data: {
            'first_name': firstName,
            'last_name': lastName,
          },
        ),
      );

      // BUG FIX (pedido explícito, badge no matcheaba el nombre editado):
      // lo de arriba solo escribe en auth.users.raw_user_meta_data. El
      // trigger que copia eso a public.profiles.first_name (handle_new_
      // user) SOLO corre en INSERT (alta de cuenta), nunca en UPDATE --
      // así que editar el nombre acá nunca llegaba a la tabla de donde
      // AppState/el saludo del Dashboard leen. Se escribe directo acá
      // también, misma tabla, mismo campo.
      //
      // BUG FIX (real, encontrado al arreglar el saludo del Dashboard):
      // full_name es una columna GENERATED ALWAYS AS (...) STORED en
      // Postgres (calculada sola a partir de first_name/last_name) -- este
      // UPDATE explícito a full_name SIEMPRE fallaba ("column full_name can
      // only be updated to DEFAULT"), rompiendo el guardado de perfil
      // completo, no solo el nombre. Se quita del payload; Postgres la
      // recalcula solo.
      await _supabase.from('profiles').update({
        'first_name': firstName,
        'last_name': lastName,
      }).eq('id', user.id);

      // Refresca el caché en memoria de AppState (mismo patrón que ya se
      // usa post-login para display_id) -- así el saludo del Dashboard se
      // actualiza al toque, sin cerrar/reabrir la app.
      await appState.fetchUserProfile();

      setState(() => _isEditing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appState.tr('profile_updated_success')), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${appState.tr('error')}: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              appState.tr('profile').toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            Text(
              appState.userDisplayId ?? '---',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: Colors.white70,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_note_rounded),
              onPressed: () => setState(() => _isEditing = true),
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          children: [
            _buildHeader(appState, isDark),
            const SizedBox(height: 10),
            if (_isEditing)
              _buildEditForm(appState, isDark)
            else
              _buildInfoCard(appState, isDark),

            _buildSectionTitle(appState.tr('settings')),
            _buildUnitSelector(appState, isDark),
            const SizedBox(height: 12),
            _buildDarkModeSwitch(appState, isDark),

            const SizedBox(height: 40),
            _buildLogoutButton(context, appState),
            const SizedBox(height: 30),
            _buildVersionInfo(appState),
          ],
        ),
      ),
    );
  }

  // ====================== HEADER ======================
  Widget _buildHeader(AppState appState, bool isDark) {
    final fullName = "${_nameController.text} ${_lastNameController.text}".trim();
    final displayName = fullName.isNotEmpty ? fullName : "User";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 30, bottom: 40),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: isDark ? Colors.blueGrey[700] : Colors.blueGrey[800],
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            _emailController.text,
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ],
      ),
    );
  }

  // ====================== DARK MODE SWITCH ======================
  Widget _buildDarkModeSwitch(AppState appState, bool isDark) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SwitchListTile(
        title: Text(appState.tr('dark_mode'), style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(appState.tr('dark_mode_description'), style: const TextStyle(fontSize: 12)),
        value: appState.isDarkMode,
        onChanged: (value) => appState.setDarkMode(value),
        secondary: Icon(appState.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded, 
                    color: appState.isDarkMode ? Colors.amber : Colors.blue),
      ),
    );
  }

  // ====================== INFO CARD ======================
  Widget _buildInfoCard(AppState appState, bool isDark) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      elevation: 0,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), 
        side: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey[200]!)
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _infoRow(appState.tr('name'), "${_nameController.text} ${_lastNameController.text}".trim(), isDark),
            const Divider(height: 24),
            _infoRow('Email', _emailController.text, isDark),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.white60 : Colors.grey)),
          Text(value.isNotEmpty ? value : '—', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ====================== EDIT FORM ======================
  Widget _buildEditForm(AppState appState, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white, 
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.transparent)
      ),
      child: Column(
        children: [
          TextField(controller: _nameController, decoration: InputDecoration(labelText: appState.tr('name'))),
          const SizedBox(height: 12),
          TextField(controller: _lastNameController, decoration: InputDecoration(labelText: appState.tr('last_name'))),
          const SizedBox(height: 12),
          TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B), 
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              onPressed: _isLoading ? null : () => _saveProfile(appState),
              child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(appState.tr('save')),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _isEditing = false),
            child: Text(appState.tr('cancel')),
          ),
        ],
      ),
    );
  }

  // ====================== SETTINGS ======================
  Widget _buildUnitSelector(AppState appState, bool isDark) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SwitchListTile(
        title: Text(appState.tr('use_metric_system'), style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(appState.tr(appState.useMetricSystem ? 'metric_unit_desc' : 'imperial_unit_desc')),
        value: appState.useMetricSystem,
        onChanged: (value) => appState.setUseMetricSystem(value),
        secondary: const Icon(Icons.straighten_rounded),
      ),
    );
  }

  // ====================== LOGOUT ======================
  Widget _buildLogoutButton(BuildContext context, AppState appState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red, 
            side: const BorderSide(color: Colors.red),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
          ),
          onPressed: () async {
            // BUG FIX (pedido explícito): antes llamaba
            // _authService.signOut() directo, sin try/catch -- si esa
            // llamada de red fallaba, la excepción quedaba sin manejar y
            // la navegación a Login nunca se ejecutaba (la app parecía
            // "colgada"). También nunca limpiaba AppState.userDisplayId,
            // causando que el próximo login con otra cuenta mostrara el
            // ID de esta. signOutAndClear() nunca lanza y siempre limpia.
            await appState.signOutAndClear();
            if (context.mounted) {
              Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
            }
          },
          icon: const Icon(Icons.logout),
          label: Text(appState.tr('logout')),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, top: 30, bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title.toUpperCase(), 
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.1, color: Colors.grey)),
      ),
    );
  }

  Widget _buildVersionInfo(AppState appState) {
    return Column(
      children: [
        Text("${appState.tr('app_name')} v1.0.0", style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text("${appState.tr('copyright')} 2026 Olympus Mont Systems LLC", style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}