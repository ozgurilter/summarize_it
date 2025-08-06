class User {
  final String nameSurname;
  final String email;
  final String password;
  final DateTime? createdAt;

  User({
    required this.nameSurname,
    required this.email,
    required this.password,
    this.createdAt,
  });

  factory User.fromFirestore(Map<String, dynamic> data) {
    return User(
      nameSurname: data['nameSurname'] ?? '',
      email: data['email'] ?? '',
      password: data['password'] ?? '',
      createdAt: data['createdAt']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nameSurname': nameSurname,
      'email': email,
      'password': password,
      'createdAt': createdAt,
    };
  }
}
