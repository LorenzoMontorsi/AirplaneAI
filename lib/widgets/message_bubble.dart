import 'dart:io';
import 'package:flutter/material.dart';

enum BubbleRole { user, assistant, system }

class ChatBubble extends StatelessWidget {
  final String text;
  final BubbleRole role;
  final String? imagePath;
  final bool isStreaming;
  const ChatBubble({
    super.key,
    required this.text,
    required this.role,
    this.imagePath,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = role == BubbleRole.user;
    final isSystem = role == BubbleRole.system;
    final bg = isSystem
        ? Colors.amber.shade100
        : isUser
            ? const Color(0xFF0F7B6B)
            : Colors.grey.shade200;
    final fg = isSystem
        ? Colors.brown.shade800
        : isUser
            ? Colors.white
            : Colors.black87;
    final align = isSystem ? CrossAxisAlignment.center : (isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start);
    final bubbleAlign = isSystem ? Alignment.center : (isUser ? Alignment.centerRight : Alignment.centerLeft);

    return Container(
      alignment: bubbleAlign,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (imagePath != null && imagePath!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              constraints: const BoxConstraints(maxWidth: 260, maxHeight: 260),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.file(File(imagePath!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
            ),
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomRight: isUser ? const Radius.circular(4) : null,
                bottomLeft: !isUser && !isSystem ? const Radius.circular(4) : null,
              ),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    text.isEmpty && isStreaming ? '▌' : text,
                    style: TextStyle(color: fg, fontSize: 15, height: 1.35),
                  ),
                ),
                if (isStreaming) ...[
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg.withOpacity(0.6)),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}
