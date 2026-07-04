import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PermissionService 
{
    Future<PermissionStatus> getStatus (Permission permission)async 
   {
     return await permission.status ; //Function used to check the status of the permission 
   }

    static Future<PermissionStatus> requestStoragePermission() async {
    
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkVersion = androidInfo.version.sdkInt;

    Permission storagePermission = sdkVersion >= 33 
        ? Permission.audio 
        : Permission.storage;

    return await storagePermission.request();
  }
    static Future<PermissionStatus> requestNotificationPermission() async {
    
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkVersion = androidInfo.version.sdkInt;

    // Notifications are automatically granted on Android 12 and below
    if (sdkVersion < 33) {
      return PermissionStatus.granted;
    }

    return await Permission.notification.request();
  }

   Future<void> openSettings() async
   {
     await openAppSettings(); // Function to open the settings page in case of permission permanently denied
   }
}