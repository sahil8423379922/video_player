import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:maxplay_video_player/components/videoplayer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class VideoExplorer extends StatefulWidget {
  final Directory initialDirectory;

  VideoExplorer({Key? key, Directory? directory})
    : initialDirectory = directory ?? Directory('/storage/emulated/0/'),
      super(key: key);

  @override
  _VideoExplorerState createState() => _VideoExplorerState();
}

class _VideoExplorerState extends State<VideoExplorer> {
  List<BannerAd> _ads = [];
  late Directory _currentDirectory;
  List<FileSystemEntity> _items = [];

  void _launchRateUs() async {
    const url = 'https://play.google.com/store/apps/details?id=com.example.app';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _shareApp() {
    Share.share(
      'Check out this awesome app: https://play.google.com/store/apps/details?id=com.example.app',
    );
  }

  @override
  void initState() {
    super.initState();
    _currentDirectory = widget.initialDirectory;
    print("Current Directory: ${_currentDirectory.path}");
    _requestPermissionAndLoadFiles();
    _loadAds();
  }

  void _loadAds() {
    int adCount = (_items.length / 8).floor();

    _ads.clear(); // Clear any previous ads

    for (int i = 0; i < adCount; i++) {
      BannerAd ad = BannerAd(
        adUnitId:
            'ca-app-pub-3940256099942544/6300978111', // Replace with real ID
        size: AdSize.banner,
        request: AdRequest(),
        listener: BannerAdListener(
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            print("Ad failed to load: $error");
          },
        ),
      )..load();

      _ads.add(ad);
    }
  }

  @override
  void dispose() {
    for (var ad in _ads) {
      ad.dispose();
    }
    super.dispose();
  }

  Future<void> _requestPermissionAndLoadFiles() async {
    if (Platform.isAndroid) {
      if (await _hasStoragePermission()) {
        _loadFiles();
      } else {
        print("Storage permission not granted");
      }
    } else {
      _loadFiles(); // Assume permission granted on other platforms
    }
  }

  Future<bool> _hasStoragePermission() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    if (sdkInt >= 30) {
      var status = await Permission.manageExternalStorage.status;

      if (status.isGranted) return true;

      status = await Permission.manageExternalStorage.request();

      if (status.isGranted) return true;

      if (status.isPermanentlyDenied) {
        await openAppSettings();
      }

      return false;
    } else {
      var status = await Permission.storage.status;

      if (status.isGranted) return true;

      status = await Permission.storage.request();

      if (status.isGranted) return true;

      if (status.isPermanentlyDenied) {
        await openAppSettings();
      }

      return false;
    }
  }

  void _loadFiles() {
    try {
      final items =
          _currentDirectory.listSync().where((e) {
            final name = e.path.split('/').last;
            if (name.startsWith('.')) return false;

            if (e is Directory) {
              return _containsVideoRecursively(e);
            }

            final ext = name.split('.').last.toLowerCase();
            return ['mp4', 'mkv', 'avi', 'mov'].contains(ext);
          }).toList();

      items.sort((a, b) {
        if (a is Directory && b is! Directory) return -1;
        if (a is! Directory && b is Directory) return 1;
        return a.path.compareTo(b.path);
      });

      setState(() {
        _items = items;
        _loadAds();
      });
    } catch (e) {
      print("Error loading files: $e");
    }
  }

  /// Recursively checks if a directory contains any video file
  bool _containsVideoRecursively(Directory dir) {
    try {
      for (var entity in dir.listSync(recursive: true, followLinks: false)) {
        if (entity is File) {
          final name = entity.path.split('/').last;
          final ext = name.split('.').last.toLowerCase();
          if (['mp4', 'mkv', 'avi', 'mov'].contains(ext)) {
            return true;
          }
        }
      }
    } catch (e) {
      print("Skipping directory ${dir.path} due to error: $e");
    }
    return false;
  }

  // void _loadFiles() {
  //   try {
  //     final items =
  //         _currentDirectory.listSync().where((e) {
  //           final name = e.path.split('/').last;
  //           if (name.startsWith('.')) return false; // hide hidden files
  //           if (e is Directory) return true;
  //           final ext = name.split('.').last.toLowerCase();
  //           return ['mp4', 'mkv', 'avi', 'mov'].contains(ext);
  //         }).toList();

  //     items.sort((a, b) {
  //       if (a is Directory && b is! Directory) return -1;
  //       if (a is! Directory && b is Directory) return 1;
  //       return a.path.compareTo(b.path);
  //     });

  //     setState(() {
  //       _items = items;
  //       _loadAds();
  //     });
  //   } catch (e) {
  //     print("Error loading files: $e");
  //   }
  // }

  void _navigateToDirectory(Directory dir) {
    setState(() {
      _currentDirectory = dir;
    });
    _loadFiles();
  }

  void _openVideoFile(File file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(videoFile: file),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_currentDirectory.path != '/storage/emulated/0/') {
          if (_currentDirectory.path == '/storage/emulated/0') {
            return true; // Allow default back action
          } else {
            _navigateToDirectory(_currentDirectory.parent);
            return false; // Prevent default back action
          }
        } else {
          return true;
        }

        // Allow default back action
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'MaxPlay Video Player',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.indigo,
          leading: Builder(
            builder: (context) {
              // Show back button if not at root, otherwise show menu button
              if (_currentDirectory.path != '/storage/emulated/0/') {
                if (_currentDirectory.path == '/storage/emulated/0') {
                  return IconButton(
                    icon: Icon(Icons.menu),
                    color: Colors.white,
                    onPressed: () {
                      Scaffold.of(
                        context,
                      ).openDrawer(); // This uses the correct context
                    },
                  );
                } else {
                  print("Current Directory: ${_currentDirectory.path}");
                  return IconButton(
                    color: Colors.white,
                    icon: Icon(Icons.arrow_back),
                    onPressed: () {
                      _navigateToDirectory(_currentDirectory.parent);
                    },
                  );
                }
              } else {
                return IconButton(
                  icon: Icon(Icons.menu),
                  color: Colors.white,
                  onPressed: () {
                    Scaffold.of(
                      context,
                    ).openDrawer(); // This uses the correct context
                  },
                );
              }
            },
          ),
        ),

        drawer: Drawer(
          child: Column(
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.indigo,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(2),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.video_library,
                        color: Colors.indigo,
                        size: 30,
                      ),
                    ),
                    SizedBox(width: 16),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'MaxPlay Video Player',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'HD, MP4, 4K,',
                          style: TextStyle(
                            fontSize: 18,

                            color: const Color.fromARGB(255, 255, 255, 255),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(Icons.info_outline, color: Colors.indigo),
                title: Text('About Us'),
                onTap: () {
                  Navigator.pop(context);
                  showAboutDialog(
                    context: context,
                    applicationName: 'MaxPlay Video Player',
                    applicationVersion: '1.0.0',
                    applicationIcon: Icon(
                      Icons.video_library,
                      color: Colors.indigo,
                    ),
                    children: [
                      Text(
                        'This app helps you explore and play videos from your device.',
                      ),
                    ],
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.star_rate, color: Colors.orange),
                title: Text('Rate Us'),
                onTap: () {
                  Navigator.pop(context);
                  _launchRateUs();
                },
              ),
              ListTile(
                leading: Icon(Icons.share, color: Colors.green),
                title: Text('Share App'),
                onTap: () {
                  Navigator.pop(context);
                  _shareApp();
                },
              ),
              Spacer(),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  '© 2025 MaxPlay Inc. All rights reserved.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),

        body: ListView.builder(
          itemCount:
              _items.length + (_items.length ~/ 5), // Add extra slots for ads
          itemBuilder: (context, index) {
            // Show ad after every 5 items
            if ((index + 1) % 9 == 0) {
              int adIndex = (index + 1) ~/ 9 - 1;
              if (adIndex < _ads.length) {
                final ad = _ads[adIndex];
                return Container(
                  alignment: Alignment.center,
                  width: ad.size.width.toDouble(),
                  height: ad.size.height.toDouble(),
                  child: AdWidget(ad: ad),
                );
              } else {
                return SizedBox.shrink(); // fallback
              }
            }

            // Adjust actual data index to account for ads
            final itemIndex = index - (index ~/ 6);
            final item = _items[itemIndex];
            final name = item.path.split('/').last;

            return ListTile(
              leading:
                  item is Directory
                      ? Icon(Icons.folder)
                      : Icon(Icons.video_file),
              title: Text(name),
              onTap: () {
                if (item is Directory) {
                  _navigateToDirectory(item);
                } else if (item is File) {
                  _openVideoFile(item);
                }
              },
            );
          },
        ),
      ),
    );
  }
}
