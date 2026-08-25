// Olympus Mont Systems LLC - ControlMiles

// lib/screens/odometer_capture_screen.dart

// PRODUCTION · LIVE OCR · NO MOCKS · FULL I18N · SUPABASE-CONNECTED



import 'dart:async';

import 'dart:io';



import 'package:camera/camera.dart';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:provider/provider.dart';




import '../logic/app_state.dart';      // AppState

import '../services/odometer_capture_service.dart';

import '../services/odometer_ocr_service.dart';



// ─────────────────────────────────────────────────────────────────────────────

// Camera initialization

// ─────────────────────────────────────────────────────────────────────────────



List<CameraDescription> _cameras = [];



Future<void> initializeCameras() async {

  try {

    _cameras = await availableCameras();

  } catch (e) {

    debugPrint('[Camera] Hardware not found: $e');

  }

}



class OdometerCaptureScreen extends StatefulWidget {

  final String sessionId;

  final bool isStart;



  const OdometerCaptureScreen({

    super.key,

    required this.sessionId,

    required this.isStart,

  });



  @override

  State<OdometerCaptureScreen> createState() => _OdometerCaptureScreenState();

}



class _OdometerCaptureScreenState extends State<OdometerCaptureScreen>

    with WidgetsBindingObserver {



  CameraController? _cameraController;

  final OdometerOcrService _ocrService = OdometerOcrService();

  final OdometerCaptureService _captureService = OdometerCaptureService();



  OcrScanResult? _lastOcrResult;

  bool _ocrLocked = false;

  bool _ocrFailed = false;

  DateTime _lastFrameProcessed = DateTime(0);



  bool _torchOn = false;

  Timer? _torchSuggestionTimer;

  Timer? _torchFailTimer;

  bool _showTorchButton = false;

  bool _isProcessing = false;



  final TextEditingController _odometerController = TextEditingController();

  final FocusNode _odometerFocus = FocusNode();



  @override

  void initState() {

    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _initCamera();

    _startTorchSuggestionTimer();

  }



  @override

  void dispose() {

    WidgetsBinding.instance.removeObserver(this);

    _odometerFocus.dispose();

    _odometerController.dispose();

    _ocrService.dispose();

    _torchSuggestionTimer?.cancel();

    _torchFailTimer?.cancel();

    _cameraController?.dispose();

    super.dispose();

  }



  @override

  void didChangeAppLifecycleState(AppLifecycleState state) {

    if (_cameraController == null) return;

    if (state == AppLifecycleState.inactive) {

      _cameraController?.dispose();

      _cameraController = null;

    } else if (state == AppLifecycleState.resumed) {

      _initCamera();

    }

  }



  Future<void> _initCamera() async {

    if (_cameras.isEmpty) await initializeCameras();

    if (_cameras.isEmpty) return;



    final backCam = _cameras.firstWhere(

      (c) => c.lensDirection == CameraLensDirection.back,

      orElse: () => _cameras.first,

    );



    final controller = CameraController(

      backCam,

      ResolutionPreset.high,

      enableAudio: false,

      imageFormatGroup: ImageFormatGroup.yuv420,

    );



    try {

      await controller.initialize();

      await controller.setFlashMode(FlashMode.off);

      await controller.setFocusMode(FocusMode.auto);

      await controller.startImageStream(_onCameraFrame);



      if (!mounted) return;

      setState(() => _cameraController = controller);

    } catch (e) {

      debugPrint('[Camera] Init failed: $e');

    }

  }



  void _startTorchSuggestionTimer() {

    _torchSuggestionTimer?.cancel();

    _torchSuggestionTimer = Timer(const Duration(seconds: 5), () {

      if (!mounted || _ocrLocked) return;

      setState(() => _showTorchButton = true);

    });

  }



  Future<void> _toggleTorch() async {

    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {

      final next = !_torchOn;

      await _cameraController!.setFlashMode(next ? FlashMode.torch : FlashMode.off);

      setState(() {

        _torchOn = next;

        _showTorchButton = false;

      });



      if (next) {

        _torchFailTimer?.cancel();

        _torchFailTimer = Timer(const Duration(seconds: 5), () {

          if (!mounted || _ocrLocked) return;

          setState(() => _ocrFailed = true);

        });

      } else {

        _torchFailTimer?.cancel();

        if (!_ocrFailed) _startTorchSuggestionTimer();

      }

    } catch (e) {

      debugPrint('[Torch] Toggle failed: $e');

    }

  }



  // ── FIX #2: UI SIEMPRE se actualiza cuando OCR se estabiliza ──────────────

  Future<void> _onCameraFrame(CameraImage image) async {

    if (_ocrLocked || _ocrFailed || _isProcessing) return;



    final now = DateTime.now();

    if (now.difference(_lastFrameProcessed).inMilliseconds < 500) return;

    _lastFrameProcessed = now;



    final sensorOrientation = _cameraController?.description.sensorOrientation ?? 0;

    final result = await _ocrService.processFrame(image, sensorOrientation);



    if (!mounted || result == null) return;



    setState(() => _lastOcrResult = result);



    // BUG FIX (campo editable): si el usuario ya tiene el foco en el campo
    // (está corrigiendo la lectura a mano), el OCR no debe seguir
    // pisándole lo que está escribiendo con cada frame nuevo.
    if (result.isStable && !_ocrFailed && !_odometerFocus.hasFocus) {

      final formatted = _formatMiles(result.value);



      if (_odometerController.text != formatted) {

        _odometerController.text = formatted;

        HapticFeedback.lightImpact();

      }



      _torchSuggestionTimer?.cancel();

      _torchFailTimer?.cancel();



      // Aplicando fix: setState garantizado para bloquear UI

      setState(() {

        _ocrLocked = true;

        _ocrFailed = false;

        _showTorchButton = false;

      });

    }

  }



  Future<void> _capture(AppState appState) async {

    final rawText = _odometerController.text.trim();

    final cleanedText = rawText.replaceAll(RegExp(r'[,\s]'), '');

    final odometerValue = double.tryParse(cleanedText);



    if (odometerValue == null || odometerValue <= 0) {

      _showError(appState.tr('invalid_input'));

      return;

    }



    if (_cameraController == null || !_cameraController!.value.isInitialized) {

      _showError(appState.tr('error'));

      return;

    }



    if (_isProcessing) return;

    setState(() => _isProcessing = true);



    try {

      await _cameraController!.stopImageStream();

      final XFile photo = await _cameraController!.takePicture();



      final bool wasOcrSource = _ocrLocked && !_ocrFailed;

      final double? confidence = wasOcrSource ? _lastOcrResult?.confidence : null;



      final result = await _captureService.processEvidence(

        sessionId: widget.sessionId,

        file: File(photo.path),

        odometerValue: odometerValue,

        isStart: widget.isStart,

        language: appState.currentLanguage,

        ocrSource: wasOcrSource,

        ocrConfidence: confidence,

      );



      if (!mounted) return;

      Navigator.pop(context, result);

    } catch (e) {

      setState(() => _isProcessing = false);

      _ocrLocked = false;

      _ocrFailed = false;

      _lastOcrResult = null;

      await _cameraController?.startImageStream(_onCameraFrame);

      _startTorchSuggestionTimer();

      _showError(e.toString());

    }

  }



  void _showError(String msg) {

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: Text(msg),

        backgroundColor: Colors.red.shade700,

        duration: const Duration(seconds: 6),

      ),

    );

  }



  String _formatMiles(double value) {

    final intVal = value.toInt();

    final str = intVal.toString();

    if (str.length > 3) {

      return '${str.substring(0, str.length - 3)},${str.substring(str.length - 3)}';

    }

    return str;

  }



  @override

  Widget build(BuildContext context) {

    final appState = Provider.of<AppState>(context);

    return PopScope(

      canPop: widget.isStart,

      onPopInvokedWithResult: (didPop, _) {

        if (!didPop && !widget.isStart) _showError(appState.tr('end_odometer_capture'));

      },

      child: Scaffold(

        backgroundColor: Colors.black,

        body: Stack(

          fit: StackFit.expand,

          children: [

            _buildCameraPreview(),

            _buildScanOverlay(),

            _buildUI(appState),

            if (_isProcessing) _buildProcessingLoader(appState),

          ],

        ),

      ),

    );

  }



  Widget _buildCameraPreview() {

    if (_cameraController == null || !_cameraController!.value.isInitialized) {

      return const Center(child: CircularProgressIndicator(color: Colors.white));

    }

    return Center(child: CameraPreview(_cameraController!));

  }



  Widget _buildScanOverlay() {

    return IgnorePointer(

      child: CustomPaint(

        painter: _ScanOverlayPainter(

          isDetected: _ocrLocked,

          isScanning: _lastOcrResult != null && !_ocrLocked,

        ),

        child: const SizedBox.expand(),

      ),

    );

  }



  Widget _buildUI(AppState appState) {

    return SafeArea(

      child: Column(

        mainAxisAlignment: MainAxisAlignment.spaceBetween,

        children: [

          _buildTopBar(appState),

          _buildOdometerArea(appState),

          _buildBottomBar(appState),

        ],

      ),

    );

  }



  Widget _buildTopBar(AppState appState) {

    return Padding(

      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

      child: Row(

        children: [

          GestureDetector(

            onTap: () => Navigator.maybePop(context),

            child: Container(

              width: 40, height: 40,

              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),

              child: const Icon(Icons.close, color: Colors.white, size: 20),

            ),

          ),

          Expanded(

            child: Text(

              widget.isStart ? appState.tr('start_odometer_capture') : appState.tr('end_odometer_capture'),

              textAlign: TextAlign.center,

              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),

            ),

          ),

          AnimatedContainer(

            duration: const Duration(milliseconds: 250),

            width: 40, height: 40,

            decoration: BoxDecoration(

              color: _torchOn ? const Color(0xFFFFD600) : Colors.black54,

              borderRadius: BorderRadius.circular(20),

              border: _showTorchButton && !_torchOn 

                ? Border.all(color: const Color(0xFFFFD600).withValues(alpha: 0.8), width: 1.5) 

                : null,

            ),

            child: IconButton(

              padding: EdgeInsets.zero,

              onPressed: _toggleTorch,

              icon: Icon(_torchOn ? Icons.flashlight_on : Icons.flashlight_off, 

                color: _torchOn ? Colors.black : Colors.white70, size: 20),

            ),

          ),

        ],

      ),

    );

  }



  Widget _buildOdometerArea(AppState appState) {

    return Column(

      mainAxisSize: MainAxisSize.min,

      children: [

        AnimatedSlide(

          offset: _showTorchButton && !_torchOn && !_ocrLocked ? Offset.zero : const Offset(0, -1.5),

          duration: const Duration(milliseconds: 350),

          child: AnimatedOpacity(

            opacity: _showTorchButton && !_torchOn && !_ocrLocked ? 1.0 : 0.0,

            duration: const Duration(milliseconds: 300),

            child: GestureDetector(

              onTap: _toggleTorch,

              child: Container(

                margin: const EdgeInsets.only(bottom: 10),

                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),

                decoration: BoxDecoration(

                  color: Colors.black.withValues(alpha: 0.72),

                  borderRadius: BorderRadius.circular(20),

                  border: Border.all(color: const Color(0xFFFFD600).withValues(alpha: 0.7)),

                ),

                child: Row(

                  mainAxisSize: MainAxisSize.min,

                  children: [

                    const Icon(Icons.flashlight_off, size: 15, color: Color(0xFFFFD600)),

                    const SizedBox(width: 7),

                    Text(appState.tr('torch_suggestion'), 

                      style: const TextStyle(color: Color(0xFFFFD600), fontSize: 12, fontWeight: FontWeight.w500)),

                  ],

                ),

              ),

            ),

          ),

        ),

        Padding(

          padding: const EdgeInsets.only(bottom: 280),

          child: _buildScanStatus(appState),

        ),

      ],

    );

  }



  Widget _buildScanStatus(AppState appState) {

    if (_isProcessing) return const SizedBox.shrink();

    if (_ocrFailed) return _StatusChip(label: appState.tr('ocr_unreadable_manual'), color: Colors.orange, icon: Icons.warning_amber_rounded);

    if (_ocrLocked) {

      final confidence = ((_lastOcrResult?.confidence ?? 0) * 100).round();

      return _StatusChip(label: '${appState.tr('ocr_detected')} · $confidence%', color: const Color(0xFF00E5A0), icon: Icons.check_circle_outline);

    }

    if (_lastOcrResult != null) return _StatusChip(label: appState.tr('ocr_scanning'), color: Colors.white70, icon: Icons.document_scanner_outlined);

    return _StatusChip(label: appState.tr('center_odometer_numbers'), color: Colors.white54, icon: Icons.crop_free);

  }



  Widget _buildBottomBar(AppState appState) {

    return Padding(

      padding: const EdgeInsets.only(bottom: 36, left: 24, right: 24),

      child: Column(

        mainAxisSize: MainAxisSize.min,

        children: [

          _buildOdometerField(appState),

          const SizedBox(height: 20),

          _buildCaptureButton(appState),

        ],

      ),

    );

  }



  // BUG FIX (odómetro no editable): antes el campo solo se podía editar a
  // mano si el OCR se declaraba explícitamente "fallido" (solo ocurría tras
  // 5s con el flash encendido sin lograr detectar nada). Si el OCR lograba
  // "bloquear" un valor —aunque fuera incorrecto, como leer un número de
  // otra parte del tablero—, el campo quedaba de solo lectura y el usuario
  // no tenía forma de corregirlo. Ahora siempre es editable.
  Widget _buildOdometerField(AppState appState) {

    // BUG FIX (odómetro no editable, ver comentario arriba): el campo
    // siempre es editable ahora -- isEditable existía como una constante
    // `true` con varios ternarios `isEditable ? X : Y` cuya rama Y nunca
    // se alcanzaba (flutter analyze los marcaba como dead_code). Simplificado
    // a los valores directos en vez de mantener un ternario que nunca
    // toma la otra rama.
    final bool isAutoFilled = _ocrLocked && !_ocrFailed;



    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        if (isAutoFilled)

          Padding(

            padding: const EdgeInsets.only(bottom: 6),

            child: Container(

              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),

              decoration: BoxDecoration(color: const Color(0xFF00E5A0), borderRadius: BorderRadius.circular(20)),

              child: Row(

                mainAxisSize: MainAxisSize.min,

                children: [

                  const Icon(Icons.lock, size: 12, color: Colors.black),

                  const SizedBox(width: 5),

                  Text(appState.tr('ocr_auto_badge'), style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),

                ],

              ),

            ),

          ),

        TextField(

          controller: _odometerController,

          focusNode: _odometerFocus,

          readOnly: false,

          // BUG FIX: sin esto, escribir a mano no reconstruía la pantalla,
          // así que el botón de captura (que depende de si el campo tiene
          // texto) nunca se habilitaba mientras el usuario tecleaba.
          onChanged: (_) => setState(() {}),

          keyboardType: const TextInputType.numberWithOptions(decimal: false),

          textAlign: TextAlign.center,

          style: TextStyle(

            color: isAutoFilled ? const Color(0xFF00E5A0) : Colors.white,

            fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 4,

          ),

          decoration: InputDecoration(

            hintText: _ocrLocked ? '' : '------',

            hintStyle: const TextStyle(color: Colors.white24),

            labelText: appState.tr('odometer_value'),

            labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),

            filled: true,

            fillColor: Colors.black.withValues(alpha: 0.65),

            enabledBorder: OutlineInputBorder(

              borderRadius: BorderRadius.circular(14),

              borderSide: BorderSide(

                color: isAutoFilled ? const Color(0xFF00E5A0) : Colors.orange,

                width: 2.0,

              ),

            ),

            focusedBorder: OutlineInputBorder(

              borderRadius: BorderRadius.circular(14),

              borderSide: BorderSide(color: Colors.orange, width: 2.0),

            ),

            suffixIcon: const Icon(Icons.edit, size: 18, color: Colors.orange),

          ),

        ),

      ],

    );

  }



  // ── FIX #1: Botón correctamente controlado por OCR ───────────────────────

  // BUG FIX: antes el botón exigía que el OCR hubiera "bloqueado" un valor
  // o se hubiera declarado fallido — si el usuario escribía el valor a
  // mano mientras el OCR seguía escaneando en segundo plano (sin ninguna
  // de esas dos banderas activas), el botón quedaba deshabilitado para
  // siempre pese a tener un valor válido en el campo. Ahora solo depende
  // de que haya un valor no vacío, sin importar de dónde vino.
  Widget _buildCaptureButton(AppState appState) {

    final bool canCapture = _odometerController.text.trim().isNotEmpty &&

                            !_isProcessing;



    return SizedBox(

      width: double.infinity,

      height: 56,

      child: ElevatedButton.icon(

        onPressed: canCapture ? () => _capture(appState) : null,

        icon: const Icon(Icons.camera_alt, size: 22),

        label: Text(

          appState.tr('ocr_confirm_capture'),

          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.5),

        ),

        style: ElevatedButton.styleFrom(

          backgroundColor: const Color(0xFF00E5A0),

          foregroundColor: Colors.black,

          disabledBackgroundColor: Colors.white12,

          disabledForegroundColor: Colors.white38,

          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

          elevation: 0,

        ),

      ),

    );

  }



  Widget _buildProcessingLoader(AppState appState) {

    return Container(

      color: Colors.black87,

      child: Center(

        child: Column(

          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            const CircularProgressIndicator(color: Color(0xFF00E5A0), strokeWidth: 2.5),

            const SizedBox(height: 24),

            Text(appState.tr('ai_processing'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),

            const SizedBox(height: 8),

            Text(appState.tr('validating_mileage_gps_hash'), style: const TextStyle(color: Colors.white54, fontSize: 12)),

          ],

        ),

      ),

    );

  }

}



class _ScanOverlayPainter extends CustomPainter {

  final bool isDetected;

  final bool isScanning;



  const _ScanOverlayPainter({required this.isDetected, required this.isScanning});



  @override

  void paint(Canvas canvas, Size size) {

    const frameW = 280.0;

    const frameH = 100.0;

    final frameRect = RRect.fromRectAndRadius(

      Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: frameW, height: frameH),

      const Radius.circular(10),

    );



    final scrimPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);

    final fullPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final cutPath = Path()..addRRect(frameRect);

    canvas.drawPath(Path.combine(PathOperation.difference, fullPath, cutPath), scrimPaint);



    final Color frameColor = isDetected ? const Color(0xFF00E5A0) : isScanning ? Colors.white70 : Colors.white38;

    final borderPaint = Paint()..color = frameColor..style = PaintingStyle.stroke..strokeWidth = 2.5;



    const cornerLen = 22.0;

    final r = frameRect.outerRect;

    void drawCorner(Offset start, Offset hEnd, Offset vEnd) {

      canvas.drawLine(start, hEnd, borderPaint);

      canvas.drawLine(start, vEnd, borderPaint);

    }



    drawCorner(r.topLeft, r.topLeft + const Offset(cornerLen, 0), r.topLeft + const Offset(0, cornerLen));

    drawCorner(r.topRight, r.topRight - const Offset(cornerLen, 0), r.topRight + const Offset(0, cornerLen));

    drawCorner(r.bottomLeft, r.bottomLeft + const Offset(cornerLen, 0), r.bottomLeft - const Offset(0, cornerLen));

    drawCorner(r.bottomRight, r.bottomRight - const Offset(cornerLen, 0), r.bottomRight - const Offset(0, cornerLen));



    if (isScanning) {

      final scanPaint = Paint()

        ..shader = LinearGradient(colors: [Colors.transparent, Colors.white.withValues(alpha: 0.6), Colors.transparent]).createShader(r)

        ..strokeWidth = 1.5..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(r.left + 8, r.center.dy), Offset(r.right - 8, r.center.dy), scanPaint);

    }

  }



  @override

  bool shouldRepaint(_ScanOverlayPainter old) => old.isDetected != isDetected || old.isScanning != isScanning;

}



class _StatusChip extends StatelessWidget {

  final String label;

  final Color color;

  final IconData icon;



  const _StatusChip({required this.label, required this.color, required this.icon});



  @override

  Widget build(BuildContext context) {

    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),

      decoration: BoxDecoration(

        color: Colors.black.withValues(alpha: 0.6),

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: color.withValues(alpha: 0.5)),

      ),

      child: Row(

        mainAxisSize: MainAxisSize.min,

        children: [

          Icon(icon, size: 14, color: color),

          const SizedBox(width: 6),

          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.4)),

        ],

      ),

    );

  }

}