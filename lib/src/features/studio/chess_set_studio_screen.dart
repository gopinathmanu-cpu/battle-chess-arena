// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../domain/custom_chess_set.dart';
import '../../domain/piece_pack.dart';
import '../../services/custom_chess_sets.dart';
import '../play/board_appearance.dart';
import '../play/chess_widgets.dart';
import '../../widgets/color_range_picker.dart';
import 'custom_piece.dart';

/// A local collection of original chess sets, with a draft-only editor.
class ChessSetStudioScreen extends StatefulWidget {
  const ChessSetStudioScreen({
    this.createOnOpen = false,
    this.initialSetId,
    super.key,
  });

  final bool createOnOpen;
  final String? initialSetId;

  @override
  State<ChessSetStudioScreen> createState() => _ChessSetStudioScreenState();
}

class _ChessSetStudioScreenState extends State<ChessSetStudioScreen> {
  bool _busy = false;
  bool _openedInitialEditor = false;

  String _newId() => 'set-${DateTime.now().microsecondsSinceEpoch}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_openedInitialEditor ||
        (!widget.createOnOpen && widget.initialSetId == null)) {
      return;
    }
    _openedInitialEditor = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _openInitialEditor());
  }

  Future<void> _openInitialEditor() async {
    if (!mounted) return;
    final library = CustomChessSetScope.of(context);
    await library.ready;
    if (!mounted) return;
    final initial = widget.createOnOpen
        ? CustomChessSet.create(id: _newId())
        : library.sets
              .where((set) => set.id == widget.initialSetId)
              .firstOrNull;
    if (initial == null) return;
    await _edit(library, initial);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _edit(CustomChessSets library, CustomChessSet draft) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _ChessSetEditor(library: library, initial: draft),
      ),
    );
  }

  Future<void> _operation(Future<bool> Function() action) async {
    setState(() => _busy = true);
    final success = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your changes. Please try again.'),
        ),
      );
    }
  }

  Future<void> _delete(CustomChessSets library, CustomChessSet set) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this chess set?'),
        content: Text(
          '“${set.name}” will be removed from this device. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep set'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _operation(() => library.delete(set.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = CustomChessSetScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Chess Set Studio')),
      body: !library.loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xff372756), Color(0xff152f40)],
                    ),
                    border: Border.all(
                      color: const Color(0xff8970ba).withValues(alpha: .4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        color: Color(0xffffd88b),
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your pieces. Your world.',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Build both armies from complete themed formations. Riders stay locked to their elephant, horse or chariot, so every combination remains seamless.',
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        key: const ValueKey('create-custom-set'),
                        onPressed: _busy
                            ? null
                            : () => _edit(
                                library,
                                CustomChessSet.create(id: _newId()),
                              ),
                        icon: const Icon(Icons.add),
                        label: const Text('Create a chess set'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'My collection',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Saved on this device. Using a set changes your view only, including during a game.',
                  style: TextStyle(color: Colors.white70),
                ),
                if (library.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    library.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (library.sets.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 22),
                    child: Text(
                      'A new army starts with your imagination. Create your first set above.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final set in library.sets) ...[
                  _LibrarySetCard(
                    chessSet: set,
                    active: set.id == library.activeId,
                    busy: _busy,
                    onUse: () => _operation(() => library.activate(set.id)),
                    onEdit: () => _edit(library, set),
                    onDuplicate: () {
                      var copy = CustomChessSet.create(
                        id: _newId(),
                        name: '${set.name} copy',
                      );
                      copy = copy.copyWith(
                        lightSquare: set.lightSquare,
                        darkSquare: set.darkSquare,
                        whiteAccent: set.whiteAccent,
                        blackAccent: set.blackAccent,
                        backgroundColor: set.backgroundColor,
                        surface: set.surface,
                        background: set.background,
                      );
                      for (final side in Side.values) {
                        for (final role in _roles) {
                          copy = copy.withDesign(
                            side,
                            role,
                            set.designFor(side, role),
                          );
                        }
                      }
                      _edit(library, copy);
                    },
                    onDelete: () => _delete(library, set),
                  ),
                  const SizedBox(height: 14),
                ],
                if (library.activeId != null)
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _operation(() => library.activate(null)),
                    icon: const Icon(Icons.layers_outlined),
                    label: const Text('Use my Classic / Themed set instead'),
                  ),
              ],
            ),
    );
  }
}

class _LibrarySetCard extends StatelessWidget {
  const _LibrarySetCard({
    required this.chessSet,
    required this.active,
    required this.busy,
    required this.onUse,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });
  final CustomChessSet chessSet;
  final bool active;
  final bool busy;
  final VoidCallback onUse;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(
        color: active ? Theme.of(context).colorScheme.primary : Colors.white12,
        width: active ? 2 : 1,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  chessSet.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Set options',
                enabled: !busy,
                onSelected: (value) =>
                    value == 'duplicate' ? onDuplicate() : onDelete(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          if (active)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xffbba6ff), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your active set',
                      style: TextStyle(
                        color: Color(0xffbba6ff),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 330),
              child: _StudioBoardPreview(chessSet: chessSet),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: busy ? null : onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
              FilledButton.icon(
                onPressed: busy || active ? null : onUse,
                icon: Icon(active ? Icons.check : Icons.check_circle_outline),
                label: Text(active ? 'In use' : 'Use this set'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

const _roles = [
  Role.king,
  Role.queen,
  Role.bishop,
  Role.knight,
  Role.rook,
  Role.pawn,
];
String _roleName(Role role) =>
    '${role.name[0].toUpperCase()}${role.name.substring(1)}';

class _ChessSetEditor extends StatefulWidget {
  const _ChessSetEditor({required this.library, required this.initial});
  final CustomChessSets library;
  final CustomChessSet initial;

  @override
  State<_ChessSetEditor> createState() => _ChessSetEditorState();
}

class _ChessSetEditorState extends State<_ChessSetEditor> {
  late CustomChessSet _draft = widget.initial;
  late final TextEditingController _name = TextEditingController(
    text: _draft.name,
  );
  final _form = GlobalKey<FormState>();
  Side _side = Side.white;
  Role _role = Role.knight;
  String _category = 'formation';
  int _tab = 0;
  bool _dirty = false;
  bool _saving = false;
  bool _allowPop = false;

  CustomPieceDesign get _design => _draft.designFor(_side, _role);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _update(CustomChessSet draft) => setState(() {
    _draft = draft;
    _dirty = true;
  });
  void _updateDesign(CustomPieceDesign design) =>
      _update(_draft.withDesign(_side, _role, design));

  Future<void> _close() async {
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _requestClose() async {
    if (_saving) return;
    if (!_dirty) return _close();
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard your changes?'),
        content: const Text('Your saved collection will not change.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) await _close();
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (_name.text.trim().isEmpty) {
      _form.currentState!.validate();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give your set a name before saving.')),
      );
      return;
    }
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final success = await widget.library.save(
      _draft.copyWith(name: _name.text.trim()),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (success) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your chess set is saved and ready to play.'),
        ),
      );
      await _close();
    } else {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.library.error ??
                'Could not save your set. Your draft is still here; please try again.',
          ),
        ),
      );
    }
  }

  Future<void> _reset() async {
    final reset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset this draft?'),
        content: const Text(
          'This resets the pieces, board and background. Your saved set will only change when you save.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset draft'),
          ),
        ],
      ),
    );
    if (reset == true && mounted) {
      _update(CustomChessSet.create(id: _draft.id, name: _name.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop || (!_dirty && !_saving),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _requestClose),
          title: const Text('Design your set'),
          actions: [
            IconButton(
              onPressed: _saving ? null : _reset,
              tooltip: 'Reset draft',
              icon: const Icon(Icons.restart_alt),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                if (_tab == 0) ...[
                  Semantics(
                    image: true,
                    label: 'Live ${_side.name} ${_role.name} preview',
                    child: SizedBox.square(
                      dimension: 64,
                      child: ExcludeSemantics(
                        child: CustomPiece(
                          key: const ValueKey('studio-live-preview'),
                          piece: Piece(color: _side, role: _role),
                          chessSet: _draft,
                          showRole: false,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('save-custom-set'),
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(_saving ? 'Saving…' : 'Save & use this set'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: Form(
          key: _form,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 700;
              final controls = <Widget>[
                TextFormField(
                  key: const ValueKey('custom-set-name'),
                  controller: _name,
                  enabled: !_saving,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  maxLength: 40,
                  decoration: const InputDecoration(
                    labelText: 'Chess set name',
                    prefixIcon: Icon(Icons.edit_outlined),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() => _dirty = true),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Give your set a name.'
                      : null,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (index, title, icon) in [
                      (0, 'Pieces', Icons.auto_awesome),
                      (1, 'Board', Icons.grid_view),
                      (2, 'Background', Icons.landscape_outlined),
                    ])
                      ChoiceChip(
                        key: ValueKey('studio-tab-$index'),
                        avatar: Icon(icon, size: 18),
                        label: Text(title),
                        selected: _tab == index,
                        onSelected: _saving
                            ? null
                            : (_) => setState(() => _tab = index),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                if (_tab == 0) ..._pieceControls(context),
                if (_tab == 1) ..._boardControls(context),
                if (_tab == 2) ..._backgroundControls(context),
              ];
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: math.min(380, constraints.maxWidth * .42),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: _preview(),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(12, 16, 20, 28),
                        children: controls,
                      ),
                    ),
                  ],
                );
              }
              return ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: _tab == 0 ? 220 : 320,
                      ),
                      child: _preview(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ...controls,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _preview() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_tab == 0)
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: WorldBackdrop(
            pack: piecePacks.first,
            playSoundtrack: false,
            customSet: _draft,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  SizedBox.square(
                    dimension: 164,
                    child: CustomPiece(
                      piece: Piece(color: _side, role: _role),
                      chessSet: _draft,
                      showRole: false,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_side == Side.white ? 'White' : 'Black'} ${_roleName(_role)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        )
      else
        _StudioBoardPreview(chessSet: _draft),
      const SizedBox(height: 8),
      const Text(
        'LIVE PREVIEW',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.white60),
      ),
    ],
  );

  List<Widget> _pieceControls(BuildContext context) {
    return [
      const _SectionTitle('Choose an army'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final side in Side.values)
            ChoiceChip(
              key: ValueKey('studio-side-${side.name}'),
              avatar: Icon(
                side == Side.white ? Icons.circle_outlined : Icons.circle,
                size: 18,
              ),
              label: Text(side == Side.white ? 'White army' : 'Black army'),
              selected: _side == side,
              onSelected: _saving ? null : (_) => setState(() => _side = side),
            ),
        ],
      ),
      const SizedBox(height: 16),
      const _SectionTitle('Choose a piece'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final role in _roles)
            ChoiceChip(
              key: ValueKey('studio-role-${role.name}'),
              label: Text(_roleName(role)),
              selected: _role == role,
              onSelected: _saving
                  ? null
                  : (_) => setState(() {
                      _role = role;
                      if (!CustomPieceParts.supportedCategories(
                        role,
                      ).contains(_category)) {
                        _category = CustomPieceParts.supportedCategories(
                          role,
                        ).first;
                      }
                    }),
            ),
        ],
      ),
      const SizedBox(height: 18),
      _SectionTitle(CustomPieceParts.formationName(_role)),
      const Text(
        'Choose one complete, pre-aligned formation. Mount, rider, face, costume and weapon move together.',
        style: TextStyle(color: Colors.white60),
      ),
      const SizedBox(height: 14),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 600 ? 4 : 2;
          final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var variant = 0; variant < 4; variant++)
                SizedBox(
                  width: width,
                  child: _PartOption(
                    key: ValueKey('studio-part-$_category-$variant'),
                    category: _category,
                    variant: variant,
                    role: _role,
                    side: _side,
                    label: CustomPieceParts.labels(_category)[variant],
                    selected: _partValue(_category) == variant,
                    onTap: _saving ? null : () => _setPart(_category, variant),
                  ),
                ),
            ],
          );
        },
      ),
      const Text(
        'All formations share one baseline and full-square height. Black formations mirror as a whole and keep bright faces and accessories.',
        style: TextStyle(color: Colors.white60),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        key: const ValueKey('studio-apply-army-formation'),
        onPressed: _saving
            ? null
            : () {
                var next = _draft;
                for (final role in _roles) {
                  next = next.withDesign(
                    _side,
                    role,
                    next
                        .designFor(_side, role)
                        .copyWith(costume: _design.costume, scale: 1),
                  );
                }
                _update(next);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${CustomPieceParts.labels(_category)[_design.costume]} applied to the whole ${_side.name} army.',
                    ),
                  ),
                );
              },
        icon: const Icon(Icons.groups_2_outlined),
        label: const Text('Apply this formation style to the whole army'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        key: const ValueKey('studio-copy-piece'),
        onPressed: _saving
            ? null
            : () {
                final other = _side == Side.white ? Side.black : Side.white;
                _update(_draft.withDesign(other, _role, _design));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${_roleName(_role)} design copied to the ${other.name} army.',
                    ),
                  ),
                );
              },
        icon: const Icon(Icons.copy_all_outlined),
        label: const Text('Copy this piece to the other army'),
      ),
    ];
  }

  int _partValue(String category) => _design.costume;

  void _setPart(String category, int value) =>
      _updateDesign(_design.copyWith(costume: value, scale: 1));

  List<Widget> _boardControls(BuildContext context) {
    const palettes = [
      ('Royal plum', 0xffe8dcf1, 0xff674979),
      ('Forest', 0xffe7e8cf, 0xff45654f),
      ('Walnut', 0xffefdab6, 0xff805638),
      ('Ocean', 0xffd7e8ed, 0xff346378),
      ('Tournament', 0xffefefef, 0xff47494f),
      ('Neon', 0xff6db4b3, 0xff16383e),
    ];
    final light = Color(_draft.lightSquare);
    final dark = Color(_draft.darkSquare);
    return [
      const _SectionTitle('Start with a palette'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (label, light, dark) in palettes)
            ChoiceChip(
              key: ValueKey('studio-palette-$label'),
              label: Text(label),
              avatar: _PaletteSwatch(light: Color(light), dark: Color(dark)),
              selected:
                  _draft.lightSquare == light && _draft.darkSquare == dark,
              onSelected: _saving
                  ? null
                  : (_) => _update(
                      _draft.copyWith(lightSquare: light, darkSquare: dark),
                    ),
            ),
        ],
      ),
      const SizedBox(height: 20),
      const _SectionTitle('Fine-tune your colours'),
      _ColorControl(
        label: 'Light squares',
        value: _draft.lightSquare,
        onChanged: _saving
            ? null
            : (value) => _update(_draft.copyWith(lightSquare: value)),
      ),
      _ColorControl(
        label: 'Dark squares',
        value: _draft.darkSquare,
        onChanged: _saving
            ? null
            : (value) => _update(_draft.copyWith(darkSquare: value)),
      ),
      _ColorControl(
        label: 'White army accent',
        value: _draft.whiteAccent,
        onChanged: _saving
            ? null
            : (value) => _update(_draft.copyWith(whiteAccent: value)),
      ),
      _ColorControl(
        label: 'Black army accent',
        value: _draft.blackAccent,
        onChanged: _saving
            ? null
            : (value) => _update(_draft.copyWith(blackAccent: value)),
      ),
      if ((light.computeLuminance() - dark.computeLuminance()).abs() < .15)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text(
            'Tip: increase the contrast between light and dark squares so your board is easier to read.',
            style: TextStyle(color: Color(0xffffd88b)),
          ),
        ),
      const SizedBox(height: 16),
      const _SectionTitle('Board finish'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final surface in CustomBoardSurface.values)
            ChoiceChip(
              key: ValueKey('studio-surface-${surface.name}'),
              avatar: Icon(switch (surface) {
                CustomBoardSurface.solid => Icons.square_outlined,
                CustomBoardSurface.wood => Icons.forest_outlined,
                CustomBoardSurface.marble => Icons.blur_on,
                CustomBoardSurface.neon => Icons.flare,
              }, size: 18),
              label: Text(_titleCase(surface.name)),
              selected: _draft.surface == surface,
              onSelected: _saving
                  ? null
                  : (_) => _update(_draft.copyWith(surface: surface)),
            ),
        ],
      ),
    ];
  }

  List<Widget> _backgroundControls(BuildContext context) => [
    const _SectionTitle('Set the scene'),
    const Text(
      'Choose a world for your pieces to call home.',
      style: TextStyle(color: Colors.white70),
    ),
    const SizedBox(height: 14),
    LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 600 ? 3 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final background in CustomBackground.values)
              SizedBox(
                width: width,
                child: _BackgroundOption(
                  key: ValueKey('studio-background-${background.name}'),
                  chessSet: _draft.copyWith(background: background),
                  selected: _draft.background == background,
                  onTap: _saving
                      ? null
                      : () => _update(_draft.copyWith(background: background)),
                ),
              ),
          ],
        );
      },
    ),
    const SizedBox(height: 20),
    _ColorControl(
      label: 'Background accent',
      value: _draft.backgroundColor,
      onChanged: _saving
          ? null
          : (value) => _update(_draft.copyWith(backgroundColor: value)),
    ),
  ];
}

String _titleCase(String value) =>
    '${value[0].toUpperCase()}${value.substring(1)}';
String _backgroundName(CustomBackground background) => switch (background) {
  CustomBackground.anime => 'Manga skies',
  CustomBackground.indianEpic => 'Epic palace',
  CustomBackground.greek => 'Olympian heights',
  CustomBackground.futuristic => 'Neon city',
  CustomBackground.midnight => 'Midnight',
  CustomBackground.forest => 'Forest',
  CustomBackground.royal => 'Royal velvet',
};

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

class _StudioBoardPreview extends StatelessWidget {
  const _StudioBoardPreview({required this.chessSet});
  final CustomChessSet chessSet;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: '${chessSet.name}, full chessboard preview',
    child: ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: WorldBackdrop(
          pack: piecePacks.first,
          playSoundtrack: false,
          customSet: chessSet,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: AspectRatio(
              aspectRatio: 1,
              child: RepaintBoundary(
                child: IgnorePointer(
                  child: ChessBoard(
                    position: Chess.initial,
                    selected: null,
                    legalTargets: const {},
                    accent: Color(chessSet.whiteAccent),
                    appearance: BoardAppearance(
                      white: piecePacks.first,
                      black: piecePacks.first,
                      board: piecePacks.first,
                      customSet: chessSet,
                    ),
                    onSquareTap: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _PartOption extends StatelessWidget {
  const _PartOption({
    required this.category,
    required this.variant,
    required this.role,
    required this.side,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });
  final String category;
  final int variant;
  final Role role;
  final Side side;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    label: label,
    child: Material(
      color: selected ? const Color(0xff302844) : const Color(0xff1b1c2b),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white12,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 100,
                child: CustomPartThumbnail(
                  category: category,
                  variant: variant,
                  role: role,
                  side: side,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 4),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 18,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white38,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _BackgroundOption extends StatelessWidget {
  const _BackgroundOption({
    required this.chessSet,
    required this.selected,
    required this.onTap,
    super.key,
  });
  final CustomChessSet chessSet;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: const Color(0xff1b1c2b),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white12,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 88,
                width: double.infinity,
                child: WorldBackdrop(
                  pack: piecePacks.first,
                  playSoundtrack: false,
                  customSet: chessSet,
                  child: Center(
                    child: Icon(
                      selected ? Icons.check_circle : Icons.landscape_outlined,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  _backgroundName(chessSet.background),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PaletteSwatch extends StatelessWidget {
  const _PaletteSwatch({required this.light, required this.dark});
  final Color light;
  final Color dark;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: SizedBox.square(
      dimension: 20,
      child: Row(
        children: [
          Expanded(
            child: ColoredBox(color: light, child: const SizedBox.expand()),
          ),
          Expanded(
            child: ColoredBox(color: dark, child: const SizedBox.expand()),
          ),
        ],
      ),
    ),
  );
}

class _ColorControl extends StatelessWidget {
  const _ColorControl({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final int value;
  final ValueChanged<int>? onChanged;

  Future<void> _choose(BuildContext context) async {
    final result = await showDialog<int>(
      context: context,
      builder: (_) => _ColourDialog(label: label, initial: value),
    );
    if (result != null) onChanged?.call(result);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      type: MaterialType.transparency,
      child: ListTile(
        key: ValueKey('studio-colour-$label'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white12),
        ),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Color(value),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white54),
          ),
        ),
        title: Text(label),
        subtitle: const Text('Tap to choose from the full colour range'),
        trailing: const Icon(
          Icons.palette_rounded,
          size: 20,
          color: Color(0xFFFF8A65),
        ),
        enabled: onChanged != null,
        onTap: onChanged == null ? null : () => _choose(context),
      ),
    ),
  );
}

class _ColourDialog extends StatefulWidget {
  const _ColourDialog({required this.label, required this.initial});
  final String label;
  final int initial;

  @override
  State<_ColourDialog> createState() => _ColourDialogState();
}

class _ColourDialogState extends State<_ColourDialog> {
  late HSVColor _hsv = HSVColor.fromColor(Color(widget.initial));
  int get _value => _hsv.toColor().toARGB32();
  static const _swatches = [
    0xfff3e6cf,
    0xfff7f7f7,
    0xffd9c0ec,
    0xff7e579f,
    0xffc49757,
    0xff79563d,
    0xffa2caba,
    0xff37694e,
    0xff72b4cc,
    0xff254967,
    0xffda788d,
    0xff35333b,
  ];

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.label),
    scrollable: true,
    content: SizedBox(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 56,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Color(_value),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white38),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final color in _swatches)
                Semantics(
                  label: 'Colour ${color.toRadixString(16).substring(2)}',
                  selected: _value == color,
                  button: true,
                  child: InkWell(
                    onTap: () => setState(() {
                      _hsv = HSVColor.fromColor(Color(color));
                    }),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Color(color),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _value == color
                              ? Colors.white
                              : Colors.white38,
                          width: _value == color ? 3 : 1,
                        ),
                      ),
                      child: _value == color
                          ? Icon(
                              Icons.check,
                              color: Color(color).computeLuminance() > .5
                                  ? Colors.black
                                  : Colors.white,
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ColorRangePicker(
            key: const ValueKey('studio-colour-range'),
            value: _hsv,
            onChanged: (value) => setState(() => _hsv = value),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _value),
        child: const Text('Apply colour'),
      ),
    ],
  );
}
