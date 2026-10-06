import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';

import '../domain/expense_category.dart';
import '../domain/trip.dart';
import '../persistence/trip_repository.dart';
import 'formatting.dart';

/// Per-trip category management.  A category's key is deliberately never
/// changed here: expenses retain that key, while a saved display name and
/// icon make historical entries follow the user's current presentation.
class CategorySettingsScreen extends StatefulWidget {
  final Trip trip;
  final TripRepository repository;

  const CategorySettingsScreen({
    super.key,
    required this.trip,
    required this.repository,
  });

  @override
  State<CategorySettingsScreen> createState() => _CategorySettingsScreenState();
}

class _CategoryData {
  final List<CategorySetting> settings;
  final List<String> keys;

  const _CategoryData({required this.settings, required this.keys});
}

class _CategorySettingsScreenState extends State<CategorySettingsScreen> {
  late Future<_CategoryData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_CategoryData> _load() async {
    final results = await Future.wait([
      widget.repository.getCategorySettings(widget.trip.id),
      widget.repository.getAvailableCategoryKeys(widget.trip.id),
    ]);
    final settings = results[0] as List<CategorySetting>;
    final availableKeys = results[1] as List<String>;
    // Settings can be hidden and a historical expense can contain a category
    // that predates this feature.  Both remain manageable here.
    final keys = <String>{
      ...kExpenseCategoryKeys,
      ...availableKeys,
      ...settings.map((setting) => setting.key),
    }.toList();
    keys.sort((a, b) {
      final aBuiltin = kExpenseCategoryKeys.indexOf(a);
      final bBuiltin = kExpenseCategoryKeys.indexOf(b);
      if (aBuiltin >= 0 && bBuiltin >= 0) return aBuiltin.compareTo(bBuiltin);
      if (aBuiltin >= 0) return -1;
      if (bBuiltin >= 0) return 1;
      return a.compareTo(b);
    });
    return _CategoryData(settings: settings, keys: keys);
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  CategorySetting? _settingFor(_CategoryData data, String key) {
    for (final setting in data.settings) {
      if (setting.key == key) return setting;
    }
    return null;
  }

  Future<void> _save(CategorySetting setting) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await widget.repository.saveCategorySetting(widget.trip.id, setting);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errorSaveCategory)));
      return;
    }
    if (mounted) _refresh();
  }

  bool _duplicateName(_CategoryData data, String exceptKey, String name) {
    final normalized = name.trim().toLowerCase();
    return data.keys
        .where((key) => key != exceptKey)
        .any(
          (key) =>
              categoryLabel(
                context,
                key,
                settings: data.settings,
              ).trim().toLowerCase() ==
              normalized,
        );
  }

  Future<void> _editCategory(_CategoryData data, String key) async {
    final setting = _settingFor(data, key);
    final result = await showDialog<CategorySetting>(
      context: context,
      builder: (_) => _CategoryEditorDialog(
        categoryKey: key,
        initialName: categoryLabel(context, key, settings: data.settings),
        initialIconKey: setting?.iconKey,
        hidden: setting?.hidden ?? false,
        isDuplicate: (name) => _duplicateName(data, key, name),
      ),
    );
    if (result != null) await _save(result);
  }

  Future<void> _addCategory(_CategoryData data) async {
    final key = 'custom_${const Uuid().v4()}';
    final result = await showDialog<CategorySetting>(
      context: context,
      builder: (_) => _CategoryEditorDialog(
        categoryKey: key,
        initialName: '',
        initialIconKey: 'label',
        hidden: false,
        isDuplicate: (name) => _duplicateName(data, key, name),
      ),
    );
    if (result != null) await _save(result);
  }

  Future<void> _hideCategory(_CategoryData data, String key) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.manageCategories),
        content: Text(
          l10n.hideCategoryConfirm(
            categoryLabel(context, key, settings: data.settings),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            key: Key('confirmHideCategory-$key'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final setting = _settingFor(data, key);
    await _save(
      CategorySetting(
        key: key,
        displayName: setting?.displayName,
        iconKey: setting?.iconKey,
        hidden: true,
      ),
    );
  }

  Future<void> _deleteCategory(_CategoryData data, String key) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final expenses = await widget.repository.getExpenses(widget.trip.id);
      if (!mounted) return;
      final count = expenses.where((expense) => expense.category == key).length;
      final targets = data.keys
          .where(
            (candidate) =>
                candidate != key &&
                !(_settingFor(data, candidate)?.hidden ?? false),
          )
          .toList();
      String? replacementKey;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(l10n.deleteCategory),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.deleteCategoryConfirm(
                    categoryLabel(context, key, settings: data.settings),
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(height: 12),
                  Text(l10n.moveCategoryExpenses(count)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: const Key('replacementCategoryField'),
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.replacementCategory,
                    ),
                    items: targets
                        .map(
                          (target) => DropdownMenuItem(
                            value: target,
                            child: Text(
                              categoryLabel(
                                context,
                                target,
                                settings: data.settings,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => replacementKey = value),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                key: Key('confirmDeleteCategory-$key'),
                onPressed: count > 0 && replacementKey == null
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                child: Text(l10n.deleteCategory),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true) return;
      await widget.repository.deleteCustomCategory(
        widget.trip.id,
        key,
        replacementKey: replacementKey,
      );
      if (mounted) _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errorDeleteCategory)));
    }
  }

  Future<void> _restoreCategory(_CategoryData data, String key) async {
    final setting = _settingFor(data, key);
    await _save(
      CategorySetting(
        key: key,
        displayName: setting?.displayName,
        iconKey: setting?.iconKey,
        hidden: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.manageCategories)),
      body: FutureBuilder<_CategoryData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text(l10n.errorSaveCategory));
          }
          final data = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: data.keys.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final key = data.keys[index];
              final setting = _settingFor(data, key);
              final hidden = setting?.hidden ?? false;
              return ListTile(
                key: Key('categorySetting-$key'),
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.secondaryContainer,
                  child: Icon(categoryIcon(key, settings: data.settings)),
                ),
                title: Text(
                  categoryLabel(context, key, settings: data.settings),
                ),
                subtitle: hidden ? Text(l10n.hiddenCategory) : null,
                onTap: () => _editCategory(data, key),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: Key('editCategory-$key'),
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _editCategory(data, key),
                    ),
                    if (!isBuiltInExpenseCategoryKey(key))
                      IconButton(
                        key: Key('deleteCategory-$key'),
                        tooltip: l10n.deleteCategory,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteCategory(data, key),
                      ),
                    if (hidden)
                      TextButton(
                        key: Key('restoreCategory-$key'),
                        onPressed: () => _restoreCategory(data, key),
                        child: Text(l10n.restoreCategory),
                      )
                    else
                      IconButton(
                        key: Key('hideCategory-$key'),
                        icon: const Icon(Icons.visibility_off_outlined),
                        onPressed: () => _hideCategory(data, key),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('addCategoryButton'),
        onPressed: () async {
          final data = await _future;
          if (mounted) await _addCategory(data);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CategoryEditorDialog extends StatefulWidget {
  final String categoryKey;
  final String initialName;
  final String? initialIconKey;
  final bool hidden;
  final bool Function(String name) isDuplicate;

  const _CategoryEditorDialog({
    required this.categoryKey,
    required this.initialName,
    required this.initialIconKey,
    required this.hidden,
    required this.isDuplicate,
  });

  @override
  State<_CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<_CategoryEditorDialog> {
  late final TextEditingController _nameController;
  late String _iconKey;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _iconKey = kCategoryIconChoices.containsKey(widget.initialIconKey)
        ? widget.initialIconKey!
        : 'label';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _confirm() {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l10n.errorEnterCategoryName);
      return;
    }
    if (widget.isDuplicate(name)) {
      setState(() => _error = l10n.errorDuplicateCategory);
      return;
    }
    Navigator.pop(
      context,
      CategorySetting(
        key: widget.categoryKey,
        displayName: name,
        iconKey: _iconKey,
        hidden: widget.hidden,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.category),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('categorySettingsNameField'),
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.categoryName,
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 20),
            Text(
              l10n.chooseCategoryIcon,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in kCategoryIconChoices.entries)
                  Tooltip(
                    message: entry.key,
                    child: ChoiceChip(
                      key: Key('categoryIcon-${entry.key}'),
                      label: Icon(entry.value, size: 20),
                      selected: _iconKey == entry.key,
                      onSelected: (_) => setState(() => _iconKey = entry.key),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          key: const Key('saveCategorySettingsButton'),
          onPressed: _confirm,
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}
