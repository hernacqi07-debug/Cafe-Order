import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens dari Figma "Pemrograman-Mobile" (frame Customer · Beranda).
///
/// Satu sumber kebenaran untuk warna & tipografi layar customer, supaya
/// layar berikutnya (Masuk, Daftar, Detail Menu, dst.) konsisten tanpa
/// mengulang nilai hex di tiap file.
///
/// Catatan: warna aksen hijau (#355D4C) mengikuti desain Figma. Warna
/// `warna_primer` di tabel `cafes` (saat ini coklat #7B3F00 untuk Kafe Contoh)
/// baru dipakai nanti lewat layar Kustomisasi admin.
abstract final class CafeColors {
  static const background = Color(0xFFFAF7F1);
  static const surface = Colors.white;
  static const ink = Color(0xFF30251F);
  static const muted = Color(0xFF80766E);
  static const accent = Color(0xFF355D4C);
  static const cream = Color(0xFFEFE5D5);
  static const border = Color(0xFFE7E0D6);
  static const softGreen = Color(0xFFE9F0E9);
  // Peringatan (info batas ambil / QR kedaluwarsa) & bahaya (batalkan).
  static const warnBg = Color(0xFFFBF0DE);
  static const warnText = Color(0xFF99612D);
  static const danger = Color(0xFFAD4F43);
}

/// Gaya teks Figma: Lora untuk judul/sapaan, Inter untuk semua teks lain.
abstract final class CafeText {
  static TextStyle eyebrow({Color color = CafeColors.muted}) =>
      GoogleFonts.inter(fontSize: 11, color: color);

  static TextStyle greeting = GoogleFonts.lora(
    fontSize: 27,
    color: CafeColors.ink,
    height: 1.25,
  );

  static TextStyle promoEyebrow = GoogleFonts.inter(
    fontSize: 9,
    fontWeight: FontWeight.w600,
    color: CafeColors.accent,
  );

  static TextStyle promoTitle = GoogleFonts.lora(
    fontSize: 31,
    color: CafeColors.ink,
    height: 1.15,
  );

  static TextStyle promoDesc = GoogleFonts.inter(
    fontSize: 11,
    color: CafeColors.muted,
    height: 1.5,
  );

  static TextStyle promoLink = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: CafeColors.accent,
  );

  static TextStyle cardTitle = GoogleFonts.lora(
    fontSize: 24,
    color: CafeColors.ink,
    height: 1.25,
  );

  static TextStyle cardSub = GoogleFonts.inter(
    fontSize: 11,
    color: CafeColors.muted,
    height: 1.45,
  );

  static TextStyle toggleTitle = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: CafeColors.ink,
    height: 1.45,
  );

  static TextStyle toggleSub = GoogleFonts.inter(
    fontSize: 11,
    color: CafeColors.muted,
    height: 1.45,
  );

  static TextStyle buttonLabel = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static TextStyle sectionTitle = GoogleFonts.lora(
    fontSize: 24,
    color: CafeColors.ink,
    height: 1.25,
  );

  static TextStyle searchHint = GoogleFonts.inter(
    fontSize: 12,
    color: CafeColors.muted,
  );

  static TextStyle chipActive = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static TextStyle chipInactive = GoogleFonts.inter(
    fontSize: 12,
    color: CafeColors.muted,
  );

  static TextStyle menuName = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: CafeColors.ink,
    height: 1.45,
  );

  static TextStyle menuMeta = GoogleFonts.inter(
    fontSize: 11,
    color: CafeColors.muted,
    height: 1.45,
  );

  static TextStyle menuPrice = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: CafeColors.accent,
  );

  static TextStyle orderTitle = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: CafeColors.ink,
    height: 1.45,
  );

  static TextStyle orderSub = GoogleFonts.inter(
    fontSize: 11,
    color: CafeColors.accent,
    height: 1.45,
  );

  static TextStyle shortcut = GoogleFonts.inter(
    fontSize: 12,
    color: CafeColors.accent,
  );

  static TextStyle navActive = GoogleFonts.inter(
    fontSize: 9,
    fontWeight: FontWeight.w600,
    color: CafeColors.accent,
  );

  static TextStyle navInactive = GoogleFonts.inter(
    fontSize: 9,
    color: CafeColors.muted,
  );

  static TextStyle body = GoogleFonts.inter(
    fontSize: 13,
    color: CafeColors.ink,
  );

  static TextStyle pageTitle = GoogleFonts.lora(
    fontSize: 24,
    color: CafeColors.ink,
    height: 1.25,
  );

  static TextStyle itemNote = GoogleFonts.inter(
    fontSize: 11,
    fontStyle: FontStyle.italic,
    color: CafeColors.muted,
    height: 1.45,
  );

  static TextStyle totalLabel = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: CafeColors.ink,
  );

  static TextStyle totalValue = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: CafeColors.ink,
  );
}
