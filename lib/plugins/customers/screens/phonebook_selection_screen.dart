import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../../../models/customer_model.dart';
import '../../../services/customer_repository.dart';
import '../../../widgets/h1_text_field.dart';

class PhonebookSelectionScreen extends StatefulWidget {
  const PhonebookSelectionScreen({super.key});
  @override
  State<PhonebookSelectionScreen> createState() => _PhonebookSelectionScreenState();
}

class _PhonebookSelectionScreenState extends State<PhonebookSelectionScreen> {
  List<Contact> _allContacts = [];
  List<Contact> _filtered = [];
  bool _loading = true;
  final _query = TextEditingController();
  final _repo = CustomerRepository();
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final status = await Permission.contacts.request();
      if (status != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('連絡帳へのアクセスを許可してください')),
          );
          Navigator.pop(context);
        }
        return;
      }
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      if (mounted) setState(() {
        _allContacts = contacts;
        _filtered = contacts;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('連絡帳の読み込みに失敗しました: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  void _filter(String q) {
    setState(() {
      if (q.isEmpty) {
        _filtered = _allContacts;
      } else {
        final lower = q.toLowerCase();
        _filtered = _allContacts.where((c) =>
          c.displayName?.toLowerCase().contains(lower) == true ||
          c.phones.any((p) => p.number.contains(q))
        ).toList();
      }
    });
  }

  Future<void> _import(Contact contact) async {
    final phone = contact.phones.isNotEmpty ? contact.phones.first.number : null;
    final emails = contact.emails;
    final email = emails.isNotEmpty ? emails.first.address : null;
    final email2 = emails.length > 1 ? emails[1].address : null;
    final email3 = emails.length > 2 ? emails[2].address : null;
    final addr = contact.addresses.isNotEmpty ? contact.addresses.first.address : null;
    final displayName = contact.displayName ?? '名無し';
    try {
      await _repo.saveCustomer(Customer(
        id: _uuid.v4(),
        displayName: displayName,
        formalName: displayName,
        title: 1,
        tel: phone,
        email: email,
        email2: email2,
        email3: email3,
        address: addr,
        isLocked: false,
        isHidden: false,
        isSynced: false,
        updatedAt: DateTime.now(),
        rank: CustomerRank.none,
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「$displayName」を追加しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('追加失敗: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('電話帳から選択')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: H1TextField(
                    controller: _query,
                    decoration: const InputDecoration(
                      hintText: '名前または電話番号で検索',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: _filter,
                  ),
                ),
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(child: Text('連絡先が見つかりません', style: TextStyle(color: cs.onSurfaceVariant)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filtered.length,
                          itemBuilder: (ctx, i) {
                            final c = _filtered[i];
                            final phone = c.phones.isNotEmpty ? c.phones.first.number : null;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: cs.primaryContainer,
                                  child: Text((c.displayName?.isNotEmpty == true ? c.displayName![0] : '?'),
                                      style: TextStyle(color: cs.primary)),
                                ),
                                title: Text(c.displayName ?? '', style: TextStyle(fontSize: 14, color: cs.onSurface)),
                                subtitle: Text(phone ?? '', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.person_add, size: 20),
                                  tooltip: '顧客として追加',
                                  onPressed: () => _import(c),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
