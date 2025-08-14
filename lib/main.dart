import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data.dart';
import 'screens/dashboard.dart';
import 'screens/gate.dart';
import 'screens/phone_lookup.dart';
import 'screens/sign_in.dart';
import 'screens/walkin.dart';
import 'theme.dart';

final server = DemoServer();
final device = Device(server);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  runApp(const GatepassApp());
}

class GatepassApp extends StatelessWidget {
  const GatepassApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Gateway',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    initialRoute: '/',
    routes: {
      '/': (_) => const SignInScreen(),
      '/gate': (_) => const GateScreen(),
      '/phone': (_) => const PhoneLookupScreen(),
      '/desk': (_) => const WalkinScreen(),
      '/dashboard': (_) => const DashboardScreen(),
    },
  );
}
