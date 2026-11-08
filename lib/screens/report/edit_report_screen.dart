import 'package:flutter/material.dart';

import '../../models/item_model.dart';
import '../../services/item_service.dart';
import '../../utils/helpers.dart';

class EditReportScreen extends StatefulWidget {
  final ItemModel item;
  const EditReportScreen({super.key, required this.item});
  @override
  State<EditReportScreen> createState() => _EditReportScreenState();
}

class _EditReportScreenState extends State<EditReportScreen> {
  late final _title = TextEditingController(text: widget.item.title);
  late final _description = TextEditingController(
    text: widget.item.description,
  );
  late String _location = widget.item.location;
  late String? _custody = widget.item.custodyLocation;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ItemService().editItem(
        widget.item.id,
        title: _title.text,
        description: _description.text,
        location: _location,
        custodyLocation: _custody,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not save. Use a title of at least 3 characters and a description of at least 10, then check your connection.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit your report')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        TextField(
          controller: _title,
          enabled: !_busy,
          maxLength: 120,
          decoration: const InputDecoration(labelText: 'Item title'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _description,
          enabled: !_busy,
          maxLines: 5,
          maxLength: 2000,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _location,
          decoration: const InputDecoration(labelText: 'Location'),
          items: {
            ...campusLocations,
            _location,
          }.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: _busy ? null : (s) => setState(() => _location = s!),
        ),
        const SizedBox(height: 16),
        if (widget.item.type == 'found')
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _custody,
            decoration: const InputDecoration(labelText: 'Current custody'),
            items: {
              ...custodyLocations,
              ?_custody,
            }.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: _busy ? null : (s) => setState(() => _custody = s),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(_error!),
          ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Saving…' : 'Save changes'),
        ),
      ],
    ),
  );
}
