import 'package:flutter/material.dart';
import '../services/network_service.dart';

class ConnectionStatusWidget extends StatefulWidget {
  final bool showRetryButton;
  final VoidCallback? onRetry;

  const ConnectionStatusWidget({
    Key? key,
    this.showRetryButton = true,
    this.onRetry,
  }) : super(key: key);

  @override
  State<ConnectionStatusWidget> createState() => _ConnectionStatusWidgetState();
}

class _ConnectionStatusWidgetState extends State<ConnectionStatusWidget> {
  final NetworkService _networkService = NetworkService();
  bool _isOnline = true;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _checkConnectionStatus();
  }

  void _checkConnectionStatus() {
    setState(() {
      _isOnline = _networkService.isOnline;
    });
  }

  Future<void> _retryConnection() async {
    setState(() {
      _isRetrying = true;
    });

    try {
      final success = await _networkService.forceReconnect();
      setState(() {
        _isOnline = success;
        _isRetrying = false;
      });

      if (success && widget.onRetry != null) {
        widget.onRetry!();
      }
    } catch (e) {
      setState(() {
        _isRetrying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: _isOnline ? Colors.green[100] : Colors.red[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isOnline ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isRetrying)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _isOnline ? Colors.green : Colors.red,
                ),
              ),
            )
          else
            Icon(
              _isOnline ? Icons.wifi : Icons.wifi_off,
              size: 16,
              color: _isOnline ? Colors.green : Colors.red,
            ),
          const SizedBox(width: 4),
          Text(
            _isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 12,
              color: _isOnline ? Colors.green : Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (!_isOnline && widget.showRetryButton) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _isRetrying ? null : _retryConnection,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Retry',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
} 