import 'package:permission_handler/permission_handler.dart';

class PermissionService 
{
   Future<PermissionStatus> getStatus (Permission permission)async 
   {
     return await permission.status ; //Function used to check the status of the permission 
   }

   Future <PermissionStatus> requestAccess(Permission permission) async
   {
    return await permission.request(); //Function to request the status in case of permission denied
   }

   Future<void> openSettings() async
   {
     await openAppSettings(); // Function to open the settings page in case of permission permanently denied
   }
}