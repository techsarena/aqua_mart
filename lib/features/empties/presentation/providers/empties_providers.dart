import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/empties_data_source.dart';
import '../../data/repositories/empties_repository_impl.dart';
import '../../domain/entities/empty_holding.dart';
import '../../domain/repositories/empties_repository.dart';

final emptiesRemoteDataSourceProvider = Provider<EmptiesRemoteDataSource>((ref) {
  return EmptiesApiDataSource(ref.watch(apiClientProvider));
});

final emptiesRepositoryProvider = Provider<EmptiesRepository>(
  (ref) => EmptiesRepositoryImpl(ref.watch(emptiesRemoteDataSourceProvider)),
);

/// What the customer is holding right now.
final emptiesSummaryProvider = FutureProvider.autoDispose<EmptiesSummary>((
  ref,
) async {
  final result = await ref.watch(emptiesRepositoryProvider).fetchEmpties();
  return result.when(
    success: (summary) => summary,
    // Thrown so the screen's AsyncValue.error branch renders the message the
    // repository already made user-facing.
    failure: (failure) => throw failure,
  );
});
