import 'package:flutter/material.dart';
import 'ai_assistant_panel.dart';
import '../../core/app_localizations.dart';

class SmartAssistantPage extends StatelessWidget {
  final String username;
  final String role;

  const SmartAssistantPage({
    super.key,
    required this.username,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: AiAssistantPanel(
          username: username,
          role: role,
        ),
      ),
    );
  }
}
