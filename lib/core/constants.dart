/**
 * SAARTHI Flutter App - Constants
 * Central configuration and constants
 */

class AppConstants {
  // API Configuration
  static const String baseUrl = 'https://devloperwala.in/saarthi';
  static const String apiBaseUrl = '$baseUrl/api';
  
  // API Endpoints
  static const String loginEndpoint = '/auth/login.php';
  static const String registerEndpoint = '/auth/register.php';
  static const String sensorDataEndpoint = '/device/postSensorData.php';
  static const String latestSensorDataEndpoint = '/device/getLatestSensorData.php';
  static const String locationUpdateEndpoint = '/location/update.php';
  static const String childDashboardEndpoint = '/parent/childDashboardData.php';
  static const String listChildrenEndpoint = '/parent/listChildren.php';
  static const String listAvailableChildrenEndpoint = '/parent/listAvailableChildren.php';
  static const String addChildEndpoint = '/parent/addChild.php';
  static const String createSafeZoneEndpoint = '/parent/createSafeZone.php';
  static const String createTripEndpoint = '/parent/createTrip.php';
  static const String generateDeviceTokenEndpoint = '/device/generateToken.php';
  static const String deviceAuthenticateEndpoint = '/device/authenticate.php';
  static const String uploadAudioEndpoint = '/device/uploadAudio.php';
  static const String getEmergencyContactsEndpoint = '/user/getEmergencyContacts.php';
  static const String saveEmergencyContactEndpoint = '/user/saveEmergencyContact.php';
  static const String deleteEmergencyContactEndpoint = '/user/deleteEmergencyContact.php';
  
  // User Roles
  static const String roleUser = 'USER';
  static const String roleParent = 'PARENT';
  static const String roleAdmin = 'ADMIN';
  
  // Event Types
  static const String eventSOSTouch = 'SOS_TOUCH';
  static const String eventObstacleAlert = 'OBSTACLE_ALERT';
  static const String eventLoudSoundAlert = 'LOUD_SOUND_ALERT';
  static const String eventManualSOS = 'MANUAL_SOS';
  static const String eventGeofenceBreach = 'GEOFENCE_BREACH';
  static const String eventTripDelay = 'TRIP_DELAY';
  
  // Disability Types
  static const String disabilityVisual = 'VISUAL';
  static const String disabilityHearing = 'HEARING';
  static const String disabilitySpeech = 'SPEECH';
  static const String disabilityMultiple = 'MULTIPLE';
  static const String disabilityNone = 'NONE';
  
  // Supported Languages
  static const String langEnglish = 'en';
  static const String langHindi = 'hi';
  
  // Location Update Interval (seconds)
  static const int locationUpdateInterval = 30;
  
  // Shared Preferences Keys
  static const String prefToken = 'auth_token';
  static const String prefUserId = 'user_id';
  static const String prefUserRole = 'user_role';
  static const String prefLanguage = 'language_preference';
  static const String prefDeviceId = 'device_id';
  static const String prefManualStreamUrl = 'manual_stream_url'; // Manual stream URL override (highest priority)
}

