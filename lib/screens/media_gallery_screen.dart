import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/full_screen_image_viewer.dart';

class MediaGalleryScreen extends StatelessWidget {
  final List<String> imageUrls;
  final String chatName;

  const MediaGalleryScreen({Key? key, required this.imageUrls, required this.chatName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('$chatName - Media'),
        elevation: 0,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      body: imageUrls.isEmpty
        ? Center(child: Text('No media shared yet', style: TextStyle(color: Colors.grey)))
        : GridView.builder(
            padding: EdgeInsets.all(8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: imageUrls.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FullScreenImageViewer(imageUrl: imageUrls[index]),
                    ),
                  );
                },
                child: Hero(
                  tag: 'media_$index',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: imageUrls[index],
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.grey[200]),
                      errorWidget: (context, url, error) => Icon(Icons.broken_image),
                    ),
                  ),
                ),
              );
            },
          ),
    );
  }
}
