import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
                // TODO: Implement mute
              },
            ),
            ListTile(
              leading: Icon(Icons.block, color: Colors.red),
              title: Text('Block User', style: TextStyle(color: Colors.red)),
              onTap: () {
                // Already have block logic elsewhere, but can move it here too
              },
            ),
          ],
        ),
      ),
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const FullScreenImageViewer({Key? key, required this.imageUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            placeholder: (context, url) => CircularProgressIndicator(color: Colors.white),
            errorWidget: (context, url, error) => Icon(Icons.error, color: Colors.white),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
