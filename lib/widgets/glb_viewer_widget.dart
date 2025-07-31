import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;

class GLBViewerWidget extends StatefulWidget {
  final String glbFilePath;

  const GLBViewerWidget({
    Key? key,
    required this.glbFilePath,
  }) : super(key: key);

  @override
  State<GLBViewerWidget> createState() => _GLBViewerWidgetState();
}

class _GLBViewerWidgetState extends State<GLBViewerWidget> {
  WebViewController? _controller;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _prepareAssets();
  }

  Future<void> _prepareAssets() async {
    try {
      final dir = await getTemporaryDirectory();

      // Copy HTML
      final htmlBytes = await rootBundle.load('assets/web/viewer.html');
      String htmlContent = utf8.decode(htmlBytes.buffer.asUint8List());

      // Copy GLB and convert to base64
      final glbBytes = await rootBundle.load(widget.glbFilePath);
      final glbBase64 = base64Encode(glbBytes.buffer.asUint8List());

      // Replace the model path in HTML with base64 data
      htmlContent = htmlContent.replaceAll(
          'const glbPath = urlParams.get(\'model\') || \'MyCharacter.glb\';',
          'const glbPath = \'data:model/gltf-binary;base64,$glbBase64\';');

      // Write the modified HTML to temp directory
      final htmlFile = File('${dir.path}/viewer.html');
      await htmlFile.writeAsString(htmlContent);

      // Load the HTML file
      final String fileUrl = Uri.file(htmlFile.path).toString();
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..loadRequest(Uri.parse(fileUrl));

      if (mounted) {
        setState(() {
          _controller = controller;
          _hasError = false;
        });
      }
    } catch (e) {
      print('GLB Viewer Error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '3D Model not available',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Showing image instead',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[400],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }

    return _controller == null
        ? const Center(child: CircularProgressIndicator())
        : WebViewWidget(controller: _controller!);
  }
}
