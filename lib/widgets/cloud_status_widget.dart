// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/cloud_status_widget.dart - FULL I18N PRODUCTION READY

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/app_state.dart';

class CloudStatusWidget extends StatefulWidget {
  final bool isOnline;
  final bool trackingActive;
  final bool auditChainHealthy;

  const CloudStatusWidget({
    super.key,
    required this.isOnline,
    required this.trackingActive,
    required this.auditChainHealthy,
  });

  @override
  State<CloudStatusWidget> createState() => _CloudStatusWidgetState();
}

class _CloudStatusWidgetState extends State<CloudStatusWidget> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.isOnline ? Colors.blue.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (widget.isOnline ? Colors.blue : Colors.red).withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Row(
        children: [
          // 1. Icono de Nube con efecto de respiración (Pulse Effect)
          FadeTransition(
            opacity: widget.isOnline 
                ? _pulseController.drive(CurveTween(curve: Curves.easeInOut)) 
                : const AlwaysStoppedAnimation(1.0),
            child: _buildMainCloudIcon(),
          ),
          
          const SizedBox(width: 20),

          // 2. Detalles de Estado Localizados
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.isOnline ? appState.tr('cloud_connected') : appState.tr('cloud_disconnected'),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: -0.5,
                    color: widget.isOnline ? Colors.blue.shade900 : Colors.red.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Estado del Motor de Tracking (Active/Stopped)
                _buildStatusRow(
                  icon: widget.trackingActive ? Icons.bolt : Icons.flash_off,
                  color: widget.trackingActive ? Colors.green : Colors.grey,
                  text: widget.trackingActive 
                      ? appState.tr('tracking_active') 
                      : appState.tr('tracking_stopped'),
                ),
                
                const SizedBox(height: 6),
                
                // Integridad de la Cadena de Auditoría
                _buildStatusRow(
                  icon: widget.auditChainHealthy ? Icons.gpp_good : Icons.gpp_maybe,
                  color: widget.auditChainHealthy ? Colors.green : Colors.orange,
                  text: widget.auditChainHealthy 
                      ? appState.tr('audit_chain_healthy') 
                      : appState.tr('audit_chain_compromised'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainCloudIcon() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (widget.isOnline ? Colors.blue : Colors.red).withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        widget.isOnline ? Icons.cloud : Icons.cloud_off,
        color: widget.isOnline ? Colors.blue : Colors.red,
        size: 28,
      ),
    );
  }

  Widget _buildStatusRow({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0.5,
            color: color.withValues(alpha: 0.9),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}