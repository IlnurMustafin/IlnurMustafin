import 'package:flutter/material.dart';

class MessageBubble extends StatelessWidget {
  final String message;
  final bool isUser;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isUser ? Colors.blue.shade700 : Colors.grey.shade700,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      margin: EdgeInsets.only(
        left: isUser ? 50 : 0,
        right: isUser ? 0 : 50,
        top: 5,
        bottom: 5,
      ),
      child: SelectableText(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
    );
  }
}