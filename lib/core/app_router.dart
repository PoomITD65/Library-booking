// lib/core/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ==== Pages ====
import 'package:library_booking/features/auth/presentation/login_page.dart';
import 'package:library_booking/features/auth/presentation/register_page.dart';
import 'package:library_booking/features/books/presentation/favorites_page.dart';
import 'package:library_booking/features/books/presentation/home_page.dart';
import 'package:library_booking/features/books/presentation/book_detail_page.dart';
import 'package:library_booking/features/loans/presentation/my_loans_page.dart';
import 'package:library_booking/features/loans/presentation/loan_history_page.dart'; // ⬅️ เพิ่ม
import 'package:library_booking/features/profile/presentation/edit_profile_page.dart';
import 'package:library_booking/features/profile/presentation/profile_page.dart';

// ✅ สถานะล็อกอิน
import 'package:library_booking/features/auth/data/session.dart';
import 'package:library_booking/features/settings/presentation/settings_page.dart';

final GoRouter appRouter = GoRouter(
  debugLogDiagnostics: false,
  initialLocation: '/home',

  // ให้ router refresh เมื่อสถานะ login เปลี่ยน
  refreshListenable: Session.auth,

  // ✅ guard
  redirect: (context, state) {
    final loggedIn = Session.isLoggedIn;
    final loc = state.matchedLocation;
    final goingLogin = loc == '/login';
    final goingRegister = loc == '/register';

    if (!loggedIn) {
      // ยังไม่ล็อกอิน → อนุญาตไป /login /register เท่านั้น
      if (goingLogin || goingRegister) return null;
      return '/login';
    }

    // ล็อกอินแล้ว → กันไม่ให้ย้อนมาหน้า login/register
    if (loggedIn && (goingLogin || goingRegister)) {
      return '/home';
    }

    return null;
  },

  routes: [
    GoRoute(
      path: '/',
      redirect: (_, __) => '/home',
    ),

    // ---- Auth ----
    GoRoute(
      path: '/login',
      name: 'login',
      pageBuilder: (_, __) => const NoTransitionPage(child: LoginPage()),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      pageBuilder: (_, __) => const NoTransitionPage(child: RegisterPage()),
    ),

    // ---- Home ----
    GoRoute(
      path: '/home',
      name: 'home',
      pageBuilder: (_, __) => const NoTransitionPage(child: HomePage()),
    ),

    // ---- Favorites ----
    GoRoute(
      path: '/favorites',
      name: 'favorites',
      pageBuilder: (_, __) => const NoTransitionPage(child: FavoritesPage()),
    ),

    // ---- Loans (ปัจจุบัน) ----
    GoRoute(
      path: '/loans',
      name: 'loans',
      pageBuilder: (_, __) => const NoTransitionPage(child: MyLoansPage()),
    ),

    // ---- Loan History (ใหม่) ----
    GoRoute(
      path: '/history',
      name: 'history',
      pageBuilder: (_, __) =>
          const NoTransitionPage(child: LoanHistoryPage()),
    ),

    // ---- Profile ----
    GoRoute(
      path: '/profile',
      name: 'profile',
      pageBuilder: (_, __) => const NoTransitionPage(child: ProfilePage()),
    ),

    // ---- Book detail (push) ----
    GoRoute(
      path: '/books/:id',
      name: 'book_detail',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return BookDetailPage(id: id);
      },
    ),

    GoRoute(
      path: '/settings',
      name: 'settings',
      pageBuilder: (_, __) => const NoTransitionPage(child: SettingsPage()),
    ),

    GoRoute(
      path: '/profile/edit',
      name: 'profile_edit',
      pageBuilder: (_, __) => const NoTransitionPage(child: EditProfilePage()),
    ),
  ],

  errorPageBuilder: (_, __) => const NoTransitionPage(child: HomePage()),
);
