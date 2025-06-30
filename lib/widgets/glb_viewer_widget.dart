import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;

class GLBViewerWidget extends StatefulWidget {
  const GLBViewerWidget({Key? key}) : super(key: key);

  @override
  State<GLBViewerWidget> createState() => _GLBViewerWidgetState();
}

class _GLBViewerWidgetState extends State<GLBViewerWidget> {
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    _prepareAssets();
  }

  Future<void> _prepareAssets() async {
    final dir = await getTemporaryDirectory();

    // Copy HTML
    final htmlBytes = await rootBundle.load('assets/web/viewer.html');
    final htmlFile = File('${dir.path}/viewer.html');
    await htmlFile.writeAsBytes(htmlBytes.buffer.asUint8List());

    // Copy GLB
    final glbBytes = await rootBundle.load('assets/web/MyCharacter.glb');
    final glbFile = File('${dir.path}/MyCharacter.glb');
    await glbFile.writeAsBytes(glbBytes.buffer.asUint8List());

    // Pass the GLB file path as a query parameter
    final String fileUrl =
        '${Uri.file(htmlFile.path)}?model=${Uri.encodeComponent(glbFile.path)}';
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(fileUrl));

    setState(() {
      _controller = controller;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _controller == null
        ? const Center(child: CircularProgressIndicator())
        : WebViewWidget(controller: _controller!);
  }
}
