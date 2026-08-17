import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_section.dart';
import '../../../auth/presentation/widgets/onboarding_scaffold.dart';
import '../../domain/entities/rider_application.dart';
import '../providers/rider_providers.dart';

/// Rider sign-up 4 of 5 — what they deliver on, which sets how many bottles
/// a run can hold.
///
/// The capacity under each option is the point of the question, so it is part
/// of the choice rather than a footnote: picking a rickshaw is picking 15
/// bottles a run.
class RiderVehicleScreen extends ConsumerStatefulWidget {
  const RiderVehicleScreen({super.key});

  @override
  ConsumerState<RiderVehicleScreen> createState() => _RiderVehicleScreenState();
}

class _RiderVehicleScreenState extends ConsumerState<RiderVehicleScreen> {
  late final TextEditingController _registration;

  @override
  void initState() {
    super.initState();
    _registration = TextEditingController(
      text: ref.read(riderApplicationProvider).registrationNumber,
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _registration.dispose();
    super.dispose();
  }

  void _continue(RiderVehicle vehicle) {
    ref
        .read(riderApplicationProvider.notifier)
        .setRegistrationNumber(
          vehicle.needsRegistration ? _registration.text.trim() : '',
        );
    context.pushNamed(AppRoutes.riderSellerCode);
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = ref.watch(
      riderApplicationProvider.select((a) => a.vehicle),
    );
    final needsPlate = vehicle?.needsRegistration ?? false;

    return OnboardingScaffold(
      step: 4,
      totalSteps: 5,
      title: 'What do you deliver on?',
      subtitle: 'This sets how many bottles a run can hold.',
      primaryLabel: 'Continue',
      primaryEnabled:
          vehicle != null &&
          (!needsPlate || _registration.text.trim().isNotEmpty),
      onPrimary: () => _continue(vehicle!),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Two to a row, so all four sit above the fold with the plate
          // field still visible underneath.
          for (var row = 0; row < RiderVehicle.values.length; row += 2) ...[
            if (row > 0) const SizedBox(height: AppSpacing.md),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var col = 0; col < 2; col++) ...[
                    if (col > 0) const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _VehicleCard(
                        vehicle: RiderVehicle.values[row + col],
                        selected: vehicle == RiderVehicle.values[row + col],
                        onTap: () => ref
                            .read(riderApplicationProvider.notifier)
                            .setVehicle(RiderVehicle.values[row + col]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // On foot has no plate to give, so the field goes rather than
          // sitting there disabled.
          if (needsPlate) ...[
            const SizedBox(height: AppSpacing.xl),
            const FieldLabel('REGISTRATION NUMBER'),
            TextField(
              controller: _registration,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (_registration.text.trim().isNotEmpty) _continue(vehicle!);
              },
              decoration: const InputDecoration(hintText: 'KMR-4471'),
            ),
          ],
        ],
      ),
    );
  }
}

/// One vehicle choice — the glyph, the vehicle, and what it holds.
///
/// Selected state is the accent border and tint used by every other choice
/// card in the sign-up, with the glyph warming to the accent.
class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.selected,
    required this.onTap,
  });

  final RiderVehicle vehicle;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (vehicle) {
    RiderVehicle.motorbike => Icons.two_wheeler_rounded,
    RiderVehicle.rickshaw => Icons.electric_rickshaw_rounded,
    RiderVehicle.loader => Icons.local_shipping_rounded,
    RiderVehicle.onFoot => Icons.directions_walk_rounded,
  };

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: selected ? AppColors.onTint : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected ? AppColors.accent : Colors.transparent,
            width: 1.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _icon,
              size: 26,
              color: selected ? AppColors.accent : AppColors.textMuted(0.6),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(vehicle.label, style: AppTypography.heading(size: 17)),
            const SizedBox(height: 3),
            Text(
              vehicle.capacityLabel,
              style: AppTypography.body(
                size: 12.5,
                color: AppColors.textMuted(0.6),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
