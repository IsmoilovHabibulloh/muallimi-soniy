import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/constants.dart';
import '../models/book.dart';

/// API client provider
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConstants.apiBaseUrl,
    connectTimeout: AppConstants.apiTimeout,
    receiveTimeout: AppConstants.apiTimeout,
    headers: {'Accept': 'application/json'},
  ));
  return dio;
});

/// Book data provider
final bookProvider = FutureProvider<BookData?>((ref) async {
  final dio = ref.read(dioProvider);
  try {
    final res = await dio.get('/book');
    return BookData.fromJson(res.data);
  } catch (e) {
    return null;
  }
});

/// Chapters provider
final chaptersProvider = FutureProvider<List<Chapter>>((ref) async {
  final dio = ref.read(dioProvider);
  try {
    final res = await dio.get('/book/chapters');
    return (res.data as List).map((e) => Chapter.fromJson(e)).toList();
  } catch (e) {
    return [];
  }
});

/// Pages list provider
final pagesListProvider = FutureProvider<List<PageSummary>>((ref) async {
  final dio = ref.read(dioProvider);
  try {
    final res = await dio.get('/book/pages', queryParameters: {'limit': 100});
    return (res.data as List).map((e) => PageSummary.fromJson(e)).toList();
  } catch (e) {
    return [];
  }
});

/// Single page with units provider (parameterized)
final pageDetailProvider = FutureProvider.family<PageDetail?, int>((ref, pageNumber) async {
  final dio = ref.read(dioProvider);
  try {
    final res = await dio.get('/book/pages/$pageNumber');
    return PageDetail.fromJson(res.data);
  } catch (e) {
    return null;
  }
});

/// Manifest version provider for polling
final manifestVersionProvider = StateProvider<int>((ref) => 0);
