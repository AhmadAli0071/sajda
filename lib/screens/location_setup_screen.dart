import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/static_data.dart';
import '../models/models.dart';
import '../screens/main_shell.dart';
import '../screens/map_location_picker_screen.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class LocationSetupScreen extends StatefulWidget {
  const LocationSetupScreen({super.key});

  @override
  State<LocationSetupScreen> createState() => _LocationSetupScreenState();
}

class _LocationSetupScreenState extends State<LocationSetupScreen> {
  final bool _busy = false;
  String? _error;
  List<LocationModel> _searchResults = [];
  String? _gpsName;
  double? _gpsLat;
  double? _gpsLng;

  final _search = TextEditingController();
  Timer? _searchTimer;

  @override
  void dispose() {
    _searchTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _confirmGps() async {
    if (_gpsLat == null || _gpsLng == null) return;
    final state = context.read<AppState>();
    final name = _gpsName ?? '$_gpsLat, $_gpsLng';
    final nearest = nearestCity(_gpsLat!, _gpsLng!);
    final loc = LocationModel(
      id: 'gps_${_gpsLat!.toStringAsFixed(4)}_${_gpsLng!.toStringAsFixed(4)}',
      city: nearest?.name ?? name.split(',').first.trim(),
      state: '',
      country: nearest?.country ?? '',
      countryCode: '',
      latitude: _gpsLat!,
      longitude: _gpsLng!,
      timezone: nearest?.timezone ?? 'Asia/Karachi',
      source: 'GPS',
      isManual: false,
    );
    await state.setLocation(loc);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  Future<void> _confirmManual(LocationModel loc) async {
    final state = context.read<AppState>();
    await state.setLocation(loc);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  void _onSearchChanged(String q) {
    if (q.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 600), () async {
      final state = context.read<AppState>();
      final results = await state.searchLocation(q);
      if (mounted) {
        setState(() => _searchResults = results);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: Text(state.t('Choose Your Location', 'اپنا مقام منتخب کریں'))),
      // The global safe area already lifts content above the system navbar.
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        children: [
          Text(state.t(
              'Prayer times need your location. Choose one option.',
              'نماز کے اوقات کے لیے مقام درکار ہے۔ ایک آپشن چنیں۔')),
          const SizedBox(height: 14),
          _OptionCard(
            icon: Icons.search_rounded,
            title: state.t('Search City or Country', 'شہر یا ملک تلاش کریں'),
            subtitle: state.t('Worldwide search', 'دنیا بھر میں تلاش'),
            onTap: () => _showGlobalSearch(state),
          ),
          const SizedBox(height: 12),
          _OptionCard(
            icon: Icons.map_rounded,
            title: state.t('Pick on Map', 'میں پ سے منتخب کریں'),
            subtitle: state.t('Drag pin to select exact location',
                'پن گھسیٹ کر درست مقام منتخب کریں'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MapLocationPickerScreen()),
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 18),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          if (_gpsLat != null && _gpsLng != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primaryPill(isDark).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(state.t('Detected Location', 'پتا لگ گیا'),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(_gpsName ?? '$_gpsLat, $_gpsLng'),
                  Text(
                      '${_gpsLat!.toStringAsFixed(4)}, ${_gpsLng!.toStringAsFixed(4)}'),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _confirmGps,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: const Color(0xFF10231B),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(state.t('Use This Location', 'یہ مقام استعمال کریں')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showGlobalSearch(AppState state) {
    _search.clear();
    _searchResults = [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _search,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: state.t('Search worldwide...', 'دنیا بھر میں تلاش...'),
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: (v) {
                      setS(() {});
                      _onSearchChanged(v);
                    },
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 320,
                    child: _searchResults.isEmpty
                        ? ListView(
                            children: [
                              if (_search.text.trim().isEmpty)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      state.t('Type at least 2 characters', 'کم از کم 2 حروف لکھیں'),
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                )
                              else
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      state.t('Searching...', 'تلاش ہو رہی ہے...'),
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                ),
                            ],
                          )
                        : ListView(
                            children: _searchResults.map((loc) {
                              return ListTile(
                                leading: const Icon(Icons.location_on_outlined),
                                title: Text(loc.city),
                                subtitle: Text(
                                  loc.state.isEmpty ? loc.country : '$loc.state, ${loc.country}',
                                ),
                                onTap: () async {
                                  Navigator.pop(ctx);
                                  await _confirmManual(loc);
                                },
                              );
                            }).toList(),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _OptionCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.primaryPill(isDark),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primaryDark),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: onTap,
      ),
    );
  }
}