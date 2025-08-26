import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:diary_mobile/providers/page_provider.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class NoteViewDialog extends StatefulWidget {
  const NoteViewDialog({super.key});

  @override
  State<NoteViewDialog> createState() => _NoteViewDialogState();
}

class _NoteViewDialogState extends State<NoteViewDialog> {
  final TextEditingController _noteController = TextEditingController();
  bool _isEditing = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        Provider.of<PageProvider>(context, listen: false).fetchNoteByDiary(1);
      }
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    final pageProvider = Provider.of<PageProvider>(context, listen: false);
    await pageProvider.updateOrCreateNote(1, _noteController.text);
    if (!mounted) {
      return;
    }
    if (pageProvider.errorMessage != null) {
      showTopSnackBar(
        Overlay.of(context),
        CustomSnackBar.error(message: 'Error: ${pageProvider.errorMessage}'),
        displayDuration: Durations.short1,
      );
    } else {
      showTopSnackBar(
        Overlay.of(context),
        const CustomSnackBar.success(message: 'Note saved successfully!'),
        displayDuration: Durations.short1,
      );
    }

    setState(() {
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.only(top: 20, left: 24, right: 24),
      contentPadding: const EdgeInsets.all(24),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text("Note", style: TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: double.maxFinite,
        child: Consumer<PageProvider>(
          builder: (context, pageProvider, child) {
            if (!_isEditing &&
                pageProvider.note != null &&
                _noteController.text.isEmpty) {
              _noteController.text = pageProvider.note!.description;
            }

            if (pageProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (pageProvider.errorMessage != null) {
              return Text("Error: ${pageProvider.errorMessage}");
            } else {
              return SingleChildScrollView(
                child: GestureDetector(
                  onTap: () {
                    if (!_isEditing) {
                      setState(() {
                        _isEditing = true;
                      });
                    }
                  },
                  child: TextField(
                    controller: _noteController,
                    enabled: _isEditing,
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: "Start writing your note...",
                      hintStyle: TextStyle(color: Colors.grey[400]),
                    ),
                    style: TextStyle(
                      fontSize: 16,
                      color: _isEditing ? Colors.black : Colors.grey[700],
                    ),
                  ),
                ),
              );
            }
          },
        ),
      ),
      actions: [
        if (_isEditing)
          TextButton(
            onPressed: () {
              setState(() {
                _isEditing = false;
                _noteController.text =
                    Provider.of<PageProvider>(
                      context,
                      listen: false,
                    ).note?.description ??
                    '';
              });
            },
            child: const Text("Cancel"),
          ),
        TextButton(
          onPressed: _isEditing ? _saveNote : () => Navigator.of(context).pop(),
          child: Text(
            _isEditing ? "Save" : "Close",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
