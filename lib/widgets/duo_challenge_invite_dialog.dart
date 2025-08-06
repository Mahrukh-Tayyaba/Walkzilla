import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/duo_challenge_lobby.dart';
import '../services/coin_service.dart';

class DuoChallengeInviteDialog extends StatelessWidget {
  final String inviterUsername;
  final String inviteId;

  const DuoChallengeInviteDialog({
    super.key,
    required this.inviterUsername,
    required this.inviteId,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      titlePadding:
          const EdgeInsets.only(left: 24, top: 24, right: 8, bottom: 0),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF7C4DFF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.emoji_events,
              color: Color(0xFF7C4DFF),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Duo Challenge Invite',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          // Cross button
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey, size: 22),
            splashRadius: 20,
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Close',
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$inviterUsername is inviting you to a Duo Challenge right now!',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Do you want to accept this challenge?',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _declineInvite(context),
          child: const Text(
            'Decline',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => _acceptInvite(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C4DFF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Accept',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _acceptInvite(BuildContext context) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Check if user has enough coins before accepting
      final coinService = CoinService();
      const requiredCoins = 50;
      final hasEnoughCoins = await coinService.hasEnoughCoins(requiredCoins);

      if (!hasEnoughCoins) {
        if (context.mounted) {
          Navigator.of(context).pop();
          _showInsufficientCoinsDialog(context, requiredCoins);
        }
        return;
      }

      // Update the invite status to accepted
      await FirebaseFirestore.instance
          .collection('duo_challenge_invites')
          .doc(inviteId)
          .update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        Navigator.of(context).pop('accepted');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Challenge accepted!'),
            backgroundColor: Color(0xFF7C4DFF),
          ),
        );
        // Navigate to the lobby screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => DuoChallengeLobby(
              inviteId: inviteId,
              otherUsername: inviterUsername,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        // Only pop if the dialog is still open
        try {
          Navigator.of(context).pop();
        } catch (popError) {
          // Dialog might already be closed, ignore the error
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting invite: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showInsufficientCoinsDialog(BuildContext context, int requiredCoins) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.warning_amber,
                  color: Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Insufficient Coins',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You need $requiredCoins coins to join this challenge.',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'To earn more coins:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Walk more steps to earn coins\n• Play daily challenges to earn more coins',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog
                // Decline the invite since user can't participate
                await _declineInvite(context);
              },
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _declineInvite(BuildContext context) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Update the invite status to declined
      await FirebaseFirestore.instance
          .collection('duo_challenge_invites')
          .doc(inviteId)
          .update({
        'status': 'declined',
        'declinedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        Navigator.of(context).pop('declined');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Challenge declined.'),
            backgroundColor: Colors.grey,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error declining invite: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
