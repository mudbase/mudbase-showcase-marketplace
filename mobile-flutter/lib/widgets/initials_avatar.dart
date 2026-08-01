import 'package:flutter/material.dart';

import '../core/formatters.dart';

/// Small initials-based avatar chip for a message sender - mirrors the
/// reference web app's message thread avatar (`components/messages/
/// MessageThread.tsx`), which is also initials-based (there is no profile
/// picture anywhere in this data model).
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({required this.name, this.radius = 14, super.key});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      child: Text(initials(name), style: TextStyle(fontSize: radius * 0.8)),
    );
  }
}
