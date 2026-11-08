import 'package:flutter/material.dart';

import '../../services/community_service.dart';

class ReportConcernScreen extends StatefulWidget {
  final String itemId;
  const ReportConcernScreen({super.key, required this.itemId});
  @override
  State<ReportConcernScreen> createState() => _ReportConcernScreenState();
}

class _ReportConcernScreenState extends State<ReportConcernScreen> {
  final _details = TextEditingController();
  String _reason = 'False report';
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await CommunityService().flagItem(widget.itemId, _reason, _details.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Concern sent to campus moderators.')),
        );
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not send your concern. Your details are still here; please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Report a concern')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Help keep the campus community safe',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        const Text(
          'Reports are reviewed by authorized campus moderators. Do not include passwords or private verification answers.',
        ),
        const SizedBox(height: 24),
        DropdownButtonFormField<String>(
          initialValue: _reason,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Reason'),
          items: [
            'False report',
            'Suspicious claim or scam',
            'Inappropriate photo',
            'Spam',
            'Other',
          ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: _busy ? null : (value) => setState(() => _reason = value!),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _details,
          enabled: !_busy,
          maxLength: 2000,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'What happened? (optional)',
          ),
        ),
        if (_error != null) Text(_error!),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _send,
          child: Text(_busy ? 'Sending…' : 'Send concern'),
        ),
      ],
    ),
  );
}
