// lib/providers/follower_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:education/core/sqlite/follower_repository.dart';
import 'package:education/core/global.dart';

final followerRepositoryProvider = Provider<FollowerRepository>((ref) {
  final db = Global.db;
  if (db == null) {
    throw Exception('Database not initialized');
  }
  return FollowerRepository(db);
});