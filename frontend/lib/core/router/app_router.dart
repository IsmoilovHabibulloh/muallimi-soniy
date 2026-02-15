import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/screens/splash_screen.dart';
import '../../presentation/screens/home_screen.dart';
import '../../presentation/screens/reader/reader_screen.dart';
import '../../presentation/screens/toc_screen.dart';
import '../../presentation/screens/feedback_screen.dart';
import '../../presentation/screens/settings_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/reader/:pageNumber',
        builder: (context, state) {
          final pageNumber = int.tryParse(state.pathParameters['pageNumber'] ?? '1') ?? 1;
          return ReaderScreen(initialPage: pageNumber);
        },
      ),
      GoRoute(
        path: '/toc',
        builder: (context, state) => const TocScreen(),
      ),
      GoRoute(
        path: '/feedback',
        builder: (context, state) => const FeedbackScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
