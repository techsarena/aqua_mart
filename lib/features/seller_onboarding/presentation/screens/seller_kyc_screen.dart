import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../auth/presentation/widgets/onboarding_scaffold.dart';
import '../../data/services/cnic_ocr_service.dart';
import '../../domain/services/cnic_validator.dart';
import '../providers/seller_onboarding_providers.dart';

/// Seller sign-up 2 of 4 — real camera, gallery, and PDF uploads for KYC.
class SellerKycScreen extends ConsumerStatefulWidget {
  const SellerKycScreen({super.key});

  @override
  ConsumerState<SellerKycScreen> createState() => _SellerKycScreenState();
}

class _SellerKycScreenState extends ConsumerState<SellerKycScreen> {
  static const _maxFileBytes = 5 * 1024 * 1024;

  final _imagePicker = ImagePicker();
  final _cnicOcr = const CnicOcrService();
  final Map<_KycSlot, File> _files = {};
  final Map<_KycSlot, CnicValidationResult> _cnicResults = {};
  final Set<_KycSlot> _validating = {};
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _recoverLostAndroidImage();
  }

  Future<void> _recoverLostAndroidImage() async {
    if (!Platform.isAndroid) return;

    try {
      final response = await _imagePicker.retrieveLostData();
      if (response.isEmpty) return;

      final recovered =
          response.file ??
          (response.files?.isNotEmpty ?? false ? response.files!.first : null);
      if (recovered == null) return;

      final slot = _KycSlot.values
          .where((item) => item.acceptsCamera && !_files.containsKey(item))
          .firstOrNull;
      if (slot != null) await _acceptFile(slot, File(recovered.path));
    } catch (_) {
      // Lost-data recovery is best effort. Normal camera selection still works.
    }
  }

  bool _isUploaded(_KycSlot slot, SellerApplication application) =>
      _files.containsKey(slot) || application.uploaded.contains(slot.document);

  bool _requiredReady(SellerApplication application) => _KycSlot.values
      .where((slot) => slot.isRequired)
      .every((slot) => _isUploaded(slot, application));

  Future<void> _chooseSource(_KycSlot slot) async {
    if (_uploading || _validating.contains(slot)) return;

    final action = await showModalBottomSheet<_PickerAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.text.withValues(alpha: 0.58),
      builder: (context) => _DocumentSourceSheet(
        slot: slot,
        hasSelection: _files.containsKey(slot),
      ),
    );

    if (!mounted || action == null) return;
    switch (action) {
      case _PickerAction.camera:
        await _pickImage(slot, ImageSource.camera);
      case _PickerAction.gallery:
        await _pickImage(slot, ImageSource.gallery);
      case _PickerAction.document:
        await _pickDocument(slot);
      case _PickerAction.remove:
        setState(() {
          _files.remove(slot);
          _cnicResults.remove(slot);
        });
    }
  }

  Future<void> _pickImage(_KycSlot slot, ImageSource source) async {
    try {
      final selected = await _imagePicker.pickImage(
        source: source,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 88,
        requestFullMetadata: false,
      );
      if (selected != null) await _acceptFile(slot, File(selected.path));
    } on PlatformException catch (error) {
      if (!mounted) return;
      final denied =
          error.code.contains('access_denied') ||
          error.code.contains('permission');
      _showMessage(
        denied
            ? 'Camera or photo access is disabled. Enable it in your phone settings and try again.'
            : 'Could not open the camera or gallery. Please try again.',
      );
    } catch (_) {
      if (mounted) {
        _showMessage('Could not open the camera or gallery. Please try again.');
      }
    }
  }

  Future<void> _pickDocument(_KycSlot slot) async {
    try {
      final selection = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      );
      final path = selection?.files.single.path;
      if (path != null) await _acceptFile(slot, File(path));
    } on PlatformException catch (_) {
      if (mounted) {
        _showMessage(
          'Could not open your files. Check app access and try again.',
        );
      }
    } catch (_) {
      if (mounted) _showMessage('Could not select that document.');
    }
  }

  Future<void> _acceptFile(_KycSlot slot, File file) async {
    if (!await file.exists()) {
      if (mounted) _showMessage('That file is no longer available.');
      return;
    }

    final extension = _extension(file.path);
    if (!const {'jpg', 'jpeg', 'png', 'pdf'}.contains(extension)) {
      if (mounted) _showMessage('Choose a JPG, PNG, or PDF file.');
      return;
    }

    if (slot.isCnic && extension == 'pdf') {
      if (mounted) _showMessage('Take or choose a clear CNIC photo.');
      return;
    }

    if (await file.length() > _maxFileBytes) {
      if (mounted) {
        _showMessage('This file is over 5 MB. Choose a smaller file.');
      }
      return;
    }

    if (slot.isCnic) {
      await _validateCnic(slot, file);
      return;
    }

    if (mounted) setState(() => _files[slot] = file);
  }

  Future<void> _validateCnic(_KycSlot slot, File file) async {
    final otherSlot = slot == _KycSlot.cnicFront
        ? _KycSlot.cnicBack
        : _KycSlot.cnicFront;
    final otherFile = _files[otherSlot];
    if (otherFile != null && await _sameFile(file, otherFile)) {
      _showMessage(
        'The same CNIC photo was selected twice. Add the other side.',
      );
      return;
    }

    setState(() => _validating.add(slot));
    try {
      final text = await _cnicOcr.recognise(file);
      final side = slot == _KycSlot.cnicFront ? CnicSide.front : CnicSide.back;
      final result = CnicValidator.validateSide(text, side);
      if (!mounted) return;
      if (!result.isValid) {
        _showMessage(result.message ?? 'This is not a valid CNIC photo.');
        return;
      }

      final otherResult = _cnicResults[otherSlot];
      if (otherResult != null) {
        final front = side == CnicSide.front ? result : otherResult;
        final back = side == CnicSide.back ? result : otherResult;
        final pairError = CnicValidator.pairError(front, back);
        if (pairError != null) {
          _showMessage(pairError);
          return;
        }
      }

      setState(() {
        _files[slot] = file;
        _cnicResults[slot] = result;
      });
    } on PlatformException catch (_) {
      if (mounted) {
        _showMessage(
          'Could not verify this CNIC. Fully restart the app and retake the photo.',
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Could not read this CNIC. Retake it in better light.');
      }
    } finally {
      if (mounted) setState(() => _validating.remove(slot));
    }
  }

  Future<bool> _sameFile(File first, File second) async {
    if (await first.length() != await second.length()) return false;
    final firstBytes = await first.readAsBytes();
    final secondBytes = await second.readAsBytes();
    if (firstBytes.length != secondBytes.length) return false;
    for (var index = 0; index < firstBytes.length; index++) {
      if (firstBytes[index] != secondBytes[index]) return false;
    }
    return true;
  }

  Future<void> _submit(SellerApplication application) async {
    if (_uploading) return;

    // A completed server-side application can continue after navigating back
    // without forcing the user to select the private documents again.
    if (application.documentsComplete &&
        !_KycSlot.values.any(_files.containsKey)) {
      context.pushNamed(AppRoutes.sellerCatalogSetup);
      return;
    }

    final cnicFront = _files[_KycSlot.cnicFront];
    final cnicBack = _files[_KycSlot.cnicBack];
    final cnicFrontOcr = _cnicResults[_KycSlot.cnicFront]?.ocrText;
    final cnicBackOcr = _cnicResults[_KycSlot.cnicBack]?.ocrText;
    final waterTest = _files[_KycSlot.waterTest];
    if (cnicFront == null ||
        cnicBack == null ||
        cnicFrontOcr == null ||
        cnicBackOcr == null ||
        waterTest == null) {
      _showMessage('Add both CNIC photos and the water testing certificate.');
      return;
    }

    setState(() => _uploading = true);
    final result = await ref
        .read(sellerApplicationProvider.notifier)
        .uploadDocuments(
          cnicFront: cnicFront,
          cnicBack: cnicBack,
          cnicFrontOcr: cnicFrontOcr,
          cnicBackOcr: cnicBackOcr,
          waterTest: waterTest,
          licence: _files[_KycSlot.licence],
          plantPhoto: _files[_KycSlot.plantPhoto],
        );
    if (!mounted) return;
    setState(() => _uploading = false);

    result.when(
      success: (_) => context.pushNamed(AppRoutes.sellerCatalogSetup),
      failure: (failure) => _showMessage(failure.message),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final application = ref.watch(sellerApplicationProvider);
    final nextRequired = _KycSlot.values
        .where((slot) => slot.isRequired && !_isUploaded(slot, application))
        .firstOrNull;

    return OnboardingScaffold(
      step: 2,
      totalSteps: 4,
      title: "Prove it's you",
      subtitle: 'Photos are fine — no scanner needed. We check within a day.',
      primaryLabel: _uploading ? 'Uploading…' : 'Upload & continue',
      primaryEnabled:
          !_uploading && _validating.isEmpty && _requiredReady(application),
      onPrimary: () => _submit(application),
      footer: const AppNote(
        icon: Icons.lock_outline_rounded,
        text:
            'Documents are seen only by our verification team. Customers '
            'never see them.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Required documents',
            style: AppTypography.body(size: 14, weight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final slot in _KycSlot.values) ...[
            if (slot == _KycSlot.licence) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Optional documents',
                style: AppTypography.body(size: 14, weight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            _DocumentUploadTile(
              slot: slot,
              file: _files[slot],
              uploaded: _isUploaded(slot, application),
              isNext: slot == nextRequired,
              enabled: !_uploading && !_validating.contains(slot),
              validating: _validating.contains(slot),
              onTap: () => _chooseSource(slot),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(
            'Accepted: JPG, PNG or PDF · Maximum 5 MB per file',
            textAlign: TextAlign.center,
            style: AppTypography.body(
              size: 12.5,
              color: AppColors.textMuted(0.55),
            ),
          ),
        ],
      ),
    );
  }
}

enum _KycSlot {
  cnicFront,
  cnicBack,
  waterTest,
  licence,
  plantPhoto;

  String get label => switch (this) {
    _KycSlot.cnicFront => 'CNIC — front',
    _KycSlot.cnicBack => 'CNIC — back',
    _KycSlot.waterTest => 'Water testing certificate',
    _KycSlot.licence => 'NTN / business licence',
    _KycSlot.plantPhoto => 'Photo of your plant',
  };

  String get hint => switch (this) {
    _KycSlot.cnicFront => 'Take a clear photo of the front',
    _KycSlot.cnicBack => 'Take a clear photo of the back',
    _KycSlot.waterTest => 'Photo or PDF · required',
    _KycSlot.licence => 'Optional — speeds up approval',
    _KycSlot.plantPhoto => 'Optional — shown on your store page',
  };

  bool get isRequired => switch (this) {
    _KycSlot.cnicFront || _KycSlot.cnicBack || _KycSlot.waterTest => true,
    _ => false,
  };

  bool get acceptsCamera => this != _KycSlot.licence;

  bool get isCnic => this == _KycSlot.cnicFront || this == _KycSlot.cnicBack;

  bool get acceptsDocument => switch (this) {
    _KycSlot.waterTest || _KycSlot.licence => true,
    _ => false,
  };

  KycDocument get document => switch (this) {
    _KycSlot.cnicFront || _KycSlot.cnicBack => KycDocument.cnic,
    _KycSlot.waterTest => KycDocument.waterTest,
    _KycSlot.licence => KycDocument.licence,
    _KycSlot.plantPhoto => KycDocument.plantPhoto,
  };
}

enum _PickerAction { camera, gallery, document, remove }

class _DocumentSourceSheet extends StatelessWidget {
  const _DocumentSourceSheet({required this.slot, required this.hasSelection});

  final _KycSlot slot;
  final bool hasSelection;

  String get _title => switch (slot) {
    _KycSlot.cnicFront || _KycSlot.cnicBack => 'Add CNIC photo',
    _KycSlot.waterTest => 'Add water test',
    _KycSlot.licence => 'Add business document',
    _KycSlot.plantPhoto => 'Add plant photo',
  };

  String get _subtitle => switch (slot) {
    _KycSlot.cnicFront ||
    _KycSlot.cnicBack => 'Front side first, then the back.',
    _KycSlot.waterTest => 'Upload a clear certificate photo or PDF.',
    _KycSlot.licence => 'Upload your NTN or business licence.',
    _KycSlot.plantPhoto => 'Choose a clear photo of your water plant.',
  };

  @override
  Widget build(BuildContext context) {
    final heightFactor = slot.acceptsDocument ? 0.9 : 0.79;

    return FractionallySizedBox(
      heightFactor: heightFactor,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(42)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 42,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: 92,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.neutral400.withValues(alpha: 0.52),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                    const SizedBox(height: 34),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        _title,
                        style: AppTypography.heading(size: 31),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        _subtitle,
                        style: AppTypography.body(
                          size: 17,
                          height: 1.35,
                          color: AppColors.neutral600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    if (slot.acceptsCamera) ...[
                      _SourceActionCard(
                        icon: Icons.photo_camera_rounded,
                        iconColor: AppColors.accent,
                        title: 'Take photo',
                        subtitle: 'Use the camera now',
                        outlined: true,
                        onTap: () =>
                            Navigator.pop(context, _PickerAction.camera),
                      ),
                      const SizedBox(height: 16),
                      _SourceActionCard(
                        icon: Icons.photo_library_rounded,
                        iconColor: AppColors.accent2,
                        title: 'Upload from gallery',
                        subtitle: 'Pick a photo you already have',
                        onTap: () =>
                            Navigator.pop(context, _PickerAction.gallery),
                      ),
                    ],
                    if (slot.acceptsDocument) ...[
                      if (slot.acceptsCamera) const SizedBox(height: 16),
                      _SourceActionCard(
                        icon: Icons.description_rounded,
                        iconColor: AppColors.accent700,
                        title: 'Choose document',
                        subtitle: 'Pick a PDF, JPG or PNG',
                        outlined: !slot.acceptsCamera,
                        onTap: () =>
                            Navigator.pop(context, _PickerAction.document),
                      ),
                    ],
                    const Spacer(),
                    if (hasSelection)
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(context, _PickerAction.remove),
                        child: Text(
                          'Remove selected file',
                          style: AppTypography.body(
                            size: 16,
                            weight: FontWeight.w700,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppTypography.body(
                          size: 20,
                          weight: FontWeight.w700,
                          color: AppColors.neutral600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceActionCard extends StatelessWidget {
  const _SourceActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.outlined = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
      side: outlined
          ? const BorderSide(color: AppColors.accent, width: 2.4)
          : BorderSide.none,
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 112),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 17),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.heading(size: 20),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                        size: 15.5,
                        height: 1.28,
                        color: AppColors.neutral600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.neutral400,
                size: 31,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DocumentUploadTile extends StatelessWidget {
  const _DocumentUploadTile({
    required this.slot,
    required this.file,
    required this.uploaded,
    required this.isNext,
    required this.enabled,
    required this.validating,
    required this.onTap,
  });

  final _KycSlot slot;
  final File? file;
  final bool uploaded;
  final bool isNext;
  final bool enabled;
  final bool validating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tile = AppCard(
      onTap: enabled ? onTap : null,
      padding: const EdgeInsets.all(AppSpacing.md),
      color: uploaded ? AppColors.accent2_100 : AppColors.surface,
      borderColor: uploaded ? AppColors.accent2_300 : null,
      child: Row(
        children: [
          _DocumentPreview(slot: slot, file: file, uploaded: uploaded),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        slot.label,
                        style: AppTypography.body(
                          size: 15,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (slot.isRequired && !uploaded)
                      Text(
                        'Required',
                        style: AppTypography.body(
                          size: 11.5,
                          weight: FontWeight.w700,
                          color: AppColors.accent700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  validating
                      ? 'Checking that this is the correct CNIC side…'
                      : file != null && slot.isCnic
                      ? 'CNIC checked · ${_fileName(file!.path)}'
                      : file != null
                      ? '${_fileName(file!.path)} · ${_fileSize(file!)}'
                      : uploaded
                      ? 'Uploaded securely'
                      : slot.hint,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    size: 13,
                    color: uploaded
                        ? AppColors.accent2Deep
                        : AppColors.textMuted(0.58),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (validating)
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          else
            Icon(
              uploaded ? Icons.check_circle_rounded : Icons.add_circle_outline,
              color: uploaded ? AppColors.accent2 : AppColors.accent,
            ),
        ],
      ),
    );

    return isNext
        ? CustomPaint(
            foregroundPainter: const _DashedBorderPainter(
              color: AppColors.accent,
              radius: AppRadius.lg,
            ),
            child: tile,
          )
        : tile;
  }
}

class _DocumentPreview extends StatelessWidget {
  const _DocumentPreview({
    required this.slot,
    required this.file,
    required this.uploaded,
  });

  final _KycSlot slot;
  final File? file;
  final bool uploaded;

  @override
  Widget build(BuildContext context) {
    final isImage = file != null && _extension(file!.path) != 'pdf';
    if (isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Image.file(
          file!,
          width: 58,
          height: 58,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _badge(Icons.broken_image_outlined),
        ),
      );
    }

    return _badge(
      file != null
          ? Icons.picture_as_pdf_rounded
          : uploaded
          ? Icons.check_rounded
          : slot == _KycSlot.plantPhoto
          ? Icons.storefront_outlined
          : slot.acceptsDocument
          ? Icons.description_outlined
          : Icons.photo_camera_outlined,
    );
  }

  Widget _badge(IconData icon) => Container(
    width: 58,
    height: 58,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: uploaded ? AppColors.accent2_200 : AppColors.neutral200,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Icon(
      icon,
      size: 25,
      color: uploaded ? AppColors.accent2Deep : AppColors.neutral600,
    ),
  );
}

String _extension(String path) {
  final name = _fileName(path);
  final dot = name.lastIndexOf('.');
  return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
}

String _fileName(String path) => path.replaceAll('\\', '/').split('/').last;

String _fileSize(File file) {
  try {
    final bytes = file.lengthSync();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  } catch (_) {
    return 'Selected';
  }
}

/// Draws a dashed rounded-rectangle stroke just inside the given bounds.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const _dash = 7.0;
  static const _gap = 5.0;
  static const _width = 1.8;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..strokeWidth = _width
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(_width / 2),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + _dash), stroke);
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
