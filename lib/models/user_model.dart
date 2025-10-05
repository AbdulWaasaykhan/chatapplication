class UserModel {
  final String uid;
  final String email;
  final String username;
  final String publicKey; // public key for encryption

  UserModel({
    required this.uid,
    required this.email,
    required this.username,
    required this.publicKey,
  });

  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      username: data['username'] ?? '',
      publicKey: data['publicKey'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'publicKey': publicKey,
    };
  }
}
