import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../customization/key_catalog.dart';
import '../theme/app_colors.dart';
import '../widgets/key_display.dart';

class ScanScreen extends StatefulWidget {
  final String title;
  final String instruction;
  final KeyStyle? keyStyle;
  final KeyColorOption? keyColor;

  const ScanScreen({
    super.key,
    this.title = 'Scan Code',
    this.instruction = 'Point your camera at a QR code or barcode',
    this.keyStyle,
    this.keyColor,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    _hasScanned = true;
    Navigator.of(context).pop(barcode.rawValue);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title.toUpperCase(),
          style: const TextStyle(
            letterSpacing: 1.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              color: AppColors.onSurface.withValues(alpha: 0.85),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Builder(builder: (_) {
                    final style = widget.keyStyle ?? keyStyleById(kDefaultKeyStyleId);
                    final color = widget.keyColor ??
                        keyColorById(style, kDefaultKeyColorId);
                    return SizedBox(
                      height: 64,
                      width: 64,
                      child: Center(
                        child: KeyDisplay(
                          style: style,
                          color: color,
                          size: 56,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 16),
                  const Text(
                    'SCAN YOUR KEY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 80,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                color: AppColors.onSurface.withValues(alpha: 0.85),
                child: Text(
                  widget.instruction,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
