import 'package:flutter/material.dart';

class EditableField extends StatefulWidget {
  final String label;
  final String value;
  final Function(String) onChanged;
  final bool isPassword;
  final bool isEditable;
  
  const EditableField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.isPassword = false,
    this.isEditable = true,
  });

  @override
  State<EditableField> createState() => _EditableFieldState();
}

class _EditableFieldState extends State<EditableField> {
  late TextEditingController _controller;
  bool _isEditing = false;
  
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }
  
  @override
  void didUpdateWidget(EditableField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.text = widget.value;
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        // Save changes
        widget.onChanged(_controller.text);
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              widget.label,
              style: const TextStyle(
                fontFamily: 'Rye',
                fontSize: 16,
                color: Colors.brown,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: _isEditing 
              ? TextField(
                  controller: _controller,
                  style: const TextStyle(
                    fontFamily: 'Rye',
                    fontSize: 16,
                    color: Colors.brown,
                  ),
                  obscureText: widget.isPassword,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  onSubmitted: (_) => _toggleEdit(),
                )
              : Text(
                  widget.isPassword ? '********' : widget.value,
                  style: const TextStyle(
                    fontFamily: 'Rye',
                    fontSize: 16,
                    color: Colors.brown,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
          ),
          if (widget.isEditable)
            IconButton(
              icon: Icon(
                _isEditing ? Icons.check : Icons.edit,
                color: Colors.brown,
              ),
              onPressed: _toggleEdit,
              tooltip: _isEditing ? 'Save' : 'Edit',
            ),
        ],
      ),
    );
  }
}
