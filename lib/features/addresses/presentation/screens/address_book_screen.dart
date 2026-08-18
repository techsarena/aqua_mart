import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/back_disc_button.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../orders/presentation/providers/cart_providers.dart';
import '../../domain/entities/address.dart';
import '../providers/address_providers.dart';

/// "Deliver where?" — the address book. Picking one sets it on the cart, which
/// is what the Change button on the order screen was always meant to do.
class AddressBookScreen extends ConsumerStatefulWidget {
  const AddressBookScreen({super.key});

  @override
  ConsumerState<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends ConsumerState<AddressBookScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(addressBookProvider);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              MediaQuery.paddingOf(context).top + AppSpacing.sm,
              AppSpacing.gutter,
              AppSpacing.lg,
            ),
            child: Row(
              children: [
                const BackDiscButton(),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Text(
                    'Deliver where?',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.heading(size: 28),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              0,
              AppSpacing.gutter,
              AppSpacing.lg,
            ),
            child: SizedBox(
              height: 54,
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: AppTypography.body(size: 17),
                decoration: InputDecoration(
                  hintText: 'Search area, street or landmark',
                  hintStyle: AppTypography.body(
                    size: 17,
                    color: AppColors.textMuted(0.45),
                  ),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: AppSpacing.md),
                    child: Icon(Icons.search_rounded, size: 24),
                  ),
                  // The box sets the height, so the padding only has to
                  // centre the text within it.
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  // Borderless on the page tint — the white fill is the field.
                  border: _searchBorder,
                  enabledBorder: _searchBorder,
                  focusedBorder: _searchBorder,
                ),
              ),
            ),
          ),
          Expanded(
            child: switch (async) {
              AsyncLoading() => const SkeletonList(
                itemCount: 3,
                itemHeight: 88,
              ),
              AsyncError(:final error) => ErrorView(
                failure: asFailure(error),
                onRetry: () => ref.invalidate(addressBookProvider),
              ),
              AsyncValue(value: final addresses) => _AddressList(
                addresses: _filter(addresses ?? const []),
              ),
            },
          ),
        ],
      ),
    );
  }

  /// The search field carries no outline — just the white pill.
  OutlineInputBorder get _searchBorder => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.pill),
    borderSide: BorderSide.none,
  );

  List<Address> _filter(List<Address> addresses) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return addresses;
    return addresses
        .where(
          (a) =>
              a.title.toLowerCase().contains(query) ||
              a.area.toLowerCase().contains(query) ||
              a.houseNumber.toLowerCase().contains(query),
        )
        .toList();
  }
}

class _AddressList extends ConsumerWidget {
  const _AddressList({required this.addresses});

  final List<Address> addresses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (addresses.isEmpty) {
      return Center(
        child: EmptyView(
          icon: Icons.location_on_outlined,
          title: 'No saved addresses',
          message: 'Add the place you want your water delivered to.',
          primaryLabel: 'Add address',
          onPrimary: () => context.pushNamed(AppRoutes.addAddress),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.xxl,
      ),
      // One extra row for the "add" affordance, which sits with the list
      // rather than pinned to the bottom of the screen.
      itemCount: addresses.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.lg),
      itemBuilder: (context, i) {
        if (i == addresses.length) {
          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: _AddAddressButton(
              onTap: () => context.pushNamed(AppRoutes.addAddress),
            ),
          );
        }

        final address = addresses[i];
        // The default is the one you are delivering to now, so it carries the
        // selected treatment.
        final selected = address.isDefault;

        return AppCard(
          color: selected ? AppColors.onTint : null,
          borderColor: selected ? AppColors.accent : null,
          padding: const EdgeInsets.all(AppSpacing.lg),
          onTap: address.isServiceable
              ? () {
                  ref.read(cartProvider.notifier).setAddress(address);
                  ref.read(addressBookProvider.notifier).setDefault(address.id);
                  context.pop();
                }
              : null,
          child: Opacity(
            opacity: address.isServiceable ? 1 : 0.55,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.accent : AppColors.neutral200,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    switch (address.label) {
                      AddressLabel.home => Icons.home_outlined,
                      AddressLabel.office => Icons.business_outlined,
                      AddressLabel.other => Icons.location_on_outlined,
                    },
                    size: 22,
                    color: selected
                        ? AppColors.surface
                        : AppColors.textMuted(0.65),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              address.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.heading(size: 16.5),
                            ),
                          ),
                          if (address.isDefault) ...[
                            const SizedBox(width: AppSpacing.sm),
                            const _DefaultBadge(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        address.fullLine,
                        style: AppTypography.body(
                          size: 13.5,
                          color: address.isServiceable
                              ? AppColors.textMuted(0.6)
                              : AppColors.textMuted(0.45),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => context.pushNamed(
                    AppRoutes.addAddress,
                    queryParameters: {'id': address.id},
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  color: AppColors.textMuted(0.45),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The solid blue "Default" pill beside the chosen address.
class _DefaultBadge extends StatelessWidget {
  const _DefaultBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.accent,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text(
      'Default',
      style: AppTypography.body(
        size: 11.5,
        weight: FontWeight.w800,
        color: AppColors.surface,
      ),
    ),
  );
}

/// The dashed pill that opens the address picker — outlined rather than
/// filled, so it reads as an empty slot waiting to be filled.
class _AddAddressButton extends StatelessWidget {
  const _AddAddressButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashedPillPainter(color: AppColors.textMuted(0.3)),
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: SizedBox(
          height: 59,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_rounded, size: 22),
              const SizedBox(width: AppSpacing.md),
              Text(
                'Add a new address',
                style: AppTypography.heading(size: 16.5),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DashedPillPainter extends CustomPainter {
  const _DashedPillPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + 7).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + 6;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPillPainter oldDelegate) =>
      oldDelegate.color != color;
}
