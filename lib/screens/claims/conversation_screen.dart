import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/activity_provider.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../../models/claim_model.dart';
import '../../services/conversation_service.dart';

class ConversationScreen extends StatefulWidget {
  final ClaimModel claim;
  const ConversationScreen({super.key, required this.claim});
  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _text = TextEditingController();
  final _service = ConversationService();
  late Future<void> _ready;
  late final _messages = _service.messages(widget.claim.id);
  bool _sending = false;
  String? _readMessage;
  @override
  void initState() {
    super.initState();
    _ready = _service.open(widget.claim);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || _text.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await _service.send(widget.claim.id, _text.text);
      if (mounted) _text.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Message not sent. Your text is still here; please retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.claim.itemTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    body: SafeArea(
      child: FutureBuilder(
        future: _ready,
        builder: (context, ready) {
          if (ready.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not open this conversation.'),
                  TextButton(
                    onPressed: () =>
                        setState(() => _ready = _service.open(widget.claim)),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            );
          }
          if (ready.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Arrange a handover at an agreed campus office. Never send passwords or pay to recover an item.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ),
              Expanded(
                child: StreamBuilder(
                  stream: _messages,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text(
                          'Messages are unavailable. Reopen this conversation to retry.',
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data!.docs;
                    if (docs.isNotEmpty &&
                        docs.first.data()['senderId'] !=
                            FirebaseAuth.instance.currentUser?.uid &&
                        _readMessage != docs.first.id) {
                      _readMessage = docs.first.id;
                      WidgetsBinding.instance.addPostFrameCallback((_) async {
                        if (!mounted) return;
                        try {
                          await context
                              .read<ActivityProvider>()
                              .markMessageRead(widget.claim.id, docs.first.id);
                        } catch (_) {
                          if (mounted) _readMessage = null;
                        }
                      });
                    }
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'Start a private conversation about this claim.',
                        ),
                      );
                    }
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data();
                        final mine =
                            data['senderId'] ==
                            FirebaseAuth.instance.currentUser?.uid;
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * .78,
                            ),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: mine
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              data['text'] as String? ?? '',
                              style: TextStyle(
                                color: mine
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        enabled: !_sending,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                          hintText: 'Write a message',
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Send message',
                      onPressed: _sending ? null : _send,
                      icon: Icon(
                        _sending ? Icons.hourglass_top : Icons.send_rounded,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
