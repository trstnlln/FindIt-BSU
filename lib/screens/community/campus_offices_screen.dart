import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/community_service.dart';
import '../../utils/helpers.dart';

class CampusOfficesScreen extends StatefulWidget {
  const CampusOfficesScreen({super.key});
  @override
  State<CampusOfficesScreen> createState() => _CampusOfficesScreenState();
}

class _CampusOfficesScreenState extends State<CampusOfficesScreen> {
  late final _offices = FirebaseFirestore.instance
      .collection('campusOffices')
      .snapshots();
  late final _moderator = CommunityService().canModerate();
  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _moderator,
    builder: (context, access) => Scaffold(
      appBar: AppBar(title: const Text('Campus pickup offices')),
      floatingActionButton: access.data == true
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const _OfficeEditor()),
              ),
              icon: const Icon(Icons.edit_location_alt_outlined),
              label: const Text('Publish office details'),
            )
          : null,
      body: StreamBuilder(
        stream: _offices,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Could not load office details. Please retry.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Office hours have not been published yet. Confirm directly with the campus office before travelling.',
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: snapshot.data!.docs.map((doc) {
              final d = doc.data();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d['name'] as String? ?? 'Campus office',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        [
                          d['hours'],
                          d['location'],
                          d['instructions'],
                        ].whereType<String>().join('\n'),
                      ),
                      if (access.data == true)
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => _OfficeEditor(data: d),
                            ),
                          ),
                          child: const Text('Edit published details'),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    ),
  );
}

class _OfficeEditor extends StatefulWidget {
  final Map<String, dynamic>? data;
  const _OfficeEditor({this.data});
  @override
  State<_OfficeEditor> createState() => _OfficeEditorState();
}

class _OfficeEditorState extends State<_OfficeEditor> {
  late String _name = widget.data?['name'] as String? ?? custodyLocations[1];
  late final _hours = TextEditingController(
    text: widget.data?['hours'] as String? ?? '',
  );
  late final _location = TextEditingController(
    text: widget.data?['location'] as String? ?? '',
  );
  late final _instructions = TextEditingController(
    text: widget.data?['instructions'] as String? ?? '',
  );
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _hours.dispose();
    _location.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_hours.text.trim().isEmpty || _location.text.trim().isEmpty) {
      setState(
        () => _error = 'Enter confirmed opening hours and an office location.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final id = base64Url.encode(utf8.encode(_name)).replaceAll('=', '');
      await FirebaseFirestore.instance.collection('campusOffices').doc(id).set({
        'name': _name,
        'hours': _hours.text.trim(),
        'location': _location.text.trim(),
        'instructions': _instructions.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not publish these details. Confirm moderator access and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Publish office details')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Publish only hours and instructions confirmed by the campus office.',
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          initialValue: _name,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Campus office'),
          items: custodyLocations
              .where((s) => s != 'With Finder (Not Surrendered)')
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: widget.data != null || _busy
              ? null
              : (s) => setState(() => _name = s!),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _hours,
          enabled: !_busy,
          maxLength: 300,
          decoration: const InputDecoration(
            labelText: 'Confirmed opening hours',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _location,
          enabled: !_busy,
          maxLength: 300,
          decoration: const InputDecoration(labelText: 'Building / room'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _instructions,
          enabled: !_busy,
          maxLength: 1000,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Handover instructions'),
        ),
        if (_error != null) Text(_error!),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Publishing…' : 'Publish details'),
        ),
      ],
    ),
  );
}
