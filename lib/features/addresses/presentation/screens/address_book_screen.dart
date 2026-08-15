import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_tag.dart';
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
      appBar: AppBar(title: const Text('Deliver where?')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              0,
              AppSpacing.gutter,
              AppSpacing.md,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search area, street or landmark',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
              ),
            ),
          ),
          Expanded(
            child: switch (async) {
              AsyncLoading() => const SkeletonList(itemCount: 3, itemHeight: 88),
              AsyncError(:final error) => ErrorView(
                failure: asFailure(error),
                onRetry: () => ref.invalidate(addressBookProvider),
              ),
              AsyncValue(value: final addresses) => _AddressList(
                addresses: _filter(addresses ?? const []),
              ),
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              child: Column(
                children: [
                  const AppNote(
                    icon: Icons.info_outline_rounded,
                    text:
                        'Changing your address may change which sellers you '
                        'can order from.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () => context.pushNamed(AppRoutes.addAddress),
                    icon: const Icon(Icons.add_rounded, size: 19),
                    label: const Text('Add a new address'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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
      return const Center(
        child: EmptyView(
          icon: Icons.location_on_outlined,
          title: 'No saved addresses',
          message: 'Add the place you want your water delivered to.',
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.lg,
      ),
      itemCount: addresses.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, i) {
        final address = addresses[i];

        return AppCard(
          onTap: address.isServiceable
              ? () {
                  ref.read(cartProvider.notifier).setAddress(address);
                  ref
                      .read(addressBookProvider.notifier)
                      .setDefault(address.id);
                  context.pop();
                }
              : null,
          child: Opacity(
            opacity: address.isServiceable ? 1 : 0.55,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accent100,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    switch (address.label) {
                      AddressLabel.home => Icons.home_rounded,
                      AddressLabel.office => Icons.business_rounded,
                      AddressLabel.other => Icons.location_on_rounded,
                    },
                    size: 19,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            address.title,
                            style: AppTypography.body(
                              size: 14.5,
                              weight: FontWeight.w700,
                            ),
                          ),
                          if (address.isDefault) ...[
                            const SizedBox(width: AppSpacing.sm),
                            const AppTag('Default', tone: TagTone.accent),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        address.fullLine,
                        style: AppTypography.body(
                          size: 12.5,
                          color: address.isServiceable
                              ? AppColors.textMuted(0.6)
                              : AppColors.danger,
                          height: 1.4,
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
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: AppColors.textMuted(0.5),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
