import 'package:chatapplication/themes/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

class ChatBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isCurrentUser;
  final bool isRead;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    this.isRead = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    // define gradients, shadow, and radius for a modern look
    final userGradient = isDarkMode
        ? const LinearGradient(
      colors: [Color(0xFF1C1C1C), Color(0xFF171717)], // deep purple
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    )
        : const LinearGradient(
      colors: [Color(0xFF0B0B0B), Color(0xFF070707)], // vibrant blue
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final otherGradient = isDarkMode
        ? LinearGradient(
      colors: [Colors.grey.shade800, Colors.grey.shade700],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    )
        : LinearGradient(
      colors: [Colors.grey.shade200, Colors.grey.shade100],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final shadow = [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.2),
        blurRadius: 5.0,
        offset: const Offset(0, 2),
      )
    ];

    final radius = isCurrentUser
        ? const BorderRadius.only(
      topLeft: Radius.circular(18),
      topRight: Radius.circular(18),
      bottomLeft: Radius.circular(18),
    )
        : const BorderRadius.only(
      topLeft: Radius.circular(18),
      topRight: Radius.circular(18),
      bottomRight: Radius.circular(18),
    );

    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        // use the new decoration
        decoration: BoxDecoration(
          gradient: isCurrentUser ? userGradient : otherGradient,
          borderRadius: radius,
          boxShadow: shadow,
        ),
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        child: Column(
          crossAxisAlignment:
          isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMessageContent(context, isDarkMode),
            if (isCurrentUser) _buildReadReceipt(isDarkMode),
          ],
        ),
      ),
    );
  }

  // upgraded read receipt with icons
  Widget _buildReadReceipt(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(top: 5.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isRead ? "Read" : "Sent",
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            isRead ? Icons.done_all : Icons.done,
            size: 14,
            color: isRead ? Colors.lightBlueAccent : Colors.white.withValues(alpha: 0.7),
          ),
        ],
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
            fontSize: 16,
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
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.all(8),
                child: InteractiveViewer(
                  child: Image.network(mediaUrl),
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
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
      return const Center(
          child: Text("⚠ Failed to load video",
              style: TextStyle(color: Colors.white)));
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_controller.value.isInitialized) {
      return const Center(
          child: Text("⚠ Video not initialized",
              style: TextStyle(color: Colors.white)));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
          // scrim
          Container(color: Colors.black.withValues(alpha: 0.1)),
          // play/pause button
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.4),
              shape: const CircleBorder(),
            ),
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
      ),
    );
  }
}