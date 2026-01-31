# APIs Used in This Repository

## Total: **8 External APIs/Services**

### 1. **Firebase** (Multiple Services)
- **Firebase Authentication** - User login/signup
- **Cloud Firestore** - Database for reviews, user preferences, music data
- **Firebase Realtime Database** - Real-time data sync
- **Firebase Hosting** - Web app deployment
- **Usage**: Core backend infrastructure
- **Config**: `lib/utils/firebase_options.dart`

### 2. **Spotify Web API**
- **Purpose**: Music data, search, recommendations, album art
- **Endpoints Used**:
  - Search tracks/albums/artists
  - Get playlists
  - Get track details
  - Get album images
  - Get artist information
- **Usage Locations**:
  - `lib/Api/apis.dart` - Multiple Spotify functions
  - `lib/MusicPreferences/musicRecommendationService.dart` - Album art fetching
  - `lib/ui/screens/addReview/reviewSheetContentForm.dart` - Track search
  - `lib/DiscoveryTab/` - Track discovery and recommendations
- **Credentials**: `clientId`, `clientSecret` in `lib/Api/api_key.dart`

### 3. **OpenAI API**
- **Purpose**: AI-powered music recommendations
- **Model**: GPT-3.5-turbo
- **Endpoint**: `https://api.openai.com/v1/chat/completions`
- **Usage**: Generates personalized music recommendations based on user preferences
- **Location**: `lib/MusicPreferences/musicRecommendationService.dart`
- **Credentials**: `openAIKey` in `lib/Api/api_key.dart`

### 4. **Unsplash API**
- **Purpose**: Fetch vinyl/album art images
- **Base URL**: `https://api.unsplash.com`
- **Usage**: Alternative album art when Spotify images aren't available
- **Location**: `lib/Api/Photos/Unsplash.dart`
- **Credentials**: `unsplashAccessKey`, `unsplashSecret` in `lib/Api/api_key.dart`

### 5. **NewsAPI**
- **Purpose**: Fetch music-related news articles
- **Base URL**: `https://newsapi.org/v2/everything`
- **Usage**: Display music news in the app
- **Location**: `lib/News/News.dart`
- **Credentials**: `newsAPIKey` in `lib/Api/api_key.dart`

### 6. **MusicBrainz API**
- **Purpose**: Album metadata, release information, genres
- **Base URL**: `https://musicbrainz.org/ws/2`
- **Usage**: Enriching album data with release dates, genres, and metadata
- **Location**: `lib/services/get_album_service.dart`
- **Endpoints Used**:
  - `/release-group` - Search albums by year/genre
  - `/recording` - Search tracks
- **Note**: No API key required, but requires User-Agent header

### 7. **MockAPI.io**
- **Purpose**: Mock data for testing/development
- **Base URL**: `https://66d638b1f5859a704268af2d.mockapi.io/test/v1/usercomments`
- **Usage**: Mock user comments for development
- **Location**: `lib/Api/apis.dart`

---

## API Key Summary

All API keys are stored in: `lib/Api/api_key.dart`

**Keys Required:**
1. Firebase API Key (`firebaseOptionsKey`)
2. Spotify Client ID & Secret (`clientId`, `clientSecret`)
3. OpenAI API Key (`openAIKey`)
4. Unsplash Access Key & Secret (`unsplashAccessKey`, `unsplashSecret`)
5. NewsAPI Key (`newsAPIKey`)
6. MusicBrainz (No key required, but User-Agent header needed)

---

## API Usage by Feature

### Music Discovery
- **Spotify API** - Track search, recommendations, album art
- **OpenAI API** - AI-powered recommendations

### User Data
- **Firebase** - User authentication, reviews, preferences storage

### Content
- **NewsAPI** - Music news articles
- **Unsplash** - Album art images
- **MusicBrainz** - Album metadata, release dates, genres

### Development
- **MockAPI** - Test data

---

## Rate Limits & Considerations

- **Spotify API**: Rate limits apply (check Spotify Developer Dashboard)
- **OpenAI API**: Pay-per-use, rate limits based on tier
- **NewsAPI**: Free tier has rate limits
- **Unsplash**: Rate limits apply (check Unsplash API docs)
- **Firebase**: Usage-based pricing after free tier

---

## Security Note

⚠️ **Important**: API keys are currently hardcoded in `api_key.dart`. For production:
- Move keys to environment variables
- Use Firebase Functions or backend proxy for sensitive keys
- Never commit keys to public repositories
