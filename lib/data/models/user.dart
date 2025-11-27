/**
 * SAARTHI Flutter App - User Model
 */

class User {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String languagePreference;
  final String disabilityType;
  final bool isActive;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.languagePreference,
    required this.disabilityType,
    required this.isActive,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Handle id conversion (can be int or string from API)
    int userId = 0;
    if (json['id'] != null) {
      userId = json['id'] is int 
          ? json['id'] as int 
          : int.tryParse(json['id'].toString()) ?? 0;
    } else if (json['user_id'] != null) {
      userId = json['user_id'] is int 
          ? json['user_id'] as int 
          : int.tryParse(json['user_id'].toString()) ?? 0;
    }
    
    return User(
      id: userId,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      role: json['role']?.toString() ?? 'USER',
      languagePreference: json['language_preference']?.toString() ?? 'en',
      disabilityType: json['disability_type']?.toString() ?? 'NONE',
      isActive: json['is_active'] is bool 
          ? json['is_active'] as bool 
          : (json['is_active']?.toString().toLowerCase() == 'true' || json['is_active'] == 1),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'language_preference': languagePreference,
      'disability_type': disabilityType,
      'is_active': isActive,
    };
  }
}

