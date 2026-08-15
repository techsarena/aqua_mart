import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_section.dart';
import '../../../../shared/widgets/settings_tile.dart';
import '../../../../shared/widgets/sticky_action_bar.dart';

/// When customers can order. Includes the Friday Jumma break, which is a real
/// fixture of the working week here.
class BusinessHoursScreen extends ConsumerStatefulWidget {
  const BusinessHoursScreen({super.key});

  @override
  ConsumerState<BusinessHoursScreen> createState() =>
      _BusinessHoursScreenState();
}

class _BusinessHoursScreenState extends ConsumerState<BusinessHoursScreen> {
  static const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  bool _sameEveryDay = true;
  final _activeDays = {0, 1, 2, 3, 4, 5, 6};
  bool _fridayBreak = true;
  TimeOfDay _opens = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _closes = const TimeOfDay(hour: 21, minute: 0);

  Future<void> _pickTime({required bool isOpening}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isOpening ? _opens : _closes,
    );
    if (picked == null) return;
    setState(() => isOpening ? _opens = picked : _closes = picked);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Business hours')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.xxl,
      ),
      children: [
        Text(
          'Customers can only order inside these hours.',
          style: AppTypography.body(
            size: 13,
            color: AppColors.textMuted(0.6),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Same hours every day',
                      style: AppTypography.body(
                        size: 14,
                        weight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Turn off to set each day separately',
                      style: AppTypography.body(
                        size: 12,
                        color: AppColors.textMuted(0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _sameEveryDay,
                onChanged: (v) => setState(() => _sameEveryDay = v),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _TimeField(
                label: 'Opens',
                time: _opens,
                onTap: () => _pickTime(isOpening: true),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _TimeField(
                label: 'Closes',
                time: _closes,
                onTap: () => _pickTime(isOpening: false),
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),
        const FieldLabel('Days you deliver'),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < _dayLetters.length; i++)
              _DayToggle(
                letter: _dayLetters[i],
                active: _activeDays.contains(i),
                onTap: () => setState(() {
                  _activeDays.contains(i)
                      ? _activeDays.remove(i)
                      : _activeDays.add(i);
                }),
              ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),
        SettingsGroup(
          children: [
            SettingsTile(
              icon: Icons.mosque_outlined,
              title: 'Friday break',
              subtitle: _fridayBreak
                  ? 'Closed 12:30 – 2:00 PM for Jumma'
                  : 'No break set',
              trailing: Switch.adaptive(
                value: _fridayBreak,
                onChanged: (v) => setState(() => _fridayBreak = v),
              ),
            ),
            SettingsTile(
              icon: Icons.event_busy_outlined,
              title: 'Holiday',
              subtitle: "Add days you'll be shut",
              onTap: () {},
            ),
          ],
        ),
      ],
    ),
    bottomNavigationBar: StickyActionBar(
      label: 'Save hours',
      onPressed: () {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Hours saved.')));
        context.pop();
      },
    ),
  );
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.time,
    required this.onTap,
  });

  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.body(
            size: 11.5,
            weight: FontWeight.w600,
            color: AppColors.textMuted(0.55),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          time.format(context),
          style: AppTypography.heading(size: 20),
        ),
      ],
    ),
  );
}

class _DayToggle extends StatelessWidget {
  const _DayToggle({
    required this.letter,
    required this.active,
    required this.onTap,
  });

  final String letter;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? AppColors.accent : AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? AppColors.accent : AppColors.divider,
        ),
      ),
      child: Text(
        letter,
        style: AppTypography.body(
          size: 14,
          weight: FontWeight.w700,
          color: active ? Colors.white : AppColors.textMuted(0.55),
        ),
      ),
    ),
  );
}
