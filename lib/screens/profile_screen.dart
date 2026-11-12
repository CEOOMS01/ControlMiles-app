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
import '../errors/app_error.dart';
import '../routes/app_routes.dart';
import 'settings_screen.dart';
import '../onboarding/product_tour.dart';

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

  // Which row is being edited ('first', 'last' or 'email') and what it said before.
  String? _editing;
  final _scope = TourScope('account');
  final _tName = GlobalKey();
  bool _tourChecked = false;
  String _beforeEdit = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _scope.register();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _scope.unregister();
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
      final newEmail = _emailController.text.trim();
      final emailChanged = newEmail != (user.email ?? '');

      await _supabase.auth.updateUser(
        UserAttributes(
          email: emailChanged ? newEmail : null,
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

      if (!mounted) return;
      setState(() {
        _editing = null;
        // A new address only takes effect once its link is confirmed.
        if (emailChanged) _emailController.text = user.email ?? '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(appState.tr(emailChanged ? 'account_email_confirm' : 'profile_updated_success')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        final appError = AppError.from(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appError.display(appState.tr(appError.messageKey))),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startTour({bool force = false}) {
    ProductTour.run(context, id: TourIds.account, scope: _scope.name, keys: [_tName], force: force);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    if (!_tourChecked) {
      _tourChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startTour();
      });
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1C1812) : const Color(0xFF2E281F),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [TourHelpButton(onPressed: () => _startTour(force: true))],
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              appState.tr('account_title').toUpperCase(),
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          children: [
            _buildHeader(appState, isDark),
            const SizedBox(height: 10),
            _buildInfoCard(appState, isDark),

            const SizedBox(height: 16),
            _navRow(
              label: appState.tr('subscription'),
              subtitle: appState.tr(appState.premiumEntitled ? 'account_plan_premium' : 'account_plan_basic'),
              isDark: isDark,
              onTap: () => Navigator.pushNamed(context, AppRoutes.subscription),
            ),
            _navRow(
              label: appState.tr('delete_account'),
              isDark: isDark,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen(section: AccountSection.deleteAccount)),
              ),
            ),
            const SizedBox(height: 30),
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
        color: isDark ? const Color(0xFF2E281F) : const Color(0xFF1C1812),
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
  // ====================== INFO CARD ======================
  Widget _buildInfoCard(AppState appState, bool isDark) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      elevation: 0,
      color: isDark ? const Color(0xFF2E281F) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), 
        side: BorderSide(color: isDark ? const Color(0xFF3D352A) : Colors.grey[200]!)
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TourTarget(
              showcaseKey: _tName,
              scope: _scope.name,
              step: 1,
              total: 1,
              titleKey: 'account_title',
              bodyKey: 'ptour_account_body',
              child: _fieldRow(appState, 'first', appState.tr('name'), _nameController, isDark),
            ),
            const Divider(height: 8),
            _fieldRow(appState, 'last', appState.tr('last_name'), _lastNameController, isDark),
            const Divider(height: 8),
            _fieldRow(appState, 'email', appState.tr('email'), _emailController, isDark, keyboard: TextInputType.emailAddress),
          ],
        ),
      ),
    );
  }

  TextEditingController _controllerFor(String field) => switch (field) {
        'first' => _nameController,
        'last' => _lastNameController,
        _ => _emailController,
      };

  void _startEdit(String field) {
    setState(() {
      // Only one row at a time: another row's unsaved text is put back.
      if (_editing != null) _controllerFor(_editing!).text = _beforeEdit;
      _editing = field;
      _beforeEdit = _controllerFor(field).text;
    });
  }

  void _cancelEdit() {
    setState(() {
      if (_editing != null) _controllerFor(_editing!).text = _beforeEdit;
      _editing = null;
    });
  }

  /// A row of the card: tap it and it becomes its own field, saved right there.
  Widget _fieldRow(
    AppState appState,
    String field,
    String label,
    TextEditingController controller,
    bool isDark, {
    TextInputType? keyboard,
  }) {
    final dim = isDark ? Colors.white60 : Colors.grey;
    if (_editing == field) {
      return Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: keyboard,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _saveProfile(appState),
              decoration: InputDecoration(labelText: label, isDense: true),
            ),
          ),
          IconButton(
            tooltip: appState.tr('save'),
            onPressed: _isLoading ? null : () => _saveProfile(appState),
            icon: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded, color: Colors.green),
          ),
          IconButton(
            tooltip: appState.tr('cancel'),
            onPressed: _isLoading ? null : _cancelEdit,
            icon: Icon(Icons.close_rounded, color: dim),
          ),
        ],
      );
    }
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _isLoading ? null : () => _startEdit(field),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: dim)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                controller.text.isNotEmpty ? controller.text : '—',
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.edit_outlined, size: 16, color: dim),
          ],
        ),
      ),
    );
  }

  // ====================== SETTINGS ======================
  // BUG FIX (pedido explícito, "use metric system" hardcoded): esta
  // pantalla usaba 3 claves i18n que nunca existieron en NINGÚN idioma
  // (use_metric_system/metric_unit_desc/imperial_unit_desc) -- grep
  // confirmó cero definiciones en lib/i18n/*.dart. AppTexts.getText()
  // devuelve la clave cruda cuando falta, así que todo usuario, en todo
  // idioma, veía el nombre de la clave en pantalla. Settings ya tiene el
  // mismo toggle correctamente traducido (metric_system, sin subtítulo)
  // -- se reusa esa clave en vez de inventar traducciones nuevas para
  // claves que nunca debieron duplicar esa función.
  Widget _navRow({required String label, String? subtitle, required bool isDark, required VoidCallback onTap}) {
    final textColor = isDark ? Colors.white : const Color(0xFF2E281F);
    final subTextColor = isDark ? Colors.white54 : const Color(0xFF6B6250);
    return Card(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      elevation: 0,
      color: isDark ? const Color(0xFF2E281F) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? const Color(0xFF3D352A) : Colors.grey[200]!),
      ),
      child: ListTile(
        title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
        subtitle: subtitle == null ? null : Text(subtitle, style: TextStyle(fontSize: 12, color: subTextColor)),
        trailing: Icon(Icons.chevron_right_rounded, color: subTextColor),
        onTap: onTap,
      ),
    );
  }

}