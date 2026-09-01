import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://lnhdrwcadlvwtrvrcjjp.supabase.co',
  );
  const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_B2VCbXqSpYtZ07D4Yff8Dg_6SCqH8VU',
  );

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabasePublishableKey,
  );

  runApp(const DrivoApp());
}

final supabase = Supabase.instance.client;

class DrivoColors {
  static const primary = Color(0xFF5030E0);
  static const navy = Color(0xFF201060);
  static const mint = Color(0xFF69EFB2);
  static const background = Color(0xFFF8F7FF);
  static const softPurple = Color(0xFFF0EDFF);
}

String drivoFriendlyError(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  final raw = error.toString().toLowerCase();

  if (raw.contains('failed host lookup') ||
      raw.contains('socketexception') ||
      raw.contains('clientexception') ||
      raw.contains('network is unreachable') ||
      raw.contains('connection refused') ||
      raw.contains('connection reset') ||
      raw.contains('connection timed out') ||
      raw.contains('timed out')) {
    return 'Check your internet connection and try again.';
  }
  if (raw.contains('active ride or request') ||
      raw.contains('finish it on the current device')) {
    return 'We couldn’t restore your active ride. Please try again.';
  }
  if (raw.contains('current_session_registered_to_another_account')) {
    return 'This device is already linked to another Drivo account.';
  }
  if (raw.contains('no nearby driver with qr payment') ||
      raw.contains('no nearby driver accepts qr')) {
    return 'No nearby driver accepts QR payments right now. Choose Cash or try again later.';
  }
  if (raw.contains('no approved online driver') ||
      raw.contains('no other nearby driver') ||
      raw.contains('no nearby driver')) {
    return 'No nearby drivers are available right now. Try again shortly.';
  }
  if (raw.contains('phone number is already registered') ||
      raw.contains('phone number is already') ||
      raw.contains('already registered with drivo')) {
    return 'This phone number is already registered.';
  }
  if (raw.contains('phone number must be exactly 10 digits') ||
      raw.contains('valid 10-digit phone')) {
    return 'Enter a valid 10-digit phone number.';
  }
  if (raw.contains('already have an active ride') ||
      raw.contains('already have a pending ride request')) {
    return 'You already have an active ride.';
  }
  if (raw.contains('driver approval is required') ||
      raw.contains('approved driver account required') ||
      raw.contains('driver is not approved')) {
    return 'Your Driver account is still under review.';
  }
  if (raw.contains('driver access is suspended') || raw.contains('suspended')) {
    return 'Your Driver account is currently unavailable. Contact Drivo support.';
  }
  if (raw.contains('passenger account required')) {
    return 'This feature is available to Passenger accounts only.';
  }
  if (raw.contains('driver account required')) {
    return 'This feature is available to Driver accounts only.';
  }
  if (raw.contains('authentication required') ||
      raw.contains('session expired') ||
      raw.contains('could not create a drivo session') ||
      raw.contains('could not create a fresh drivo session')) {
    return 'Please reopen Drivo and try again.';
  }
  if (raw.contains('ride request is no longer available') ||
      raw.contains('not assigned to you')) {
    return 'This ride request is no longer available.';
  }
  if (raw.contains('invalid ride status transition')) {
    return 'The trip status has changed. Refresh and try again.';
  }
  if (raw.contains('complete the active ride before going offline')) {
    return 'Complete your current trip before going offline.';
  }
  if (raw.contains('respond to the current ride request before going offline')) {
    return 'Respond to the current ride request before going offline.';
  }
  if (raw.contains('add your payment qr')) {
    return 'Add a payment QR before accepting QR rides.';
  }
  if (raw.contains('route service') ||
      raw.contains('no route found') ||
      raw.contains('invalid route') ||
      raw.contains('invalid trip metrics') ||
      raw.contains('places-search') ||
      raw.contains('search failed')) {
    return 'We couldn’t find a route right now. Please try again.';
  }
  if (raw.contains('location permission')) {
    return 'Allow location access to continue.';
  }
  if (raw.contains('location services') ||
      raw.contains('valid current location is required')) {
    return 'Turn on location services and try again.';
  }
  if (raw.contains('invalid vehicle category') ||
      raw.contains('vehicle categories')) {
    return 'Ride options are unavailable right now. Please try again.';
  }
  if (raw.contains('invalid payment method')) {
    return 'Choose a valid payment method.';
  }
  if (raw.contains('completed qr ride not found') ||
      raw.contains('mark payment')) {
    return 'We couldn’t update the payment. Please try again.';
  }
  if (raw.contains('ride_already_rated')) {
    return 'You’ve already rated this ride.';
  }
  if (raw.contains('ride_not_ready_for_rating')) {
    return 'Finish the trip and payment before rating your driver.';
  }
  if (raw.contains('invalid_driver_rating')) {
    return 'Choose a rating from 1 to 5 stars.';
  }
  if (raw.contains('rating_comment_too_long')) {
    return 'Keep your feedback under 300 characters.';
  }
  if (raw.contains('storage') ||
      raw.contains('upload') ||
      raw.contains('object not found') ||
      raw.contains('no such key')) {
    return 'We couldn’t upload that image. Please try again.';
  }
  if (raw.contains('driver application not found')) {
    return 'We couldn’t load your Driver account. Please try again.';
  }
  if (raw.contains('could not create ride request')) {
    return 'We couldn’t request your ride. Please try again.';
  }

  return fallback;
}

void showDrivoMessage(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      duration: const Duration(seconds: 3),
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

String _ratingLabel(int rating) {
  switch (rating) {
    case 1:
      return 'Poor';
    case 2:
      return 'Fair';
    case 3:
      return 'Good';
    case 4:
      return 'Very good';
    case 5:
      return 'Excellent';
    default:
      return 'Tap a star to rate';
  }
}

Widget _ratingStars({
  required int rating,
  double size = 20,
  MainAxisAlignment alignment = MainAxisAlignment.start,
}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: alignment,
    children: List.generate(
      5,
      (index) => Icon(
        index < rating ? Icons.star_rounded : Icons.star_border_rounded,
        size: size,
        color: const Color(0xFFFFB300),
      ),
    ),
  );
}

Future<bool> showDriverRatingSheet(
  BuildContext context, {
  required String rideId,
  required String driverName,
  required String driverVehicle,
}) async {
  var selectedRating = 0;
  var submitting = false;
  final commentController = TextEditingController();

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
          return Container(
            padding: EdgeInsets.fromLTRB(22, 10, 22, 22 + bottomInset),
            decoration: const BoxDecoration(
              color: DrivoColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: DrivoColors.softPurple,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFFB300),
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Rate your ride',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      color: DrivoColors.navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    driverVehicle.isEmpty
                        ? 'How was your ride with $driverName?'
                        : 'How was your ride with $driverName • $driverVehicle?',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final star = index + 1;
                      final selected = star <= selectedRating;
                      return IconButton(
                        tooltip: '$star star${star == 1 ? '' : 's'}',
                        onPressed: submitting
                            ? null
                            : () => setSheetState(() => selectedRating = star),
                        iconSize: 44,
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          selected ? Icons.star_rounded : Icons.star_border_rounded,
                          color: const Color(0xFFFFB300),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      _ratingLabel(selectedRating),
                      key: ValueKey(selectedRating),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: DrivoColors.navy,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: commentController,
                    enabled: !submitting,
                    minLines: 3,
                    maxLines: 4,
                    maxLength: 300,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Add feedback (optional)',
                      hintText: 'Share what went well or what could be better',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: selectedRating == 0 || submitting
                          ? null
                          : () async {
                              setSheetState(() => submitting = true);
                              try {
                                await supabase.rpc(
                                  'submit_driver_rating',
                                  params: {
                                    'p_ride_id': rideId,
                                    'p_rating': selectedRating,
                                    'p_comment': commentController.text.trim().isEmpty
                                        ? null
                                        : commentController.text.trim(),
                                  },
                                );
                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop(true);
                                }
                              } catch (error) {
                                if (sheetContext.mounted) {
                                  showDrivoMessage(
                                    sheetContext,
                                    drivoFriendlyError(
                                      error,
                                      fallback: 'We couldn’t save your rating. Please try again.',
                                    ),
                                    isError: true,
                                  );
                                  setSheetState(() => submitting = false);
                                }
                              }
                            },
                      child: submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.3,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Submit rating',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                    ),
                  ),
                  TextButton(
                    onPressed: submitting
                        ? null
                        : () => Navigator.of(sheetContext).pop(false),
                    child: const Text('Not now'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  commentController.dispose();
  return result ?? false;
}

Future<bool> showDrivoLogoutConfirmation(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Row(
        children: [
          CircleAvatar(
            backgroundColor: Color(0xFFFFECEC),
            child: Icon(Icons.logout_rounded, color: Color(0xFFB42318)),
          ),
          SizedBox(width: 12),
          Expanded(child: Text('Log out of Drivo?')),
        ],
      ),
      content: const Text(
        'You’ll return to the phone number screen. You can sign back in anytime.',
        style: TextStyle(height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFB42318),
          ),
          child: const Text('Log out'),
        ),
      ],
    ),
  );
  return result ?? false;
}

class DrivoApp extends StatelessWidget {
  const DrivoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Drivo',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: DrivoColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: DrivoColors.primary,
          secondary: DrivoColors.mint,
          tertiary: DrivoColors.navy,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: DrivoColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: DrivoColors.navy,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: DrivoColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: DrivoColors.primary, width: 2),
          ),
        ),
      ),
      home: const DrivoRoot(),
    );
  }
}

enum DrivoAccountType { passenger, driver }

DrivoAccountType drivoAccountTypeFromDb(String? value) {
  return value == 'driver' ? DrivoAccountType.driver : DrivoAccountType.passenger;
}

class DrivoProfile {
  final String id;
  final String displayName;
  final String phone;
  final DrivoAccountType accountType;
  final String? profilePhotoPath;

  const DrivoProfile({
    required this.id,
    required this.displayName,
    required this.phone,
    required this.accountType,
    this.profilePhotoPath,
  });

  bool get hasValidPhone => RegExp(r'^\d{10}$').hasMatch(phone);
  bool get isDriver => accountType == DrivoAccountType.driver;

  factory DrivoProfile.fromJson(Map<String, dynamic> json) {
    return DrivoProfile(
      id: json['id'] as String,
      displayName: ((json['display_name'] as String?) ?? '').trim(),
      phone: ((json['phone'] as String?) ?? '').trim(),
      accountType: drivoAccountTypeFromDb(json['account_type'] as String?),
      profilePhotoPath: json['profile_photo_path'] as String?,
    );
  }

  DrivoProfile copyWith({String? displayName}) {
    return DrivoProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      phone: phone,
      accountType: accountType,
      profilePhotoPath: profilePhotoPath,
    );
  }
}

class DrivoRoot extends StatefulWidget {
  const DrivoRoot({super.key});

  @override
  State<DrivoRoot> createState() => _DrivoRootState();
}

class _DrivoRootState extends State<DrivoRoot> {
  bool _loading = true;
  Object? _error;
  DrivoProfile? _profile;
  String? _pendingPhone;
  bool _phoneResolved = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _loading = true;
      _error = null;
      _profile = null;
      _pendingPhone = null;
      _phoneResolved = false;
    });

    try {
      if (supabase.auth.currentSession == null) {
        await supabase.auth.signInAnonymously();
      }
      if (supabase.auth.currentUser == null) {
        throw Exception('Could not create a Drivo session');
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  Future<Map<String, dynamic>> _phoneLoginRpc(String phone) async {
    final response = await supabase.rpc(
      'portfolio_phone_login',
      params: {'p_phone': phone},
    );
    if (response is! List || response.isEmpty) {
      throw Exception('Drivo could not check this phone number.');
    }
    return Map<String, dynamic>.from(response.first as Map);
  }

  Future<void> _startFreshAnonymousSession() async {
    await supabase.auth.signOut();
    await supabase.auth.signInAnonymously();
    if (supabase.auth.currentUser == null) {
      throw Exception('Could not create a fresh Drivo session.');
    }
  }

  Future<void> _prepareRegistrationSession() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      await _startFreshAnonymousSession();
      return;
    }
    final rows = await supabase
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .limit(1);
    if (rows.isNotEmpty) {
      await _startFreshAnonymousSession();
    }
  }

  Future<void> _lookupPhone(String phone) async {
    Map<String, dynamic> row;
    try {
      row = await _phoneLoginRpc(phone);
    } catch (error) {
      if ('$error'.contains('CURRENT_SESSION_REGISTERED_TO_ANOTHER_ACCOUNT')) {
        await _startFreshAnonymousSession();
        row = await _phoneLoginRpc(phone);
      } else {
        rethrow;
      }
    }

    final exists = row['account_exists'] == true;
    if (!exists) {
      await _prepareRegistrationSession();
      if (!mounted) return;
      setState(() {
        _profile = null;
        _pendingPhone = phone;
        _phoneResolved = true;
      });
      return;
    }

    final profile = DrivoProfile.fromJson(row);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _pendingPhone = null;
      _phoneResolved = true;
    });
  }

  Future<void> _registrationComplete() async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Drivo session expired.');
    final rows = await supabase
        .from('profiles')
        .select('id, display_name, phone, account_type, profile_photo_path')
        .eq('id', user.id)
        .limit(1);
    if (rows.isEmpty) throw Exception('Drivo account was not created.');

    final profile = DrivoProfile.fromJson(
      Map<String, dynamic>.from(rows.first),
    );
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _pendingPhone = null;
      _phoneResolved = true;
    });
  }

  Future<void> _logout() async {
    final profile = _profile;
    final user = supabase.auth.currentUser;

    if (profile?.isDriver == true && user != null) {
      try {
        final requests = await supabase
            .from('ride_requests')
            .select('id, status')
            .eq('offered_driver_id', user.id)
            .eq('status', 'offered')
            .limit(1);
        if (requests.isNotEmpty) {
          await supabase.rpc(
            'respond_to_ride_request_v2',
            params: {
              'p_request_id': requests.first['id'],
              'p_accept': false,
            },
          );
        }

        final rides = await supabase
            .from('rides')
            .select('status')
            .eq('driver_id', user.id)
            .limit(10);
        final hasActiveRide = rides.any((row) {
          final status = row['status'] as String?;
          return status != 'completed' && status != 'cancelled';
        });
        if (!hasActiveRide) {
          await supabase.rpc(
            'set_driver_presence',
            params: {'p_online': false},
          );
        }
      } catch (_) {
        // Logout must remain available even if presence cleanup cannot finish.
      }
    }

    await _startFreshAnonymousSession();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = null;
      _profile = null;
      _pendingPhone = null;
      _phoneResolved = false;
    });
  }

  void _profileSaved(DrivoProfile profile) {
    setState(() => _profile = profile);
  }

  void _changePhone() {
    setState(() {
      _profile = null;
      _pendingPhone = null;
      _phoneResolved = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _DrivoSplash();
    }

    if (_error != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 52),
                  const SizedBox(height: 16),
                  const Text(
                    'Something went wrong',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    drivoFriendlyError(
                      _error!,
                      fallback: 'We couldn’t open Drivo. Please try again.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _initialize,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_phoneResolved) {
      return DrivoPhoneEntryScreen(onContinue: _lookupPhone);
    }

    final profile = _profile;
    if (profile == null) {
      return DrivoRegistrationChoiceScreen(
        phone: _pendingPhone!,
        onRegistered: _registrationComplete,
        onChangePhone: _changePhone,
      );
    }

    if (!profile.hasValidPhone) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'We couldn’t open this account. Please contact Drivo support.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        ),
      );
    }

    if (profile.isDriver) {
      return DrivoDriverGate(
        profile: profile,
        onProfileChanged: _profileSaved,
        onLogout: _logout,
      );
    }

    return DrivoPassengerScreen(
      profile: profile,
      onProfileChanged: _profileSaved,
      onLogout: _logout,
    );
  }
}

class DrivoPhoneEntryScreen extends StatefulWidget {
  final Future<void> Function(String phone) onContinue;

  const DrivoPhoneEntryScreen({
    super.key,
    required this.onContinue,
  });

  @override
  State<DrivoPhoneEntryScreen> createState() => _DrivoPhoneEntryScreenState();
}

class _DrivoPhoneEntryScreenState extends State<DrivoPhoneEntryScreen> {
  final _phoneController = TextEditingController();
  bool _checking = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_checking) return;
    final phone = _phoneController.text.trim();
    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
      showDrivoMessage(
        context,
        'Enter a valid 10-digit phone number.',
        isError: true,
      );
      return;
    }

    setState(() => _checking = true);
    try {
      await widget.onContinue(phone);
    } catch (error) {
      if (!mounted) return;
      showDrivoMessage(
        context,
        drivoFriendlyError(error, fallback: 'Couldn’t continue. Please try again.'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 38, 24, 28),
          children: [
            Center(
              child: Image.asset(
                'assets/branding/drivo_logo.png',
                width: 220,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 54),
            const Text(
              'Enter your phone number',
              style: TextStyle(
                color: DrivoColors.navy,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.7,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _phoneController,
              autofocus: true,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              maxLength: 10,
              onSubmitted: (_) => _continue(),
              decoration: const InputDecoration(
                labelText: '10-digit phone number',
                hintText: '98XXXXXXXX',
                prefixIcon: Icon(Icons.phone_android),
                counterText: '',
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _checking ? null : _continue,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
              child: _checking
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Continue'),
            ),

          ],
        ),
      ),
    );
  }
}

class _DrivoSplash extends StatelessWidget {
  const _DrivoSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: DrivoColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image(
              image: AssetImage('assets/branding/drivo_mark.png'),
              width: 144,
              height: 144,
            ),
            SizedBox(height: 20),
            Text(
              'Drivo',
              style: TextStyle(
                color: DrivoColors.navy,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 28),
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: DrivoColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum AppState {
  choosingLocation,
  selectingRide,
  searchingDriver,
  waitingForPickup,
  riding,
  postRide,
}

enum RideStatus {
  driverArriving,
  driverArrived,
  inProgress,
  completed,
  cancelled,
  unknown,
}

RideStatus rideStatusFromDatabase(String? value) {
  switch (value) {
    case 'driver_arriving':
    case 'picking_up':
      return RideStatus.driverArriving;
    case 'driver_arrived':
      return RideStatus.driverArrived;
    case 'in_progress':
    case 'riding':
      return RideStatus.inProgress;
    case 'completed':
      return RideStatus.completed;
    case 'cancelled':
      return RideStatus.cancelled;
    default:
      return RideStatus.unknown;
  }
}

class FareOption {
  final String categorySlug;
  final String categoryName;
  final int capacity;
  final int fare;

  const FareOption({
    required this.categorySlug,
    required this.categoryName,
    required this.capacity,
    required this.fare,
  });

  factory FareOption.fromJson(Map<String, dynamic> json) {
    return FareOption(
      categorySlug: json['category_slug'] as String,
      categoryName: json['category_name'] as String,
      capacity: (json['capacity'] as num).toInt(),
      fare: (json['fare'] as num).toInt(),
    );
  }
}

class Ride {
  final String id;
  final String driverId;
  final String passengerId;
  final int fare;
  final RideStatus status;

  const Ride({
    required this.id,
    required this.driverId,
    required this.passengerId,
    required this.fare,
    required this.status,
  });

  factory Ride.fromJson(Map<String, dynamic> json) {
    return Ride(
      id: json['id'] as String,
      driverId: json['driver_id'] as String,
      passengerId: json['passenger_id'] as String,
      fare: (json['fare'] as num).toInt(),
      status: rideStatusFromDatabase(json['status'] as String?),
    );
  }
}

class Driver {
  final String id;
  final String name;
  final String phone;
  final String model;
  final String number;
  final double rating;
  final int ratingCount;
  final bool isAvailable;
  final LatLng location;

  const Driver({
    required this.id,
    required this.name,
    required this.phone,
    required this.model,
    required this.number,
    required this.rating,
    required this.ratingCount,
    required this.isAvailable,
    required this.location,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Drivo Driver',
      phone: (json['phone'] as String?) ?? '',
      model: json['model'] as String,
      number: json['number'] as String,
      rating: (json['rating'] as num?)?.toDouble() ?? 5,
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
      isAvailable: json['is_available'] as bool,
      location: LatLng(
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      ),
    );
  }
}

class PlaceResult {
  final String id;
  final String title;
  final String subtitle;
  final String type;
  final LatLng location;

  const PlaceResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.location,
  });

  factory PlaceResult.fromJson(Map<String, dynamic> json) {
    return PlaceResult(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      type: (json['type'] as String?) ?? 'place',
      location: LatLng(
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      ),
    );
  }
}

class RideHistoryItem {
  final String id;
  final int fare;
  final String status;
  final String pickupLabel;
  final String destinationLabel;
  final String categoryName;
  final int? distanceMeters;
  final DateTime createdAt;
  final String driverName;
  final String driverPhone;
  final String driverVehicle;
  final String paymentMethod;
  final String paymentStatus;
  final int? driverRating;
  final String driverRatingComment;

  const RideHistoryItem({
    required this.id,
    required this.fare,
    required this.status,
    required this.pickupLabel,
    required this.destinationLabel,
    required this.categoryName,
    required this.distanceMeters,
    required this.createdAt,
    required this.driverName,
    required this.driverPhone,
    required this.driverVehicle,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.driverRating,
    required this.driverRatingComment,
  });

  factory RideHistoryItem.fromJson(Map<String, dynamic> json) {
    final rawCategory = json['vehicle_categories'];
    String categoryName = 'Drivo ride';
    if (rawCategory is Map) {
      categoryName = (rawCategory['name'] as String?) ?? categoryName;
    }

    return RideHistoryItem(
      id: json['id'] as String,
      fare: (json['fare'] as num).toInt(),
      status: (json['status'] as String?) ?? 'unknown',
      pickupLabel: (json['pickup_label'] as String?) ?? 'Pickup',
      destinationLabel: (json['destination_label'] as String?) ?? 'Pinned destination',
      categoryName: categoryName,
      distanceMeters: (json['distance_meters'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      driverName: (json['driver_name'] as String?) ?? 'Drivo Driver',
      driverPhone: (json['driver_phone'] as String?) ?? '',
      driverVehicle: (json['driver_vehicle'] as String?) ?? 'Vehicle',
      paymentMethod: (json['payment_method'] as String?) ?? 'cash',
      paymentStatus: (json['payment_status'] as String?) ?? 'pending',
      driverRating: (json['driver_rating'] as num?)?.toInt(),
      driverRatingComment: (json['driver_rating_comment'] as String?) ?? '',
    );
  }
}

class DrivoPassengerScreen extends StatefulWidget {
  final DrivoProfile profile;
  final ValueChanged<DrivoProfile> onProfileChanged;
  final Future<void> Function() onLogout;

  const DrivoPassengerScreen({
    super.key,
    required this.profile,
    required this.onProfileChanged,
    required this.onLogout,
  });

  @override
  State<DrivoPassengerScreen> createState() => _DrivoPassengerScreenState();
}

class _DrivoPassengerScreenState extends State<DrivoPassengerScreen> {
  static const _osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const _tileUserAgentPackage = 'com.drivo.app';

  final MapController _mapController = MapController();
  final NumberFormat _moneyFormat = NumberFormat.decimalPattern();

  AppState _appState = AppState.choosingLocation;
  LatLng _initialCenter = const LatLng(27.7172, 85.3240);
  LatLng? _selectedDestination;
  String _selectedDestinationLabel = 'Pinned destination';
  LatLng? _currentLocation;
  List<LatLng> _routePoints = const [];
  bool _mapReady = false;
  bool _busy = false;

  int? _distanceMeters;
  int? _durationSeconds;
  List<FareOption> _fareOptions = const [];
  FareOption? _selectedFare;
  String _paymentMethod = 'cash';

  StreamSubscription<dynamic>? _driverSubscription;
  StreamSubscription<dynamic>? _rideSubscription;
  StreamSubscription<dynamic>? _rideRequestSubscription;

  Driver? _driver;
  String? _rideId;
  RideStatus? _rideStatus;
  LatLng? _previousDriverLocation;
  double _driverRotationDegrees = 0;

  @override
  void initState() {
    super.initState();
    _initializePassengerPortal();
  }

  Future<void> _initializePassengerPortal() async {
    await _checkLocationPermission();
    await _restorePassengerActivity();
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return _askForLocationPermission();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return _askForLocationPermission();
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return _askForLocationPermission();
    }

    await _getCurrentLocation();
  }

  Future<void> _askForLocationPermission() async {
    if (!mounted) return;

    return showDialog<void>(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Location required'),
          content: const Text(
            'Drivo needs your location to choose a pickup point and find nearby drivers.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                SystemChannels.platform.invokeMethod('SystemNavigator.pop');
              },
              child: const Text('Close app'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openLocationSettings();
              },
              child: const Text('Open settings'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      final location = LatLng(position.latitude, position.longitude);

      if (!mounted) return;
      setState(() {
        _currentLocation = location;
        _initialCenter = location;
        _selectedDestination ??= location;
      });

      _moveMap(location, 15);
    } catch (error) {
      debugPrint('Location error: $error');
      if (!mounted) return;
      showDrivoMessage(
        context,
        'We couldn’t find your location. Check your location settings and try again.',
        isError: true,
      );
    }
  }

  void _moveMap(LatLng center, double zoom) {
    if (!_mapReady) return;
    _mapController.move(center, zoom);
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (_appState == AppState.choosingLocation) {
      _selectedDestination = camera.center;
      if (hasGesture) _selectedDestinationLabel = 'Pinned destination';
    }
  }

  Future<void> _restorePassengerActivity() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final rideRows = await supabase
          .from('rides')
          .select(
            'id, driver_id, passenger_id, fare, status, pickup_label, destination_label, distance_meters, duration_seconds, origin_latitude, origin_longitude, destination_latitude, destination_longitude, payment_method, category_id, vehicle_categories(slug, name, capacity)',
          )
          .eq('passenger_id', user.id)
          .order('created_at', ascending: false)
          .limit(12);

      Map<String, dynamic>? activeRide;
      for (final raw in rideRows) {
        final row = Map<String, dynamic>.from(raw);
        final status = rideStatusFromDatabase(row['status'] as String?);
        if (status != RideStatus.completed && status != RideStatus.cancelled) {
          activeRide = row;
          break;
        }
      }

      if (activeRide != null) {
        await _restoreAcceptedRide(activeRide);
        return;
      }

      final requestRows = await supabase
          .from('ride_requests')
          .select(
            'id, status, offered_driver_id, fare, pickup_label, destination_label, distance_meters, duration_seconds, origin_latitude, origin_longitude, destination_latitude, destination_longitude, payment_method, category_id, vehicle_categories(slug, name, capacity)',
          )
          .eq('passenger_id', user.id)
          .order('created_at', ascending: false)
          .limit(12);

      Map<String, dynamic>? activeRequest;
      for (final raw in requestRows) {
        final row = Map<String, dynamic>.from(raw);
        if (row['status'] == 'offered') {
          activeRequest = row;
          break;
        }
      }

      if (activeRequest != null) {
        await _restorePendingRideRequest(activeRequest);
      }
    } catch (error) {
      debugPrint('Passenger activity restore failed: $error');
    }
  }

  FareOption _fareFromActivityRow(Map<String, dynamic> row) {
    final rawCategory = row['vehicle_categories'];
    var slug = 'car';
    var name = 'Drivo Car';
    var capacity = 4;
    if (rawCategory is Map) {
      slug = (rawCategory['slug'] as String?) ?? slug;
      name = (rawCategory['name'] as String?) ?? name;
      capacity = (rawCategory['capacity'] as num?)?.toInt() ?? capacity;
    }
    return FareOption(
      categorySlug: slug,
      categoryName: name,
      capacity: capacity,
      fare: (row['fare'] as num?)?.toInt() ?? 0,
    );
  }

  LatLng? _latLngFromActivityRow(
    Map<String, dynamic> row,
    String latitudeKey,
    String longitudeKey,
  ) {
    final latitude = row[latitudeKey] as num?;
    final longitude = row[longitudeKey] as num?;
    if (latitude == null || longitude == null) return null;
    return LatLng(latitude.toDouble(), longitude.toDouble());
  }

  Future<void> _restoreAcceptedRide(Map<String, dynamic> row) async {
    final rideId = row['id'] as String?;
    final driverId = row['driver_id'] as String?;
    if (rideId == null || driverId == null) return;

    final origin = _latLngFromActivityRow(
      row,
      'origin_latitude',
      'origin_longitude',
    );
    final destination = _latLngFromActivityRow(
      row,
      'destination_latitude',
      'destination_longitude',
    );
    final fare = _fareFromActivityRow(row);
    final status = rideStatusFromDatabase(row['status'] as String?);

    if (!mounted) return;
    setState(() {
      if (origin != null) _currentLocation ??= origin;
      if (destination != null) _selectedDestination = destination;
      _selectedDestinationLabel =
          (row['destination_label'] as String?) ?? 'Destination';
      _distanceMeters = (row['distance_meters'] as num?)?.toInt();
      _durationSeconds = (row['duration_seconds'] as num?)?.toInt();
      _paymentMethod = (row['payment_method'] as String?) ?? 'cash';
      _selectedFare = fare;
      _fareOptions = [fare];
      _rideId = rideId;
      _rideStatus = status;
      _appState = status == RideStatus.inProgress
          ? AppState.riding
          : AppState.waitingForPickup;
    });

    if (origin != null && destination != null) {
      await _loadRestoredRoute(origin, destination);
    }

    await _connectToAcceptedRide(
      driverId: driverId,
      rideId: rideId,
      serverFare: fare.fare,
    );
    _handleRideStatus(status);
  }

  Future<void> _restorePendingRideRequest(Map<String, dynamic> row) async {
    final requestId = row['id'] as String?;
    if (requestId == null) return;

    final origin = _latLngFromActivityRow(
      row,
      'origin_latitude',
      'origin_longitude',
    );
    final destination = _latLngFromActivityRow(
      row,
      'destination_latitude',
      'destination_longitude',
    );
    final fare = _fareFromActivityRow(row);

    if (!mounted) return;
    setState(() {
      if (origin != null) _currentLocation ??= origin;
      if (destination != null) _selectedDestination = destination;
      _selectedDestinationLabel =
          (row['destination_label'] as String?) ?? 'Destination';
      _distanceMeters = (row['distance_meters'] as num?)?.toInt();
      _durationSeconds = (row['duration_seconds'] as num?)?.toInt();
      _paymentMethod = (row['payment_method'] as String?) ?? 'cash';
      _selectedFare = fare;
      _fareOptions = [fare];
      _appState = AppState.searchingDriver;
    });

    if (origin != null && destination != null) {
      await _loadRestoredRoute(origin, destination);
    }

    await _rideRequestSubscription?.cancel();
    _rideRequestSubscription = supabase
        .from('ride_requests')
        .stream(primaryKey: ['id'])
        .eq('id', requestId)
        .listen((List<Map<String, dynamic>> data) {
          if (!mounted || data.isEmpty) return;
          _handleRideRequestUpdate(data.first, fare.fare);
        });
  }

  Future<void> _loadRestoredRoute(LatLng origin, LatLng destination) async {
    try {
      final response = await supabase.functions.invoke(
        'route',
        body: {
          'origin': {
            'latitude': origin.latitude,
            'longitude': origin.longitude,
          },
          'destination': {
            'latitude': destination.latitude,
            'longitude': destination.longitude,
          },
        },
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final legs = data['legs'] as List<dynamic>?;
      if (legs == null || legs.isEmpty) return;
      final firstLeg = Map<String, dynamic>.from(legs.first as Map);
      final polyline = Map<String, dynamic>.from(firstLeg['polyline'] as Map);
      final geoJson = Map<String, dynamic>.from(
        polyline['geoJsonLinestring'] as Map,
      );
      final coordinates = geoJson['coordinates'] as List<dynamic>?;
      if (coordinates == null || coordinates.length < 2) return;
      final points = coordinates.map((rawCoordinate) {
        final coordinate = rawCoordinate as List<dynamic>;
        return LatLng(
          (coordinate[1] as num).toDouble(),
          (coordinate[0] as num).toDouble(),
        );
      }).toList(growable: false);
      if (!mounted) return;
      setState(() => _routePoints = points);
    } catch (error) {
      debugPrint('Restored route preview failed: $error');
    }
  }

  Future<void> _openDestinationSearch() async {
    if (_appState != AppState.choosingLocation) return;

    final result = await showModalBottomSheet<PlaceResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => DestinationSearchSheet(
        currentLocation: _currentLocation,
      ),
    );

    if (result == null || !mounted) return;
    setState(() {
      _selectedDestination = result.location;
      _selectedDestinationLabel = result.subtitle;
    });
    _moveMap(result.location, 16);
  }

  Future<void> _confirmLocation() async {
    if (_busy) return;
    if (supabase.auth.currentSession == null) return;

    final origin = _currentLocation;
    final destination = _selectedDestination;
    if (origin == null || destination == null) return;

    final straightDistance = const Distance().as(
      LengthUnit.Meter,
      origin,
      destination,
    );
    if (straightDistance < 80) {
      showDrivoMessage(
        context,
        'Choose a destination farther from your pickup point.',
        isError: true,
      );
      return;
    }

    setState(() => _busy = true);

    try {
      final response = await supabase.functions.invoke(
        'route',
        body: {
          'origin': {
            'latitude': origin.latitude,
            'longitude': origin.longitude,
          },
          'destination': {
            'latitude': destination.latitude,
            'longitude': destination.longitude,
          },
        },
      );

      final data = Map<String, dynamic>.from(response.data as Map);
      final legs = data['legs'] as List<dynamic>?;
      if (legs == null || legs.isEmpty) {
        throw Exception(data['error'] ?? 'No route found');
      }

      final firstLeg = Map<String, dynamic>.from(legs.first as Map);
      final polyline = Map<String, dynamic>.from(firstLeg['polyline'] as Map);
      final geoJson = Map<String, dynamic>.from(
        polyline['geoJsonLinestring'] as Map,
      );
      final coordinates = geoJson['coordinates'] as List<dynamic>;

      final routePoints = coordinates.map((rawCoordinate) {
        final coordinate = rawCoordinate as List<dynamic>;
        return LatLng(
          (coordinate[1] as num).toDouble(),
          (coordinate[0] as num).toDouble(),
        );
      }).toList(growable: false);

      if (routePoints.length < 2) {
        throw Exception('The route service returned an invalid route');
      }

      final distanceMeters = (data['distanceMeters'] as num?)?.round();
      final durationSeconds = (data['durationSeconds'] as num?)?.round();
      if (distanceMeters == null ||
          distanceMeters <= 0 ||
          durationSeconds == null ||
          durationSeconds <= 0) {
        throw Exception('The route service returned invalid trip metrics');
      }

      final fareResponse = await supabase.rpc(
        'estimate_fares',
        params: {
          'p_distance_meters': distanceMeters,
          'p_duration_seconds': durationSeconds,
        },
      );

      final fareOptions = (fareResponse as List<dynamic>)
          .map(
            (row) => FareOption.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);

      if (fareOptions.isEmpty) {
        throw Exception('No Drivo vehicle categories are currently available');
      }

      FareOption selectedFare = fareOptions.first;
      for (final option in fareOptions) {
        if (option.categorySlug == 'mini') {
          selectedFare = option;
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        _routePoints = routePoints;
        _distanceMeters = distanceMeters;
        _durationSeconds = durationSeconds;
        _fareOptions = fareOptions;
        _selectedFare = selectedFare;
        _appState = AppState.selectingRide;
      });

      if (_mapReady) {
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: routePoints,
            padding: const EdgeInsets.fromLTRB(48, 48, 48, 410),
            maxZoom: 16,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      showDrivoMessage(
        context,
        drivoFriendlyError(error, fallback: 'Couldn’t prepare this trip. Please try again.'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestRide() async {
    if (_busy) return;
    if (supabase.auth.currentSession == null) return;

    final origin = _currentLocation;
    final destination = _selectedDestination;
    final selectedFare = _selectedFare;
    final distanceMeters = _distanceMeters;
    final durationSeconds = _durationSeconds;

    if (origin == null ||
        destination == null ||
        selectedFare == null ||
        distanceMeters == null ||
        durationSeconds == null) {
      return;
    }

    setState(() => _busy = true);

    try {
      final response = await supabase.rpc(
        'request_ride_v4',
        params: {
          'p_origin': 'POINT(${origin.longitude} ${origin.latitude})',
          'p_destination':
              'POINT(${destination.longitude} ${destination.latitude})',
          'p_category_slug': selectedFare.categorySlug,
          'p_distance_meters': distanceMeters,
          'p_duration_seconds': durationSeconds,
          'p_payment_method': _paymentMethod,
          'p_pickup_label': 'Current location',
          'p_destination_label': _selectedDestinationLabel,
        },
      );

      final rows = response as List<dynamic>;
      if (rows.isEmpty) throw Exception('Could not create ride request');

      final result = Map<String, dynamic>.from(rows.first as Map);
      final requestId = result['request_id'] as String;
      final requestStatus = result['request_status'] as String;
      final serverFare = (result['fare_amount'] as num).toInt();

      if (requestStatus == 'no_driver') {
        if (!mounted) return;
        showDrivoMessage(
          context,
          'No nearby ${selectedFare.categoryName} drivers are available right now.',
          isError: true,
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _selectedFare = FareOption(
          categorySlug: selectedFare.categorySlug,
          categoryName: selectedFare.categoryName,
          capacity: selectedFare.capacity,
          fare: serverFare,
        );
        _appState = AppState.searchingDriver;
      });

      await _rideRequestSubscription?.cancel();
      _rideRequestSubscription = supabase
          .from('ride_requests')
          .stream(primaryKey: ['id'])
          .eq('id', requestId)
          .listen((List<Map<String, dynamic>> data) {
            if (!mounted || data.isEmpty) return;
            _handleRideRequestUpdate(data.first, serverFare);
          });
    } catch (error) {
      if (!mounted) return;
      final raw = error.toString().toLowerCase();
      final message = raw.contains('no nearby driver with qr payment')
          ? 'No nearby ${selectedFare.categoryName} driver accepts QR payments right now. Choose Cash or try again later.'
          : drivoFriendlyError(
              error,
              fallback: 'Couldn’t request a ride. Please try again.',
            );
      showDrivoMessage(context, message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleRideRequestUpdate(
    Map<String, dynamic> row,
    int serverFare,
  ) async {
    final status = row['status'] as String?;

    if (status == 'no_driver') {
      if (!mounted) return;
      showDrivoMessage(
        context,
        'No other nearby driver is available right now.',
        isError: true,
      );
      _resetAppState();
      return;
    }

    if (status == 'cancelled') {
      if (!mounted) return;
      showDrivoMessage(
        context,
        'Your ride request was cancelled.',
        isError: true,
      );
      _resetAppState();
      return;
    }

    if (status != 'accepted') return;

    final rideId = row['ride_id'] as String?;
    final driverId = row['offered_driver_id'] as String?;
    if (rideId == null || driverId == null || _rideId == rideId) return;

    await _connectToAcceptedRide(
      driverId: driverId,
      rideId: rideId,
      serverFare: serverFare,
    );
  }

  Future<void> _listenToAssignedDriver(String driverId) async {
    await _driverSubscription?.cancel();
    _driverSubscription = supabase
        .from('drivers')
        .stream(primaryKey: ['id'])
        .eq('id', driverId)
        .listen((List<Map<String, dynamic>> data) {
          if (!mounted || data.isEmpty) return;

          final nextDriver = Driver.fromJson(data.first);
          var rotation = _driverRotationDegrees;
          if (_previousDriverLocation != null) {
            rotation = _calculateRotation(
              _previousDriverLocation!,
              nextDriver.location,
            );
          }

          setState(() {
            _driver = nextDriver;
            _driverRotationDegrees = rotation;
            _previousDriverLocation = nextDriver.location;
          });
          _adjustMapView();
        });
  }

  Future<void> _connectToAcceptedRide({
    required String driverId,
    required String rideId,
    required int serverFare,
  }) async {
    await _listenToAssignedDriver(driverId);
    await _rideSubscription?.cancel();

    _rideSubscription = supabase
        .from('rides')
        .stream(primaryKey: ['id'])
        .eq('id', rideId)
        .listen((List<Map<String, dynamic>> data) {
          if (!mounted || data.isEmpty) return;
          final ride = Ride.fromJson(data.first);
          if (_driver?.id != ride.driverId) {
            unawaited(_listenToAssignedDriver(ride.driverId));
          }
          _handleRideStatus(ride.status);
        });

    if (!mounted) return;
    setState(() {
      _rideId = rideId;
      _rideStatus = RideStatus.driverArriving;
      final selectedFare = _selectedFare;
      if (selectedFare != null) {
        _selectedFare = FareOption(
          categorySlug: selectedFare.categorySlug,
          categoryName: selectedFare.categoryName,
          capacity: selectedFare.capacity,
          fare: serverFare,
        );
      }
      _appState = AppState.waitingForPickup;
    });
  }

  void _handleRideStatus(RideStatus status) {
    if (!mounted) return;

    if (status == RideStatus.completed) {
      if (_appState == AppState.postRide) return;
      setState(() {
        _rideStatus = status;
        _appState = AppState.postRide;
      });
      _cancelSubscriptions();
      _showCompletionModal();
      return;
    }

    if (status == RideStatus.cancelled) {
      showDrivoMessage(
        context,
        'This ride was cancelled.',
        isError: true,
      );
      _resetAppState();
      return;
    }

    setState(() {
      _rideStatus = status;
      if (status == RideStatus.inProgress) {
        _appState = AppState.riding;
      } else if (status == RideStatus.driverArriving ||
          status == RideStatus.driverArrived) {
        _appState = AppState.waitingForPickup;
      }
    });

    _adjustMapView();
  }

  void _adjustMapView() {
    final driver = _driver;
    final origin = _currentLocation;
    final destination = _selectedDestination;
    if (!_mapReady || driver == null || origin == null || destination == null) {
      return;
    }

    final target = _appState == AppState.riding ? destination : origin;
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: [driver.location, target],
        padding: const EdgeInsets.fromLTRB(64, 64, 64, 320),
        maxZoom: 16,
      ),
    );
  }

  double _calculateRotation(LatLng start, LatLng end) {
    final latDiff = end.latitude - start.latitude;
    final lngDiff = end.longitude - start.longitude;
    final angle = atan2(lngDiff, latDiff);
    return angle * 180 / pi;
  }

  void _cancelSubscriptions() {
    _driverSubscription?.cancel();
    _rideSubscription?.cancel();
    _rideRequestSubscription?.cancel();
    _driverSubscription = null;
    _rideSubscription = null;
    _rideRequestSubscription = null;
  }

  Future<void> _showCompletionModal() async {
    if (!mounted) return;

    final rideId = _rideId;
    String paymentMethod = _paymentMethod;
    String? paymentQrPath;
    Uint8List? qrBytes;

    if (rideId != null) {
      try {
        final row = await supabase
            .from('rides')
            .select('payment_method, driver_payment_qr_path, payment_status')
            .eq('id', rideId)
            .single();
        paymentMethod = (row['payment_method'] as String?) ?? paymentMethod;
        paymentQrPath = row['driver_payment_qr_path'] as String?;
        if (paymentMethod == 'qr' && paymentQrPath != null) {
          qrBytes = await supabase.storage
              .from('driver-payment-assets')
              .download(paymentQrPath);
        }
      } catch (error) {
        debugPrint('Could not load payment details: $error');
      }
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.check_circle, size: 44, color: Colors.green),
          title: const Text('Trip complete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Fare: Rs. ${_moneyFormat.format(_selectedFare?.fare ?? 0)}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Text(
                paymentMethod == 'qr'
                    ? 'Scan your driver’s QR and pay with your preferred payment app.'
                    : 'Please pay the driver in cash.',
                textAlign: TextAlign.center,
              ),
              if (paymentMethod == 'qr' && qrBytes != null) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(qrBytes, width: 220, height: 220, fit: BoxFit.contain),
                ),
              ] else if (paymentMethod == 'qr') ...[
                const SizedBox(height: 12),
                const Text(
                  'The payment QR isn’t available right now. Ask your driver to show it directly.',
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () async {
                if (paymentMethod == 'qr' && rideId != null) {
                  try {
                    await supabase.rpc(
                      'passenger_mark_qr_paid',
                      params: {'p_ride_id': rideId},
                    );
                  } catch (error) {
                    if (dialogContext.mounted) {
                      showDrivoMessage(
                        dialogContext,
                        drivoFriendlyError(
                          error,
                          fallback: 'We couldn’t update the payment. Please try again.',
                        ),
                        isError: true,
                      );
                    }
                    return;
                  }
                }

                final driverName = _driver?.name ?? 'your driver';
                final driverVehicle = _driver?.model ?? '';
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if (!mounted) return;

                if (rideId != null) {
                  final rated = await showDriverRatingSheet(
                    context,
                    rideId: rideId,
                    driverName: driverName,
                    driverVehicle: driverVehicle,
                  );
                  if (rated && mounted) {
                    showDrivoMessage(context, 'Thanks for rating your driver.');
                  }
                }

                _resetAppState();
              },
              child: Text(paymentMethod == 'qr' ? 'I have paid' : 'Continue'),
            ),
          ],
        );
      },
    );
  }

  void _resetAppState() {
    _cancelSubscriptions();

    if (!mounted) return;
    setState(() {
      _appState = AppState.choosingLocation;
      _selectedDestination = null;
      _selectedDestinationLabel = 'Pinned destination';
      _driver = null;
      _rideId = null;
      _rideStatus = null;
      _fareOptions = const [];
      _selectedFare = null;
      _paymentMethod = 'cash';
      _distanceMeters = null;
      _durationSeconds = null;
      _routePoints = const [];
      _previousDriverLocation = null;
      _driverRotationDegrees = 0;
      _busy = false;
    });

    _getCurrentLocation();
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DrivoProfileScreen(
          profile: widget.profile,
          onProfileChanged: widget.onProfileChanged,
          onLogout: widget.onLogout,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  String get _rideStatusText {
    switch (_rideStatus) {
      case RideStatus.driverArriving:
        return 'Your driver is heading to the pickup point';
      case RideStatus.driverArrived:
        return 'Your driver has arrived';
      case RideStatus.inProgress:
        return 'Your trip is in progress';
      case RideStatus.completed:
        return 'Trip completed';
      case RideStatus.cancelled:
        return 'Trip cancelled';
      case RideStatus.unknown:
      case null:
        return 'Connecting to your driver...';
    }
  }

  IconData _vehicleIcon(String slug) {
    switch (slug) {
      case 'bike':
        return Icons.two_wheeler;
      case 'xl':
        return Icons.airport_shuttle;
      case 'mini':
        return Icons.local_taxi;
      default:
        return Icons.directions_car;
    }
  }

  String _formatDistance() {
    final meters = _distanceMeters;
    if (meters == null) return '--';
    if (meters < 1000) return '$meters m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _formatDuration() {
    final seconds = _durationSeconds;
    if (seconds == null) return '--';
    final minutes = max(1, (seconds / 60).ceil());
    return '$minutes min';
  }

  String _shortPlaceLabel(String value) {
    final parts = value.split(',');
    return parts.take(min(parts.length, 2)).join(',').trim();
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    if (_selectedDestination != null &&
        _appState != AppState.choosingLocation) {
      markers.add(
        Marker(
          point: _selectedDestination!,
          width: 48,
          height: 48,
          alignment: Alignment.bottomCenter,
          child: Image.asset('assets/images/pin.png'),
        ),
      );
    }

    if (_driver != null) {
      markers.add(
        Marker(
          point: _driver!.location,
          width: 54,
          height: 54,
          alignment: Alignment.center,
          child: Transform.rotate(
            angle: _driverRotationDegrees * pi / 180,
            child: Image.asset('assets/images/car.png'),
          ),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.profile.displayName.isEmpty
        ? 'D'
        : widget.profile.displayName[0].toUpperCase();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/branding/drivo_mark.png', width: 30, height: 30),
            const SizedBox(width: 8),
            const Text(
              'Drivo',
              style: TextStyle(
                color: DrivoColors.navy,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          if (_appState != AppState.choosingLocation)
            IconButton(
              tooltip: 'Start over',
              onPressed: _busy ? null : _resetAppState,
              icon: const Icon(Icons.close),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _openProfile,
              child: CircleAvatar(
                radius: 18,
                child: Text(
                  initial,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_currentLocation == null)
            const Center(child: CircularProgressIndicator())
          else
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _initialCenter,
                initialZoom: 15,
                minZoom: 3,
                maxZoom: 19,
                onMapReady: () {
                  _mapReady = true;
                  final location = _currentLocation;
                  if (location != null) {
                    _mapController.move(location, 15);
                  }
                },
                onPositionChanged: _onPositionChanged,
              ),
              children: [
                TileLayer(
                  urlTemplate: _osmTileUrl,
                  userAgentPackageName: _tileUserAgentPackage,
                  maxNativeZoom: 19,
                ),
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        strokeWidth: 5,
                        color: DrivoColors.primary,
                      ),
                    ],
                  ),
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _currentLocation!,
                      radius: 8,
                      color: DrivoColors.mint,
                      borderColor: Colors.white,
                      borderStrokeWidth: 3,
                    ),
                  ],
                ),
                MarkerLayer(markers: _buildMarkers()),
                const SimpleAttributionWidget(
                  source: Text('OpenStreetMap contributors'),
                  alignment: Alignment.topRight,
                ),
              ],
            ),
          if (_appState == AppState.choosingLocation &&
              _currentLocation != null) ...[
            Center(
              child: IgnorePointer(
                child: Image.asset(
                  'assets/images/center-pin.png',
                  width: 92,
                  height: 92,
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              top: 14,
              child: Material(
                elevation: 5,
                borderRadius: BorderRadius.circular(18),
                color: Colors.white,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: _openDestinationSearch,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Where to?',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                _selectedDestinationLabel == 'Pinned destination'
                                    ? 'Search a place or move the map pin'
                                    : _shortPlaceLabel(_selectedDestinationLabel),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (_busy)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.06),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _appState == AppState.choosingLocation
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : _confirmLocation,
              label: const Text('Choose this destination'),
              icon: const Icon(Icons.arrow_forward),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomSheet: _buildBottomSheet(),
    );
  }

  Widget _buildBottomSheet() {
    switch (_appState) {
      case AppState.selectingRide:
        return _buildRideSelector();
      case AppState.searchingDriver:
        return _buildSearchingDriverSheet();
      case AppState.waitingForPickup:
        return _buildDriverSheet(waiting: true);
      case AppState.riding:
        return _buildDriverSheet(waiting: false);
      case AppState.choosingLocation:
      case AppState.postRide:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSearchingDriverSheet() {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 14),
            const Text(
              'Waiting for a driver',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'A nearby approved ${_selectedFare?.categoryName ?? 'Drivo'} driver has been offered your trip. The ride starts only after a driver accepts.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, height: 1.35),
            ),
            const SizedBox(height: 12),
            Text(
              'Estimated fare: Rs. ${_moneyFormat.format(_selectedFare?.fare ?? 0)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRideSelector() {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Ride to ${_shortPlaceLabel(_selectedDestinationLabel)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '${_formatDistance()}  •  ${_formatDuration()}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 10),
            ..._fareOptions.map(_buildFareOption),
            const SizedBox(height: 8),
            const Text(
              'Payment method',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _PaymentChoice(
                    icon: Icons.payments_outlined,
                    label: 'Cash',
                    selected: _paymentMethod == 'cash',
                    onTap: () => setState(() => _paymentMethod = 'cash'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PaymentChoice(
                    icon: Icons.qr_code_2,
                    label: 'Online QR',
                    selected: _paymentMethod == 'qr',
                    onTap: () => setState(() => _paymentMethod = 'qr'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _requestRide,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
              child: Text(
                _selectedFare == null
                    ? 'Select a ride'
                    : 'Request ${_selectedFare!.categoryName}',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFareOption(FareOption option) {
    final selected = option.categorySlug == _selectedFare?.categorySlug;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _selectedFare = option),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_vehicleIcon(option.categorySlug)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.categoryName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Up to ${option.capacity} ${option.capacity == 1 ? 'rider' : 'riders'}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Rs. ${_moneyFormat.format(option.fare)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDriverSheet({required bool waiting}) {
    final driver = _driver;
    final selectedFare = _selectedFare;

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _rideStatusText,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              waiting
                  ? 'Your driver is heading toward your pickup location.'
                  : '${_formatDistance()} trip • ${_formatDuration()} estimated',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 14),
            if (driver == null)
              const LinearProgressIndicator()
            else
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    child: Text(
                      driver.name.isEmpty ? 'D' : driver.name[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                driver.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: Color(0xFFFFB300),
                            ),
                            Text(
                              driver.ratingCount == 0
                                  ? 'New'
                                  : '${driver.rating.toStringAsFixed(1)} (${driver.ratingCount})',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text('${driver.model} • ${driver.number}'),
                        if (driver.phone.isNotEmpty)
                          Text(driver.phone, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  if (selectedFare != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Fare',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          'Rs. ${_moneyFormat.format(selectedFare.fare)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                _StatusPill(
                  label: _paymentMethod == 'qr' ? 'ONLINE QR' : 'CASH',
                  icon: _paymentMethod == 'qr' ? Icons.qr_code_2 : Icons.payments_outlined,
                ),
                const SizedBox(width: 8),
                const _StatusPill(label: 'PAYMENT PENDING', icon: Icons.schedule),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DestinationSearchSheet extends StatefulWidget {
  final LatLng? currentLocation;

  const DestinationSearchSheet({
    super.key,
    required this.currentLocation,
  });

  @override
  State<DestinationSearchSheet> createState() => _DestinationSearchSheetState();
}

class _DestinationSearchSheetState extends State<DestinationSearchSheet> {
  final _controller = TextEditingController();
  bool _searching = false;
  String? _error;
  List<PlaceResult> _results = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_searching) return;
    final query = _controller.text.trim();
    if (query.length < 2) {
      setState(() => _error = 'Type at least 2 characters.');
      return;
    }

    setState(() {
      _searching = true;
      _error = null;
    });

    try {
      final response = await supabase.functions.invoke(
        'places-search',
        body: {
          'query': query,
          if (widget.currentLocation != null)
            'latitude': widget.currentLocation!.latitude,
          if (widget.currentLocation != null)
            'longitude': widget.currentLocation!.longitude,
        },
      );

      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['error'] != null) throw Exception(data['error']);

      final rawResults = (data['results'] as List<dynamic>?) ?? const [];
      final results = rawResults
          .map(
            (row) => PlaceResult.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);

      if (!mounted) return;
      setState(() => _results = results);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = drivoFriendlyError(error, fallback: 'Search is unavailable right now. Try again.'));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  IconData _iconForType(String type) {
    if (type.contains('airport')) return Icons.flight;
    if (type.contains('hospital')) return Icons.local_hospital_outlined;
    if (type.contains('restaurant') || type.contains('cafe')) {
      return Icons.restaurant_outlined;
    }
    if (type.contains('hotel')) return Icons.hotel_outlined;
    return Icons.place_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, max(16.0, keyboard + 12)),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Where are you going?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Search places in Nepal',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Search',
                        onPressed: _search,
                        icon: const Icon(Icons.arrow_forward),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Search runs only when you submit • OpenStreetMap/Nominatim',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Text(
                        _searching
                            ? 'Searching...'
                            : 'Search for a landmark, neighborhood, street, or city.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final result = _results[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          leading: CircleAvatar(
                            child: Icon(_iconForType(result.type)),
                          ),
                          title: Text(
                            result.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            result.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.of(context).pop(result),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class DrivoProfileScreen extends StatefulWidget {
  final DrivoProfile profile;
  final ValueChanged<DrivoProfile> onProfileChanged;
  final Future<void> Function() onLogout;

  const DrivoProfileScreen({
    super.key,
    required this.profile,
    required this.onProfileChanged,
    required this.onLogout,
  });

  @override
  State<DrivoProfileScreen> createState() => _DrivoProfileScreenState();
}

class _DrivoProfileScreenState extends State<DrivoProfileScreen> {
  final NumberFormat _moneyFormat = NumberFormat.decimalPattern();
  late DrivoProfile _profile;
  bool _loadingHistory = true;
  String? _historyError;
  List<RideHistoryItem> _history = const [];

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });

    try {
      final rows = await supabase
          .from('rides')
          .select(
            'id, fare, status, pickup_label, destination_label, distance_meters, created_at, driver_name, driver_phone, driver_vehicle, payment_method, payment_status, driver_rating, driver_rating_comment, rated_at, vehicle_categories(name)',
          )
          .order('created_at', ascending: false)
          .limit(30);

      final history = rows
          .map(
            (row) => RideHistoryItem.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _history = history;
        _loadingHistory = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingHistory = false;
        _historyError = drivoFriendlyError(error, fallback: 'Ride history is unavailable right now.');
      });
    }
  }


  String _formatDistance(int? meters) {
    if (meters == null) return '';
    if (meters < 1000) return '$meters m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  Future<void> _rateRide(RideHistoryItem ride) async {
    final rated = await showDriverRatingSheet(
      context,
      rideId: ride.id,
      driverName: ride.driverName,
      driverVehicle: ride.driverVehicle,
    );
    if (!mounted || !rated) return;
    showDrivoMessage(context, 'Thanks for rating your driver.');
    await _loadHistory();
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDrivoLogoutConfirmation(context);
    if (!confirmed || !mounted) return;
    try {
      await widget.onLogout();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      showDrivoMessage(
        context,
        drivoFriendlyError(error, fallback: 'Couldn’t log out. Please try again.'),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final completedTrips = _history.where((ride) => ride.status == 'completed').length;
    final totalSpent = _history
        .where((ride) => ride.status == 'completed')
        .fold<int>(0, (sum, ride) => sum + ride.fare);
    final initial = _profile.displayName.isEmpty
        ? 'D'
        : _profile.displayName[0].toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Passenger profile')),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Card(
              elevation: 0,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _profile.displayName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _profile.phone,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Completed trips',
                    value: '$completedTrips',
                    icon: Icons.route_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    label: 'Total spent',
                    value: 'Rs. ${_moneyFormat.format(totalSpent)}',
                    icon: Icons.payments_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ride history',
                        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Your recent Drivo trips',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                if (!_loadingHistory)
                  IconButton.filledTonal(
                    tooltip: 'Refresh history',
                    onPressed: _loadHistory,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (_loadingHistory)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_historyError != null)
              _HistoryErrorCard(
                message: _historyError!,
                onRetry: _loadHistory,
              )
            else if (_history.isEmpty)
              const _EmptyHistory()
            else
              ..._history.map(
                (ride) => _PassengerTripHistoryCard(
                  ride: ride,
                  moneyFormat: _moneyFormat,
                  distanceText: _formatDistance(ride.distanceMeters),
                  onRate: () => _rateRide(ride),
                ),
              ),
            const SizedBox(height: 22),
            const Divider(height: 1),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Log out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB42318),
                side: const BorderSide(color: Color(0xFFF3B6B2)),
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryErrorCard extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _HistoryErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, color: DrivoColors.primary, size: 34),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _PassengerTripHistoryCard extends StatelessWidget {
  final RideHistoryItem ride;
  final NumberFormat moneyFormat;
  final String distanceText;
  final VoidCallback onRate;

  const _PassengerTripHistoryCard({
    required this.ride,
    required this.moneyFormat,
    required this.distanceText,
    required this.onRate,
  });

  String get _statusLabel {
    switch (ride.status) {
      case 'completed':
        return 'COMPLETED';
      case 'cancelled':
        return 'CANCELLED';
      default:
        return 'IN PROGRESS';
    }
  }

  Color get _statusColor {
    switch (ride.status) {
      case 'completed':
        return const Color(0xFF067647);
      case 'cancelled':
        return const Color(0xFFB42318);
      default:
        return const Color(0xFFB54708);
    }
  }

  Color get _statusBackground {
    switch (ride.status) {
      case 'completed':
        return const Color(0xFFECFDF3);
      case 'cancelled':
        return const Color(0xFFFEF3F2);
      default:
        return const Color(0xFFFFFAEB);
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEE, MMM d • h:mm a').format(ride.createdAt);
    final canRate = ride.status == 'completed' &&
        ride.paymentStatus == 'paid' &&
        ride.driverRating == null;
    final paymentPaid = ride.paymentStatus == 'paid';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8E7F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x09000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusBackground,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(
                      color: _statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .35,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Rs. ${moneyFormat.format(ride.fare)}',
                  style: const TextStyle(
                    color: DrivoColors.navy,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(date, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            _TripRouteTimeline(
              pickup: ride.pickupLabel,
              destination: ride.destinationLabel,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _HistoryMetaPill(
                  icon: Icons.local_taxi_outlined,
                  label: ride.categoryName,
                ),
                if (distanceText.isNotEmpty)
                  _HistoryMetaPill(
                    icon: Icons.route_outlined,
                    label: distanceText,
                  ),
                _HistoryMetaPill(
                  icon: ride.paymentMethod == 'qr'
                      ? Icons.qr_code_2_rounded
                      : Icons.payments_outlined,
                  label: ride.paymentMethod == 'qr' ? 'Online QR' : 'Cash',
                ),
                _HistoryMetaPill(
                  icon: paymentPaid
                      ? Icons.check_circle_outline_rounded
                      : Icons.schedule_rounded,
                  label: paymentPaid ? 'Paid' : 'Pending',
                  foreground: paymentPaid
                      ? const Color(0xFF067647)
                      : const Color(0xFFB54708),
                  background: paymentPaid
                      ? const Color(0xFFECFDF3)
                      : const Color(0xFFFFFAEB),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DrivoColors.background,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: DrivoColors.softPurple,
                    child: Icon(Icons.person_rounded, color: DrivoColors.primary),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ride.driverName,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            ride.driverVehicle,
                            if (ride.driverPhone.isNotEmpty) ride.driverPhone,
                          ].join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (canRate || ride.driverRating != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              if (canRate)
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('How was your driver?', style: TextStyle(fontWeight: FontWeight.w900)),
                          SizedBox(height: 2),
                          Text('Your feedback helps improve Drivo.', style: TextStyle(fontSize: 11, color: Colors.black54)),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: onRate,
                      icon: const Icon(Icons.star_rounded, color: Color(0xFFFFB300)),
                      label: const Text('Rate'),
                    ),
                  ],
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _ratingStars(rating: ride.driverRating ?? 0, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '${ride.driverRating}/5',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      if (ride.driverRatingComment.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          '“${ride.driverRatingComment}”',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TripRouteTimeline extends StatelessWidget {
  final String pickup;
  final String destination;

  const _TripRouteTimeline({required this.pickup, required this.destination});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: DrivoColors.mint,
                shape: BoxShape.circle,
              ),
            ),
            Container(width: 2, height: 38, color: const Color(0xFFD9D7E5)),
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: DrivoColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PICKUP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade500, letterSpacing: .5)),
              const SizedBox(height: 2),
              Text(pickup, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 18),
              Text('DESTINATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade500, letterSpacing: .5)),
              const SizedBox(height: 2),
              Text(destination, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ],
    );
  }
}

class _HistoryMetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? foreground;
  final Color? background;

  const _HistoryMetaPill({
    required this.icon,
    required this.label,
    this.foreground,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? DrivoColors.navy;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background ?? DrivoColors.softPurple,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 14),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 42),
      child: Column(
        children: [
          Icon(Icons.history, size: 46, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          const Text(
            'No rides yet',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Your completed Drivo rides will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

enum DriverApplicationStatus { pending, approved, rejected }

DriverApplicationStatus driverApplicationStatusFromDb(String? value) {
  switch (value) {
    case 'approved':
      return DriverApplicationStatus.approved;
    case 'rejected':
      return DriverApplicationStatus.rejected;
    default:
      return DriverApplicationStatus.pending;
  }
}

class VehicleCategoryChoice {
  final String id;
  final String slug;
  final String name;

  const VehicleCategoryChoice({
    required this.id,
    required this.slug,
    required this.name,
  });

  factory VehicleCategoryChoice.fromJson(Map<String, dynamic> json) {
    return VehicleCategoryChoice(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
    );
  }
}

class DriverApplication {
  final String id;
  final String userId;
  final String fullName;
  final String phone;
  final String categoryId;
  final String categorySlug;
  final String categoryName;
  final String vehicleModel;
  final String vehicleColor;
  final String plateNumber;
  final String licenseNumber;
  final DriverApplicationStatus status;
  final String? reviewNote;
  final DateTime submittedAt;
  final DateTime? reviewedAt;

  const DriverApplication({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.categoryId,
    required this.categorySlug,
    required this.categoryName,
    required this.vehicleModel,
    required this.vehicleColor,
    required this.plateNumber,
    required this.licenseNumber,
    required this.status,
    required this.reviewNote,
    required this.submittedAt,
    required this.reviewedAt,
  });

  factory DriverApplication.fromJson(Map<String, dynamic> json) {
    final rawCategory = json['vehicle_categories'];
    final category = rawCategory is Map
        ? Map<String, dynamic>.from(rawCategory)
        : const <String, dynamic>{};

    return DriverApplication(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      fullName: (json['full_name'] as String?) ?? 'Drivo driver',
      phone: (json['phone'] as String?) ?? '',
      categoryId: (json['category_id'] as String?) ?? '',
      categorySlug: (category['slug'] as String?) ?? '',
      categoryName: (category['name'] as String?) ?? 'Drivo vehicle',
      vehicleModel: (json['vehicle_model'] as String?) ?? '',
      vehicleColor: (json['vehicle_color'] as String?) ?? '',
      plateNumber: (json['plate_number'] as String?) ?? '',
      licenseNumber: (json['license_number'] as String?) ?? '',
      status: driverApplicationStatusFromDb(json['status'] as String?),
      reviewNote: json['review_note'] as String?,
      submittedAt: DateTime.parse(json['submitted_at'] as String).toLocal(),
      reviewedAt: json['reviewed_at'] == null
          ? null
          : DateTime.parse(json['reviewed_at'] as String).toLocal(),
    );
  }
}

class _DocumentPickerTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final XFile? file;
  final VoidCallback onTap;

  const _DocumentPickerTile({
    required this.title,
    required this.subtitle,
    required this.file,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: ListTile(
        onTap: onTap,
        leading: file == null
            ? const CircleAvatar(child: Icon(Icons.add_a_photo_outlined))
            : ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(file!.path),
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(file == null ? subtitle : file!.name),
        trailing: Icon(file == null ? Icons.upload_outlined : Icons.check_circle,
            color: file == null ? null : Colors.green),
      ),
    );
  }
}

class DriverApplicationStatusScreen extends StatefulWidget {
  final DrivoProfile profile;
  final DriverApplication initialApplication;
  final Future<void> Function() onLogout;

  const DriverApplicationStatusScreen({
    super.key,
    required this.profile,
    required this.initialApplication,
    required this.onLogout,
  });

  @override
  State<DriverApplicationStatusScreen> createState() =>
      _DriverApplicationStatusScreenState();
}

class _DriverApplicationStatusScreenState
    extends State<DriverApplicationStatusScreen> {
  late DriverApplication _application;
  StreamSubscription<dynamic>? _subscription;

  @override
  void initState() {
    super.initState();
    _application = widget.initialApplication;
    _listen();
  }

  void _listen() {
    _subscription = supabase
        .from('driver_applications')
        .stream(primaryKey: ['id'])
        .eq('id', _application.id)
        .listen((data) async {
          if (!mounted || data.isEmpty) return;
          try {
            final rows = await supabase
                .from('driver_applications')
                .select(
                  'id, user_id, full_name, phone, vehicle_model, vehicle_color, plate_number, license_number, status, review_note, submitted_at, reviewed_at, category_id, vehicle_categories(slug, name)',
                )
                .eq('id', _application.id)
                .limit(1);
            if (!mounted || rows.isEmpty) return;
            setState(() {
              _application = DriverApplication.fromJson(
                Map<String, dynamic>.from(rows.first),
              );
            });
          } catch (_) {}
        });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _application.status;
    final approved = status == DriverApplicationStatus.approved;
    final rejected = status == DriverApplicationStatus.rejected;
    final icon = approved
        ? Icons.verified
        : rejected
            ? Icons.cancel_outlined
            : Icons.hourglass_top;
    final color = approved
        ? Colors.green
        : rejected
            ? Colors.red
            : Colors.amber.shade800;
    final title = approved
        ? 'You are approved to drive'
        : rejected
            ? 'Application not approved'
            : 'Application under review';

    return Scaffold(
      appBar: AppBar(title: const Text('Driver application')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 24),
          Icon(icon, color: color, size: 68),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              color: DrivoColors.navy,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            approved
                ? 'You’re ready to start driving with Drivo.'
                : rejected
                    ? 'Your application was reviewed but was not approved.'
                    : 'We’re reviewing your details and documents. We’ll update this screen when your Driver account is ready.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, height: 1.4),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ApplicationInfoRow('Vehicle', _application.categoryName),
                  _ApplicationInfoRow('Model', _application.vehicleModel),
                  _ApplicationInfoRow('Color', _application.vehicleColor),
                  _ApplicationInfoRow('Plate', _application.plateNumber),
                  _ApplicationInfoRow(
                    'Submitted',
                    DateFormat('MMM d, y • h:mm a')
                        .format(_application.submittedAt),
                  ),
                  if ((_application.reviewNote ?? '').trim().isNotEmpty)
                    _ApplicationInfoRow(
                      'Review note',
                      _application.reviewNote!.trim(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (approved)
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => DrivoDriverPortal(
                    profile: widget.profile,
                    onLogout: widget.onLogout,
                  ),
                ),
              ),
              icon: const Icon(Icons.drive_eta),
              label: const Text('Start driving'),
            )
          else
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Drivo'),
            ),
        ],
      ),
    );
  }
}

class _ApplicationInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _ApplicationInfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class DriverOperationalState {
  final String id;
  final String name;
  final String model;
  final String plate;
  final String? color;
  final bool isOnline;
  final bool isAvailable;
  final bool isSuspended;
  final LatLng? location;

  const DriverOperationalState({
    required this.id,
    required this.name,
    required this.model,
    required this.plate,
    required this.color,
    required this.isOnline,
    required this.isAvailable,
    required this.isSuspended,
    required this.location,
  });

  factory DriverOperationalState.fromJson(Map<String, dynamic> json) {
    final lat = (json['latitude'] as num?)?.toDouble();
    final lng = (json['longitude'] as num?)?.toDouble();
    return DriverOperationalState(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Drivo Driver',
      model: (json['model'] as String?) ?? '',
      plate: (json['number'] as String?) ?? '',
      color: json['vehicle_color'] as String?,
      isOnline: (json['is_online'] as bool?) ?? false,
      isAvailable: (json['is_available'] as bool?) ?? false,
      isSuspended: (json['is_suspended'] as bool?) ?? false,
      location: lat == null || lng == null ? null : LatLng(lat, lng),
    );
  }
}

class DriverRideRequest {
  final String id;
  final String pickupLabel;
  final String destinationLabel;
  final int fare;
  final int distanceMeters;
  final String paymentMethod;
  final String passengerName;
  final String passengerPhone;
  final LatLng origin;
  final LatLng destination;

  const DriverRideRequest({
    required this.id,
    required this.pickupLabel,
    required this.destinationLabel,
    required this.fare,
    required this.distanceMeters,
    required this.paymentMethod,
    required this.passengerName,
    required this.passengerPhone,
    required this.origin,
    required this.destination,
  });

  int get estimatedEarning => fare - (fare * 0.10).round();

  factory DriverRideRequest.fromJson(Map<String, dynamic> json) {
    return DriverRideRequest(
      id: json['id'] as String,
      pickupLabel: (json['pickup_label'] as String?) ?? 'Pickup',
      destinationLabel: (json['destination_label'] as String?) ?? 'Destination',
      fare: (json['fare'] as num).toInt(),
      distanceMeters: (json['distance_meters'] as num).toInt(),
      paymentMethod: (json['payment_method'] as String?) ?? 'cash',
      passengerName: (json['passenger_name'] as String?) ?? 'Passenger',
      passengerPhone: (json['passenger_phone'] as String?) ?? '',
      origin: LatLng(
        (json['origin_latitude'] as num).toDouble(),
        (json['origin_longitude'] as num).toDouble(),
      ),
      destination: LatLng(
        (json['destination_latitude'] as num).toDouble(),
        (json['destination_longitude'] as num).toDouble(),
      ),
    );
  }
}

class DriverActiveRide {
  final String id;
  final RideStatus status;
  final String pickupLabel;
  final String destinationLabel;
  final int fare;
  final String paymentMethod;
  final String paymentStatus;
  final int driverEarning;
  final String passengerName;
  final String passengerPhone;
  final LatLng origin;
  final LatLng destination;

  const DriverActiveRide({
    required this.id,
    required this.status,
    required this.pickupLabel,
    required this.destinationLabel,
    required this.fare,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.driverEarning,
    required this.passengerName,
    required this.passengerPhone,
    required this.origin,
    required this.destination,
  });

  factory DriverActiveRide.fromJson(Map<String, dynamic> json) {
    final fare = (json['fare'] as num).toInt();
    return DriverActiveRide(
      id: json['id'] as String,
      status: rideStatusFromDatabase(json['status'] as String?),
      pickupLabel: (json['pickup_label'] as String?) ?? 'Pickup',
      destinationLabel: (json['destination_label'] as String?) ?? 'Destination',
      fare: fare,
      paymentMethod: (json['payment_method'] as String?) ?? 'cash',
      paymentStatus: (json['payment_status'] as String?) ?? 'pending',
      driverEarning: (json['driver_earning'] as num?)?.toInt() ?? (fare - (fare * 0.10).round()),
      passengerName: (json['passenger_name'] as String?) ?? 'Passenger',
      passengerPhone: (json['passenger_phone'] as String?) ?? '',
      origin: LatLng(
        (json['origin_latitude'] as num).toDouble(),
        (json['origin_longitude'] as num).toDouble(),
      ),
      destination: LatLng(
        (json['destination_latitude'] as num).toDouble(),
        (json['destination_longitude'] as num).toDouble(),
      ),
    );
  }
}

class DrivoDriverHomeScreen extends StatefulWidget {
  final DrivoProfile profile;

  const DrivoDriverHomeScreen({super.key, required this.profile});

  @override
  State<DrivoDriverHomeScreen> createState() => _DrivoDriverHomeScreenState();
}

class _DrivoDriverHomeScreenState extends State<DrivoDriverHomeScreen> {
  static const _osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const _tileUserAgentPackage = 'com.drivo.app';

  final MapController _mapController = MapController();
  final NumberFormat _moneyFormat = NumberFormat.decimalPattern();
  StreamSubscription<dynamic>? _driverSubscription;
  StreamSubscription<dynamic>? _requestSubscription;
  StreamSubscription<dynamic>? _rideSubscription;
  StreamSubscription<Position>? _positionSubscription;

  DriverOperationalState? _driver;
  DriverRideRequest? _incomingRequest;
  DriverActiveRide? _activeRide;
  DriverActiveRide? _pendingPaymentRide;
  LatLng _mapCenter = const LatLng(27.7172, 85.3240);
  bool _mapReady = false;
  bool _loading = true;
  bool _busy = false;
  bool _locationUpdateInFlight = false;

  @override
  void initState() {
    super.initState();
    _initializeDriverMode();
  }

  @override
  void dispose() {
    _driverSubscription?.cancel();
    _requestSubscription?.cancel();
    _rideSubscription?.cancel();
    _positionSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initializeDriverMode() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final rows = await supabase
          .from('drivers')
          .select(
            'id, name, model, number, vehicle_color, is_online, is_available, is_suspended, latitude, longitude',
          )
          .eq('id', user.id)
          .limit(1);
      if (rows.isEmpty) throw Exception('Driver approval is required');

      final driver = DriverOperationalState.fromJson(
        Map<String, dynamic>.from(rows.first),
      );
      if (driver.isSuspended) throw Exception('Driver access is suspended');

      if (!mounted) return;
      setState(() {
        _driver = driver;
        _mapCenter = driver.location ?? _mapCenter;
        _loading = false;
      });

      _listenDriverRow(user.id);
      _listenRideRequests(user.id);
      _listenRides(user.id);
      if (driver.isOnline) {
        await _ensureLocationPermission();
        _startLocationPublishing();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showDrivoMessage(
        context,
        drivoFriendlyError(error, fallback: 'Your Driver account is unavailable right now. Please try again.'),
        isError: true,
      );
    }
  }

  void _listenDriverRow(String userId) {
    _driverSubscription = supabase
        .from('drivers')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .listen((data) {
          if (!mounted || data.isEmpty) return;
          final driver = DriverOperationalState.fromJson(data.first);
          setState(() {
            _driver = driver;
            if (driver.location != null) _mapCenter = driver.location!;
          });
        });
  }

  void _listenRideRequests(String userId) {
    _requestSubscription = supabase
        .from('ride_requests')
        .stream(primaryKey: ['id'])
        .eq('offered_driver_id', userId)
        .listen((data) {
          if (!mounted) return;
          DriverRideRequest? incoming;
          for (final raw in data.reversed) {
            if (raw['status'] == 'offered') {
              incoming = DriverRideRequest.fromJson(raw);
              break;
            }
          }
          setState(() => _incomingRequest = incoming);
          _fitDriverMap();
        });
  }

  void _listenRides(String userId) {
    _rideSubscription = supabase
        .from('rides')
        .stream(primaryKey: ['id'])
        .eq('driver_id', userId)
        .listen((data) {
          if (!mounted) return;
          DriverActiveRide? active;
          DriverActiveRide? pendingPayment;
          for (final raw in data.reversed) {
            final status = rideStatusFromDatabase(raw['status'] as String?);
            final hasCoordinates = raw['origin_latitude'] != null &&
                raw['origin_longitude'] != null &&
                raw['destination_latitude'] != null &&
                raw['destination_longitude'] != null;
            if (!hasCoordinates) continue;

            if (active == null && status != RideStatus.completed && status != RideStatus.cancelled) {
              active = DriverActiveRide.fromJson(raw);
            }
            if (pendingPayment == null &&
                status == RideStatus.completed &&
                raw['payment_method'] == 'qr' &&
                raw['payment_status'] == 'pending') {
              pendingPayment = DriverActiveRide.fromJson(raw);
            }
          }
          setState(() {
            _activeRide = active;
            _pendingPaymentRide = pendingPayment;
            if (active != null) _incomingRequest = null;
          });
          _fitDriverMap();
        });
  }

  Future<bool> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) {
        showDrivoMessage(
          context,
          'Turn on location services to go online.',
          isError: true,
        );
      }
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        showDrivoMessage(
          context,
          'Allow location access to go online.',
          isError: true,
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _toggleOnline() async {
    if (_busy || _driver == null) return;
    final goingOnline = !_driver!.isOnline;
    setState(() => _busy = true);

    try {
      double? latitude;
      double? longitude;
      if (goingOnline) {
        if (!await _ensureLocationPermission()) return;
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        latitude = position.latitude;
        longitude = position.longitude;
      }

      await supabase.rpc(
        'set_driver_presence',
        params: {
          'p_online': goingOnline,
          'p_latitude': latitude,
          'p_longitude': longitude,
        },
      );

      if (goingOnline) {
        _startLocationPublishing();
      } else {
        await _positionSubscription?.cancel();
        _positionSubscription = null;
      }
    } catch (error) {
      if (mounted) {
        showDrivoMessage(
          context,
          drivoFriendlyError(error, fallback: 'Couldn’t update your online status. Please try again.'),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startLocationPublishing() {
    _positionSubscription?.cancel();
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 8,
    );
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen((position) async {
      if (_locationUpdateInFlight) return;
      _locationUpdateInFlight = true;
      try {
        await supabase.rpc(
          'update_driver_location',
          params: {
            'p_latitude': position.latitude,
            'p_longitude': position.longitude,
          },
        );
      } catch (error) {
        debugPrint('Driver location publish failed: $error');
      } finally {
        _locationUpdateInFlight = false;
      }
    });
  }

  Future<void> _respondToRequest(bool accept) async {
    final request = _incomingRequest;
    if (_busy || request == null) return;
    setState(() => _busy = true);
    try {
      await supabase.rpc(
        'respond_to_ride_request_v2',
        params: {'p_request_id': request.id, 'p_accept': accept},
      );
      if (!mounted) return;
      setState(() => _incomingRequest = null);
      showDrivoMessage(
        context,
        accept ? 'Ride accepted.' : 'Ride declined.',
      );
    } catch (error) {
      if (mounted) {
        showDrivoMessage(
          context,
          drivoFriendlyError(error, fallback: 'Couldn’t respond to this ride. Please try again.'),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _advanceRide() async {
    final ride = _activeRide;
    if (_busy || ride == null) return;
    String? nextStatus;
    switch (ride.status) {
      case RideStatus.driverArriving:
        nextStatus = 'driver_arrived';
        break;
      case RideStatus.driverArrived:
        nextStatus = 'in_progress';
        break;
      case RideStatus.inProgress:
        nextStatus = 'completed';
        break;
      case RideStatus.completed:
      case RideStatus.cancelled:
      case RideStatus.unknown:
        return;
    }

    setState(() => _busy = true);
    try {
      await supabase.rpc(
        'driver_update_ride_status_v2',
        params: {'p_ride_id': ride.id, 'p_status': nextStatus},
      );
    } catch (error) {
      if (mounted) {
        showDrivoMessage(
          context,
          drivoFriendlyError(error, fallback: 'Couldn’t update this trip. Please try again.'),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fitDriverMap() {
    if (!_mapReady) return;
    final points = <LatLng>[];
    if (_driver?.location != null) points.add(_driver!.location!);
    final ride = _activeRide;
    final request = _incomingRequest;
    if (ride != null) {
      points.add(ride.origin);
      points.add(ride.destination);
    } else if (request != null) {
      points.add(request.origin);
      points.add(request.destination);
    }
    if (points.length >= 2) {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.fromLTRB(48, 80, 48, 340),
          maxZoom: 16,
        ),
      );
    } else if (points.isNotEmpty) {
      _mapController.move(points.first, 15);
    }
  }

  String _distanceLabel(int meters) {
    if (meters < 1000) return '$meters m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String get _rideActionLabel {
    switch (_activeRide?.status) {
      case RideStatus.driverArriving:
        return 'I have arrived';
      case RideStatus.driverArrived:
        return 'Start trip';
      case RideStatus.inProgress:
        return 'Complete trip';
      default:
        return 'Update trip';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final driver = _driver;
    if (driver == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Drivo Driver')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'We couldn’t load your Driver account. Please try again.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Drivo Driver'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: driver.isOnline ? Colors.green.shade50 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  driver.isOnline ? 'ONLINE' : 'OFFLINE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: driver.isOnline ? Colors.green.shade800 : Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: 14,
              onMapReady: () {
                _mapReady = true;
                _fitDriverMap();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _osmTileUrl,
                userAgentPackageName: _tileUserAgentPackage,
              ),
              if (_activeRide != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_activeRide!.origin, _activeRide!.destination],
                      strokeWidth: 5,
                      color: DrivoColors.primary,
                    ),
                  ],
                ),
              MarkerLayer(markers: _driverMapMarkers()),
              const SimpleAttributionWidget(
                source: Text('OpenStreetMap contributors'),
              ),
            ],
          ),
          if (_busy)
            const Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Colors.black12,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
        ],
      ),
      bottomSheet: _buildDriverPanel(driver),
    );
  }

  List<Marker> _driverMapMarkers() {
    final markers = <Marker>[];
    if (_driver?.location != null) {
      markers.add(
        Marker(
          point: _driver!.location!,
          width: 52,
          height: 52,
          child: const CircleAvatar(
            backgroundColor: DrivoColors.navy,
            child: Icon(Icons.navigation, color: Colors.white),
          ),
        ),
      );
    }
    final ride = _activeRide;
    final request = _incomingRequest;
    final origin = ride?.origin ?? request?.origin;
    final destination = ride?.destination ?? request?.destination;
    if (origin != null) {
      markers.add(
        Marker(
          point: origin,
          width: 44,
          height: 44,
          alignment: Alignment.bottomCenter,
          child: const Icon(Icons.location_on, color: Colors.green, size: 42),
        ),
      );
    }
    if (destination != null) {
      markers.add(
        Marker(
          point: destination,
          width: 44,
          height: 44,
          alignment: Alignment.bottomCenter,
          child: const Icon(Icons.flag, color: DrivoColors.primary, size: 38),
        ),
      );
    }
    return markers;
  }

  Widget _buildDriverPanel(DriverOperationalState driver) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: _activeRide != null
            ? _buildActiveRidePanel(_activeRide!)
            : _incomingRequest != null
                ? _buildIncomingRequestPanel(_incomingRequest!)
                : _pendingPaymentRide != null
                    ? _buildPendingPaymentPanel(_pendingPaymentRide!)
                    : _buildPresencePanel(driver),
      ),
    );
  }

  Widget _buildPendingPaymentPanel(DriverActiveRide ride) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.qr_code_2, color: DrivoColors.primary),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Waiting for QR payment',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
            ),
            _StatusPill(label: 'PENDING', icon: Icons.schedule),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          ride.passengerPhone.isEmpty
              ? ride.passengerName
              : '${ride.passengerName} • ${ride.passengerPhone}',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        Text(
          'The trip is complete. You’ll become available for another request after the Passenger marks the QR payment as paid.',
          style: TextStyle(color: Colors.grey.shade700, height: 1.35),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                'Fare Rs. ${_moneyFormat.format(ride.fare)}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              'You earn Rs. ${_moneyFormat.format(ride.driverEarning)}',
              style: const TextStyle(fontWeight: FontWeight.w900, color: DrivoColors.primary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPresencePanel(DriverOperationalState driver) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          driver.isOnline ? 'You are online' : 'You are offline',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        Text(
          driver.isOnline
              ? 'You’re available for nearby requests. Drivo will show Passenger and payment details before you accept.'
              : 'Go online when you are ready to receive ride requests.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                '${driver.model} • ${driver.plate}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(driver.isAvailable && driver.isOnline ? 'Available' : 'Not available'),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _toggleOnline,
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            backgroundColor: driver.isOnline ? Colors.grey.shade900 : DrivoColors.primary,
          ),
          icon: Icon(driver.isOnline ? Icons.power_settings_new : Icons.wifi_tethering),
          label: Text(driver.isOnline ? 'Go offline' : 'Go online'),
        ),
      ],
    );
  }

  Widget _buildIncomingRequestPanel(DriverRideRequest request) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'New ride request',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              'Rs. ${_moneyFormat.format(request.fare)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: DrivoColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: DrivoColors.softPurple,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 20,
                child: Icon(Icons.person_outline),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.passengerName, style: const TextStyle(fontWeight: FontWeight.w900)),
                    if (request.passengerPhone.isNotEmpty)
                      Text(request.passengerPhone, style: TextStyle(color: Colors.grey.shade700)),
                  ],
                ),
              ),
              const _StatusPill(label: 'PAYMENT PENDING', icon: Icons.schedule),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _DriverTripLine(
          icon: Icons.radio_button_checked,
          label: 'Pickup',
          value: request.pickupLabel,
          color: Colors.green,
        ),
        const SizedBox(height: 10),
        _DriverTripLine(
          icon: Icons.flag_outlined,
          label: 'Destination',
          value: request.destinationLabel,
          color: DrivoColors.primary,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: Text('Trip: ${_distanceLabel(request.distanceMeters)}')),
            _StatusPill(
              label: request.paymentMethod == 'qr' ? 'ONLINE QR' : 'CASH',
              icon: request.paymentMethod == 'qr' ? Icons.qr_code_2 : Icons.payments_outlined,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Estimated earning: Rs. ${_moneyFormat.format(request.estimatedEarning)}',
          style: const TextStyle(fontWeight: FontWeight.w900, color: DrivoColors.navy),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => _respondToRequest(false),
                child: const Text('Decline'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _busy ? null : () => _respondToRequest(true),
                child: const Text('Accept'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActiveRidePanel(DriverActiveRide ride) {
    final heading = switch (ride.status) {
      RideStatus.driverArriving => 'Head to the passenger',
      RideStatus.driverArrived => 'Passenger pickup',
      RideStatus.inProgress => 'Trip in progress',
      _ => 'Active trip',
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.person_outline, color: DrivoColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ride.passengerPhone.isEmpty
                    ? ride.passengerName
                    : '${ride.passengerName} • ${ride.passengerPhone}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _DriverTripLine(
          icon: Icons.radio_button_checked,
          label: 'Pickup',
          value: ride.pickupLabel,
          color: Colors.green,
        ),
        const SizedBox(height: 9),
        _DriverTripLine(
          icon: Icons.flag_outlined,
          label: 'Destination',
          value: ride.destinationLabel,
          color: DrivoColors.primary,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                'You earn: Rs. ${_moneyFormat.format(ride.driverEarning)}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            _StatusPill(
              label: ride.paymentMethod == 'qr' ? 'ONLINE QR' : 'CASH',
              icon: ride.paymentMethod == 'qr' ? Icons.qr_code_2 : Icons.payments_outlined,
            ),
            const SizedBox(width: 6),
            _StatusPill(
              label: ride.paymentStatus.toUpperCase(),
              icon: ride.paymentStatus == 'paid' ? Icons.check_circle_outline : Icons.schedule,
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _advanceRide,
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
          ),
          child: Text(_rideActionLabel),
        ),
      ],
    );
  }
}

class _DriverTripLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DriverTripLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentChoice extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentChoice({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? DrivoColors.softPurple : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? DrivoColors.primary : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: selected ? DrivoColors.primary : Colors.grey.shade700),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected ? DrivoColors.navy : Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final IconData icon;

  const _StatusPill({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: DrivoColors.softPurple,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: DrivoColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: DrivoColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

class DrivoRegistrationChoiceScreen extends StatelessWidget {
  final String phone;
  final Future<void> Function() onRegistered;
  final VoidCallback onChangePhone;

  const DrivoRegistrationChoiceScreen({
    super.key,
    required this.phone,
    required this.onRegistered,
    required this.onChangePhone,
  });

  Future<void> _open(BuildContext context, Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
          child: Column(
            children: [
              Image.asset('assets/branding/drivo_logo.png', width: 210),
              const Spacer(),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'How will you use Drivo?',
                  style: TextStyle(
                    color: DrivoColors.navy,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose the account that matches how you’ll use Drivo.',
                  style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                ),
              ),
              const SizedBox(height: 22),
              _AccountTypeCard(
                icon: Icons.person_pin_circle_outlined,
                title: 'Passenger',
                subtitle: 'Book Bike, Mini, Car and XL rides.',
                onTap: () => _open(
                  context,
                  DrivoPassengerRegistrationScreen(phone: phone, onRegistered: onRegistered),
                ),
              ),
              const SizedBox(height: 12),
              _AccountTypeCard(
                icon: Icons.drive_eta,
                title: 'Driver',
                subtitle: 'Register your vehicle and documents to earn with Drivo.',
                onTap: () => _open(
                  context,
                  DrivoDriverRegistrationScreen(phone: phone, onRegistered: onRegistered),
                ),
              ),
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: onChangePhone,
                icon: const Icon(Icons.arrow_back),
                label: Text('Use a different number instead of $phone'),
              ),

            ],
          ),
        ),
      ),
    );
  }
}

class _AccountTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AccountTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: DrivoColors.softPurple,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, color: DrivoColors.primary, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: TextStyle(color: Colors.grey.shade600, height: 1.3)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 17),
            ],
          ),
        ),
      ),
    );
  }
}

class DrivoPassengerRegistrationScreen extends StatefulWidget {
  final String phone;
  final Future<void> Function() onRegistered;

  const DrivoPassengerRegistrationScreen({
    super.key,
    required this.phone,
    required this.onRegistered,
  });

  @override
  State<DrivoPassengerRegistrationScreen> createState() => _DrivoPassengerRegistrationScreenState();
}

class _DrivoPassengerRegistrationScreenState extends State<DrivoPassengerRegistrationScreen> {
  final _nameController = TextEditingController();
  late final TextEditingController _phoneController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.phone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.length < 2) {
      _message('Enter your full name.');
      return;
    }
    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
      _message('Phone number must be exactly 10 digits.');
      return;
    }

    setState(() => _saving = true);
    try {
      await supabase.rpc(
        'register_passenger_account',
        params: {'p_full_name': name, 'p_phone': phone},
      );
      await widget.onRegistered();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      _message(drivoFriendlyError(error, fallback: 'Couldn’t create your Passenger account. Please try again.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String value) {
    if (!mounted) return;
    showDrivoMessage(context, value, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Passenger registration')),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const Icon(Icons.person_pin_circle_outlined, size: 58, color: DrivoColors.primary),
          const SizedBox(height: 14),
          const Text(
            'Create your Passenger account',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: DrivoColors.navy),
          ),
          const SizedBox(height: 8),
          Text(
            'Set up your profile and start booking rides with Drivo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              prefixIcon: Icon(Icons.phone_outlined),
              suffixIcon: Icon(Icons.lock_outline),
            ),
          ),

          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _register,
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 54)),
            child: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Create Passenger account'),
          ),
        ],
      ),
    );
  }
}

class DrivoDriverRegistrationScreen extends StatefulWidget {
  final String phone;
  final Future<void> Function() onRegistered;

  const DrivoDriverRegistrationScreen({
    super.key,
    required this.phone,
    required this.onRegistered,
  });

  @override
  State<DrivoDriverRegistrationScreen> createState() => _DrivoDriverRegistrationScreenState();
}

class _DrivoDriverRegistrationScreenState extends State<DrivoDriverRegistrationScreen> {
  final ImagePicker _picker = ImagePicker();
  final _nameController = TextEditingController();
  late final TextEditingController _phoneController;
  final _addressController = TextEditingController();
  final _licenseController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _plateController = TextEditingController();

  final Map<String, XFile?> _docs = {
    'profile': null,
    'license_front': null,
    'license_back': null,
    'registration_front': null,
    'registration_back': null,
    'insurance': null,
    'vehicle_front': null,
    'vehicle_rear': null,
    'vehicle_side': null,
  };

  List<VehicleCategoryChoice> _categories = const [];
  String? _categoryId;
  DateTime? _dob;
  DateTime? _licenseIssue;
  DateTime? _licenseExpiry;
  DateTime? _insuranceExpiry;
  int _step = 0;
  bool _loadingCategories = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.phone);
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _licenseController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final rows = await supabase
          .from('vehicle_categories')
          .select('id, slug, name')
          .eq('is_active', true)
          .order('display_order');
      final categories = rows
          .map((row) => VehicleCategoryChoice.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _categoryId = categories.isEmpty ? null : categories.first.id;
        _loadingCategories = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingCategories = false);
      _message(drivoFriendlyError(error, fallback: 'Ride options are unavailable right now. Please try again.'));
    }
  }

  Future<void> _pickDoc(String key) async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 86, maxWidth: 1800);
    if (image == null || !mounted) return;
    if (await image.length() > 5 * 1024 * 1024) {
      _message('Choose images smaller than 5 MB.');
      return;
    }
    setState(() => _docs[key] = image);
  }

  Future<void> _pickDate(String key) async {
    final now = DateTime.now();
    DateTime initial;
    DateTime first;
    DateTime last;
    switch (key) {
      case 'dob':
        initial = DateTime(now.year - 22, now.month, now.day);
        first = DateTime(1950);
        last = DateTime(now.year - 18, now.month, now.day);
        break;
      case 'license_issue':
        initial = DateTime(now.year - 2, now.month, now.day);
        first = DateTime(1990);
        last = now;
        break;
      default:
        initial = DateTime(now.year + 1, now.month, now.day);
        first = now;
        last = DateTime(now.year + 15);
    }
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: first, lastDate: last);
    if (picked == null || !mounted) return;
    setState(() {
      switch (key) {
        case 'dob': _dob = picked; break;
        case 'license_issue': _licenseIssue = picked; break;
        case 'license_expiry': _licenseExpiry = picked; break;
        case 'insurance_expiry': _insuranceExpiry = picked; break;
      }
    });
  }

  bool _validStep(int step) {
    if (step == 0) {
      if (_nameController.text.trim().length < 2 ||
          !RegExp(r'^\d{10}$').hasMatch(_phoneController.text.trim()) ||
          _dob == null ||
          _addressController.text.trim().length < 5 ||
          _docs['profile'] == null) {
        _message('Complete all personal details and add your profile photo.');
        return false;
      }
    } else if (step == 1) {
      if (_licenseController.text.trim().length < 3 || _licenseIssue == null || _licenseExpiry == null ||
          _docs['license_front'] == null || _docs['license_back'] == null) {
        _message('Complete the driving license section.');
        return false;
      }
    } else if (step == 2) {
      final year = int.tryParse(_yearController.text.trim());
      if (_categoryId == null || _makeController.text.trim().length < 2 || _modelController.text.trim().length < 2 ||
          year == null || _colorController.text.trim().length < 2 || _plateController.text.trim().length < 3 ||
          _docs['vehicle_front'] == null || _docs['vehicle_rear'] == null || _docs['vehicle_side'] == null) {
        _message('Complete all vehicle details and vehicle photos.');
        return false;
      }
    } else if (step == 3) {
      if (_docs['registration_front'] == null || _docs['registration_back'] == null ||
          _docs['insurance'] == null || _insuranceExpiry == null) {
        _message('Complete registration and insurance documents.');
        return false;
      }
    }
    return true;
  }

  String _extensionFor(XFile file) {
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'png';
    if (name.endsWith('.webp')) return 'webp';
    return 'jpg';
  }

  String _contentTypeFor(XFile file) {
    final extension = _extensionFor(file);
    if (extension == 'png') return 'image/png';
    if (extension == 'webp') return 'image/webp';
    return 'image/jpeg';
  }

  Future<String> _upload(String key, XFile file) async {
    final user = supabase.auth.currentUser!;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final path = '${user.id}/${key}_$stamp.${_extensionFor(file)}';
    await supabase.storage.from('driver-documents').upload(
      path,
      File(file.path),
      fileOptions: FileOptions(cacheControl: '3600', contentType: _contentTypeFor(file), upsert: false),
    );
    return path;
  }

  String _date(DateTime value) => DateFormat('yyyy-MM-dd').format(value);

  Future<void> _submit() async {
    if (_submitting || !_validStep(0) || !_validStep(1) || !_validStep(2) || !_validStep(3)) return;
    setState(() => _submitting = true);
    try {
      final uploaded = <String, String>{};
      for (final entry in _docs.entries) {
        uploaded[entry.key] = await _upload(entry.key, entry.value!);
      }

      await supabase.rpc(
        'register_driver_account',
        params: {
          'p_full_name': _nameController.text.trim(),
          'p_phone': _phoneController.text.trim(),
          'p_date_of_birth': _date(_dob!),
          'p_address': _addressController.text.trim(),
          'p_license_number': _licenseController.text.trim(),
          'p_license_issue_date': _date(_licenseIssue!),
          'p_license_expiry_date': _date(_licenseExpiry!),
          'p_category_id': _categoryId,
          'p_vehicle_make': _makeController.text.trim(),
          'p_vehicle_model': _modelController.text.trim(),
          'p_vehicle_year': int.parse(_yearController.text.trim()),
          'p_vehicle_color': _colorController.text.trim(),
          'p_plate_number': _plateController.text.trim().toUpperCase(),
          'p_profile_photo_path': uploaded['profile'],
          'p_license_front_photo_path': uploaded['license_front'],
          'p_license_back_photo_path': uploaded['license_back'],
          'p_registration_front_photo_path': uploaded['registration_front'],
          'p_registration_back_photo_path': uploaded['registration_back'],
          'p_insurance_photo_path': uploaded['insurance'],
          'p_insurance_expiry_date': _date(_insuranceExpiry!),
          'p_vehicle_front_photo_path': uploaded['vehicle_front'],
          'p_vehicle_rear_photo_path': uploaded['vehicle_rear'],
          'p_vehicle_side_photo_path': uploaded['vehicle_side'],
        },
      );

      await widget.onRegistered();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      _message(drivoFriendlyError(error, fallback: 'Couldn’t submit your Driver application. Please try again.'));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _next() {
    if (_validStep(_step)) {
      if (_step < 3) {
        setState(() => _step++);
      } else {
        _submit();
      }
    }
  }

  void _message(String value) {
    if (!mounted) return;
    showDrivoMessage(context, value, isError: true);
  }

  Widget _dateTile(String title, DateTime? value, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.calendar_month_outlined),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(value == null ? 'Select date' : DateFormat('MMM d, y').format(value)),
      trailing: const Icon(Icons.chevron_right),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver registration')),
      body: _loadingCategories
          ? const Center(child: CircularProgressIndicator())
          : Stepper(
              currentStep: _step,
              onStepTapped: (index) {
                if (index <= _step) setState(() => _step = index);
              },
              controlsBuilder: (context, details) {
                return Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _submitting ? null : _next,
                          child: _submitting
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(_step == 3 ? 'Submit for review' : 'Continue'),
                        ),
                      ),
                      if (_step > 0) ...[
                        const SizedBox(width: 9),
                        OutlinedButton(onPressed: _submitting ? null : () => setState(() => _step--), child: const Text('Back')),
                      ],
                    ],
                  ),
                );
              },
              steps: [
                Step(
                  title: const Text('Personal'),
                  subtitle: const Text('Identity and contact'),
                  isActive: _step >= 0,
                  content: Column(
                    children: [
                      TextField(controller: _nameController, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full legal name')),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _phoneController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Phone number',
                          suffixIcon: Icon(Icons.lock_outline),
                                    ),
                      ),
                      _dateTile('Date of birth', _dob, () => _pickDate('dob')),
                      TextField(controller: _addressController, maxLines: 2, decoration: const InputDecoration(labelText: 'Current address')),
                      const SizedBox(height: 10),
                      _DocumentPickerTile(title: 'Driver profile photo', subtitle: 'Clear front-facing photo', file: _docs['profile'], onTap: () => _pickDoc('profile')),
                    ],
                  ),
                ),
                Step(
                  title: const Text('License'),
                  subtitle: const Text('Driving eligibility'),
                  isActive: _step >= 1,
                  content: Column(
                    children: [
                      TextField(controller: _licenseController, decoration: const InputDecoration(labelText: 'Driving license number')),
                      _dateTile('License issue date', _licenseIssue, () => _pickDate('license_issue')),
                      _dateTile('License expiry date', _licenseExpiry, () => _pickDate('license_expiry')),
                      _DocumentPickerTile(title: 'License front', subtitle: 'Front side of license', file: _docs['license_front'], onTap: () => _pickDoc('license_front')),
                      const SizedBox(height: 9),
                      _DocumentPickerTile(title: 'License back', subtitle: 'Back side of license', file: _docs['license_back'], onTap: () => _pickDoc('license_back')),
                    ],
                  ),
                ),
                Step(
                  title: const Text('Vehicle'),
                  subtitle: const Text('Category and vehicle details'),
                  isActive: _step >= 2,
                  content: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _categoryId,
                        decoration: const InputDecoration(labelText: 'What will you drive?'),
                        items: _categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(growable: false),
                        onChanged: (value) => setState(() => _categoryId = value),
                      ),
                      const SizedBox(height: 10),
                      TextField(controller: _makeController, decoration: const InputDecoration(labelText: 'Vehicle manufacturer', hintText: 'e.g. Suzuki')),
                      const SizedBox(height: 10),
                      TextField(controller: _modelController, decoration: const InputDecoration(labelText: 'Vehicle model', hintText: 'e.g. Swift')),
                      const SizedBox(height: 10),
                      TextField(controller: _yearController, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)], decoration: const InputDecoration(labelText: 'Model year')),
                      const SizedBox(height: 10),
                      TextField(controller: _colorController, decoration: const InputDecoration(labelText: 'Vehicle color')),
                      const SizedBox(height: 10),
                      TextField(controller: _plateController, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Plate number')),
                      const SizedBox(height: 12),
                      _DocumentPickerTile(title: 'Vehicle front', subtitle: 'Front photo', file: _docs['vehicle_front'], onTap: () => _pickDoc('vehicle_front')),
                      const SizedBox(height: 9),
                      _DocumentPickerTile(title: 'Vehicle rear', subtitle: 'Rear photo', file: _docs['vehicle_rear'], onTap: () => _pickDoc('vehicle_rear')),
                      const SizedBox(height: 9),
                      _DocumentPickerTile(title: 'Vehicle side', subtitle: 'Side photo', file: _docs['vehicle_side'], onTap: () => _pickDoc('vehicle_side')),
                    ],
                  ),
                ),
                Step(
                  title: const Text('Documents'),
                  subtitle: const Text('Registration and insurance'),
                  isActive: _step >= 3,
                  content: Column(
                    children: [
                      _DocumentPickerTile(title: 'Registration front', subtitle: 'Vehicle registration front', file: _docs['registration_front'], onTap: () => _pickDoc('registration_front')),
                      const SizedBox(height: 9),
                      _DocumentPickerTile(title: 'Registration back', subtitle: 'Vehicle registration back', file: _docs['registration_back'], onTap: () => _pickDoc('registration_back')),
                      const SizedBox(height: 9),
                      _DocumentPickerTile(title: 'Insurance document', subtitle: 'Current vehicle insurance', file: _docs['insurance'], onTap: () => _pickDoc('insurance')),
                      _dateTile('Insurance expiry date', _insuranceExpiry, () => _pickDate('insurance_expiry')),
                      const SizedBox(height: 8),
                      Text(
                        'Once your application is approved, you’ll be ready to start driving.',
                        style: TextStyle(color: Colors.grey.shade700, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class DrivoDriverGate extends StatefulWidget {
  final DrivoProfile profile;
  final ValueChanged<DrivoProfile> onProfileChanged;
  final Future<void> Function() onLogout;

  const DrivoDriverGate({
    super.key,
    required this.profile,
    required this.onProfileChanged,
    required this.onLogout,
  });

  @override
  State<DrivoDriverGate> createState() => _DrivoDriverGateState();
}

class _DrivoDriverGateState extends State<DrivoDriverGate> {
  DriverApplication? _application;
  bool _loading = true;
  String? _error;
  StreamSubscription<dynamic>? _subscription;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await supabase
          .from('driver_applications')
          .select('id, user_id, full_name, phone, vehicle_model, vehicle_color, plate_number, license_number, status, review_note, submitted_at, reviewed_at, category_id, vehicle_categories(slug, name)')
          .eq('user_id', widget.profile.id)
          .limit(1);
      if (rows.isEmpty) throw Exception('Driver application not found');
      final application = DriverApplication.fromJson(Map<String, dynamic>.from(rows.first));
      if (!mounted) return;
      setState(() {
        _application = application;
        _loading = false;
      });
      _listen(application.id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = drivoFriendlyError(error, fallback: 'We couldn’t load your Driver account. Please try again.');
        _loading = false;
      });
    }
  }

  void _listen(String applicationId) {
    _subscription?.cancel();
    _subscription = supabase
        .from('driver_applications')
        .stream(primaryKey: ['id'])
        .eq('id', applicationId)
        .listen((data) async {
          if (!mounted || data.isEmpty) return;
          await _loadSingle(applicationId);
        });
  }

  Future<void> _loadSingle(String id) async {
    try {
      final row = await supabase
          .from('driver_applications')
          .select('id, user_id, full_name, phone, vehicle_model, vehicle_color, plate_number, license_number, status, review_note, submitted_at, reviewed_at, category_id, vehicle_categories(slug, name)')
          .eq('id', id)
          .single();
      if (mounted) setState(() => _application = DriverApplication.fromJson(Map<String, dynamic>.from(row)));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null || _application == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error ?? 'We couldn’t load your Driver account. Please try again.', textAlign: TextAlign.center),
          ),
        ),
      );
    }
    if (_application!.status == DriverApplicationStatus.approved) {
      return DrivoDriverPortal(
        profile: widget.profile,
        onLogout: widget.onLogout,
      );
    }
    return DriverApplicationStatusScreen(
      profile: widget.profile,
      initialApplication: _application!,
      onLogout: widget.onLogout,
    );
  }
}

class DrivoDriverPortal extends StatefulWidget {
  final DrivoProfile profile;
  final Future<void> Function() onLogout;

  const DrivoDriverPortal({
    super.key,
    required this.profile,
    required this.onLogout,
  });

  @override
  State<DrivoDriverPortal> createState() => _DrivoDriverPortalState();
}

class _DrivoDriverPortalState extends State<DrivoDriverPortal> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      DrivoDriverHomeScreen(profile: widget.profile),
      const DrivoDriverEarningsScreen(),
      const DrivoDriverTripsScreen(),
      DrivoDriverAccountScreen(
        profile: widget.profile,
        onLogout: widget.onLogout,
      ),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Earnings'),
          NavigationDestination(icon: Icon(Icons.history), selectedIcon: Icon(Icons.history_rounded), label: 'Trips'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class DriverTripRecord {
  final String id;
  final int fare;
  final int earning;
  final int platformFee;
  final String pickup;
  final String destination;
  final String paymentMethod;
  final String paymentStatus;
  final String passengerName;
  final String passengerPhone;
  final int? driverRating;
  final String driverRatingComment;
  final DateTime createdAt;
  final DateTime? completedAt;

  const DriverTripRecord({
    required this.id,
    required this.fare,
    required this.earning,
    required this.platformFee,
    required this.pickup,
    required this.destination,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.passengerName,
    required this.passengerPhone,
    required this.driverRating,
    required this.driverRatingComment,
    required this.createdAt,
    required this.completedAt,
  });

  factory DriverTripRecord.fromJson(Map<String, dynamic> json) {
    final fare = (json['fare'] as num).toInt();
    final fallbackFee = (fare * 0.10).round();
    return DriverTripRecord(
      id: json['id'] as String,
      fare: fare,
      earning: (json['driver_earning'] as num?)?.toInt() ?? fare - fallbackFee,
      platformFee: (json['platform_fee'] as num?)?.toInt() ?? fallbackFee,
      pickup: (json['pickup_label'] as String?) ?? 'Pickup',
      destination: (json['destination_label'] as String?) ?? 'Destination',
      paymentMethod: (json['payment_method'] as String?) ?? 'cash',
      paymentStatus: (json['payment_status'] as String?) ?? 'pending',
      passengerName: (json['passenger_name'] as String?) ?? 'Passenger',
      passengerPhone: (json['passenger_phone'] as String?) ?? '',
      driverRating: (json['driver_rating'] as num?)?.toInt(),
      driverRatingComment: (json['driver_rating_comment'] as String?) ?? '',
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      completedAt: json['completed_at'] == null ? null : DateTime.parse(json['completed_at'] as String).toLocal(),
    );
  }
}

Future<List<DriverTripRecord>> loadDriverCompletedTrips() async {
  final user = supabase.auth.currentUser;
  if (user == null) return const [];
  final rows = await supabase
      .from('rides')
      .select('id, fare, driver_earning, platform_fee, pickup_label, destination_label, payment_method, payment_status, passenger_name, passenger_phone, driver_rating, driver_rating_comment, rated_at, created_at, completed_at')
      .eq('driver_id', user.id)
      .eq('status', 'completed')
      .order('created_at', ascending: false)
      .limit(100);
  return rows.map((row) => DriverTripRecord.fromJson(Map<String, dynamic>.from(row))).toList(growable: false);
}

class DrivoDriverEarningsScreen extends StatefulWidget {
  const DrivoDriverEarningsScreen({super.key});

  @override
  State<DrivoDriverEarningsScreen> createState() => _DrivoDriverEarningsScreenState();
}

class _DrivoDriverEarningsScreenState extends State<DrivoDriverEarningsScreen> {
  final NumberFormat _money = NumberFormat.decimalPattern();
  List<DriverTripRecord> _trips = const [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loadError = null);
    try {
      final trips = await loadDriverCompletedTrips();
      if (mounted) {
        setState(() {
          _trips = trips;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadError = drivoFriendlyError(
            error,
            fallback: 'We couldn’t load your earnings. Please try again.',
          );
          _loading = false;
        });
      }
    }
  }

  int _sumWhere(bool Function(DriverTripRecord) test) => _trips.where(test).fold(0, (sum, trip) => sum + trip.earning);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: todayStart.weekday - 1));
    final monthStart = DateTime(now.year, now.month);
    final today = _sumWhere((t) => (t.completedAt ?? t.createdAt).isAfter(todayStart));
    final week = _sumWhere((t) => (t.completedAt ?? t.createdAt).isAfter(weekStart));
    final month = _sumWhere((t) => (t.completedAt ?? t.createdAt).isAfter(monthStart));
    final cash = _trips.where((t) => t.paymentMethod == 'cash').fold(0, (sum, t) => sum + t.earning);
    final qr = _trips.where((t) => t.paymentMethod == 'qr').fold(0, (sum, t) => sum + t.earning);

    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: _loadError != null && !_loading
          ? ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 120),
                const Icon(Icons.cloud_off_outlined, size: 52, color: DrivoColors.primary),
                const SizedBox(height: 14),
                Text(_loadError!, textAlign: TextAlign.center),
                const SizedBox(height: 18),
                Center(
                  child: FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ),
              ],
            )
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: DrivoColors.navy,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Today', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('Rs. ${_money.format(today)}', style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text('${_trips.where((t) => (t.completedAt ?? t.createdAt).isAfter(todayStart)).length} completed trips', style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _DriverMetricCard(label: 'This week', value: 'Rs. ${_money.format(week)}', icon: Icons.calendar_view_week_outlined)),
                const SizedBox(width: 10),
                Expanded(child: _DriverMetricCard(label: 'This month', value: 'Rs. ${_money.format(month)}', icon: Icons.calendar_month_outlined)),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Payment breakdown', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              child: Column(
                children: [
                  ListTile(leading: const Icon(Icons.payments_outlined), title: const Text('Cash earnings'), trailing: Text('Rs. ${_money.format(cash)}', style: const TextStyle(fontWeight: FontWeight.w900))),
                  const Divider(height: 1),
                  ListTile(leading: const Icon(Icons.qr_code_2), title: const Text('Online QR earnings'), trailing: Text('Rs. ${_money.format(qr)}', style: const TextStyle(fontWeight: FontWeight.w900))),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text('Drivo service fee: 10% per completed ride.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            if (_loading) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }
}

class _DriverMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DriverMetricCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: DrivoColors.primary),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

class DrivoDriverTripsScreen extends StatefulWidget {
  const DrivoDriverTripsScreen({super.key});

  @override
  State<DrivoDriverTripsScreen> createState() => _DrivoDriverTripsScreenState();
}

class _DrivoDriverTripsScreenState extends State<DrivoDriverTripsScreen> {
  final NumberFormat _money = NumberFormat.decimalPattern();
  List<DriverTripRecord> _trips = const [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loadError = null);
    try {
      final trips = await loadDriverCompletedTrips();
      if (mounted) {
        setState(() {
          _trips = trips;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadError = drivoFriendlyError(
            error,
            fallback: 'We couldn’t load your trip history. Please try again.',
          );
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalEarnings = _trips.fold<int>(0, (sum, trip) => sum + trip.earning);
    final paidTrips = _trips.where((trip) => trip.paymentStatus == 'paid').length;

    return Scaffold(
      appBar: AppBar(title: const Text('Trip history')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                children: const [
                  SizedBox(height: 240),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _loadError != null
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 120),
                      const Icon(
                        Icons.cloud_off_outlined,
                        size: 52,
                        color: DrivoColors.primary,
                      ),
                      const SizedBox(height: 14),
                      Text(_loadError!, textAlign: TextAlign.center),
                      const SizedBox(height: 18),
                      Center(
                        child: FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try again'),
                        ),
                      ),
                    ],
                  )
                : _trips.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          const SizedBox(height: 150),
                          Icon(
                            Icons.route_outlined,
                            size: 58,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No completed trips yet',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Completed rides and earnings will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: DrivoColors.navy,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Trip activity',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${_trips.length} completed trip${_trips.length == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _DriverHistorySummaryMetric(
                                        label: 'Your earnings',
                                        value: 'Rs. ${_money.format(totalEarnings)}',
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _DriverHistorySummaryMetric(
                                        label: 'Paid trips',
                                        value: '$paidTrips',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Recent trips',
                                  style: TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              IconButton.filledTonal(
                                tooltip: 'Refresh trips',
                                onPressed: _load,
                                icon: const Icon(Icons.refresh_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ..._trips.map(
                            (trip) => _DriverTripHistoryCard(
                              trip: trip,
                              money: _money,
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }

}

class _DriverHistorySummaryMetric extends StatelessWidget {
  final String label;
  final String value;

  const _DriverHistorySummaryMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

class _DriverTripHistoryCard extends StatelessWidget {
  final DriverTripRecord trip;
  final NumberFormat money;

  const _DriverTripHistoryCard({required this.trip, required this.money});

  @override
  Widget build(BuildContext context) {
    final paid = trip.paymentStatus == 'paid';
    final completedAt = trip.completedAt ?? trip.createdAt;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8E7F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x09000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF3),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'COMPLETED',
                  style: TextStyle(
                    color: Color(0xFF067647),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .35,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Rs. ${money.format(trip.earning)}',
                style: const TextStyle(
                  color: DrivoColors.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            DateFormat('EEE, MMM d • h:mm a').format(completedAt),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DrivoColors.background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: DrivoColors.softPurple,
                  child: Icon(Icons.person_rounded, color: DrivoColors.primary),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.passengerName,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      if (trip.passengerPhone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          trip.passengerPhone,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          _TripRouteTimeline(
            pickup: trip.pickup,
            destination: trip.destination,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _HistoryMetaPill(
                icon: trip.paymentMethod == 'qr'
                    ? Icons.qr_code_2_rounded
                    : Icons.payments_outlined,
                label: trip.paymentMethod == 'qr' ? 'Online QR' : 'Cash',
              ),
              _HistoryMetaPill(
                icon: paid
                    ? Icons.check_circle_outline_rounded
                    : Icons.schedule_rounded,
                label: paid ? 'Paid' : 'Pending',
                foreground: paid
                    ? const Color(0xFF067647)
                    : const Color(0xFFB54708),
                background: paid
                    ? const Color(0xFFECFDF3)
                    : const Color(0xFFFFFAEB),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _DriverFareMetric(
                    label: 'Trip fare',
                    value: 'Rs. ${money.format(trip.fare)}',
                  ),
                ),
                Expanded(
                  child: _DriverFareMetric(
                    label: 'Drivo fee',
                    value: 'Rs. ${money.format(trip.platformFee)}',
                  ),
                ),
                Expanded(
                  child: _DriverFareMetric(
                    label: 'You earned',
                    value: 'Rs. ${money.format(trip.earning)}',
                    highlight: true,
                  ),
                ),
              ],
            ),
          ),
          if (trip.driverRating != null) ...[
            const SizedBox(height: 13),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _ratingStars(rating: trip.driverRating!, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '${trip.driverRating}/5',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const Spacer(),
                      Text(
                        'Passenger rating',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  if (trip.driverRatingComment.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '“${trip.driverRatingComment}”',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DriverFareMetric extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _DriverFareMetric({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: highlight ? DrivoColors.primary : DrivoColors.navy,
          ),
        ),
      ],
    );
  }
}

class DriverRatingFeedback {
  final int rating;
  final String comment;
  final String passengerName;
  final DateTime date;

  const DriverRatingFeedback({
    required this.rating,
    required this.comment,
    required this.passengerName,
    required this.date,
  });

  factory DriverRatingFeedback.fromJson(Map<String, dynamic> json) {
    final rawDate = (json['completed_at'] ?? json['created_at']) as String;
    return DriverRatingFeedback(
      rating: (json['driver_rating'] as num).toInt(),
      comment: (json['driver_rating_comment'] as String?) ?? '',
      passengerName: (json['passenger_name'] as String?) ?? 'Passenger',
      date: DateTime.parse(rawDate).toLocal(),
    );
  }
}

class DrivoDriverRatingsScreen extends StatefulWidget {
  const DrivoDriverRatingsScreen({super.key});

  @override
  State<DrivoDriverRatingsScreen> createState() => _DrivoDriverRatingsScreenState();
}

class _DrivoDriverRatingsScreenState extends State<DrivoDriverRatingsScreen> {
  List<DriverRatingFeedback> _ratings = const [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Authentication required');
      final rows = await supabase
          .from('rides')
          .select(
            'driver_rating, driver_rating_comment, passenger_name, created_at, completed_at',
          )
          .eq('driver_id', user.id)
          .eq('status', 'completed')
          .order('created_at', ascending: false)
          .limit(100);
      final ratings = rows
          .where((row) => row['driver_rating'] != null)
          .map(
            (row) => DriverRatingFeedback.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _ratings = ratings;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = drivoFriendlyError(
          error,
          fallback: 'We couldn’t load your ratings. Please try again.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _ratings.length;
    final average = total == 0
        ? 0.0
        : _ratings.fold<int>(0, (sum, item) => sum + item.rating) / total;
    final breakdown = <int, int>{
      for (var star = 1; star <= 5; star++)
        star: _ratings.where((item) => item.rating == star).length,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Ratings & feedback')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                children: const [
                  SizedBox(height: 240),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _loadError != null
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 120),
                      const Icon(
                        Icons.cloud_off_outlined,
                        size: 52,
                        color: DrivoColors.primary,
                      ),
                      const SizedBox(height: 14),
                      Text(_loadError!, textAlign: TextAlign.center),
                      const SizedBox(height: 18),
                      Center(
                        child: FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try again'),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: DrivoColors.navy,
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: total == 0
                            ? const Column(
                                children: [
                                  Icon(
                                    Icons.star_outline_rounded,
                                    color: DrivoColors.mint,
                                    size: 46,
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'No ratings yet',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    'Passenger ratings from completed rides will appear here.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        average.toStringAsFixed(2),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 42,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      _ratingStars(
                                        rating: average.round(),
                                        size: 22,
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        '$total rating${total == 1 ? '' : 's'}',
                                        style: const TextStyle(color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 26),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        for (var star = 5; star >= 1; star--)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 3),
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                  width: 14,
                                                  child: Text(
                                                    '$star',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                                const Icon(
                                                  Icons.star_rounded,
                                                  size: 13,
                                                  color: Color(0xFFFFB300),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(99),
                                                    child: LinearProgressIndicator(
                                                      minHeight: 7,
                                                      value: total == 0
                                                          ? 0
                                                          : (breakdown[star] ?? 0) / total,
                                                      backgroundColor: Colors.white24,
                                                      valueColor: const AlwaysStoppedAnimation<Color>(
                                                        DrivoColors.mint,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      if (total > 0) ...[
                        const SizedBox(height: 22),
                        const Text(
                          'Recent feedback',
                          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 9),
                        ..._ratings.take(20).map(
                              (item) => Card(
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 9),
                                child: Padding(
                                  padding: const EdgeInsets.all(15),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.passengerName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            DateFormat('MMM d').format(item.date),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 7),
                                      _ratingStars(rating: item.rating, size: 19),
                                      if (item.comment.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          '“${item.comment}”',
                                          style: TextStyle(
                                            height: 1.35,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ],
                  ),
      ),
    );
  }
}

class DrivoDriverAccountScreen extends StatefulWidget {
  final DrivoProfile profile;
  final Future<void> Function() onLogout;

  const DrivoDriverAccountScreen({
    super.key,
    required this.profile,
    required this.onLogout,
  });

  @override
  State<DrivoDriverAccountScreen> createState() => _DrivoDriverAccountScreenState();
}

class _DrivoDriverAccountScreenState extends State<DrivoDriverAccountScreen> {
  final ImagePicker _picker = ImagePicker();
  Map<String, dynamic>? _application;
  Map<String, dynamic>? _driver;
  bool _loading = true;
  bool _uploadingQr = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loadError = null);
    try {
      final user = supabase.auth.currentUser!;
      final app = await supabase
          .from('driver_applications')
          .select('id, full_name, phone, date_of_birth, address, license_number, license_issue_date, license_expiry_date, profile_photo_path, license_photo_path, license_back_photo_path, registration_photo_path, registration_back_photo_path, insurance_photo_path, insurance_expiry_date, vehicle_front_photo_path, vehicle_rear_photo_path, vehicle_side_photo_path, vehicle_make, vehicle_model, vehicle_year, vehicle_color, plate_number, status, review_note, vehicle_categories(name)')
          .eq('user_id', user.id)
          .single();
      final driver = await supabase
          .from('drivers')
          .select('id, name, phone, model, vehicle_make, vehicle_year, number, vehicle_color, rating, rating_count, is_online, is_available, is_suspended, payment_qr_path, vehicle_categories(name)')
          .eq('id', user.id)
          .single();
      if (mounted) setState(() { _application = Map<String, dynamic>.from(app); _driver = Map<String, dynamic>.from(driver); _loading = false; });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadError = drivoFriendlyError(
            error,
            fallback: 'We couldn’t load your Driver profile. Please try again.',
          );
          _loading = false;
        });
      }
    }
  }

  String _extensionFor(XFile file) {
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'png';
    if (name.endsWith('.webp')) return 'webp';
    return 'jpg';
  }

  String _contentTypeFor(XFile file) {
    final ext = _extensionFor(file);
    return ext == 'png' ? 'image/png' : ext == 'webp' ? 'image/webp' : 'image/jpeg';
  }

  Future<void> _uploadPaymentQr() async {
    if (_uploadingQr) return;
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 92, maxWidth: 1600);
    if (image == null || !mounted) return;
    final imageSize = await image.length();
    if (!mounted) return;
    if (imageSize > 5 * 1024 * 1024) {
      showDrivoMessage(
        context,
        'Choose a QR image smaller than 5 MB.',
        isError: true,
      );
      return;
    }
    setState(() => _uploadingQr = true);
    try {
      final user = supabase.auth.currentUser!;
      final path = '${user.id}/payment_qr_${DateTime.now().microsecondsSinceEpoch}.${_extensionFor(image)}';
      await supabase.storage.from('driver-payment-assets').upload(
        path,
        File(image.path),
        fileOptions: FileOptions(upsert: false, contentType: _contentTypeFor(image)),
      );
      await supabase.rpc('set_driver_payment_qr', params: {'p_path': path});
      await _load();
      if (mounted) showDrivoMessage(context, 'Payment QR updated.');
    } catch (error) {
      if (mounted) showDrivoMessage(context, drivoFriendlyError(error, fallback: 'Couldn’t save your payment QR. Please try again.'), isError: true);
    } finally {
      if (mounted) setState(() => _uploadingQr = false);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDrivoLogoutConfirmation(context);
    if (!confirmed || !mounted) return;
    try {
      await widget.onLogout();
    } catch (error) {
      if (!mounted) return;
      showDrivoMessage(
        context,
        drivoFriendlyError(error, fallback: 'Couldn’t log out. Please try again.'),
        isError: true,
      );
    }
  }

  String _categoryName() {
    final raw = _application?['vehicle_categories'];
    return raw is Map ? ((raw['name'] as String?) ?? 'Drivo vehicle') : 'Drivo vehicle';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Driver profile')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 52, color: DrivoColors.primary),
                const SizedBox(height: 14),
                Text(_loadError!, textAlign: TextAlign.center),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final app = _application ?? const <String, dynamic>{};
    final driver = _driver ?? const <String, dynamic>{};
    final qrPath = driver['payment_qr_path'] as String?;
    final rating = (driver['rating'] as num?)?.toDouble() ?? 5.0;
    final ratingCount = (driver['rating_count'] as num?)?.toInt() ?? 0;
    final initial = widget.profile.displayName.isEmpty ? 'D' : widget.profile.displayName[0].toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Driver profile')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: DrivoColors.navy, borderRadius: BorderRadius.circular(24)),
              child: Row(
                children: [
                  CircleAvatar(radius: 34, backgroundColor: Colors.white, child: Text(initial, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: DrivoColors.navy))),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.profile.displayName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text(widget.profile.phone, style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 7),
                        const Row(children: [Icon(Icons.verified, color: DrivoColors.mint, size: 17), SizedBox(width: 4), Text('Verified Driver', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: Column(
                children: [
                  ListTile(leading: const Icon(Icons.directions_car_outlined), title: Text('${app['vehicle_make'] ?? ''} ${app['vehicle_model'] ?? driver['model'] ?? ''}'.trim()), subtitle: Text('${_categoryName()} • ${app['vehicle_color'] ?? driver['vehicle_color'] ?? ''} • ${app['plate_number'] ?? driver['number'] ?? ''}')),
                  const Divider(height: 1),
                  ListTile(leading: const Icon(Icons.badge_outlined), title: const Text('Driving license'), subtitle: Text('${app['license_number'] ?? 'Not provided'}')),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFFB300),
                    ),
                    title: const Text('Ratings & feedback'),
                    subtitle: Text(
                      ratingCount == 0
                          ? 'No passenger ratings yet'
                          : '${rating.toStringAsFixed(2)} average • $ratingCount rating${ratingCount == 1 ? '' : 's'}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const DrivoDriverRatingsScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Online payment QR', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    if (qrPath == null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Column(children: [Icon(Icons.qr_code_2, size: 58, color: Colors.grey.shade400), const SizedBox(height: 8), const Text('No payment QR added yet.')]),
                      )
                    else
                      _PrivateStorageImage(bucket: 'driver-payment-assets', path: qrPath, height: 220),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _uploadingQr ? null : _uploadPaymentQr,
                      icon: const Icon(Icons.upload_outlined),
                      label: Text(qrPath == null ? 'Add payment QR' : 'Replace payment QR'),
                    ),
                    const SizedBox(height: 7),
                    Text('Passengers choosing Online QR can use this after the trip.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Verification documents', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            ...[
              ('Profile photo', app['profile_photo_path'] as String?),
              ('License front', app['license_photo_path'] as String?),
              ('License back', app['license_back_photo_path'] as String?),
              ('Registration front', app['registration_photo_path'] as String?),
              ('Registration back', app['registration_back_photo_path'] as String?),
              ('Insurance', app['insurance_photo_path'] as String?),
              ('Vehicle front', app['vehicle_front_photo_path'] as String?),
              ('Vehicle rear', app['vehicle_rear_photo_path'] as String?),
              ('Vehicle side', app['vehicle_side_photo_path'] as String?),
            ].where((item) => item.$2 != null).map((item) => _DriverDocumentCard(title: item.$1, path: item.$2!)),
            const SizedBox(height: 12),
            const Card(
              elevation: 0,
              color: DrivoColors.softPurple,
              child: ListTile(
                leading: Icon(Icons.lock_outline, color: DrivoColors.primary),
                title: Text('Account details', style: TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text('Contact Drivo support if you need to change your name, phone number or account type.'),
              ),
            ),
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Log out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB42318),
                side: const BorderSide(color: Color(0xFFF3B6B2)),
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverDocumentCard extends StatelessWidget {
  final String title;
  final String path;

  const _DriverDocumentCard({required this.title, required this.path});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ExpansionTile(
        leading: const Icon(Icons.verified_outlined, color: Colors.green),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: const Text('Submitted'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: _PrivateStorageImage(bucket: 'driver-documents', path: path, height: 210),
          ),
        ],
      ),
    );
  }
}

class _PrivateStorageImage extends StatelessWidget {
  final String bucket;
  final String path;
  final double height;

  const _PrivateStorageImage({required this.bucket, required this.path, required this.height});

  Future<Uint8List> _load() => supabase.storage.from(bucket).download(path);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return SizedBox(height: height, child: const Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 90,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image_not_supported_outlined, size: 20),
                  SizedBox(width: 8),
                  Text('Image unavailable'),
                ],
              ),
            ),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(snapshot.data!, height: height, width: double.infinity, fit: BoxFit.contain),
        );
      },
    );
  }
}
