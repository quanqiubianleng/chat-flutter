import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// 扫一扫页：与参考图一致。右上角相册图标与底部「照片」按钮打开相册选图并解析二维码，结果返回转账页地址栏
class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _alreadyPopped = false;
  /// 页面统一偏绿色
  static const Color _green = Color(0xFF00D1A7);
  static final Color _greenLight = Colors.white;

  void _onDetect(BarcodeCapture capture) {
    if (_alreadyPopped) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? raw = barcode.rawValue;
      if (raw != null && raw.trim().isNotEmpty) {
        _alreadyPopped = true;
        Navigator.of(context).pop(raw.trim());
        return;
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_alreadyPopped) return;
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null || !mounted) return;
      final path = file.path;
      if (path == null || path.isEmpty) return;
      final capture = await _controller.analyzeImage(path);
      if (!mounted) return;
      if (capture != null) {
        for (final barcode in capture.barcodes) {
          final raw = barcode.rawValue;
          if (raw != null && raw.trim().isNotEmpty) {
            _alreadyPopped = true;
            Navigator.of(context).pop(raw.trim());
            return;
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未识别到二维码/条码')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('解析失败: $e')),
        );
      }
    }
  }

  void _toggleTorch() {
    _controller.toggleTorch();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('扫一扫', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 26),
            onPressed: _pickFromGallery,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // 四角绿色 L 形扫描框 + 框内闪光灯（整体上移）
          _buildScanFrame(),
          // 底部说明文字（偏绿色）
          Positioned(
            left: 0,
            right: 0,
            bottom: 100,
            child: Center(
              child: Text(
                '将二维码/条码放入框内,即可自动扫描',
                style: TextStyle(color: _greenLight, fontSize: 14),
              ),
            ),
          ),
          // 底部绿色「照片」按钮
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: SafeArea(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _pickFromGallery,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  ),
                  child: const Text('照片', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanFrame() {
    const double frameSize = 240;
    const double cornerLen = 32;
    const double strokeWidth = 4;

    return Positioned.fill(
      child: Align(
        alignment: const Alignment(0, -0.25),
        child: SizedBox(
          width: frameSize,
          height: frameSize,
          child: Stack(
            children: [
              CustomPaint(
                size: Size(frameSize, frameSize),
                painter: _ScanFramePainter(
                  cornerLength: cornerLen,
                  strokeWidth: strokeWidth,
                  color: _green,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: frameSize * 0.35,
                child: Center(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _toggleTorch,
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(Icons.flash_on, color: _green, size: 28),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 绘制四角 L 形扫描框
class _ScanFramePainter extends CustomPainter {
  final double cornerLength;
  final double strokeWidth;
  final Color color;

  _ScanFramePainter({
    required this.cornerLength,
    required this.strokeWidth,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;
    final c = cornerLength;

    // 左上
    canvas.drawPath(
      Path()
        ..moveTo(0, c)
        ..lineTo(0, 0)
        ..lineTo(c, 0),
      paint,
    );
    // 右上
    canvas.drawPath(
      Path()
        ..moveTo(w - c, 0)
        ..lineTo(w, 0)
        ..lineTo(w, c),
      paint,
    );
    // 右下
    canvas.drawPath(
      Path()
        ..moveTo(w, h - c)
        ..lineTo(w, h)
        ..lineTo(w - c, h),
      paint,
    );
    // 左下
    canvas.drawPath(
      Path()
        ..moveTo(c, h)
        ..lineTo(0, h)
        ..lineTo(0, h - c),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
