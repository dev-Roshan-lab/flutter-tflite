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
  final firstCamera = cameras.first;
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
            );
            var image = await _controller.takePicture(path);
            classifyImage(path);
            setState(() {
              _captured = true;
              pic = path;
            });
            /*Navigator.push(

              context,
              MaterialPageRoute(
                builder: (context) => DisplayPictureScreen(imagePath: path),
              ),

            );*/
          } catch (e) {print(e);}
        },
        child: Icon(Icons.camera,
          size: 20,
          color: Colors.white,
        ),
        backgroundColor: Colors.greenAccent,
      ),

      /*body: Container(
        color: Colors.white,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _loading ? Container(
              height: 300,
              width: 300,
            ):
            Container(
              margin: EdgeInsets.all(20),
              width: MediaQuery.of(context).size.width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _image == null ? Container() : Image.file(_image),
                  SizedBox(
                    height: 20,
                  ),
                  _image == null ? Container() : _outputs != null ?
                  Text(_outputs[0]["label"],style: TextStyle(color: Colors.black,fontSize: 20),
                  ) : Container(child: Text(""))
                ],
              ),
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.01,
            ),
            FloatingActionButton(
              tooltip: 'Pick Image',
              onPressed: pickImage,
              child: Icon(Icons.add_a_photo,
                size: 20,
                color: Colors.white,
              ),
              backgroundColor: Colors.amber,
            ),
          ],
        ),
      ),*/

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
class DisplayPictureScreen extends StatelessWidget {
  final String imagePath;
  final Map value;
  const DisplayPictureScreen({Key key, this.imagePath, this.value}) : super(key: key);


  @override

  Widget build(BuildContext context) {
    return Scaffold(
      /*appBar: AppBar(title: Text(value[0]["label"],style: TextStyle(color: Colors.black,fontSize: 20),
      )),*/
      // The image is stored as a file on the device. Use the `Image.file`
      // constructor with the given path to display the image.
      body: Column(
        children: [
          Image.file(File(imagePath)),
          Text(value[0]["labels"])

        ],
      ),

    );
  }
}