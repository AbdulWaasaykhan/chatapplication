import 'package:chatapplication/themes/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

class ChatBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isCurrentUser;
  final bool isRead;  // <-- New parameter for read receipt

  const ChatBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    this.isRead = false,  // default false if not provided
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    // bubble color
    final bubbleColor = isCurrentUser
        ? (isDarkMode ? Colors.grey.shade700 : Colors.green.shade500)
        : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200);

    // chat bubble radius
    final radius = isCurrentUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(14),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomRight: Radius.circular(14),
          );

    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: radius,
        ),
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        child: Column(
          crossAxisAlignment:
              isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMessageContent(context, isDarkMode),
            if (isCurrentUser)
              Padding(
                padding: const EdgeInsets.only(top: 4.0, right: 4.0),
                child: Text(
                  isRead ? "✓✓ Read" : "✓ Sent",
                  style: TextStyle(
                    fontSize: 10,
                    color: isRead
                        ? Colors.blueAccent
                        : (isDarkMode ? Colors.white54 : Colors.black45),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, bool isDarkMode) {
    final String type = message["type"] ?? "text";
    final String mediaUrl = message["mediaUrl"] ?? "";

    switch (type) {
      case "text":
        return Text(
          message["message"] ?? "",
          style: TextStyle(
            fontSize: 15,
            color: isCurrentUser
                ? Colors.white
                : (isDarkMode ? Colors.white : Colors.black87),
          ),
        );

      case "image":
        if (mediaUrl.isEmpty) {
          return const Icon(Icons.broken_image, size: 50, color: Colors.red);
        }
        return GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => Dialog(
                backgroundColor: Colors.black,
                insetPadding: const EdgeInsets.all(8),
                child: InteractiveViewer(
                  child: Image.network(mediaUrl),
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              mediaUrl,
              width: 220,
              height: 220,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.broken_image, size: 50, color: Colors.red),
              loadingBuilder: (context, child, loadingProgress) =>
                  loadingProgress == null
                      ? child
                      : const SizedBox(
                          width: 220,
                          height: 220,
                          child: Center(child: CircularProgressIndicator()),
                        ),
            ),
          ),
        );

      case "video":
        if (mediaUrl.isEmpty) {
          return const Text("⚠ Invalid video URL");
        }
        return SizedBox(
          width: 250,
          height: 200,
          child: VideoPlayerBubble(url: mediaUrl),
        );

      default:
        return const Text("⚠ Unsupported message type");
    }
  }
}

class VideoPlayerBubble extends StatefulWidget {
  final String url;

  const VideoPlayerBubble({super.key, required this.url});

  @override
  State<VideoPlayerBubble> createState() => _VideoPlayerBubbleState();
}

class _VideoPlayerBubbleState extends State<VideoPlayerBubble> {
  late VideoPlayerController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        _controller.setLooping(true);
        setState(() => _isLoading = false);
      }).catchError((error) {
        debugPrint("Video load error: $error");
        setState(() => _hasError = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const Center(child: Text("⚠ Failed to load video"));
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_controller.value.isInitialized) {
      return const Center(child: Text("⚠ Video not initialized"));
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        ),
        IconButton(
          icon: Icon(
            _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 40,
          ),
          onPressed: () {
            setState(() {
              _controller.value.isPlaying
                  ? _controller.pause()
                  : _controller.play();
            });
          },
        ),
      ],
    );
  }
}
