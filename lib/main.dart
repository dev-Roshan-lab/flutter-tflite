import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'package:tflite/tflite.dart';



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  // Get a specific camera from the list of available cameras.
  final firstCamera = cameras.first;// get the first camera or back camera
  runApp(MaterialApp(
    theme: ThemeData.dark(),
    home: Tensorflow(
      camera : firstCamera,
    ),
  ));
}

class Tensorflow extends StatefulWidget {

  final CameraDescription camera;

  const Tensorflow({
    Key key,
    @required this.camera,
  }) : super(key: key);

  @override
  _TensorflowState createState() => _TensorflowState();
}

class _TensorflowState extends State<Tensorflow> {
  CameraController _controller;
  Future<void> _initializeControllerFuture;
  //bool _cameraInitialized = false;
  List _outputs;
  File _image;
  bool _loading = false;
  bool _captured = false;
  String pic;

  @override
  void initState() {
    super.initState();
    _loading = true;
    _controller = CameraController(
      // Get a specific camera from the list of available cameras.
      widget.camera,
      // Define the resolution to use.
      ResolutionPreset.high,
    );

    // Next, initialize the controller. This returns a Future.
    _initializeControllerFuture = _controller.initialize();
    loadModel().then((value) {
      setState(() {
        _loading = false;
      });
    });
  }


  loadModel() async {
    await Tflite.loadModel(
      model: "asset/model.tflite",
      labels: "asset/fruit.txt",
      numThreads: 1,
    );
  }
  classifyImage(String imgpath) async {
    var output = await Tflite.runModelOnImage(
        path: imgpath,
        imageMean: 0.0,
        imageStd: 255.0,
        numResults: 2,
        threshold: 0.2,
        asynch: true
    );
    setState(() {
      _loading = false;
      _outputs = output;
    });
    print(_outputs);
    print(_outputs[0]["label"]);
  }

  @override //https://stackoverflow.com/questions/60374935/flutter-camera-disconnect-exception-when-other-camera-apps-are-opened
  void resume(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller != null
          ? _initializeControllerFuture = _controller.initialize()
          : null; //on pause camera is disposed, so we need to call again "issue is only for android"
    }
  }

  @override
  void dispose() {
    Tflite.close();
    _controller?.dispose();
    super.dispose();
  }
  //function for picking an image from gallery
  /*pickImage() async {
    var image = await ImagePicker.pickImage(source: ImageSource.gallery);
    if (image == null) return null;
    setState(() {
      _loading = true;
      _image = image;
    });
    if (_image.length != 0) {
      classifyImage(_image);
    } else { print('No outputs');}
  }*/

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        tooltip: 'Pick Image',
        onPressed: () async {
          try {

            await _initializeControllerFuture;
            final path = join(

              (await getTemporaryDirectory()).path,
              '${DateTime.now()}.png',
            );//get the cached image location
            //var image = await _controller.takePicture(path);
            classifyImage(path);
            setState(() {
              _captured = true;
              pic = path;
            });
            
          } catch (e) {print(e);}
        },
        child: Icon(Icons.camera,
          size: 20,
          color: Colors.white,
        ),
        backgroundColor: Colors.greenAccent,
      ),

      //use a terniary operator to load image if captured by pressinf the fab button
      body: _captured ? Container(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.file(File(pic)),
          ],
        ),
      ) : FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          final size = MediaQuery.of(context).size;
          final deviceRatio = size.width / size.height;
          if (snapshot.connectionState == ConnectionState.done) {
            // If the Future is complete, display the preview.
            return Transform.scale(
              scale: _controller.value.aspectRatio / deviceRatio,
              child: Center(
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: CameraPreview(_controller),
                ),
              ),
            );
          } else {
            // Otherwise, display a loading indicator.
            return Center(child: CircularProgressIndicator());
          }
        },
      ),

    );
  }
}
