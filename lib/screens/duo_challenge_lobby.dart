import 'package:flutter/material.dart';

class DuoChallengeLobby extends StatelessWidget {
  final String inviteId;
  final String? otherUsername;

  const DuoChallengeLobby(
      {Key? key, required this.inviteId, this.otherUsername})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Duo Challenge Lobby'),
        backgroundColor: const Color(0xFF7C4DFF),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.groups, size: 80, color: Color(0xFF7C4DFF)),
            const SizedBox(height: 24),
            Text(
              otherUsername != null
                  ? 'Waiting for $otherUsername...'
                  : 'Waiting for the other player...',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Once both players are ready, the game will start!',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
