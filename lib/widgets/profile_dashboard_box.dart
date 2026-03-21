import 'package:flutter/material.dart';
import 'dart:ui';
import '../models/user_model.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfileDashboardBox extends StatelessWidget {
  final UserModel user;
  final bool isCurrentUser;

  const ProfileDashboardBox({
    Key? key,
    required this.user,
    this.isCurrentUser = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // 1. THE BANNER (Background)
            _buildBanner(),

            // 2. GLASS EFFECT OVERLAY
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Container(
                  color: Colors.black.withOpacity(0.35),
                ),
              ),
            ),

            // 3. CONTENT
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStreakBadge(),
                      _buildCoinDisplay(),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isCurrentUser ? 'My Achievements' : '${user.name}\'s Dashboard',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildGiftsRow(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner() {
    if (user.profileBanner != null && user.profileBanner!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: user.profileBanner!,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: Colors.grey[900]),
        errorWidget: (context, url, error) => _buildDefaultBanner(),
      );
    }
    return _buildDefaultBanner();
  }

  Widget _buildDefaultBanner() {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueGrey[900]!, Colors.blue[900]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Opacity(
        opacity: 0.1,
        child: Icon(Icons.sports_esports, size: 100, color: Colors.white),
      ),
    );
  }

  Widget _buildStreakBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 20),
          const SizedBox(width: 4),
          Text(
            '${user.streak} Day Streak',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.yellowAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.yellowAccent.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on, color: Colors.yellowAccent, size: 20),
          const SizedBox(width: 4),
          Text(
            '${user.coins}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftsRow() {
    final giftList = user.gifts ?? [];
    if (giftList.isEmpty) {
      return Text(
        'No gifts received yet. Send one to say hi!',
        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
      );
    }

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: giftList.length > 5 ? 5 : giftList.length,
        itemBuilder: (context, index) {
          final gift = giftList[index];
          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: _getGiftIcon(gift['itemId']),
          );
        },
      ),
    );
  }

  Widget _getGiftIcon(String? itemId) {
    IconData icon;
    Color color;
    switch (itemId) {
      case 'rose':
        icon = Icons.favorite;
        color = Colors.redAccent;
        break;
      case 'cake':
        icon = Icons.cake;
        color = Colors.pinkAccent;
        break;
      case 'car':
        icon = Icons.directions_car;
        color = Colors.blueAccent;
        break;
      case 'friendship_band':
        icon = Icons.watch;
        color = Colors.purpleAccent;
        break;
      default:
        icon = Icons.card_giftcard;
        color = Colors.white;
    }
    return Tooltip(
      message: itemId ?? 'Gift',
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}
