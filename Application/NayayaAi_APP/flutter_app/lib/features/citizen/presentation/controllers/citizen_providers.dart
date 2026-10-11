import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../data/datasources/citizen_remote_data_sources.dart';
import '../../data/repositories/citizen_repositories_impl.dart';
import '../../domain/repositories/citizen_repositories.dart';

final citizenComplaintRepositoryProvider = Provider<CitizenComplaintRepository>(
  (ref) => CitizenComplaintRepositoryImpl(
    remote: CitizenComplaintRemoteDataSource(ref.watch(dioClientProvider).dio),
  ),
);

final rightsChatRepositoryProvider = Provider<RightsChatRepository>(
  (ref) => RightsChatRepositoryImpl(
    remote: RightsChatRemoteDataSource(ref.watch(dioClientProvider).dio),
  ),
);

final caseStatusRepositoryProvider = Provider<CaseStatusRepository>(
  (ref) => CaseStatusRepositoryImpl(
    remote: CaseStatusRemoteDataSource(ref.watch(dioClientProvider).dio),
  ),
);
