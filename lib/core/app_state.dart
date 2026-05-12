class AppState {
  static String? token;
  static String? userId;
  static String? profileId;
  static String? email;
  static String? userName;
  // Valores posibles: 'Votante', 'Expositor', 'Jurado', 'Secretario', 'Admin'
  static String? role;

  static void clear() {
    token = null;
    userId = null;
    profileId = null;
    email = null;
    userName = null;
    role = null;
  }
}
