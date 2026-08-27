// Olympus Mont Systems LLC - ControlMiles
// lib/screens/subscription_screen.dart
//
// Real Stripe subscription management (see [[project_controlmiles]]).
// This screen never collects a card number -- "Upgrade" and "Manage
// subscription" both call a Supabase edge function that returns a
// Stripe-hosted URL, opened externally via url_launcher. Payment details
// go straight to Stripe; this screen only ever reflects
// AppState.premiumEntitled, which stripe-webhook keeps in sync server-side.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logic/app_state.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = false;

  Future<void> _openStripeUrl(AppState appState, String functionName) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.functions.invoke(functionName);
      final data = response.data;

      if (data is Map && data['configured'] == false) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(appState.tr('subscriptions_not_configured'))),
          );
        }
        return;
      }

      final url = data is Map ? data['url'] as String? : null;
      if (url == null) {
        throw Exception(data is Map ? data['error'] : 'no url returned');
      }

      final launched = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${appState.tr('error')}: could not open browser')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${appState.tr('error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subscribed = appState.premiumEntitled;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(appState.tr('subscription')),
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        subscribed ? Icons.verified_rounded : Icons.lock_outline_rounded,
                        color: subscribed ? Colors.green : Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        subscribed ? appState.tr('subscription_active') : appState.tr('subscription_required'),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    appState.tr('premium_plan_description'),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ))
            else if (subscribed)
              FilledButton(
                onPressed: () => _openStripeUrl(appState, 'create-portal-session'),
                child: Text(appState.tr('manage_subscription')),
              )
            else
              FilledButton(
                onPressed: () => _openStripeUrl(appState, 'create-checkout-session'),
                child: Text(appState.tr('upgrade_plan')),
              ),
          ],
        ),
      ),
    );
  }
}
