import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/location/app_location.dart';
import '../../../../core/location/location_providers.dart';
import '../../../../core/location/pakistan.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Search for the area a seller delivers to, and pick one from the results.
///
/// Pops the chosen [AppLocation] — the caller centres its map on it, so the
/// seller sets their radius around a place they searched for rather than
/// hunting for it by dragging.
class AreaSearchScreen extends ConsumerStatefulWidget {
  const AreaSearchScreen({super.key});

  @override
  ConsumerState<AreaSearchScreen> createState() => _AreaSearchScreenState();
}

class _AreaSearchScreenState extends ConsumerState<AreaSearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  Timer? _debounce;
  List<AppLocation> _results = const [];
  bool _searching = false;
  bool _hasSearched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // The keyboard is the point of this screen, so it opens with one.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Geocoding is a network call per keystroke, so typing is debounced and
  /// very short queries are ignored entirely.
  void _onChanged(String value) {
    _debounce?.cancel();
    // Rebuild so the clear button appears/disappears with the text.
    setState(() {});
    if (value.trim().length < 3) {
      setState(() {
        _results = const [];
        _hasSearched = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(value));
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await ref
          .read(appLocationServiceProvider)
          .search(trimmed);
      if (!mounted) return;
      setState(() {
        _results = results;
        _hasSearched = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _hasSearched = true;
        _error = 'Location search is unavailable right now. Try again.';
      });
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _useMyLocation() async {
    setState(() => _searching = true);
    final location = await ref.read(currentLocationProvider.future);
    if (!mounted) return;
    setState(() => _searching = false);

    if (location == null) {
      setState(
        () => _error = 'Could not find your location. Search for it instead.',
      );
      return;
    }
    if (!Pakistan.contains(location.latitude, location.longitude)) {
      setState(
        () => _error =
            'You appear to be outside Pakistan. Search for your area instead.',
      );
      return;
    }
    Navigator.pop(context, location);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Find your area')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.sm,
            AppSpacing.gutter,
            AppSpacing.md,
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            onSubmitted: _search,
            decoration: InputDecoration(
              hintText: 'Search an area, e.g. Gulberg III',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _controller.clear();
                        _onChanged('');
                      },
                    ),
            ),
          ),
        ),

        if (_searching) const LinearProgressIndicator(minHeight: 2),

        Expanded(
          child: _error != null
              ? _Message(icon: Icons.cloud_off_rounded, text: _error!)
              : _results.isNotEmpty
              ? ListView.separated(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                  itemCount: _results.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final result = _results[index];
                    return ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(
                        result.label,
                        style: AppTypography.body(
                          size: 15,
                          weight: FontWeight.w600,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                      ),
                      // The caller drops its map pin here and opens the
                      // radius control on it.
                      onTap: () => Navigator.pop(context, result),
                    );
                  },
                )
              : _hasSearched
              ? const _Message(
                  icon: Icons.search_off_rounded,
                  text: 'No matching place found. Try a different spelling.',
                )
              : const _Message(
                  icon: Icons.travel_explore_rounded,
                  text:
                      'Search for the area you deliver to, then set how far '
                      'around it you go.',
                ),
        ),

        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              0,
              AppSpacing.gutter,
              AppSpacing.md,
            ),
            child: SizedBox(
              height: 52,
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _searching ? null : _useMyLocation,
                icon: const Icon(Icons.my_location_rounded, size: 18),
                label: const Text('Use my current location'),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34, color: AppColors.textMuted(0.35)),
          const SizedBox(height: AppSpacing.lg),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTypography.body(
              size: 14,
              color: AppColors.textMuted(0.6),
              height: 1.5,
            ),
          ),
        ],
      ),
    ),
  );
}
