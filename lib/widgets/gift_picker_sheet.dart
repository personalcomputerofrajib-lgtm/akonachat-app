import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class GiftPickerSheet extends StatefulWidget {
  final String recipientId;
  final String recipientName;

  const GiftPickerSheet({
    Key? key,
    required this.recipientId,
    required this.recipientName,
  }) : super(key: key);

  @override
  _GiftPickerSheetState createState() => _GiftPickerSheetState();
}

class _GiftPickerSheetState extends State<GiftPickerSheet> {
  final AuthService _authService = AuthService();
  bool _isSending = false;
  bool _isAnonymous = false;

  final List<Map<String, dynamic>> _gifts = [
    {'id': 'rose', 'name': 'Rose', 'price': 10, 'icon': Icons.favorite, 'color': Colors.redAccent},
    {'id': 'cake', 'name': 'Cake', 'price': 25, 'icon': Icons.cake, 'color': Colors.pinkAccent},
    {'id': 'friendship_band', 'name': 'Friend Band', 'price': 50, 'icon': Icons.watch, 'color': Colors.purpleAccent},
    {'id': 'car', 'name': 'Sports Car', 'price': 500, 'icon': Icons.directions_car, 'color': Colors.blueAccent},
  ];

  void _sendGift(String itemId, int price) async {
    setState(() => _isSending = true);
    
    final result = await _authService.sendGift(widget.recipientId, itemId);
    
    if (mounted) {
      setState(() => _isSending = false);
      if (result != null) {
        Navigator.pop(context, true); // Success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sent ${itemId.replaceAll('_', ' ')} to ${widget.recipientName}!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send gift. Check your coins!'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Send a Gift to ${widget.recipientName}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 16),
          
          // Anonymous Toggle
          SwitchListTile(
            title: const Text('Send Anonymously'),
            subtitle: const Text('Recipient won\'t see your name'),
            value: _isAnonymous,
            onChanged: (val) => setState(() => _isAnonymous = val),
            secondary: const Icon(Icons.security),
          ),
          const Divider(),
          const SizedBox(height: 8),

          // Gift Grid
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              itemCount: _gifts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                final gift = _gifts[index];
                return InkWell(
                  onTap: _isSending ? null : () => _sendGift(gift['id'], gift['price']),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: gift['color'].withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: gift['color'].withOpacity(0.3), width: 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(gift['icon'], color: gift['color'], size: 36),
                        const SizedBox(height: 8),
                        Text(gift['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.monetization_on, size: 14, color: Colors.orangeAccent),
                            const SizedBox(width: 4),
                            Text('${gift['price']}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          if (_isSending)
             const Padding(
               padding: EdgeInsets.all(20.0),
               child: Center(child: CircularProgressIndicator()),
             ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
