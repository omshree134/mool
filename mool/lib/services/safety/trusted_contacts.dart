import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../../core/local_store.dart';
import '../repository.dart';

class TrustedContact {
  const TrustedContact({required this.name, required this.phone});
  final String name;
  final String phone;

  Map<String, dynamic> toMap() => {'name': name, 'phone': phone};
  factory TrustedContact.fromMap(Map<String, dynamic> m) =>
      TrustedContact(name: m['name'] as String? ?? '', phone: m['phone'] as String? ?? '');
}

/// People who get an SMS when the person presses "I'm in danger".
/// Stored on phone and shared with guardian for emergency oversight.
class TrustedContacts extends ChangeNotifier {
  TrustedContacts._();
  static final TrustedContacts instance = TrustedContacts._();

  static const max = 5;
  static const _key = 'safety.contacts';

  List<TrustedContact> get all => LocalStore.instance.getJsonList(_key).map(TrustedContact.fromMap).toList();

  Future<bool> add(TrustedContact c) async {
    final list = all;
    final normalized = _digits(c.phone);
    if (normalized.length < 8) return false;
    if (list.any((x) => _digits(x.phone) == normalized)) return true;
    if (list.length >= max) return false;
    list.add(c);
    final mapped = list.map((x) => x.toMap()).toList();
    await LocalStore.instance.setJsonList(_key, mapped);
    Repo.instance.syncTrustedContacts(mapped);
    notifyListeners();
    return true;
  }

  Future<void> remove(TrustedContact c) async {
    final list = all..removeWhere((x) => x.phone == c.phone);
    final mapped = list.map((x) => x.toMap()).toList();
    await LocalStore.instance.setJsonList(_key, mapped);
    Repo.instance.syncTrustedContacts(mapped);
    notifyListeners();
  }

  static String _digits(String s) => s.replaceAll(RegExp(r'[^0-9+]'), '');

  /// Opens the system contact picker. Abhaya loaded every contact with all
  /// properties into its own list, which is slow on large address books.
  Future<TrustedContact?> pickFromPhone() async {
    if (!await FlutterContacts.requestPermission(readonly: true)) return null;
    final picked = await FlutterContacts.openExternalPick();
    if (picked == null) return null;
    final full = await FlutterContacts.getContact(picked.id, withProperties: true);
    if (full == null || full.phones.isEmpty) return null;
    return TrustedContact(name: full.displayName, phone: full.phones.first.number);
  }
}
