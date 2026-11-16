class AppUser {
  final String id, name, email, role;
  final bool active;
  const AppUser({required this.id, required this.name, required this.email,
    required this.role, this.active = true});
  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String, name: json['name'] as String,
    email: json['email'] as String, role: json['role'] as String,
    active: json['active'] as bool? ?? true);
  bool get isAdmin => role == 'admin';
}
