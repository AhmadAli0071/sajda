import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/qibla_compass.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  QiblaResponse? _qibla;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQibla();
  }

  Future<void> _loadQibla() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final state = context.read<AppState>();
      double? lat = state.lat;
      double? lng = state.lng;

      if (lat == null || lng == null) {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          final requested = await Geolocator.requestPermission();
          if (requested == LocationPermission.denied ||
              requested == LocationPermission.deniedForever) {
            throw Exception(
              state.t(
                'Location permission denied. Please enable it in settings.',
                'مقام کی اجازت مسترد ہے۔ براہ کرم سیٹنگز میں فعال کریں۔',
              ),
            );
          }
        }

        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
        );
        lat = position.latitude;
        lng = position.longitude;
        await state.setLocation(
          LocationModel(
            id: 'gps',
            city: '',
            state: '',
            country: '',
            countryCode: '',
            latitude: lat,
            longitude: lng,
            timezone: '',
            source: 'GPS',
            isManual: false,
          ),
        );
      }

      final qibla = await ApiClient.instance.getQibla(lat, lng);
      if (!mounted) return;
      setState(() {
        _qibla = qibla;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Scale the dial with the screen instead of a fixed 230px so it fits
    // small phones (320dp) and never exceeds ~280px on tablets.
    final compassSize =
        (MediaQuery.of(context).size.width * 0.62).clamp(180.0, 280.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(state.t('Qibla Direction', 'قبلہ کی سمت')),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadQibla,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: state.t('Refresh', 'تازہ کریں'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            children: [
              const SizedBox(height: 12),

              // Compass
              if (_qibla != null && !_loading)
                Center(
                  child: QiblaCompass(
                    qibla: _qibla!,
                    isUrdu: state.isUrdu,
                    size: compassSize,
                  ),
                ),

              const SizedBox(height: 24),

              // Info card
              if (_qibla != null && !_loading)
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _infoTile(
                            context,
                            icon: Icons.explore_rounded,
                            label: state.t('Direction', 'سمت'),
                            value: _qibla!.direction,
                            dark: dark,
                          ),
                          _infoTile(
                            context,
                            icon: Icons.circle_outlined,
                            label: state.t('Degree', 'درجہ'),
                            value: '${_qibla!.degree}°',
                            dark: dark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPill(dark),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.mosque_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                state
                                    .t(
                                      'Distance to Kaaba: {distance} km',
                                      'کعبہ تک فاصلہ: {distance} کلومیٹر',
                                    )
                                    .replaceAll(
                                      '{distance}',
                                      _qibla!.distance.toString(),
                                    ),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // How to use
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_rounded, color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          state.t('How to use', 'استعمال کیسے کریں'),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.t(
                        'Hold your phone flat and rotate until the Kaaba marker aligns with the fixed red line at the top of the screen.',
                        'اپنے فون کو افقی رکھیں اور اس وقت تک گھمائیں جب تک کعبہ کا نشان سکرین کے اوپر لکڑی لکیر کے ساتھ align نہ ہو جائے۔',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              // Retry
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _loadQibla,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(state.t('Retry', 'دوبارہ کوشش کریں')),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required bool dark,
  }) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}
