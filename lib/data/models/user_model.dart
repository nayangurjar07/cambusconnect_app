enum UserRole { student, admin, driver, owner, unknown }

class UserModel {
  final String uid;
  final String email;
  final String name;
  final UserRole role;
  // Denormalized student fields
  final String branch;
  final String year;
  final String passStatus;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.branch = '',
    this.year = '',
    this.passStatus = '',
  });

  factory UserModel.fromJson(Map<String, dynamic> json, String uid) {
    return UserModel(
      uid: uid,
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      role: parseRole(json['role']),
      branch: json['branch'] ?? '',
      year: json['year'] ?? '',
      passStatus: json['status'] ?? json['passStatus'] ?? 'pending',
    );
  }

  static UserRole parseRole(String? roleStr) {
    switch (roleStr?.toLowerCase()) {
      case 'student':
        return UserRole.student;
      case 'admin':
        return UserRole.admin;
      case 'driver':
        return UserRole.driver;
      case 'owner':
        return UserRole.owner;
      default:
        return UserRole.unknown;
    }
  }
}
