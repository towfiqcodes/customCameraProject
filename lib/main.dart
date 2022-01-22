import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:video_camera_project/camera_screen.dart';
List<CameraDescription> cameras = [];

Future<void> main() async {
  // Fetch the available cameras before initializing the app.
  try {
    WidgetsFlutterBinding.ensureInitialized();
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Error in fetching the cameras: $e');
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      color: Colors.white,
      // theme: ThemeData(
      //   primarySwatch: Colors.white10,
      // ),
      debugShowCheckedModeBanner: false,
      home: CameraScreen(),
    );
  }
}
