// SPDX-License-Identifier: GPL-3.0-or-later

/// Validation shared by Avatar ID creation and profile editing.
///
/// Keep the equivalent server list in `server/src/content-policy.js` in sync.
const abusiveAvatarNameTerms = <String>{
  'asshole',
  'bastard',
  'bitch',
  'cunt',
  'dickhead',
  'faggot',
  'fuck',
  'motherfucker',
  'nazi',
  'nigger',
  'pedo',
  'porn',
  'pussy',
  'rape',
  'rapist',
  'retard',
  'shit',
  'slut',
  'whore',
};

const _abusiveAvatarNameFragments = <String>{
  'asshole',
  'bastard',
  'bitch',
  'cunt',
  'faggot',
  'fuck',
  'motherfucker',
  'nazi',
  'nigger',
  'pedo',
  'porn',
  'pussy',
  'rapist',
  'retard',
  'shit',
  'slut',
  'whore',
};

String normalizedAvatarName(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ');

String? avatarNameValidationError(String value) {
  final name = normalizedAvatarName(value);
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9 _-]{2,19}$').hasMatch(name)) {
    return 'Use 3–20 letters, numbers, spaces, _ or -';
  }
  if (_containsAbusiveAvatarNameTerm(name)) {
    return 'Choose a respectful Avatar ID without abusive or offensive words';
  }
  return null;
}

String? preferredNameValidationError(String value) {
  final name = normalizedAvatarName(value);
  if (name.isEmpty ||
      name.length > 24 ||
      name.contains(RegExp(r'[\x00-\x1F]'))) {
    return 'Use a name between 1 and 24 characters';
  }
  if (_containsAbusiveAvatarNameTerm(name)) {
    return 'Choose a respectful name without abusive or offensive words';
  }
  return null;
}

bool _containsAbusiveAvatarNameTerm(String value) {
  final canonical = value.toLowerCase().replaceAllMapped(
    RegExp(r'[013457@\$]'),
    (match) => const {
      '0': 'o',
      '1': 'i',
      '3': 'e',
      '4': 'a',
      '5': 's',
      '7': 't',
      '@': 'a',
      r'$': 's',
    }[match.group(0)]!,
  );
  final words = canonical
      .split(RegExp(r'[^a-z]+'))
      .where((word) => word.isNotEmpty);
  if (words.any(abusiveAvatarNameTerms.contains)) return true;
  final compact = canonical.replaceAll(RegExp(r'[^a-z]'), '');
  return _abusiveAvatarNameFragments.any(compact.contains);
}
