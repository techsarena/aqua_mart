import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_section.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import '../providers/auth_providers.dart';
import '../widgets/onboarding_scaffold.dart';

/// Sign-up 4 of 4 — optional. Skipping lands you in the app just the same.
///
/// The last step, so this is where the account is actually created from the
/// draft the previous three steps filled in.
class SignUpDetailsScreen extends ConsumerStatefulWidget {
  const SignUpDetailsScreen({super.key});

  @override
  ConsumerState<SignUpDetailsScreen> createState() =>
      _SignUpDetailsScreenState();
}

class _SignUpDetailsScreenState extends ConsumerState<SignUpDetailsScreen> {
  Gender _gender = Gender.unspecified;
  DateTime _dob = DateTime(1994, 4, 14);

  /// Creates the account and signs in. Sellers register their business
  /// first, so they are routed there rather than to a customer home.
  Future<void> _finish({bool skipped = false}) async {
    if (!skipped) {
      ref
          .read(sessionProvider.notifier)
          .updateDraft((d) => d.copyWith(gender: _gender, dateOfBirth: _dob));
    }

    final draft = ref.read(sessionProvider).draft;
    final result = await ref
        .read(authRepositoryProvider)
        .completeProfile(draft);
    if (!mounted) return;

    result.when(
      success: (user) {
        // Signing in first: the seller onboarding routes sit outside the
        // onboarding stack, so a signed-out seller would be redirected
        // straight back to the intro.
        ref.read(sessionProvider.notifier).signIn(user);
        if (draft.role == UserRole.seller) {
          context.goNamed(AppRoutes.sellerOnboarding);
        }
      },
      failure: (f) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(f.message)));
      },
    );
  }

  @override
  Widget build(BuildContext context) => OnboardingScaffold(
    step: 4,
    totalSteps: 4,
    title: 'A little about you',
    subtitle:
        "Optional — it helps sellers plan deliveries. Skip if you'd rather not.",
    primaryLabel: 'Finish · start ordering',
    onPrimary: _finish,
    secondaryLabel: 'Skip for now',
    onSecondary: () => _finish(skipped: true),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('GENDER'),
        Row(
          children: [
            Expanded(
              child: _GenderCard(
                label: 'Female',
                icon: Icons.female_rounded,
                badgeColor: AppColors.accent,
                selected: _gender == Gender.female,
                onTap: () => setState(() => _gender = Gender.female),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _GenderCard(
                label: 'Male',
                icon: Icons.male_rounded,
                badgeColor: AppColors.neutral400,
                selected: _gender == Gender.male,
                onTap: () => setState(() => _gender = Gender.male),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        const FieldLabel('DATE OF BIRTH'),
        _DateOfBirthPicker(
          value: _dob,
          onChanged: (date) => setState(() => _dob = date),
        ),
      ],
    ),
  );
}

/// One gender choice — a filled icon badge above the label, in a tall card.
///
/// Selected state draws the accent border and tints the fill; unselected
/// cards stay plain white.
class _GenderCard extends StatelessWidget {
  const _GenderCard({
    required this.label,
    required this.icon,
    required this.badgeColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color badgeColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        decoration: BoxDecoration(
          color: selected ? AppColors.onTint : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected ? AppColors.accent : Colors.transparent,
            width: 1.6,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: AppColors.surface),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(label, style: AppTypography.heading(size: 18)),
          ],
        ),
      ),
    ),
  );
}

/// Day · month · year wheels in one white panel.
///
/// Inline rather than behind a dialog: the date is the only thing left to
/// set on this screen, so it is quicker to spin than to open a picker.
class _DateOfBirthPicker extends StatelessWidget {
  const _DateOfBirthPicker({required this.value, required this.onChanged});

  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// Youngest sign-up we accept, and the oldest year offered.
  static const _minimumAge = 13;
  static const _earliestYear = 1930;

  int get _latestYear => DateTime.now().year - _minimumAge;

  /// Clamps the day when a shorter month or a non-leap February would leave
  /// the current selection out of range — 31 March → February becomes the
  /// 28th rather than spilling into the next month.
  void _emit({int? day, int? month, int? year}) {
    final y = year ?? value.year;
    final m = month ?? value.month;
    final lastDay = DateTime(y, m + 1, 0).day;
    onChanged(DateTime(y, m, (day ?? value.day).clamp(1, lastDay)));
  }

  @override
  Widget build(BuildContext context) => Container(
    height: 230,
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        // The highlight band sits behind all three wheels so it reads as one
        // strip across the panel rather than three separate pills.
        Container(
          height: 56,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.neutral100,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _Wheel(
                // Days are rebuilt per month so February never offers a 30th.
                count: DateTime(value.year, value.month + 1, 0).day,
                selectedIndex: value.day - 1,
                labelAt: (i) => '${i + 1}',
                onSelected: (i) => _emit(day: i + 1),
              ),
            ),
            Expanded(
              flex: 5,
              child: _Wheel(
                count: _months.length,
                selectedIndex: value.month - 1,
                labelAt: (i) => _months[i],
                onSelected: (i) => _emit(month: i + 1),
              ),
            ),
            Expanded(
              flex: 4,
              child: _Wheel(
                count: _latestYear - _earliestYear + 1,
                selectedIndex: value.year - _earliestYear,
                labelAt: (i) => '${_earliestYear + i}',
                onSelected: (i) => _emit(year: _earliestYear + i),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// A single column of the date picker.
class _Wheel extends StatefulWidget {
  const _Wheel({
    required this.count,
    required this.selectedIndex,
    required this.labelAt,
    required this.onSelected,
  });

  final int count;
  final int selectedIndex;
  final String Function(int index) labelAt;
  final ValueChanged<int> onSelected;

  @override
  State<_Wheel> createState() => _WheelState();
}

class _WheelState extends State<_Wheel> {
  late final FixedExtentScrollController _controller =
      FixedExtentScrollController(initialItem: widget.selectedIndex);

  @override
  void didUpdateWidget(_Wheel old) {
    super.didUpdateWidget(old);
    // A clamped day (31 March → February) moves the selection without the
    // wheel having been touched, so pull it back into line.
    if (widget.selectedIndex != _controller.selectedItem) {
      _controller.jumpToItem(widget.selectedIndex);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CupertinoPicker.builder(
    scrollController: _controller,
    itemExtent: 46,
    childCount: widget.count,
    squeeze: 1.1,
    magnification: 1.0,
    diameterRatio: 100,
    // The centred highlight band is drawn once across the whole panel by
    // the day column, so the other two wheels stay bare.
    selectionOverlay: const SizedBox.shrink(),
    onSelectedItemChanged: widget.onSelected,
    itemBuilder: (context, i) {
      final isSelected = i == widget.selectedIndex;
      return Center(
        child: Text(
          widget.labelAt(i),
          style: AppTypography.body(
            size: isSelected ? 19 : 17,
            weight: isSelected ? FontWeight.w700 : FontWeight.w400,
            color: isSelected ? AppColors.text : AppColors.textMuted(0.45),
          ),
        ),
      );
    },
  );
}
