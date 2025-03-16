import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'amplifyconfiguration.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureAmplify();
  runApp(MyApp());
}

Future<void> configureAmplify() async {
  try {
    if (!Amplify.isConfigured) {
      await Amplify.addPlugin(AmplifyAuthCognito());
      await Amplify.configure(amplifyConfig);
      print("✅ Amplify successfully configured");
    }
  } catch (e) {
    print("❌ Error configuring Amplify: $e");
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Hub',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _accessToken;
  String? _userEmail;
  bool _isLoggedIn = false;
  List<dynamic> _playlists = [];
  final String clientId = '9b2fc2802d624dd2861d67f1f213a9d9';
  final String redirectUri = 'http://localhost:3000/';
  final String clientSecret = 'eb199c7d66a9494f9683197ee08fbe82';

  @override
  void initState() {
    super.initState();
    _handleAuthRedirect();
    _checkCurrentUser();
  }

  /// Check if the user is already signed in
  Future<void> _checkCurrentUser() async {
    try {
      AuthUser user = await Amplify.Auth.getCurrentUser();
      setState(() {
        _userEmail = user.username;
        _isLoggedIn = true;
      });
      print("✅ User is already signed in: $_userEmail");
    } catch (e) {
      print("❌ No user signed in");
    }
  }

  void _handleAuthRedirect() {
    final Uri uri = Uri.parse(Uri.base.toString());
    if (uri.queryParameters.containsKey('code')) {
      final String authCode = uri.queryParameters['code']!;
      print('Authorization Code: $authCode');
      exchangeCodeForToken(authCode);
    }
  }

  Future<void> loginToSpotify() async {
    final scopes = [
      'user-read-private',
      'user-read-email',
      'playlist-read-private',
      'playlist-read-collaborative',
      'user-modify-playback-state',
      'user-read-playback-state',
      'user-read-currently-playing'
    ].join('%20');

    final authUrl =
        'https://accounts.spotify.com/authorize'
        '?client_id=$clientId'
        '&response_type=code'
        '&redirect_uri=$redirectUri'
        '&scope=$scopes';

    web.window.location.href = authUrl;
  }

  Future<void> signInUser() async {
    try {
      print("🚀 Attempting AWS Cognito login...");
      SignInResult result = await Amplify.Auth.signInWithWebUI(provider: AuthProvider.cognito);

      if (result.isSignedIn) {
        AuthUser user = await Amplify.Auth.getCurrentUser();
        setState(() {
          _userEmail = user.username;
          _isLoggedIn = true;
        });
        print("✅ User signed in successfully: $_userEmail");
      } else {
        print("❌ Sign-in was not completed.");
      }
    } catch (e) {
      print("❌ Error signing in: $e");
    }
  }

  Future<void> signOutUser() async {
    try {
      await Amplify.Auth.signOut();
      setState(() {
        _userEmail = null;
        _isLoggedIn = false;
      });
      print("✅ User signed out");
    } catch (e) {
      print("❌ Error signing out: $e");
    }
  }

  Future<void> exchangeCodeForToken(String code) async {
    final response = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': 'Basic ' + base64Encode(utf8.encode('$clientId:$clientSecret')),
      },
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirectUri,
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _accessToken = data['access_token'];
      });
      print('🎵 Spotify Access Token: $_accessToken');
      fetchPlaylists();
    } else {
      print('❌ Error fetching token: ${response.body}');
    }
  }

  Future<void> fetchPlaylists() async {
    if (_accessToken == null) return;

    final response = await http.get(
      Uri.parse('https://api.spotify.com/v1/me/playlists'),
      headers: {
        'Authorization': 'Bearer $_accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _playlists = data['items'];
      });
      print('🎵 Fetched Playlists: $_playlists');
    } else {
      print('❌ Error fetching playlists: ${response.body}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Music Hub')), 
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _isLoggedIn
                ? Column(
                    children: [
                      Text("Welcome, $_userEmail"),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: signOutUser,
                        child: Text('Sign Out'),
                      ),
                    ],
                  )
                : ElevatedButton(
                    onPressed: signInUser,
                    child: Text('Sign In with AWS Cognito'),
                  ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: loginToSpotify,
              child: Text('Login to Spotify'),
            ),
            SizedBox(height: 20),
            _accessToken != null
                ? Column(
                    children: [
                      Text('Spotify Connected', style: TextStyle(color: Colors.green)),
                      ElevatedButton(
                        onPressed: fetchPlaylists,
                        child: Text('Fetch Playlists'),
                      ),
                    ],
                  )
                : Text('Not Connected', style: TextStyle(color: Colors.red)),
            SizedBox(height: 20),
            _playlists.isNotEmpty
                ? Expanded(
                    child: ListView.builder(
                      itemCount: _playlists.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(_playlists[index]['name']),
                          subtitle: Text('${_playlists[index]['tracks']['total']} tracks'),
                        );
                      },
                    ),
                  )
                : Container(),
          ],
        ),
      ),
    );
  }
}
