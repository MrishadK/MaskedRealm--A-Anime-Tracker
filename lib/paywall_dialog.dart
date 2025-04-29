import 'package:flutter/material.dart';

class PaywallDialog extends StatelessWidget {
  const PaywallDialog(
      {Key? key, required Future<Null> Function() onPurchaseSuccess})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      title: const Text(
        'Support Us – Go Premium',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: Colors.blueAccent,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'We appreciate your support! By making a one-time donation, you can remove ads and enjoy a seamless experience.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          const Text(
            'To make a donation, please use PayPal and send your contribution to the following email address:',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          const Text(
            'mrishad963@gmail.com',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Important: Please include your email ID with your donation so we can verify your purchase and provide premium access.',
            style: TextStyle(fontSize: 14, color: Colors.redAccent),
          ),
          const SizedBox(height: 16),
          const Text(
            'Thank you for supporting the app and helping us continue to improve!',
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Donate Now',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }
}
