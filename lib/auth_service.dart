import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';

class AuthService {
  Future<bool> login(String username, String password) async {
    var user = await DatabaseHelper.instance.getUser(username, password);
    if (user != null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', username);
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
  }

  Future<bool> isLoggedIn() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('username') != null;
  }
}