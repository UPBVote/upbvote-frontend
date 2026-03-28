class AppState {
  static String? token;
  static String? userId;
  static String? email;
  static String? userName;
  // Valores posibles: 'Votante', 'Expositor', 'Jurado', 'Secretario'
  static String? role;

  static void clear() {
    token = null;
    userId = null;
    email = null;
    userName = null;
    role = null;
  }
}
