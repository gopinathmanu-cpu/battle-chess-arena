// SPDX-License-Identifier: GPL-3.0-or-later

/// Compact, portable appearance parameters, shared unchanged with opponents.
///
/// The v1 wire order and bounds are mirrored by server/src/protocol.js. Adding
/// categories or changing their meaning requires a new avatar-format version.
class CustomAvatarDesign {
  const CustomAvatarDesign({
    int presentation = 0,
    int age = 2,
    int face = 0,
    int skinTone = 3,
    int hairStyle = 2,
    int hairColor = 1,
    int moustache = 0,
    int beard = 0,
    int eyewear = 0,
    int outfit = 0,
    int outfitColor = 0,
    int background = 0,
  }) : presentation = presentation < 0
           ? 0
           : (presentation > 1 ? 1 : presentation),
       age = age < 0 ? 0 : (age > 3 ? 3 : age),
       face = face < 0 ? 0 : (face > 3 ? 3 : face),
       skinTone = skinTone < 0 ? 0 : (skinTone > 7 ? 7 : skinTone),
       hairStyle = hairStyle < 0 ? 0 : (hairStyle > 11 ? 11 : hairStyle),
       hairColor = hairColor < 0 ? 0 : (hairColor > 9 ? 9 : hairColor),
       moustache = moustache < 0 ? 0 : (moustache > 4 ? 4 : moustache),
       beard = beard < 0 ? 0 : (beard > 5 ? 5 : beard),
       eyewear = eyewear < 0 ? 0 : (eyewear > 5 ? 5 : eyewear),
       outfit = outfit < 0 ? 0 : (outfit > 5 ? 5 : outfit),
       outfitColor = outfitColor < 0 ? 0 : (outfitColor > 7 ? 7 : outfitColor),
       background = background < 0 ? 0 : (background > 7 ? 7 : background);

  static const prefix = 'custom-v1-';
  static const presentationLabels = ['Masculine', 'Feminine'];
  static const ageLabels = ['Child', 'Teen', 'Adult', 'Senior'];
  static const faceLabels = ['Oval', 'Round', 'Square', 'Heart'];
  static const skinToneLabels = [
    'Light ivory',
    'Soft beige',
    'Warm beige',
    'Golden tan',
    'Rich tan',
    'Warm brown',
    'Deep brown',
    'Deep ebony',
  ];
  static const hairStyleLabels = [
    'Shaved',
    'Crop',
    'Side part',
    'Quiff',
    'Curls',
    'Afro',
    'Bob',
    'Long',
    'Waves',
    'Braids',
    'Bun',
    'Ponytail',
  ];
  static const hairColorLabels = [
    'Black',
    'Dark brown',
    'Brown',
    'Chestnut',
    'Auburn',
    'Blond',
    'Silver',
    'White',
    'Blue',
    'Purple',
  ];
  static const moustacheLabels = [
    'None',
    'Pencil',
    'Classic',
    'Handlebar',
    'Full',
  ];
  static const beardLabels = [
    'None',
    'Stubble',
    'Goatee',
    'Short',
    'Full',
    'Pointed',
  ];
  static const eyewearLabels = [
    'None',
    'Round',
    'Rectangular',
    'Cat-eye',
    'Sunglasses',
    'Aviators',
  ];
  static const outfitLabels = [
    'Crew neck',
    'Hoodie',
    'Shirt',
    'Jacket',
    'Kurta',
    'Dress',
  ];
  static const outfitColorLabels = [
    'Navy',
    'Teal',
    'Burgundy',
    'Forest',
    'Gold',
    'Violet',
    'Coral',
    'Slate',
  ];
  static const backgroundLabels = [
    'Midnight blue',
    'Seafoam',
    'Rose',
    'Lavender',
    'Amber',
    'Sky',
    'Forest',
    'Sand',
  ];

  static const _maxima = [1, 3, 3, 7, 11, 9, 4, 5, 5, 5, 7, 7];
  static final _wirePattern = RegExp(r'^custom-v1-[0-9a-z]{12}$');

  final int presentation;
  final int age;
  final int face;
  final int skinTone;
  final int hairStyle;
  final int hairColor;
  final int moustache;
  final int beard;
  final int eyewear;
  final int outfit;
  final int outfitColor;
  final int background;

  List<int> get _values => [
    presentation,
    age,
    face,
    skinTone,
    hairStyle,
    hairColor,
    moustache,
    beard,
    eyewear,
    outfit,
    outfitColor,
    background,
  ];

  String get avatarId =>
      '$prefix${_values.map((value) => value.toRadixString(36)).join()}';

  /// Reject malformed or future-version values rather than silently displaying
  /// a different custom portrait from the one another player selected.
  static CustomAvatarDesign? tryParse(String value) {
    // Check length separately: RegExp '$' may also match before a final newline.
    if (value.length != prefix.length + 12 || !_wirePattern.hasMatch(value)) {
      return null;
    }
    final values = value
        .substring(prefix.length)
        .split('')
        .map((digit) => int.parse(digit, radix: 36))
        .toList();
    for (var i = 0; i < values.length; i++) {
      if (values[i] > _maxima[i]) return null;
    }
    return CustomAvatarDesign(
      presentation: values[0],
      age: values[1],
      face: values[2],
      skinTone: values[3],
      hairStyle: values[4],
      hairColor: values[5],
      moustache: values[6],
      beard: values[7],
      eyewear: values[8],
      outfit: values[9],
      outfitColor: values[10],
      background: values[11],
    );
  }

  CustomAvatarDesign copyWith({
    int? presentation,
    int? age,
    int? face,
    int? skinTone,
    int? hairStyle,
    int? hairColor,
    int? moustache,
    int? beard,
    int? eyewear,
    int? outfit,
    int? outfitColor,
    int? background,
  }) => CustomAvatarDesign(
    presentation: presentation ?? this.presentation,
    age: age ?? this.age,
    face: face ?? this.face,
    skinTone: skinTone ?? this.skinTone,
    hairStyle: hairStyle ?? this.hairStyle,
    hairColor: hairColor ?? this.hairColor,
    moustache: moustache ?? this.moustache,
    beard: beard ?? this.beard,
    eyewear: eyewear ?? this.eyewear,
    outfit: outfit ?? this.outfit,
    outfitColor: outfitColor ?? this.outfitColor,
    background: background ?? this.background,
  );

  @override
  bool operator ==(Object other) =>
      other is CustomAvatarDesign &&
      presentation == other.presentation &&
      age == other.age &&
      face == other.face &&
      skinTone == other.skinTone &&
      hairStyle == other.hairStyle &&
      hairColor == other.hairColor &&
      moustache == other.moustache &&
      beard == other.beard &&
      eyewear == other.eyewear &&
      outfit == other.outfit &&
      outfitColor == other.outfitColor &&
      background == other.background;

  @override
  int get hashCode => Object.hashAll(_values);
}
