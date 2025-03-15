import 'dart:html' as html;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
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
  List<dynamic> _playlists = [];
  final String clientId = '9b2fc2802d624dd2861d67f1f213a9d9';
  final String redirectUri = 'http://localhost:3000/'; // Match Spotify Settings
  final String clientSecret = 'eb199c7d66a9494f9683197ee08fbe82';

  @override
  void initState() {
    super.initState();
    _handleAuthRedirect();
  }

  /// Detects if the browser redirected with an authorization code
  void _handleAuthRedirect() {
    final Uri uri = Uri.parse(html.window.location.href);
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
    ].join('%20'); // URL encoding

    final authUrl =
        'https://accounts.spotify.com/authorize'
        '?client_id=$clientId'
        '&response_type=code'
        '&redirect_uri=$redirectUri'
        '&scope=$scopes';

    // Redirect user to Spotify login page
    html.window.location.href = authUrl;
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
        'redirect_uri': redirectUri, // Must match registered URL
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _accessToken = data['access_token'];
      });
      print('Spotify Access Token: $_accessToken');
      fetchPlaylists();
    } else {
      print('Error fetching token: ${response.body}');
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
      print('Fetched Playlists: $_playlists');
    } else {
      print('Error fetching playlists: ${response.body}');
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
                : Container(),
          ],
        ),
      ),
    );
  }
}
