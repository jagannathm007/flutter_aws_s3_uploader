import 'dart:developer';
import 'dart:io';
import 'package:aws3_bucket/aws3_bucket.dart';
import 'package:aws3_bucket/aws_region.dart';
import 'package:aws3_bucket/iam_crediental.dart';
import 'package:aws3_bucket/image_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

Future<void> main() async {
  runApp(const MyApp());
  await Permission.camera.request();
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aws Uploader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List awsImages = [];
  bool isLoading = false;

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      File image = File(pickedFile.path);
      List<int>? compressedData = await FlutterImageCompress.compressWithFile(image.path, quality: 50);
      if (compressedData != null) {
        await image.writeAsBytes(compressedData);
        awsImages.add({"path": "", "file": image, "isLoading": true});
        setState(() {});
        int lastIndex = awsImages.length - 1;
        uploadToAWS(image, lastIndex).then((object) {
          if (object["path"] != null) {
            awsImages[object["index"]]["path"] = object["path"];
            awsImages[object["index"]]["isLoading"] = false;
            setState(() {});
          } else {
            awsImages.removeAt(object["index"]);
            setState(() {});
          }
        });
      }
    }
  }

  Future<dynamic> uploadToAWS(File file, int index) async {
    var uuid = const Uuid();
    IAMCrediental iamCrediental = IAMCrediental(
      secretId: "",
      secretKey: "",
    );
    ImageData imageData = ImageData(
      "${uuid.v1()}.${file.path.split(".").last}",
      file.path,
      uniqueId: uuid.v1(),
      imageUploadFolder: "testing",
    );

    try {
      String? awsImage = await Aws3Bucket.upload(
        "",
        AwsRegion.US_EAST_1,
        AwsRegion.US_EAST_1,
        imageData,
        iamCrediental,
      );
      return {"index": index, "path": awsImage};
    } catch (err) {
      log("Please re-try to upload images!");
      return {"index": index, "path": null};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aws Uploader'),
        actions: [
          IconButton(
            onPressed: () => _pickImage(),
            icon: const Icon(Icons.camera),
          ),
        ],
      ),
      body: Column(
        children: [
          const Text("Aws Images"),
          const SizedBox(height: 10),
          Center(
            child: Wrap(
              children: [
                ...awsImages.map(
                  (e) => Container(
                    padding: const EdgeInsets.all(8.0),
                    width: 80,
                    height: 80,
                    child: Stack(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: e["path"] != ""
                                ? Image.file(
                                    e["file"],
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, url, error) => const SizedBox(
                                      width: 25,
                                      height: 25,
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                : const SizedBox(
                                    height: 60,
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                          ),
                        ),
                        if (e["path"] != "")
                          Align(
                            alignment: Alignment.topRight,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 15,
                              ),
                            ),
                          )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...awsImages.map((v) => v["path"]).toList().map((v) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: Text(v.toString(), textAlign: TextAlign.center),
            );
          })
        ],
      ),
    );
  }
}
