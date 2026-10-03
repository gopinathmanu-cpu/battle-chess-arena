// SPDX-License-Identifier: GPL-3.0-or-later

// Keep the equivalent app list in lib/src/domain/avatar_name_policy.dart in sync.
export const abusiveAvatarNameTerms = new Set([
  'asshole', 'bastard', 'bitch', 'cunt', 'dickhead', 'faggot', 'fuck',
  'motherfucker', 'nazi', 'nigger', 'pedo', 'porn', 'pussy', 'rape', 'rapist',
  'retard', 'shit', 'slut', 'whore',
]);

const blockedFragments = new Set([
  'asshole', 'bastard', 'bitch', 'cunt', 'faggot', 'fuck', 'motherfucker',
  'nazi', 'nigger', 'pedo', 'porn', 'pussy', 'rapist', 'retard', 'shit', 'slut',
  'whore',
]);

export function avatarNameAllowed(value) {
  const canonical = value.toLocaleLowerCase('en-US').replace(/[013457@$]/g,
    character => ({'0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's',
      '7': 't', '@': 'a', '$': 's'})[character]);
  const words = canonical.split(/[^a-z]+/).filter(Boolean);
  if (words.some(word => abusiveAvatarNameTerms.has(word))) return false;
  const compact = canonical.replace(/[^a-z]/g, '');
  return ![...blockedFragments].some(fragment => compact.includes(fragment));
}
