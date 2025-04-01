import 'dart:convert';

class UserModel {
  final String id;
  final String firstname;
  final String lastname;
  final String birthdate;
  final List<String> interests;
  final bool isAnonymous;
  final String? anonymousId;
  final String accountType;
  final String? grade;
  final bool temporary;
  final String username;
  final String photo;
  final String email;
  final String emailStatus;
  final String role;
  final int readListLength;
  final List<dynamic> audioCollections;
  final List<dynamic> preferences;

  UserModel({
    required this.id,
    required this.firstname,
    required this.lastname,
    required this.birthdate,
    required this.interests,
    required this.isAnonymous,
    this.anonymousId,
    required this.accountType,
    this.grade,
    required this.temporary,
    required this.username,
    required this.photo,
    required this.email,
    required this.emailStatus,
    required this.role,
    required this.readListLength,
    required this.audioCollections,
    required this.preferences,
  });

  factory UserModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return UserModel(
        id: '',
        firstname: '',
        lastname: '',
        birthdate: 'Not available',
        interests: [],
        isAnonymous: false,
        anonymousId: '',
        accountType: 'registered',
        grade: '',
        temporary: false,
        username: 'Guest',
        photo: '',
        email: '',
        emailStatus: 'pending',
        role: 'user',
        readListLength: 0,
        audioCollections: [],
        preferences: [],
      );
    }
    
    return UserModel(
      id: json['_id'] ?? '',
      firstname: json['firstname'] ?? '',
      lastname: json['lastname'] ?? '',
      birthdate: json['birthdate'] ?? 'Not available',
      interests: List<String>.from(json['interests'] ?? []),
      isAnonymous: json['isAnonymous'] ?? false,
      anonymousId: json['anonymousId'],
      accountType: json['accountType'] ?? 'registered',
      grade: json['grade'],
      temporary: json['temporary'] ?? false,
      username: json['username'] ?? '',
      photo: json['photo'] ?? '',
      email: json['email'] ?? '',
      emailStatus: json['emailStatus'] ?? 'pending',
      role: json['role'] ?? 'user',
      readListLength: json['readListLength'] ?? 0,
      audioCollections: json['audioCollections'] ?? [],
      preferences: json['preferences'] ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'firstname': firstname,
      'lastname': lastname,
      'birthdate': birthdate,
      'interests': interests,
      'isAnonymous': isAnonymous,
      'anonymousId': anonymousId,
      'accountType': accountType,
      'grade': grade,
      'temporary': temporary,
      'username': username,
      'photo': photo,
      'email': email,
      'emailStatus': emailStatus,
      'role': role,
      'readListLength': readListLength,
      'audioCollections': audioCollections,
      'preferences': preferences,
    };
  }

  String toJsonString() {
    return jsonEncode(toJson());
  }
  
  factory UserModel.fromJsonString(String jsonString) {
    final Map<String, dynamic> json = jsonDecode(jsonString);
    return UserModel.fromJson(json);
  }
}