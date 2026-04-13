import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:main_ui/models/user_model.dart';
import 'package:main_ui/services/auth_service.dart';
import 'package:main_ui/services/api_service.dart';

// Notifier for the current authenticated user
class UserNotifier extends StateNotifier<User?> {
  UserNotifier(this.ref) : super(null) {
    _initialize();
  }

  final Ref ref;
  bool _disposed = false;

  // Initialize with a slight delay to avoid constructor async issues
  void _initialize() async {
    await Future.delayed(Duration.zero);
    if (!_disposed) {
      await fetchCurrentUser();
    }
  }

  Future<void> fetchCurrentUser() async {
    try {
      final user = await AuthService.getCurrentUser();
      // Check if not disposed before updating state
      if (!_disposed) {
        state = user;
      }
    } catch (e) {
      // Only update state if not disposed
      if (!_disposed) {
        state = null;
      }
    }
  }

  Future<void> refreshUser() async {
    // Check if disposed before proceeding
    if (_disposed) return;
    await fetchCurrentUser();
  }

  Future<void> updateUser() async {
    try {
      // Early return if disposed
      if (_disposed) return;
      
      final response = await ApiService.get('/settings/user');
      if (response.data != null && !_disposed) {
        state = User.fromJson(response.data);
      }
    } catch (e) {
      if (!_disposed) {
        rethrow;
      }
    }
  }

  void setUser(User? user) {
    // Only update if not disposed
    if (!_disposed) {
      state = user;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

// Define the user provider
final userNotifierProvider = StateNotifierProvider<UserNotifier, User?>((ref) {
  return UserNotifier(ref);
});

// Provider for managing a list of users (for admin)
final usersProvider = StateNotifierProvider<UsersNotifier, List<User>>((ref) {
  return UsersNotifier(ref);
});

// Notifier for managing a list of users
class UsersNotifier extends StateNotifier<List<User>> {
  UsersNotifier(this.ref) : super([]) {
    _initialize();
  }

  final Ref ref;
  bool _disposed = false;

  // Initialize with a slight delay
  void _initialize() async {
    await Future.delayed(Duration.zero);
    if (!_disposed) {
      await fetchUsers();
    }
  }

  // Fetch all users from the backend
  Future<void> fetchUsers() async {
    try {
      final users = await ApiService.getUsers();
      // Check if not disposed before updating
      if (!_disposed) {
        state = users;
      }
    } catch (e) {
      // Only update if not disposed
      if (!_disposed) {
        state = [];
      }
    }
  }

  // Add or update a user
  Future<void> addUser(Map<String, dynamic> userData) async {
    try {
      final userDataToSend = <String, dynamic>{};
      for (final entry in userData.entries) {
        var value = entry.value;  // Can be null
        if (entry.key == 'role' && value != null) {
          value = value.toString().toLowerCase();
        }
        userDataToSend[entry.key] = value;
      }
      
      await ApiService.addUpdateUser(userDataToSend);
      
      // Only refresh if not disposed
      if (!_disposed) {
        await fetchUsers();
      }
    } catch (e) {
      if (!_disposed) {
        rethrow;
      }
    }
  }

  // Update an existing user
  Future<void> updateUser(int userId, Map<String, dynamic> userData) async {
    try {
      // Early return if disposed
      if (_disposed) return;
      
      final dataToSend = Map<String, dynamic>.from(userData);
      if (dataToSend['role'] != null) {
        dataToSend['role'] = dataToSend['role'].toString().toLowerCase();
      }

      await ApiService.addUpdateUser(dataToSend);
      
      // Only refresh if not disposed
      if (!_disposed) {
        await fetchUsers();
      }
    } catch (e) {
      if (!_disposed) {
        rethrow;
      }
    }
  }

  // Delete a user
// lib/providers/user_provider.dart
Future<bool> deleteUser(int userId) async {
  try {
    await ApiService.deleteUser(userId);

    if (_disposed) return false;

    await fetchUsers();

    final currentUser = ref.read(userNotifierProvider);
    if (currentUser?.id == userId) {
      ref.read(userNotifierProvider.notifier).setUser(null);
    }

    return true; // ✅ SUCCESS
  } catch (e) {
    return false; // ❌ FAILURE
  }
}

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}