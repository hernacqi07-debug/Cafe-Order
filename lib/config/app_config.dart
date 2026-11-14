import 'package:flutter/material.dart';

/// White-label configuration for the app.
///
/// Values are injected at build/run time via `--dart-define`.
/// **Nothing cafe-specific may be hard-coded anywhere else in the app** —
/// that is what makes white-label builds (Model B) possible from day one.
///
/// Supported defines:
///   APP_NAME, APP_ID, API_BASE_URL,
///   PRIMARY_COLOR, SECONDARY_COLOR (hex, e.g. #6F4E37),
///   CAFE_NAME, LOGO_URL, CAFE_ALAMAT, CAFE_JAM_BUKA,
///   SUPABASE_URL, SUPABASE_ANON_KEY (publishable key; public-safe,
///     one Supabase project per cafe — 1 database per cafe).
class AppConfig {
  const AppConfig({
    required this.appName,
    required this.applicationId,
    required this.apiBaseUrl,
    required this.primaryColor,
    required this.secondaryColor,
    required this.cafeName,
    required this.logoUrl,
    required this.alamat,
    required this.jamBuka,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  /// Display name used inside the app. The Android launcher label is set
  /// separately per flavor in android/app/build.gradle.kts.
  final String appName;

  /// Android applicationId, e.g. com.serve.kopikenangan
  final String applicationId;

  /// Base URL of THIS cafe's backend (one database per cafe — no multi-tenant).
  final String apiBaseUrl;

  final Color primaryColor;
  final Color secondaryColor;

  /// Cafe display name & logo. Also editable later via the admin panel
  /// (table `cafes`); these defines are the shipped defaults.
  final String cafeName;
  final String logoUrl;

  /// Alamat & jam buka cafe (dipakai layar Lokasi & Meja). Kosong =
  /// belum diatur; nanti diatur lewat Kustomisasi admin.
  final String alamat;
  final String jamBuka;

  /// Supabase project for THIS cafe's database. The anon/publishable key is
  /// public-safe by design (it ships inside the client app).
  final String supabaseUrl;
  final String supabaseAnonKey;

  factory AppConfig.fromEnvironment() {
    return AppConfig(
      appName: const String.fromEnvironment('APP_NAME',
          defaultValue: 'CafeOrder'),
      applicationId: const String.fromEnvironment('APP_ID',
          defaultValue: 'com.cafeorder.cafe_order'),
      apiBaseUrl: const String.fromEnvironment('API_BASE_URL',
          defaultValue: 'https://api.example.com'),
      primaryColor: _parseColor(const String.fromEnvironment(
          'PRIMARY_COLOR',
          defaultValue: '#6F4E37')),
      secondaryColor: _parseColor(const String.fromEnvironment(
          'SECONDARY_COLOR',
          defaultValue: '#C8A97E')),
      cafeName: const String.fromEnvironment('CAFE_NAME',
          defaultValue: 'Cafe Contoh'),
      logoUrl:
          const String.fromEnvironment('LOGO_URL', defaultValue: ''),
      alamat: const String.fromEnvironment('CAFE_ALAMAT', defaultValue: ''),
      jamBuka:
          const String.fromEnvironment('CAFE_JAM_BUKA', defaultValue: ''),
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL',
          defaultValue: 'https://kainrvcifxryfqyjjanl.supabase.co'),
      supabaseAnonKey: const String.fromEnvironment('SUPABASE_ANON_KEY',
          defaultValue: 'sb_publishable_9BsKYUzLi5LhneJroN1oRA_RtfGu0H_'),
    );
  }

  static Color _parseColor(String hex) {
    final buffer = StringBuffer();
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      buffer.write('ff');
    }
    buffer.write(clean);
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
