import 'package:flutter/material.dart';
import '../services/google_auth_service.dart';

class GoogleAuthBadge extends StatefulWidget {
  const GoogleAuthBadge({super.key});
  @override
  State<GoogleAuthBadge> createState() => _GoogleAuthBadgeState();
}

class _GoogleAuthBadgeState extends State<GoogleAuthBadge> {
  bool _signedIn = false;
  String? _email;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final email = await GoogleAuthService.instance.getEmail();
    if (mounted) setState(() {
      _signedIn = email != null && email.isNotEmpty;
      _email = email;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_signedIn && _email != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Google連携済み: $_email'),
            duration: const Duration(seconds: 2),
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Google未連携 - 設定画面からログインできます'),
            duration: Duration(seconds: 2),
          ));
        }
      },
      child: Tooltip(
        message: _signedIn ? 'Google連携済み' : 'Google未連携',
        child: Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(left: 4, right: 4),
          decoration: BoxDecoration(
            color: _signedIn ? const Color(0xFF34A853) : Colors.grey.shade400,
            shape: BoxShape.circle,
            boxShadow: _signedIn
                ? [BoxShadow(color: const Color(0xFF34A853).withValues(alpha: 0.4), blurRadius: 4)]
                : null,
          ),
        ),
      ),
    );
  }
}
