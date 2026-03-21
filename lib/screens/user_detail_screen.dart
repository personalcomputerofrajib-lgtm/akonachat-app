import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/full_screen_image_viewer.dart';
import '../widgets/profile_dashboard_box.dart';
import '../widgets/gift_picker_sheet.dart';

class UserDetailScreen extends StatelessWidget {
  final UserModel user;

  const UserDetailScreen({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('User Info'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                if (user.profilePic != null && user.profilePic!.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FullScreenImageViewer(imageUrl: user.profilePic!),
                    ),
                  );
                }
              },
              child: Hero(
                tag: 'profile_pic_${user.id}',
                child: CircleAvatar(
                  radius: 70,
                  backgroundImage: user.profilePic != null && user.profilePic!.isNotEmpty
                      ? CachedNetworkImageProvider(user.profilePic!)
                      : null,
                  child: user.profilePic == null || user.profilePic!.isEmpty
                      ? Icon(Icons.person, size: 70, color: Colors.grey)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 10),
            
            // --- NEW DASHBOARD SECTION ---
            ProfileDashboardBox(user: user),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => GiftPickerSheet(
                      recipientId: user.id,
                      recipientName: user.name,
                    ),
                  );
                },
                icon: const Icon(Icons.card_giftcard),
                label: const Text('Send a Social Gift'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
            
            const SizedBox(height: 10),
            SizedBox(height: 20),
            Text(
              user.name,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              '@${user.username}',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('About', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                  SizedBox(height: 10),
                  Text(
                    user.about != null && user.about!.isNotEmpty ? user.about! : 'No bio provided.',
                    style: TextStyle(fontSize: 16, height: 1.5),
                  ),
                ],
              ),
            ),
            SizedBox(height: 40),
            Divider(),
            ListTile(
              leading: Icon(Icons.search, color: Colors.blueAccent),
              title: Text('Search Messages'),
              onTap: () {
                // TODO: Implement in-chat search
              },
            ),
            ListTile(
              leading: Icon(Icons.notifications_off_outlined, color: Colors.orange),
              title: Text('Mute Notifications'),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Notifications muted for ${user.name}'))
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.block, color: Colors.red),
              title: Text('Block User', style: TextStyle(color: Colors.red)),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Block ${user.name}?'),
                    content: Text('They will not be able to send you messages or see your status.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true), 
                        child: Text('Block', style: TextStyle(color: Colors.red))
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  // Implementation note: This should call ApiService().post('/users/block/${user.id}')
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${user.name} has been blocked'))
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

