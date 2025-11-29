import 'package:flutter/material.dart';

import '../main_page.dart';

/// Legacy wrapper kept for backward compatibility with older routes.
/// Internally delegates to [MainPage].
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MainPage();
  }
}
