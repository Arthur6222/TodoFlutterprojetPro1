import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

class Note {
  final int id;
  final String texte;
  final DateTime date;
  final String? type;
  final int? typeId;
  final int priorite;

  Note({
    required this.id,
    required this.texte,
    required this.date,
    this.type,
    this.typeId,
    this.priorite = 0,
  });

  factory Note.fromMap(Map<String, dynamic> map) => Note(
        id: map['id_notes'],
        texte: map['texte'],
        date: DateTime.parse(map['created_at']),
        type: map['type_label'],
        typeId: map['id__types'],
        priorite: map['type_priorite'] ?? 0,
      );
}

class NoteType {
  final int id;
  final String label;
  final int priorite;

  NoteType({required this.id, required this.label, required this.priorite});

  factory NoteType.fromMap(Map<String, dynamic> map) => NoteType(
        id: map['id__types'],
        label: map['label'],
        priorite: map['priorite'],
      );
}

class NotePage extends StatefulWidget {
  const NotePage({super.key});

  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  final _supabase = Supabase.instance.client;
  List<Note> _notes = [];
  List<NoteType> _types = [];
  bool _loading = true;
  String _username = '';

  @override
  void initState() {
    super.initState();
    _getUsername();
    _initData();
  }

  Future<void> _initData() async {
    await _loadTypes();
    await _loadNotes();
  }

  Future<void> _getUsername() async {
    final box = await Hive.openBox('auth');
    if (!mounted) return;
    setState(() => _username = box.get('username', defaultValue: 'Utilisateur'));
  }

  Future<void> _loadTypes() async {
    try {
      final data = await _supabase
          .from('types')
          .select('id__types, label, priorite')
          .order('priorite', ascending: false);

      if (!mounted) return;
      setState(() {
        _types = (data as List).map((e) => NoteType.fromMap(e)).toList();
      });
    } catch (e) {
      debugPrint('Erreur _loadTypes: $e');
    }
  }

  Future<void> _loadNotes() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final box = await Hive.openBox('auth');
      final idUser = box.get('id_user');

      if (idUser == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final data = await _supabase
          .from('notes')
          .select('id_notes, texte, created_at, id__types')
          .eq('id_user', idUser)
          .order('created_at', ascending: false);

      final typeById = {for (final t in _types) t.id: t};

      final mapped = (data as List).map((e) {
        final row = Map<String, dynamic>.from(e as Map);
        final rowTypeId = row['id__types'] as int?;
        final rowType = rowTypeId != null ? typeById[rowTypeId] : null;
        row['type_label'] = rowType?.label;
        row['type_priorite'] = rowType?.priorite ?? 0;
        return Note.fromMap(row);
      }).toList();

      if (!mounted) return;
      setState(() {
        _notes = mapped..sort((a, b) => b.priorite.compareTo(a.priorite));
        _loading = false;
      });
    } catch (e) {
      debugPrint('Erreur _loadNotes: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addNote(String texte, int? typeId) async {
    final box = await Hive.openBox('auth');
    final idUser = box.get('id_user');
    if (idUser == null) return;

    await _supabase.from('notes').insert({
      'texte': texte,
      'id__types': typeId,
      'id_user': idUser,
    });
    await _loadNotes();
  }

  Future<void> _updateNote(int id, String texte, int? typeId) async {
    await _supabase
        .from('notes')
        .update({'texte': texte, 'id__types': typeId}).eq('id_notes', id);
    await _loadNotes();
  }

  Future<void> _suppr(int id) async {
    await _supabase.from('notes').delete().eq('id_notes', id);
    await _loadNotes();
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: Text('Voulez-vous vraiment vous déconnecter, $_username ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final box = await Hive.openBox('auth');
      await box.delete('username');
      await box.delete('id_user');
    }
  }

  Color _couleur(String? type) {
    switch (type) {
      case 'Important':
        return Colors.red;
      case 'A regarder':
      case 'À regarder':
        return Colors.orange;
      case 'Pas important':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _showDialog({Note? note}) {
    final controller = TextEditingController(text: note?.texte ?? '');
    final isEditing = note != null;
    String? selectedValue = note?.typeId?.toString();
    int? selectedTypeId = note?.typeId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Modifier la note' : 'Ajouter une note'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Texte de la tâche',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedValue,
                decoration: const InputDecoration(
                  labelText: 'Priorité',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Aucune'),
                  ),
                  ..._types.map(
                    (t) => DropdownMenuItem<String>(
                      value: t.id.toString(),
                      child: Text(
                        t.label == 'Important'
                            ? '🔴 Important'
                            : t.label == 'Pas important'
                                ? '🟢 Pas important'
                                : '🟠 ${t.label}',
                      ),
                    ),
                  ),
                ],
                onChanged: (val) {
                  setDialogState(() {
                    selectedValue = val;
                    selectedTypeId =
                        val != null ? int.tryParse(val) : null;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                final texte = controller.text.trim();
                if (texte.isEmpty) return;
                Navigator.pop(ctx);
                if (isEditing) {
                  _updateNote(note.id, texte, selectedTypeId);
                } else {
                  _addNote(texte, selectedTypeId);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent[700],
                foregroundColor: Colors.black,
              ),
              child: Text(isEditing ? 'Modifier' : 'Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Flutter Supanotes',
          style: TextStyle(
            color: Colors.amberAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.white70, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    _username,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.note_add, color: Colors.amberAccent),
            onPressed: _showDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: _logout,
            tooltip: 'Se déconnecter',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.note_alt_outlined,
                          size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune note',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Appuyez sur + pour ajouter une note',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _notes.length,
                  itemBuilder: (ctx, i) {
                    final note = _notes[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 2,
                      child: ListTile(
                        leading: note.type != null
                            ? Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _couleur(note.type),
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null,
                        title: Text(
                          note.texte,
                          style: const TextStyle(fontSize: 16),
                        ),
                        subtitle: Text(
                          '${note.date.day.toString().padLeft(2, '0')}'
                          '/${note.date.month.toString().padLeft(2, '0')}'
                          '/${note.date.year}',
                          style: const TextStyle(color: Colors.blue),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_document,
                                  color: Colors.green),
                              onPressed: () => _showDialog(note: note),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_forever,
                                  color: Colors.red),
                              onPressed: () => _suppr(note.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
