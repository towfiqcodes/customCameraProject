import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../../main.dart';
import 'components.dart';

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? controller;
  VideoPlayerController? videoController;

  File? _imageFile;
  File? _videoFile;
  XFile? file;

  // Initial values
  bool _isCameraInitialized = false;
  bool _isRearCameraSelected = true;
  bool _isVideoCameraSelected = true;
  bool _isRecordingInProgress = false;

  bool _isRecordingComplete = true;

  double _minAvailableExposureOffset = 0.0;
  double _maxAvailableExposureOffset = 0.0;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;

  // Current values
  double _currentZoomLevel = 1.0;
  double _currentExposureOffset = 0.0;
  FlashMode? _currentFlashMode;

  List<File> allFileList = [];
  final ImagePicker _picker = ImagePicker();

  Timer? _timer;
  var _start;

  void startTimer(int start) {
    _start = start;
    const oneSec = const Duration(seconds: 1);
    _timer = Timer.periodic(
      oneSec,
          (Timer timer) {
        if (_start == 0) {
          setState(() {
            restartTimer();
            stopVideoRecording();
            _isRecordingComplete = false;
          });
        } else {
          setState(() {
            _start--;
          });
        }
      },
    );
  }

  final resolutionPresets = ResolutionPreset.values;

  ResolutionPreset currentResolutionPreset = ResolutionPreset.high;

  void onImageButtonPressed(ImageSource source) async {
    file = await _picker.pickVideo(source: source);
    // int? idx = file?.path.indexOf(".mp4");
    setState(() {
      _videoFile = File(file!.path);
      _isRecordingInProgress = false;
      _startVideoPlayer(_videoFile!);
    });
    //  videoByts=await file!.readAsBytes();
  }

  Future<void> _startVideoPlayer(File videoFile) async {
    if (_videoFile != null) {
      videoController = VideoPlayerController.file(_videoFile!);
      await videoController!.initialize().then((_) {
        // Ensure the first frame is shown after the video is initialized,
        // even before the play button has been pressed.
        setState(() {});
      });
      await videoController!.setLooping(false);
      await videoController!.play();
    }
  }

  void restartTimer() {
    _timer?.cancel();
    startTimer(30);
  }

  Future<void> startVideoRecording() async {
    final CameraController? cameraController = controller;

    if (controller!.value.isRecordingVideo) {
      // A recording has already started, do nothing.
      return;
    }

    try {
      await cameraController!.startVideoRecording();
      setState(() {
        startTimer(30);
        _isRecordingInProgress = true;
        print(_isRecordingInProgress);
      });
    } on CameraException catch (e) {
      print('Error starting to record video: $e');
    }
  }

  Future<XFile?> stopVideoRecording() async {
    if (!controller!.value.isRecordingVideo) {
      // Recording is already is stopped state
      return null;
    }

    try {
      XFile file = await controller!.stopVideoRecording();

      setState(() {
        _timer?.cancel();
        _isRecordingInProgress = false;
      });
      return file;
    } on CameraException catch (e) {
      print('Error stopping video recording: $e');
      return null;
    }
  }

  Future<void> pauseVideoRecording() async {
    if (!controller!.value.isRecordingVideo) {
      // Video recording is not in progress
      return;
    }

    try {
      await controller!.pauseVideoRecording();
    } on CameraException catch (e) {
      print('Error pausing video recording: $e');
    }
  }

  Future<void> resumeVideoRecording() async {
    if (!controller!.value.isRecordingVideo) {
      // No video recording was in progress
      return;
    }

    try {
      await controller!.resumeVideoRecording();
    } on CameraException catch (e) {
      print('Error resuming video recording: $e');
    }
  }

  void resetCameraValues() async {
    _currentZoomLevel = 1.0;
    _currentExposureOffset = 0.0;
  }

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    final previousCameraController = controller;

    final CameraController cameraController = CameraController(
      cameraDescription,
      currentResolutionPreset,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await previousCameraController?.dispose();

    resetCameraValues();

    if (mounted) {
      setState(() {
        controller = cameraController;
      });
    }

    // Update UI if controller updated
    cameraController.addListener(() {
      if (mounted) setState(() {});
    });

    try {
      await cameraController.initialize();
      await Future.wait([
        cameraController
            .getMinExposureOffset()
            .then((value) => _minAvailableExposureOffset = value),
        cameraController
            .getMaxExposureOffset()
            .then((value) => _maxAvailableExposureOffset = value),
        // cameraController
        //     .getMaxZoomLevel()
        //     .then((value) => _maxAvailableZoom = value),
        // cameraController
        //     .getMinZoomLevel()
        //     .then((value) => _minAvailableZoom = value),
      ]);

      // _currentFlashMode = controller!.value.flashMode;
    } on CameraException catch (e) {
      print('Error initializing camera: $e');
    }

    if (mounted) {
      setState(() {
        _isCameraInitialized = controller!.value.isInitialized;
      });
    }
  }

  @override
  void initState() {
    // Hide the status bar in Android
    SystemChrome.setEnabledSystemUIOverlays([]);
    // Set and initialize the new camera
    onNewCameraSelected(cameras[0]);
    //  refreshAlreadyCapturedImages();
    super.initState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      onNewCameraSelected(cameraController.description);
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: Icon(
              Icons.clear,
              size: 35.0,
              color: Colors.black,
            ),
            onPressed: () => {setState(() {})},
          ),
          title: Container(
            child: Row(
              children: [],
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CustomButton.small(
                showProgressIndicator: false,
                onPressed: () {},
                text: "Done",
              ),
            ),
          ],
        ),
        backgroundColor: Colors.black,
        body: _isCameraInitialized
            ? Column(
          children: [
            AspectRatio(
              aspectRatio: 1 / controller!.value.aspectRatio,
              child: Stack(
                children: [
                  videoController != null &&
                      videoController!.value.isInitialized
                      ? Container(
                    margin: EdgeInsets.all(5),
                    child: Stack(children: <Widget>[
                      Center(
                        child: videoController!.value.isInitialized
                            ? SizedBox(
                          width: 500,
                          height: 500,
                          child:
                          VideoPlayer(videoController!),
                        )
                            : Container(),
                      ),
                      Center(
                        child: ButtonTheme(
                          height: 50.0,
                          minWidth: 10.0,
                          child: RaisedButton(
                            padding: EdgeInsets.all(10.0),
                            color: Colors.transparent,
                            textColor: Colors.white,
                            onPressed: () {
                              setState(() {
                                if (videoController!
                                    .value.isPlaying) {
                                  videoController?.pause();
                                } else {
                                  videoController?.play();
                                }
                              });
                            },
                            child: Icon(
                              videoController!.value.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              size: 50.0,
                            ),
                          ),
                        ),
                      )
                    ]),
                  )
                      : controller!.buildPreview(),
                  Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _isRecordingInProgress
                            ? Align(
                            alignment: Alignment.center,
                            child: Text(
                              "00:00:$_start",
                              style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 25),
                            ))
                            : SizedBox(),

                        // Spacer(),

                        // Expanded(
                        //   child: RotatedBox(
                        //     quarterTurns: 3,
                        //     child: Container(
                        //       height: 30,
                        //       child: Slider(
                        //         value: _currentExposureOffset,
                        //         min: _minAvailableExposureOffset,
                        //         max: _maxAvailableExposureOffset,
                        //         activeColor: Colors.white,
                        //         inactiveColor: Colors.white30,
                        //         onChanged: (value) async {
                        //           setState(() {
                        //             _currentExposureOffset = value;
                        //           });
                        //           await controller!
                        //               .setExposureOffset(value);
                        //         },
                        //       ),
                        //     ),
                        //   ),
                        // ),
                        // Row(
                        //   children: [
                        //     // Expanded(
                        //     //   child: Slider(
                        //     //     value: _currentZoomLevel,
                        //     //     min: _minAvailableZoom,
                        //     //     max: _maxAvailableZoom,
                        //     //     activeColor: Colors.white,
                        //     //     inactiveColor: Colors.white30,
                        //     //     onChanged: (value) async {
                        //     //       setState(() {
                        //     //         _currentZoomLevel = value;
                        //     //       });
                        //     //       await controller!.setZoomLevel(value);
                        //     //     },
                        //     //   ),
                        //     // ),
                        //     Padding(
                        //       padding: const EdgeInsets.only(right: 8.0),
                        //       child: Container(
                        //         decoration: BoxDecoration(
                        //           color: Colors.black87,
                        //           borderRadius:
                        //               BorderRadius.circular(10.0),
                        //         ),
                        //         child: Padding(
                        //           padding: const EdgeInsets.all(8.0),
                        //           child: Text(
                        //             _currentZoomLevel.toStringAsFixed(1) +
                        //                 'x',
                        //             style: TextStyle(color: Colors.white),
                        //           ),
                        //         ),
                        //       ),
                        //     ),
                        //   ],
                        // ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              // mainAxisAlignment:
                              //     MainAxisAlignment.spaceBetween,
                              children: [
                                InkWell(
                                  onTap: () {
                                    onImageButtonPressed(
                                        ImageSource.gallery);
                                  },
                                  child: Container(
                                    height: 50,
                                    width: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius:
                                      BorderRadius.circular(30.0),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      CupertinoIcons.photo_on_rectangle,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                ),

                                // InkWell(
                                //   onTap: _isRecordingInProgress
                                //       ? () async {
                                //     if (controller!
                                //         .value.isRecordingPaused) {
                                //       await resumeVideoRecording();
                                //     } else {
                                //       await pauseVideoRecording();
                                //     }
                                //   }
                                //       : () {
                                //     setState(() {
                                //       _isCameraInitialized = false;
                                //     });
                                //     onNewCameraSelected(cameras[
                                //     _isRearCameraSelected ? 1 : 0]);
                                //     setState(() {
                                //       _isRearCameraSelected = !_isRearCameraSelected;
                                //     });
                                //   },
                                //   child: Stack(
                                //     alignment: Alignment.center,
                                //     children: [
                                //
                                //       _isRecordingInProgress
                                //           ? controller!.value.isRecordingPaused
                                //           ? Icon(
                                //         Icons.play_arrow,
                                //         color: Colors.white,
                                //         size: 30,
                                //       ) : Icon(
                                //         Icons.pause,
                                //         color: Colors.white,
                                //         size: 30,
                                //       ) : Icon(
                                //         _isRearCameraSelected
                                //             ? Icons.camera_front
                                //             : Icons.camera_rear,
                                //         color: Colors.white,
                                //         size: 30,
                                //       ),
                                //     ],
                                //   ),
                                // ),
                                InkWell(
                                  onTap: () async {
                                    if (_isRecordingInProgress) {
                                      XFile? rawVideo =
                                      await stopVideoRecording();
                                      File videoFile =
                                      File(rawVideo!.path);

                                      int currentUnix = DateTime.now()
                                          .millisecondsSinceEpoch;

                                      final directory =
                                      await getApplicationDocumentsDirectory();

                                      String fileFormat =
                                          videoFile.path.split('.').last;
                                      _videoFile = await videoFile.copy(
                                        '${directory.path}/$currentUnix.$fileFormat',
                                      );

                                      _startVideoPlayer(_videoFile!);
                                    } else {
                                      await startVideoRecording();
                                    }
                                  },
                                  child:

                                  videoController != null?SizedBox():Stack(
                                    alignment:
                                    AlignmentDirectional.bottomEnd,
                                    children: [
                                      Icon(
                                        Icons.circle,
                                        color: _isVideoCameraSelected
                                            ? Colors.white
                                            : Colors.white38,
                                        size: 80,
                                      ),
                                      Icon(
                                        Icons.circle,
                                        color: _isVideoCameraSelected
                                            ? Colors.red
                                            : Colors.white,
                                        size: 50,
                                      ),
                                      _isVideoCameraSelected &&
                                          _isRecordingInProgress
                                          ? Icon(
                                        Icons.stop_rounded,
                                        color: Colors.white,
                                        size: 32,
                                      )
                                          : Container(),
                                    ],
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _isCameraInitialized = false;
                                    });
                                    onNewCameraSelected(cameras[
                                    _isRearCameraSelected ? 1 : 0]);
                                    setState(() {
                                      _isRearCameraSelected =
                                      !_isRearCameraSelected;
                                    });
                                  },
                                  child: Icon(
                                    Icons.camera_front,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                                // Container(
                                //   width: 40,
                                //   height: 40,
                                //   decoration: BoxDecoration(
                                //     color: Colors.black,
                                //     borderRadius: BorderRadius.circular(20.0),
                                //     border: Border.all(
                                //       color: Colors.white,
                                //       width: 2,
                                //     ),
                                //   ),
                                //   child: _isVideoCameraSelected &&
                                //           _isRecordingInProgress
                                //       ? IconButton(
                                //           onPressed: () {},
                                //           icon: Center(
                                //               child: Icon(
                                //             Icons.check_outlined,
                                //             color: Colors.white,
                                //           )))
                                //       : SizedBox(),
                                // )
                                // InkWell(
                                //   onTap:
                                //       _imageFile != null || _videoFile != null
                                //           ? () {
                                //               Navigator.of(context).push(
                                //                 MaterialPageRoute(
                                //                   builder: (context) =>
                                //                       PreviewScreen(
                                //                     imageFile: _imageFile!,
                                //                     fileList: allFileList,
                                //                   ),
                                //                 ),
                                //               );
                                //             }
                                //           : null,
                                //   child: Container(
                                //     width: 60,
                                //     height: 60,
                                //     decoration: BoxDecoration(
                                //       color: Colors.black,
                                //       borderRadius:
                                //           BorderRadius.circular(10.0),
                                //       border: Border.all(
                                //         color: Colors.white,
                                //         width: 2,
                                //       ),
                                //       image: _imageFile != null
                                //           ? DecorationImage(
                                //               image: FileImage(_imageFile!),
                                //               fit: BoxFit.cover,
                                //             )
                                //           : null,
                                //     ),
                                //     child: videoController != null &&
                                //             videoController!
                                //                 .value.isInitialized
                                //         ? ClipRRect(
                                //             borderRadius:
                                //                 BorderRadius.circular(8.0),
                                //             child: AspectRatio(
                                //               aspectRatio: videoController!
                                //                   .value.aspectRatio,
                                //               child: VideoPlayer(
                                //                   videoController!),
                                //             ),
                                //           )
                                //         : Container(),
                                //   ),
                                // ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        )
            : Center(
          child: Text(
            'LOADING',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
