import 'package:flutter/material.dart';
import '../sign_up_login_screen/sign_up_login_screen.dart';

class ProviderLoginScreen extends StatelessWidget {
  const ProviderLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SignUpLoginScreen(fixedRole: 'provider');
  }
}
