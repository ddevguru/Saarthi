/**
 * SAARTHI AI Agent - Image Analysis Agent
 * Advanced object detection, scene understanding, and obstacle classification
 * For Mumbai Hackathon - Health IoT Project
 */

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants.dart';

class ImageAnalysisAgent {
  final String _apiBaseUrl = AppConstants.apiBaseUrl;
  
  /// Analyze image from ESP32 camera for objects and obstacles
  Future<ImageAnalysisResult> analyzeImage(String imageUrl) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/ai/analyzeImage.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'image_url': imageUrl,
          'analysis_type': 'full', // full, obstacle_only, objects_only
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return ImageAnalysisResult.fromJson(data['data']);
        }
      }
      
      return ImageAnalysisResult.empty();
    } catch (e) {
      print('Image analysis error: $e');
      return ImageAnalysisResult.empty();
    }
  }

  /// Quick obstacle detection (faster, lightweight)
  Future<ObstacleInfo> detectObstacle(String imageUrl) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/ai/detectObstacle.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image_url': imageUrl}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return ObstacleInfo.fromJson(data['data']);
        }
      }
      
      return ObstacleInfo.empty();
    } catch (e) {
      print('Obstacle detection error: $e');
      return ObstacleInfo.empty();
    }
  }

  /// Classify scene type (indoor, outdoor, road, stairs, etc.)
  Future<SceneClassification> classifyScene(String imageUrl) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/ai/classifyScene.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image_url': imageUrl}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return SceneClassification.fromJson(data['data']);
        }
      }
      
      return SceneClassification.empty();
    } catch (e) {
      print('Scene classification error: $e');
      return SceneClassification.empty();
    }
  }

  /// Detect dangerous objects (vehicles, animals, etc.)
  Future<List<DangerousObject>> detectDangerousObjects(String imageUrl) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/ai/detectDangerousObjects.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image_url': imageUrl}),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final objects = (data['data']['objects'] as List)
              .map((obj) => DangerousObject.fromJson(obj))
              .toList();
          return objects;
        }
      }
      
      return [];
    } catch (e) {
      print('Dangerous object detection error: $e');
      return [];
    }
  }
}

class ImageAnalysisResult {
  final List<DetectedObject> objects;
  final ObstacleInfo obstacleInfo;
  final SceneClassification scene;
  final double confidence;
  final String summary;

  ImageAnalysisResult({
    required this.objects,
    required this.obstacleInfo,
    required this.scene,
    required this.confidence,
    required this.summary,
  });

  factory ImageAnalysisResult.fromJson(Map<String, dynamic> json) {
    return ImageAnalysisResult(
      objects: (json['objects'] as List? ?? [])
          .map((obj) => DetectedObject.fromJson(obj))
          .toList(),
      obstacleInfo: ObstacleInfo.fromJson(json['obstacle_info'] ?? {}),
      scene: SceneClassification.fromJson(json['scene'] ?? {}),
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      summary: json['summary'] ?? 'No objects detected',
    );
  }

  factory ImageAnalysisResult.empty() {
    return ImageAnalysisResult(
      objects: [],
      obstacleInfo: ObstacleInfo.empty(),
      scene: SceneClassification.empty(),
      confidence: 0.0,
      summary: 'Analysis unavailable',
    );
  }
}

class DetectedObject {
  final String label;
  final double confidence;
  final BoundingBox boundingBox;
  final String category; // obstacle, vehicle, person, animal, etc.

  DetectedObject({
    required this.label,
    required this.confidence,
    required this.boundingBox,
    required this.category,
  });

  factory DetectedObject.fromJson(Map<String, dynamic> json) {
    return DetectedObject(
      label: json['label'] ?? 'Unknown',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      boundingBox: BoundingBox.fromJson(json['bbox'] ?? {}),
      category: json['category'] ?? 'unknown',
    );
  }
}

class BoundingBox {
  final double x;
  final double y;
  final double width;
  final double height;

  BoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory BoundingBox.fromJson(Map<String, dynamic> json) {
    return BoundingBox(
      x: (json['x'] ?? 0.0).toDouble(),
      y: (json['y'] ?? 0.0).toDouble(),
      width: (json['width'] ?? 0.0).toDouble(),
      height: (json['height'] ?? 0.0).toDouble(),
    );
  }
}

class ObstacleInfo {
  final bool hasObstacle;
  final String obstacleType; // wall, vehicle, person, stairs, etc.
  final double distance; // estimated distance in cm
  final double confidence;
  final String recommendation;

  ObstacleInfo({
    required this.hasObstacle,
    required this.obstacleType,
    required this.distance,
    required this.confidence,
    required this.recommendation,
  });

  factory ObstacleInfo.fromJson(Map<String, dynamic> json) {
    return ObstacleInfo(
      hasObstacle: json['has_obstacle'] ?? false,
      obstacleType: json['obstacle_type'] ?? 'unknown',
      distance: (json['distance'] ?? 0.0).toDouble(),
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      recommendation: json['recommendation'] ?? 'Proceed with caution',
    );
  }

  factory ObstacleInfo.empty() {
    return ObstacleInfo(
      hasObstacle: false,
      obstacleType: 'unknown',
      distance: 0.0,
      confidence: 0.0,
      recommendation: 'Unable to detect obstacles',
    );
  }
}

class SceneClassification {
  final String sceneType; // indoor, outdoor, road, stairs, building, etc.
  final double confidence;
  final Map<String, dynamic> attributes;

  SceneClassification({
    required this.sceneType,
    required this.confidence,
    required this.attributes,
  });

  factory SceneClassification.fromJson(Map<String, dynamic> json) {
    return SceneClassification(
      sceneType: json['scene_type'] ?? 'unknown',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      attributes: json['attributes'] ?? {},
    );
  }

  factory SceneClassification.empty() {
    return SceneClassification(
      sceneType: 'unknown',
      confidence: 0.0,
      attributes: {},
    );
  }
}

class DangerousObject {
  final String objectType; // vehicle, animal, person, etc.
  final double dangerLevel; // 0.0 to 1.0
  final double distance;
  final String warning;

  DangerousObject({
    required this.objectType,
    required this.dangerLevel,
    required this.distance,
    required this.warning,
  });

  factory DangerousObject.fromJson(Map<String, dynamic> json) {
    return DangerousObject(
      objectType: json['object_type'] ?? 'unknown',
      dangerLevel: (json['danger_level'] ?? 0.0).toDouble(),
      distance: (json['distance'] ?? 0.0).toDouble(),
      warning: json['warning'] ?? 'Caution required',
    );
  }
}

