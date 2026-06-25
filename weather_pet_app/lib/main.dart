import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const WeatherPetApp());
}

class WeatherPetApp extends StatelessWidget {
  const WeatherPetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '天气小人',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'NotoSansSC',
      ),
      home: const HomeScreen(),
    );
  }
}
