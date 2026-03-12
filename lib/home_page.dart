import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

class Note {
  final int id;
  final String texte;
  final DateTime date;
  final String? type;

  Note({required this.id, required this.texte, required this.date, this.type});

  factory Note.fromMap(Map<String, dynamic> map) => Note(
        id: map['id'],
        texte: map['texte'],
        date: DateTime.parse(map['date']),
        type: map['type'],
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
  bool _loading = true;
  String _username = '';

  @override
  void initState() {
    super.initState();
    _getUsername();
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
      final username = box.get('username');
      
      if (username == null) return;

      final data = await _supabase
          .from('notes')
          .select()
          .eq('username', username)
          .order('date', ascending: false);

      setState(() {
        _notes = (data as List).map((e) => Note.fromMap(e)).toList();
        _notes.sort((a, b) {
          int priorite(String? type) {
            if (type == 'Important') return 3;
            if (type == 'À regarder') return 2;
            if (type == 'Pas important') return 1;
            return 0;
          }
          return priorite(b.type).compareTo(priorite(a.type));
        });
        _loading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _addNote(String texte, String? type) async {
    final box = await Hive.openBox('auth');
    final username = box.get('username');
    
    if (username == null) return;

    await _supabase.from('notes').insert({
      'texte': texte,
      'date': DateTime.now().toIso8601String(),
      'type': type,
      'username': username,
    });
    _loadNotes();
  }

  Future<void> _updateNote(int id, String texte, String? type) async {
    await _supabase.from('notes').update({
      'texte': texte,
      'type': type,   
    }).eq('id', id);
    _loadNotes();
  }

  Future<void> _suppr(int id) async {
    await _supabase.from('notes').delete().eq('id', id);
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
    String? selectedType = note?.type;
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
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Priorité',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Aucune')),
                  DropdownMenuItem(value: 'Pas important', child: Text('🟢 Pas important')),
                  DropdownMenuItem(value: 'À regarder', child: Text('🟠 À regarder')),
                  DropdownMenuItem(value: 'Important', child: Text('🔴 Important')),
                ],
                onChanged: (value) {
                  setDialogState(() {
                    selectedType = value;
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
                    ? _updateNote(note.id, controller.text.trim(), selectedType) 
                    : _addNote(controller.text.trim(), selectedType);
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