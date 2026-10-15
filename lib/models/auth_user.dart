class AuthUser {
  final int id;
  final String username;
  final String name;
  final String email;
  final String status;
  final String? role;

  const AuthUser({required this.id, required this.username, required this.name, required this.email, required this.status, this.role});
  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(id: json['id'] as int, username: json['username'] as String, name: json['name'] as String, email: json['email'] as String, status: json['status'] as String, role: json['role'] as String?);
  bool get isAdmin => role == 'Administrador';
  bool get isReadOnly => role == 'Consulta';
  String get greeting => 'Bienvenido $name';
}
