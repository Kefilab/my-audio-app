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
      await Amplify.configure(amplifyconfig);
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
  final String redirectUri = 'https://main.d33boiz7wmudx.amplifyapp.com/';
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
      'user-read-currently-playing',
      'app-remote-control',
      'streaming'
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

  Future<void> playPlaylist(String playlistId) async {
  if (_accessToken == null) return;

  // Step 1: Check for an active device
  final deviceResponse = await http.get(
    Uri.parse('https://api.spotify.com/v1/me/player/devices'),
    headers: {
      'Authorization': 'Bearer $_accessToken',
    },
  );

  if (deviceResponse.statusCode == 200) {
    final deviceData = json.decode(deviceResponse.body);
    if (deviceData['devices'].isEmpty) {
      print('No active Spotify device found. Please open Spotify on a device.');
      return;
    }

    String activeDeviceId = deviceData['devices'][0]['id']; // Get first available device

    // Step 2: Fetch the first track from the playlist
    final response = await http.get(
      Uri.parse('https://api.spotify.com/v1/playlists/$playlistId/tracks'),
      headers: {
        'Authorization': 'Bearer $_accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['items'].isNotEmpty) {
        String firstTrackUri = data['items'][0]['track']['uri'];
        print('Playing first track: $firstTrackUri');

        // Step 3: Send playback request to the active device
        final playResponse = await http.put(
          Uri.parse('https://api.spotify.com/v1/me/player/play?device_id=$activeDeviceId'),
          headers: {
            'Authorization': 'Bearer $_accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            "uris": [firstTrackUri]
          }),
        );

        if (playResponse.statusCode == 204) {
          print('Track is playing on device $activeDeviceId');
        } else {
          print('Error playing track: ${playResponse.body}');
        }
      } else {
        print('Playlist is empty');
      }
    } else {
      print('Error fetching playlist tracks: ${response.body}');
    }
  } else {
    print('Error fetching active devices: ${deviceResponse.body}');
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
                    Text("Welcome, ${_userEmail ?? 'Guest'}", 
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),

                    // Logout Button
                    ElevatedButton(
                      onPressed: signOutUser,
                      child: Text('Sign Out'),
                    ),

                    SizedBox(height: 20),
                    Text("Spotify Authentication", 
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),

                    // Spotify Login Button
                    _accessToken == null
                        ? ElevatedButton(
                            onPressed: loginToSpotify,
                            child: Text('Login to Spotify'),
                          )
                        : Column(
                            children: [
                              Text('🎵 Spotify Connected', style: TextStyle(color: Colors.green)),
                              ElevatedButton(
                                onPressed: fetchPlaylists,
                                child: Text('Fetch Playlists'),
                              ),
                            ],
                          ),
                  ],
                )
              : ElevatedButton(
                  onPressed: signInUser,
                  child: Text('Sign In with AWS Cognito'),
                ),

          SizedBox(height: 20),

          // Playlists Section
          (_playlists.isNotEmpty)
              ? Expanded(
                  child: ListView.builder(
                    itemCount: _playlists.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(_playlists[index]['name']),
                        subtitle: Text('${_playlists[index]['tracks']['total']} tracks'),
                        trailing: IconButton(
                          icon: Icon(Icons.play_arrow),
                            onPressed: () {
                              playPlaylist(_playlists[index]['id']); // Play first track from playlist
                          },
                        ),
                      );
                    },
                  ),
                )
              : (_isLoggedIn && _accessToken != null)
                  ? Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        "No playlists found. Try fetching them.",
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : Container(),
        ],
      ),
    ),
  );
}
}
