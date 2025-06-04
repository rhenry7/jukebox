import 'dart:convert';
import 'package:http/http.dart' as http;

// Token Response Model
class SpotifyToken {
  final String accessToken;
  final int expiresIn;
  final String tokenType;

  SpotifyToken({
    required this.accessToken,
    required this.expiresIn,
    required this.tokenType,
  });

  factory SpotifyToken.fromJson(Map<String, dynamic> json) {
    return SpotifyToken(
      accessToken: json['access_token'],
      expiresIn: json['expires_in'],
      tokenType: json['token_type'],
    );
  }
}

// Function to get Spotify access token using Client Credentials flow
Future<String> getSpotifyAccessToken({
  required String clientId,
  required String clientSecret,
}) async {
  // Encode credentials in base64
  final credentials = base64Encode(utf8.encode('$clientId:$clientSecret'));

  final uri = Uri.https('accounts.spotify.com', '/api/token');

  final response = await http.post(
    uri,
    headers: {
      'Authorization': 'Basic $credentials',
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: {
      'grant_type': 'client_credentials',
    },
  );

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final token = SpotifyToken.fromJson(data);
    return token.accessToken;
  } else {
    throw Exception('Failed to get access token: ${response.body}');
  }
}

// Enhanced version with token caching and automatic refresh
class SpotifyTokenManager {
  String? _accessToken;
  DateTime? _expiryTime;
  final String clientId;
  final String clientSecret;

  SpotifyTokenManager({
    required this.clientId,
    required this.clientSecret,
  });

  Future<String> getValidAccessToken() async {
    // Check if we have a valid token
    if (_accessToken != null &&
        _expiryTime != null &&
        DateTime.now().isBefore(_expiryTime!)) {
      return _accessToken!;
    }

    // Get new token
    final credentials = base64Encode(utf8.encode('$clientId:$clientSecret'));
    final uri = Uri.https('accounts.spotify.com', '/api/token');

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Basic $credentials',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'client_credentials',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final token = SpotifyToken.fromJson(data);

      // Cache the token
      _accessToken = token.accessToken;
      _expiryTime = DateTime.now().add(
          Duration(seconds: token.expiresIn - 60)); // Refresh 1 minute early

      return _accessToken!;
    } else {
      throw Exception('Failed to get access token: ${response.body}');
    }
  }
}
