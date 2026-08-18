import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../catalog/domain/entities/seller.dart';

/// Where the application stands, as the waiting room polls it (API_SPEC 6.1).
class VerificationState {
  const VerificationState({
    required this.status,
    this.submittedAt,
    this.estimatedHours = 24,
    this.rejectionReason,
  });

  final SellerVerificationStatus status;
  final DateTime? submittedAt;
  final int estimatedHours;

  /// Set only when [status] is `rejected` — shown verbatim.
  final String? rejectionReason;

  static VerificationState fromJson(Map<String, dynamic> json) =>
      VerificationState(
        status:
            SellerVerificationStatus.values
                .where((s) => s.name == json['verification_status'])
                .firstOrNull ??
            SellerVerificationStatus.detailsReceived,
        submittedAt: DateTime.tryParse(json['submitted_at'] as String? ?? ''),
        estimatedHours: (json['estimated_hours'] as num?)?.toInt() ?? 24,
        rejectionReason: json['rejection_reason'] as String?,
      );
}

/// One priced size, as the catalogue step submits it.
class BottleDraftPayload {
  const BottleDraftPayload({
    required this.litres,
    required this.refillPrice,
    required this.newPrice,
    this.deposit,
  });

  final int litres;
  final int refillPrice;
  final int newPrice;

  /// Omitted to accept the platform default (Aqua Settings).
  final int? deposit;

  Map<String, dynamic> toJson() => {
    'litres': litres,
    'refill_price': refillPrice,
    'new_price': newPrice,
    if (deposit != null) 'deposit': deposit,
  };
}

abstract interface class SellerOnboardingRemoteDataSource {
  /// Step 1 — creates the store and flips the account's role to seller.
  Future<SellerVerificationStatus> register({
    required String businessName,
    required String ownerName,
    required SellerBusinessType businessType,
  });

  /// Step 2 — the KYC files, uploaded as multipart.
  Future<SellerVerificationStatus> uploadDocuments({
    required File cnicFront,
    required File cnicBack,
    required File waterTest,
    File? licence,
    File? plantPhoto,
  });

  /// Step 3 — the catalogue, which also submits the whole application.
  Future<SellerVerificationStatus> submitForReview({
    required List<BottleDraftPayload> bottles,
    bool sellsOtherSizes = false,
  });

  Future<VerificationState> fetchStatus();
}

class SellerOnboardingApiDataSource
    implements SellerOnboardingRemoteDataSource {
  const SellerOnboardingApiDataSource(this._client);

  final ApiClient _client;

  @override
  Future<SellerVerificationStatus> register({
    required String businessName,
    required String ownerName,
    required SellerBusinessType businessType,
  }) async {
    final json = await _client.postObject(
      ApiEndpoints.sellerRegister,
      body: {
        'business_name': businessName,
        'owner_name': ownerName,
        'business_type': businessType.name,
      },
    );
    return _statusFrom(json);
  }

  @override
  Future<SellerVerificationStatus> uploadDocuments({
    required File cnicFront,
    required File cnicBack,
    required File waterTest,
    File? licence,
    File? plantPhoto,
  }) async {
    final json = await _client.upload<Map<String, dynamic>?>(
      ApiEndpoints.sellerDocuments,
      fields: {
        'cnic_front': await _part(cnicFront),
        'cnic_back': await _part(cnicBack),
        'water_test': await _part(waterTest),
        if (licence != null) 'licence': await _part(licence),
        if (plantPhoto != null) 'plant_photo': await _part(plantPhoto),
      },
    );
    // The upload path returns the raw envelope, so `data` is unwrapped here.
    final data = json?['data'];
    return _statusFrom(data is Map<String, dynamic> ? data : json);
  }

  @override
  Future<SellerVerificationStatus> submitForReview({
    required List<BottleDraftPayload> bottles,
    bool sellsOtherSizes = false,
  }) async {
    final json = await _client.postObject(
      ApiEndpoints.sellerVerification,
      body: {
        'bottles': bottles.map((b) => b.toJson()).toList(),
        'sells_other_sizes': sellsOtherSizes,
      },
    );
    return _statusFrom(json);
  }

  @override
  Future<VerificationState> fetchStatus() async {
    final json = await _client.getObject(ApiEndpoints.sellerVerification);
    return VerificationState.fromJson(json ?? const {});
  }

  Future<MultipartFile> _part(File file) =>
      MultipartFile.fromFile(file.path, filename: file.path.split('/').last);

  SellerVerificationStatus _statusFrom(Map<String, dynamic>? json) =>
      SellerVerificationStatus.values
          .where((s) => s.name == json?['verification_status'])
          .firstOrNull ??
      SellerVerificationStatus.detailsReceived;
}

/// Advances through the pipeline locally so the four steps and the waiting
/// room can be walked without a backend.
class MockSellerOnboardingDataSource
    implements SellerOnboardingRemoteDataSource {
  MockSellerOnboardingDataSource();

  static const _latency = Duration(milliseconds: 600);

  SellerVerificationStatus _status = SellerVerificationStatus.detailsReceived;
  DateTime? _submittedAt;

  @override
  Future<SellerVerificationStatus> register({
    required String businessName,
    required String ownerName,
    required SellerBusinessType businessType,
  }) async {
    await Future<void>.delayed(_latency);
    return _status = SellerVerificationStatus.detailsReceived;
  }

  @override
  Future<SellerVerificationStatus> uploadDocuments({
    required File cnicFront,
    required File cnicBack,
    required File waterTest,
    File? licence,
    File? plantPhoto,
  }) async {
    await Future<void>.delayed(_latency);
    return _status = SellerVerificationStatus.documentsUploaded;
  }

  @override
  Future<SellerVerificationStatus> submitForReview({
    required List<BottleDraftPayload> bottles,
    bool sellsOtherSizes = false,
  }) async {
    await Future<void>.delayed(_latency);
    _submittedAt = DateTime.now();
    return _status = SellerVerificationStatus.inReview;
  }

  @override
  Future<VerificationState> fetchStatus() async {
    await Future<void>.delayed(_latency);
    return VerificationState(status: _status, submittedAt: _submittedAt);
  }
}
