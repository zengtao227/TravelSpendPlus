/// Default category keys stay stable in expenses and statistics. Per-trip
/// settings can change their labels/icons or hide them from new expenses.
const List<String> kExpenseCategoryKeys = [
  'flight',
  'lodging',
  'food',
  'drinks',
  'transport',
  'sightseeing',
  'shopping',
  'entertainment',
  'other',
];

bool isBuiltInExpenseCategoryKey(String key) => kExpenseCategoryKeys.contains(key);

/// Presentation settings for one immutable expense-category key in a trip.
///
/// Expenses deliberately continue to store [key], even after a user changes
/// the displayed name or icon. That keeps existing expense records, charts,
/// and backups connected to the same category while allowing a trip to have
/// its own presentation choices.
class CategorySetting {
  final String key;
  final String? displayName;
  final String? iconKey;
  final bool hidden;

  const CategorySetting({
    required this.key,
    this.displayName,
    this.iconKey,
    this.hidden = false,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        if (displayName != null) 'displayName': displayName,
        if (iconKey != null) 'iconKey': iconKey,
        if (hidden) 'hidden': hidden,
      };

  factory CategorySetting.fromJson(Map<String, dynamic> json) {
    final key = json['key'] as String;
    final displayName = json['displayName'] as String?;
    // Validate while decoding the entire backup, before import writes any trip.
    if (key.trim().isEmpty || (displayName != null && displayName.trim().isEmpty)) {
      throw const FormatException('Category key and display name must not be empty');
    }
    return CategorySetting(
      key: key,
      displayName: displayName,
      iconKey: json['iconKey'] as String?,
      hidden: json['hidden'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CategorySetting &&
      other.key == key &&
      other.displayName == displayName &&
      other.iconKey == iconKey &&
      other.hidden == hidden;

  @override
  int get hashCode => Object.hash(key, displayName, iconKey, hidden);
}
