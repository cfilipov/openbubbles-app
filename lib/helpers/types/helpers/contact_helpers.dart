import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:dlibphonenumber/dlibphonenumber.dart';
import 'package:get/get.dart';

Future<String> formatPhoneNumber(dynamic item) async {
  String cc = Get.deviceLocale?.countryCode ?? "US";
  String? address;

  // Set the address/country accordingly
  if (item is String?) {
    address = item;
  } else if (item is Handle?) {
    address = item?.address;
    cc = item?.country ?? cc;
  } else {
    return item.toString();
  }

  // If we don't have a valid address, or it's an email, return it
  if (isNullOrEmpty(address) || address!.isEmail || address.contains("urn:biz")) return address ?? "Unknown";
  address = address.trim();

  String? formatted;
  try {
    final parsed = PhoneNumberUtil.instance.parse(address, address.startsWith("+") ? null : cc);
    formatted = PhoneNumberUtil.instance.format(parsed, PhoneNumberFormat.international);
  } catch (_) {}

  return formatted ?? address;
}

List<String> getUniqueNumbers(Iterable<String> numbers) {
  List<String> phones = [];
  for (String phone in numbers) {
    bool exists = false;
    for (String current in phones) {
      if (phone.numericOnly() == current.numericOnly()) {
        exists = true;
        break;
      }
    }

    if (!exists) {
      phones.add(phone);
    }
  }

  return phones;
}

List<String> getUniqueEmails(Iterable<String> list) {
  List<String> emails = [];
  for (String email in list) {
    bool exists = false;
    for (String current in emails) {
      if (email.trim() == current.trim()) {
        exists = true;
        break;
      }
    }

    if (!exists) {
      emails.add(email);
    }
  }

  return emails;
}

String getDisplayName(String? displayName, String? firstName, String? lastName) {
  String? _displayName = (displayName?.isEmpty ?? false) ? null : displayName;
  return _displayName ?? [firstName, lastName].where((e) => e?.isNotEmpty ?? false).toList().join(" ");
}

Contact? selectPreferredContact(Iterable<Contact> candidates, {Contact? current}) {
  Contact? preferred;
  for (final candidate in candidates) {
    if (preferred == null || _compareContactPreference(candidate, preferred, current) < 0) {
      preferred = candidate;
    }
  }
  return preferred;
}

int _compareContactPreference(Contact first, Contact second, Contact? current) {
  final avatarComparison = _comparePreferredBool(_hasAvatar(first), _hasAvatar(second));
  if (avatarComparison != 0) return avatarComparison;

  final richnessComparison = _contactRichness(second).compareTo(_contactRichness(first));
  if (richnessComparison != 0) return richnessComparison;

  final currentId = current?.id;
  final currentComparison = _comparePreferredBool(first.id == currentId, second.id == currentId);
  if (currentComparison != 0) return currentComparison;

  return first.id.compareTo(second.id);
}

int _comparePreferredBool(bool first, bool second) => first == second ? 0 : (first ? -1 : 1);

bool _hasAvatar(Contact contact) => contact.avatar?.isNotEmpty == true;

int _contactRichness(Contact contact) {
  final structuredName = contact.structuredName;
  final populatedNameParts = structuredName == null
      ? 0
      : [
          structuredName.namePrefix,
          structuredName.givenName,
          structuredName.middleName,
          structuredName.familyName,
          structuredName.nameSuffix,
        ].where((part) => part.trim().isNotEmpty).length;
  final addressCount = getUniqueNumbers(contact.phones).length + getUniqueEmails(contact.emails).length;

  // Name data is a stronger indication of a real address-book entry than an
  // app-created shadow contact. Address count breaks ties between otherwise
  // equivalent records.
  return populatedNameParts * 100 + addressCount;
}
