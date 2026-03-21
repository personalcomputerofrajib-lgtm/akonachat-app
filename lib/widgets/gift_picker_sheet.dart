import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
    {'id': 'rose', 'name': 'Rose', 'price': 5, 'icon': Icons.favorite_border, 'color': Colors.redAccent},
    {'id': 'heart', 'name': 'Heart', 'price': 10, 'icon': Icons.favorite, 'color': Colors.pinkAccent},
    {'id': 'chocolate', 'name': 'Chocolate', 'price': 20, 'icon': Icons.wallet_giftcard, 'color': Colors.brown},
    {'id': 'cake', 'name': 'Cake', 'price': 50, 'icon': Icons.cake, 'color': Colors.orangeAccent},
    {'id': 'car', 'name': 'Sport Car', 'price': 200, 'icon': Icons.directions_car, 'color': Colors.blueAccent},
    {'id': 'diamond', 'name': 'Diamond', 'price': 150, 'icon': Icons.diamond, 'color': Colors.cyanAccent},
    {'id': 'rocket', 'name': 'Rocket', 'price': 1000, 'icon': Icons.rocket_launch, 'color': Colors.deepPurpleAccent},
  ];

  void _sendGift(String itemId, int price) async {
    setState(() => _isSending = true);
    
    final result = await _authService.sendGift(
      widget.recipientId, 
      itemId, 
      isAnonymous: _isAnonymous
    );
    
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
                        if (gift['isStatic'] == true)
                          CachedNetworkImage(
                            imageUrl: 'http://52.66.216.152:9000/static/${gift['id']}.png',
                            height: 40,
                            width: 40,
                            placeholder: (context, url) => Icon(Icons.card_giftcard, color: gift['color'], size: 36),
                            errorWidget: (context, url, error) => Icon(Icons.error, color: Colors.red, size: 36),
                          )
                        else
                          Icon(gift['icon'], color: gift['color'], size: 36),
                        const SizedBox(height: 8),
                        Text(gift['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CachedNetworkImage(
                              imageUrl: 'http://52.66.216.152:9000/static/coin.png',
                              height: 14,
                              width: 14,
                              placeholder: (context, url) => const Icon(Icons.monetization_on, size: 14, color: Colors.orangeAccent),
                              errorWidget: (context, url, error) => const Icon(Icons.monetization_on, size: 14, color: Colors.orangeAccent),
                            ),
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
