import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../services/auth_service.dart';

class DailyRewardPopup extends StatefulWidget {
  final int currentStreak;
  final int nextRewardDay;

  const DailyRewardPopup({
    Key? key,
    required this.currentStreak,
    required this.nextRewardDay,
  }) : super(key: key);

  @override
  _DailyRewardPopupState createState() => _DailyRewardPopupState();
}

class _DailyRewardPopupState extends State<DailyRewardPopup> {
  bool _isClaiming = false;
  final List<int> _rewards = [15, 20, 25, 30, 35, 40, 50];

  Future<void> _claimReward() async {
    setState(() => _isClaiming = true);
    try {
      final token = await AuthService().getToken();
      final response = await http.post(
        Uri.parse('${Constants.apiUrl}/engagement/claim-daily'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Claimed ${data['reward']} coins!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Already claimed or error occurred')),
        );
      }
    } catch (e) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 16,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  const Icon(Icons.star, color: Colors.white, size: 40),
                  const SizedBox(height: 8),
                  const Text(
                    'Daily Rewards',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Don\'t miss out on your daily gold!',
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Rewards Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: List.generate(7, (index) {
                  int day = index + 1;
                  bool isNext = day == widget.nextRewardDay;
                  bool isClaimed = day < widget.nextRewardDay;
                  
                  return _buildRewardItem(day, _rewards[index], isNext, isClaimed);
                }),
              ),
            ),
            const SizedBox(height: 30),
            // Claim Button
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 24),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isClaiming ? null : _claimReward,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5722),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 4,
                  ),
                  child: _isClaiming
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Claim Reward', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardItem(int day, int amount, bool isNext, bool isClaimed) {
    return Container(
      width: (day == 7) ? 140 : 65,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isNext ? const Color(0xFFFFF3E0) : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNext ? const Color(0xFFFF9800) : Colors.transparent,
          width: 2,
        ),
        boxShadow: isNext ? [BoxShadow(color: Colors.orange.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))] : null,
      ),
      child: Column(
        children: [
          Text('Day $day', style: TextStyle(fontSize: 10, color: isNext ? const Color(0xFFFF9800) : Colors.grey)),
          const SizedBox(height: 4),
          if (day == 7)
            const Icon(Icons.card_giftcard, color: Color(0xFFFF5722), size: 28)
          else
            const Icon(Icons.monetization_on, color: Color(0xFFFFC107), size: 20),
          const SizedBox(height: 4),
          Text(
            day == 7 ? 'Mystery' : '+$amount',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isNext ? const Color(0xFFFF5722) : Colors.black87,
            ),
          ),
          if (isClaimed)
            const Icon(Icons.check_circle, color: Colors.green, size: 14),
        ],
      ),
    );
  }
}

void showDailyRewardPopup(BuildContext context, {required int currentStreak, required int nextRewardDay}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => DailyRewardPopup(currentStreak: currentStreak, nextRewardDay: nextRewardDay),
  );
}
