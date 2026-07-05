import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../services/role_service.dart';
import '../../services/database_helper.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<User> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final users = await UserService().getAllUsers();
    setState(() {
      _users = users;
      _isLoading = false;
    });
  }

  Future<void> _changeRole(User user, String newRole) async {
    await RoleService().setRole(user.id, newRole);
    await _loadUsers();
  }

  Future<void> _toggleActive(User user) async {
    final db = await DatabaseHelper().database;
    if (user.isActive) {
      await db.update('users', {'is_active': 0}, where: 'id = ?', whereArgs: [user.id]);
    } else {
      await db.update('users', {'is_active': 1}, where: 'id = ?', whereArgs: [user.id]);
    }
    await _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ユーザー管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(child: Text('ユーザーが登録されていません'))
              : ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return _UserTile(
                      user: user,
                      onRoleChanged: (role) => _changeRole(user, role),
                      onToggleActive: () => _toggleActive(user),
                    );
                  },
                ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final User user;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onToggleActive;

  const _UserTile({
    required this.user,
    required this.onRoleChanged,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final roleLabel = user.role == 'admin' ? '管理者'
        : user.role == 'member' ? 'メンバー'
        : '閲覧者';

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
        child: user.photoUrl == null ? Text(user.email[0].toUpperCase()) : null,
      ),
      title: Text(user.displayName ?? user.email),
      subtitle: Text('${user.email} • $roleLabel'),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'role_admin') onRoleChanged('admin');
          if (value == 'role_member') onRoleChanged('member');
          if (value == 'role_viewer') onRoleChanged('viewer');
          if (value == 'toggle_active') onToggleActive();
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'role_admin', child: Text('管理者に設定')),
          const PopupMenuItem(value: 'role_member', child: Text('メンバーに設定')),
          const PopupMenuItem(value: 'role_viewer', child: Text('閲覧者に設定')),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'toggle_active',
            child: Text(user.isActive ? '無効にする' : '有効にする'),
          ),
        ],
      ),
    );
  }
}
