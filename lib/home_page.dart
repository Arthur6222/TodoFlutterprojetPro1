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

  factory Note.fromMap(Map<String, dynamic> map) {
    final typeData = map['types'];
    final typeMap = typeData is List
        ? (typeData.isNotEmpty ? typeData.first as Map<String, dynamic> : null)
        : (typeData as Map<String, dynamic>?);

    return Note(
      id: map['id_notes'],
      texte: map['texte'],
      date: DateTime.parse(map['created_at']),
      type: typeMap?['label'],
      typeId: map['id__types'],
      priorite: typeMap?['priorite'] ?? 0,
    );
  }
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
    _loadTypes();
    _loadNotes();
  }

  Future<void> _getUsername() async {
    final box = await Hive.openBox('auth');
    setState(() {
      _username = box.get('username', defaultValue: 'Utilisateur');
    });
  }

  Future<void> _loadNotes() async {
    setState(() => _loading = true);
    try {
      final box = await Hive.openBox('auth');
      final idUser = box.get('id_user');
      
      if (idUser == null) {
        setState(() => _loading = false);
        return;
      }

      final data = await _supabase
          .from('notes')
          .select('id_notes, texte, created_at, id__types, types(label, priorite)')
          .eq('id_user', idUser)
          .order('created_at', ascending: false);

      setState(() {
        _notes = (data as List).map((e) => Note.fromMap(e)).toList();
        _notes.sort((a, b) => b.priorite.compareTo(a.priorite));
        _loading = false;
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _loadTypes() async {
    try {
      final data = await _supabase
          .from('types')
          .select('id__types, label, priorite')
          .order('priorite', ascending: false);

      setState(() {
        _types = (data as List).map((e) => NoteType.fromMap(e)).toList();
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement des types: $e');
    }
  }

  Future<void> _addNote(String texte, int? typeId) async {
    final box = await Hive.openBox('auth');
    final idUser = box.get('id_user');
    
    if (idUser == null) return;

    await _supabase.from('notes').insert({
      'texte': texte,
      'created_at': DateTime.now().toIso8601String(),
      'id__types': typeId,
      'id_user': idUser,
    });
    _loadNotes();
  }

  Future<void> _updateNote(int id, String texte, int? typeId) async {
    await _supabase.from('notes').update({
      'texte': texte,
      'id__types': typeId,   
    }).eq('id_notes', id);
    _loadNotes();
  }

  Future<void> _suppr(int id) async {
    await _supabase.from('notes').delete().eq('id_notes', id);
    _loadNotes();
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
    int? selectedTypeId = note?.typeId;
    final isEditing = note != null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(  
          title: Text(isEditing ? 'Modifier' : 'Ajouter'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: 'Texte de la tâche'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedTypeId?.toString(),
                decoration: const InputDecoration(
                  labelText: 'Priorité',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(value: '', child: Text('Aucune')),
                  ..._types.map(
                    (t) => DropdownMenuItem<String>(
                      value: t.id.toString(),
                      child: Text(t.label),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setDialogState(() {
                    selectedTypeId =
                        (value == null || value.isEmpty) ? null : int.tryParse(value);
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
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(ctx);
                  isEditing 
                    ? _updateNote(note.id, controller.text.trim(), selectedTypeId) 
                    : _addNote(controller.text.trim(), selectedTypeId);
                }
              },
              child: Text(isEditing ? 'Modifier' : 'Ajouter'),
            ),
          ],
        ),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Flutter Supanotes',
          style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        actions: [
          // Affichage du username
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
            onPressed: () => _showDialog(), 
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
                      Icon(
                        Icons.note_alt_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
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
                          '${note.date.day.toString().padLeft(2, '0')}/${note.date.month.toString().padLeft(2, '0')}/${note.date.year}',
                          style: const TextStyle(color: Colors.blue),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_document, color: Colors.green),
                              onPressed: () => _showDialog(note: note),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_forever, color: Colors.red),
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