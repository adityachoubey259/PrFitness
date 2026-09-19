import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/prfitness_launcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );

  runApp(
    const PrFitnessLauncher(),
  );
}