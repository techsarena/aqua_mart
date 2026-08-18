import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

enum CnicCameraSide { front, back }

class CnicCameraResult {
  const CnicCameraResult({required this.path, required this.side});

  final String path;
  final CnicCameraSide side;
}

/// A focused, in-app CNIC camera so the capture experience stays consistent
/// across iOS and Android.
class CnicCameraScreen extends StatefulWidget {
  const CnicCameraScreen({required this.initialSide, super.key});

  final CnicCameraSide initialSide;

  @override
  State<CnicCameraScreen> createState() => _CnicCameraScreenState();
}

class _CnicCameraScreenState extends State<CnicCameraScreen>
    with WidgetsBindingObserver {
  static const _background = Color(0xFF081215);
  static const _previewBackground = Color(0xFF15252B);
  static const _controlBackground = Color(0xFF30393E);
  static const _blue = Color(0xFF117EB7);
  static const _muted = Color(0xFFAFB4B6);

  final _imagePicker = ImagePicker();
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  late CnicCameraSide _side;
  bool _busy = false;
  bool _flashEnabled = false;
  String? _cameraError;
  int _initializationId = 0;

  @override
  void initState() {
    super.initState();
    _side = widget.initialSide;
    WidgetsBinding.instance.addObserver(this);
    _loadCameras();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _initializationId++;
      final controller = _controller;
      _controller = null;
      controller?.dispose();
    } else if (state == AppLifecycleState.resumed && _controller == null) {
      _loadCameras();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _initializationId++;
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadCameras() async {
    if (mounted) setState(() => _cameraError = null);
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      _cameras = cameras;
      if (cameras.isEmpty) {
        setState(() => _cameraError = 'No camera was found on this device.');
        return;
      }
      final initial = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      await _initializeCamera(initial);
    } on CameraException catch (error) {
      _setCameraError(_friendlyCameraError(error.code));
    } catch (_) {
      _setCameraError('The camera could not be started. Please try again.');
    }
  }

  Future<void> _initializeCamera(CameraDescription description) async {
    final initializationId = ++_initializationId;
    final oldController = _controller;
    _controller = null;
    await oldController?.dispose();

    final controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await controller.initialize();
      await controller.setFlashMode(
        _flashEnabled ? FlashMode.auto : FlashMode.off,
      );
      if (!mounted || initializationId != _initializationId) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _cameraError = null;
        _busy = false;
      });
    } on CameraException catch (error) {
      await controller.dispose();
      if (initializationId == _initializationId) {
        _setCameraError(_friendlyCameraError(error.code));
      }
    } catch (_) {
      await controller.dispose();
      if (initializationId == _initializationId) {
        _setCameraError('The camera could not be started. Please try again.');
      }
    }
  }

  void _setCameraError(String message) {
    if (!mounted) return;
    setState(() {
      _cameraError = message;
      _busy = false;
    });
  }

  String _friendlyCameraError(String code) {
    if (code.toLowerCase().contains('accessdenied') ||
        code.toLowerCase().contains('permission')) {
      return 'Camera access is disabled. Enable it in your phone settings, then try again.';
    }
    return 'The camera could not be started. Please try again.';
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (_busy || controller == null || !controller.value.isInitialized) return;

    setState(() => _busy = true);
    try {
      await HapticFeedback.mediumImpact();
      final photo = await controller.takePicture();
      if (!mounted) return;
      Navigator.pop(context, CnicCameraResult(path: photo.path, side: _side));
    } on CameraException {
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage('The photo could not be taken. Please try again.');
    }
  }

  Future<void> _chooseFromGallery() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 88,
        requestFullMetadata: false,
      );
      if (!mounted) return;
      if (photo == null) {
        setState(() => _busy = false);
        return;
      }
      Navigator.pop(context, CnicCameraResult(path: photo.path, side: _side));
    } on PlatformException {
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage(
        'Photo access is disabled. Enable it in your phone settings.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage('Could not open your photo gallery.');
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (_busy || controller == null || !controller.value.isInitialized) return;

    final enabled = !_flashEnabled;
    try {
      await controller.setFlashMode(enabled ? FlashMode.auto : FlashMode.off);
      if (mounted) setState(() => _flashEnabled = enabled);
    } on CameraException {
      if (mounted) _showMessage('Flash is not available on this camera.');
    }
  }

  Future<void> _switchCamera() async {
    final current = _controller;
    if (_busy || current == null || _cameras.length < 2) return;

    final currentIndex = _cameras.indexWhere(
      (camera) => camera.name == current.description.name,
    );
    final next = _cameras[(currentIndex + 1) % _cameras.length];
    setState(() => _busy = true);
    await _initializeCamera(next);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final titleSide = _side == CnicCameraSide.front ? 'front' : 'back';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
            child: Column(
              children: [
                SizedBox(
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _RoundControl(
                          tooltip: 'Close camera',
                          onTap: _busy ? null : () => Navigator.pop(context),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 29,
                          ),
                        ),
                      ),
                      Text(
                        'CNIC — $titleSide',
                        key: const Key('cnic-camera-title'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Figtree',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _RoundControl(
                          tooltip: _flashEnabled
                              ? 'Turn flash off'
                              : 'Use auto flash',
                          onTap: _toggleFlash,
                          child: Icon(
                            _flashEnabled
                                ? Icons.flash_auto_rounded
                                : Icons.flash_on_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                AspectRatio(
                  aspectRatio: 1.585,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: _previewBackground),
                        _buildCameraPreview(),
                        const IgnorePointer(
                          child: CustomPaint(painter: _CnicFramePainter()),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Fit the $titleSide of your CNIC inside the frame. Keep\nall four corners visible.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _muted,
                    fontFamily: 'Figtree',
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 1.42,
                  ),
                ),
                const Spacer(),
                _SideSelector(
                  selected: _side,
                  onChanged: (side) => setState(() => _side = side),
                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _RoundControl(
                      tooltip: 'Choose from gallery',
                      size: 54,
                      onTap: _chooseFromGallery,
                      child: const Icon(
                        Icons.photo_outlined,
                        color: Color(0xFFD8DCDD),
                        size: 27,
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Take photo',
                      child: GestureDetector(
                        key: const Key('cnic-camera-shutter'),
                        onTap: _capture,
                        child: AnimatedOpacity(
                          opacity: _busy || _controller == null ? 0.55 : 1,
                          duration: const Duration(milliseconds: 150),
                          child: Container(
                            width: 80,
                            height: 80,
                            padding: const EdgeInsets.all(7),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE0E3E4),
                              shape: BoxShape.circle,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _background,
                                  width: 4,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _RoundControl(
                      tooltip: 'Switch camera',
                      size: 54,
                      onTap: _cameras.length > 1 ? _switchCamera : null,
                      child: Icon(
                        Icons.cameraswitch_rounded,
                        color: _cameras.length > 1
                            ? const Color(0xFFD8DCDD)
                            : const Color(0xFF70787B),
                        size: 27,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      return CameraPreview(controller);
    }

    final error = _cameraError;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(42),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              color: Color(0xFF899398),
              size: 34,
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF9BA4A8),
                fontFamily: 'Figtree',
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _loadCameras, child: const Text('Try again')),
          ],
        ),
      );
    }

    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.badge_outlined, color: Color(0xFF899398), size: 31),
          SizedBox(height: 13),
          Text(
            'Camera preview',
            style: TextStyle(
              color: Color(0xFF899398),
              fontFamily: 'Figtree',
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SideSelector extends StatelessWidget {
  const _SideSelector({required this.selected, required this.onChanged});

  final CnicCameraSide selected;
  final ValueChanged<CnicCameraSide> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (final side in CnicCameraSide.values)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Semantics(
            button: true,
            selected: selected == side,
            child: GestureDetector(
              key: Key('cnic-side-${side.name}'),
              onTap: () => onChanged(side),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 76,
                height: 41,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected == side
                      ? _CnicCameraScreenState._blue
                      : _CnicCameraScreenState._controlBackground,
                  borderRadius: BorderRadius.circular(23),
                ),
                child: Text(
                  side == CnicCameraSide.front ? 'Front' : 'Back',
                  style: TextStyle(
                    color: selected == side
                        ? Colors.white
                        : const Color(0xFFBEC2C4),
                    fontFamily: 'Figtree',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.tooltip,
    required this.child,
    required this.onTap,
    this.size = 42,
  });

  final String tooltip;
  final Widget child;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: _CnicCameraScreenState._controlBackground,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: size,
            child: Center(child: child),
          ),
        ),
      ),
    ),
  );
}

class _CnicFramePainter extends CustomPainter {
  const _CnicFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 16.0;
    const arm = 36.0;
    const radius = 12.0;
    final left = inset;
    final top = inset;
    final right = size.width - inset;
    final bottom = size.height - inset;
    final paint = Paint()
      ..color = _CnicCameraScreenState._blue
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(left, top + arm)
      ..lineTo(left, top + radius)
      ..quadraticBezierTo(left, top, left + radius, top)
      ..lineTo(left + arm, top)
      ..moveTo(right - arm, top)
      ..lineTo(right - radius, top)
      ..quadraticBezierTo(right, top, right, top + radius)
      ..lineTo(right, top + arm)
      ..moveTo(right, bottom - arm)
      ..lineTo(right, bottom - radius)
      ..quadraticBezierTo(right, bottom, right - radius, bottom)
      ..lineTo(right - arm, bottom)
      ..moveTo(left + arm, bottom)
      ..lineTo(left + radius, bottom)
      ..quadraticBezierTo(left, bottom, left, bottom - radius)
      ..lineTo(left, bottom - arm);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
