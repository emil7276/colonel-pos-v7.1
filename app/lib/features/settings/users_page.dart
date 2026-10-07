import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../data/database.dart';
class UsersPage
    extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() =>
      _UsersPageState();
}
class _UsersPageState
    extends State<UsersPage> {
  List<Map<String, dynamic>>
      users = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final x =
          await DB.users();

      if (!mounted) return;

      setState(() => users = x);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Gagal memuat pengguna: '
            '$e',
          ),
        ),
      );
    }
  }

  Future<void> edit([
    Map<String, dynamic>? u,
  ]) async {
    final username =
        TextEditingController(
      text:
          u?['username'] ?? '',
    );

    final password =
        TextEditingController(
      text:
          u?['password'] ?? '',
    );

    String role =
        u?['role'] ?? 'Kasir';

    bool active =
        (u?['active'] ?? 1) == 1;

    await showDialog(
      context: context,
      builder: (_) =>
          StatefulBuilder(
        builder: (
          context,
          setDialog,
        ) =>
            AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          title: Text(
            u == null
                ? 'Tambah Pengguna'
                : 'Edit Pengguna',
          ),
          content: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              TextField(
                controller: username,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Username',
                ),
              ),
              TextField(
                controller: password,
                obscureText:
                    true,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Password',
                ),
              ),
              DropdownButtonFormField<
                  String>(
                value: role,
                items: const [
                  DropdownMenuItem(
                    value:
                        'Administrator',
                    child: Text(
                      'Administrator',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Kasir',
                    child: Text(
                      'Kasir',
                    ),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setDialog(
                      () =>
                          role = v,
                    );
                  }
                },
                decoration:
                    const InputDecoration(
                  labelText:
                      'Role',
                ),
              ),
              SwitchListTile(
                value: active,
                onChanged: (v) {
                  setDialog(
                    () =>
                        active = v,
                  );
                },
                title:
                    const Text(
                  'Aktif',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                context,
              ),
              child:
                  const Text(
                'Batal',
              ),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await DB.saveUser(
                    id: u?['id'],
                    username:
                        username.text
                            .trim(),
                    password:
                        password.text,
                    role: role,
                    active: active,
                  );

                  if (context
                      .mounted) {
                    Navigator.pop(
                      context,
                    );
                  }
                } catch (e) {
                  if (context
                      .mounted) {
                    ScaffoldMessenger
                            .of(context)
                        .showSnackBar(
                      SnackBar(
                        duration:
                            const Duration(
                          seconds: 5,
                        ),
                        content: Text(
                          'Gagal menyimpan pengguna:\n'
                          '$e',
                        ),
                      ),
                    );
                  }
                }
              },
              child:
                  const Text(
                'Simpan',
              ),
            ),
          ],
        ),
      ),
    );

    await load();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'Manajemen Pengguna',
        ),
        actions: [
          IconButton(
            onPressed: () => edit(),
            icon: const Icon(
              Icons.add,
            ),
          ),
        ],
      ),
      body: ListView(
        padding:
            const EdgeInsets.all(10),
        children:
            users.map((u) {
          return Card(
            child: ListTile(
              leading:
                  const Icon(
                Icons.person,
                color: red,
              ),
              title: Text(
                u['username']
                    .toString(),
              ),
              subtitle: Text(
                u['role'].toString(),
              ),
              trailing: Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Switch(
                    value:
                        u['active'] ==
                            1,
                    onChanged:
                        (v) async {
                      try {
                        await DB
                            .saveUser(
                          id: u['id']
                              as int,
                          username: u[
                                  'username']
                              .toString(),
                          password: u[
                                  'password']
                              .toString(),
                          role: u['role']
                              .toString(),
                          active: v,
                        );

                        await load();
                      } catch (e) {
                        if (!mounted)
                          return;

                        ScaffoldMessenger
                                .of(
                          context,
                        ).showSnackBar(
                          SnackBar(
                            content:
                                Text(
                              'Gagal: $e',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  IconButton(
                    onPressed: () =>
                        edit(u),
                    icon:
                        const Icon(
                      Icons.edit,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
