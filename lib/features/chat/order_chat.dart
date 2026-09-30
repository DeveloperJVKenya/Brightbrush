import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../l10n/app_localizations.dart';
import '../../core/logging/stream_error_logger.dart';

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.from,
    required this.fromRole,
    required this.fromName,
    required this.text,
    required this.attachments,
    required this.at,
  });

  final String id;
  final String from;
  final String fromRole;
  final String fromName;
  final String text;
  final List<Map<String, dynamic>> attachments;
  final DateTime at;

  factory ChatMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return ChatMessage(
      id: doc.id,
      from: d['from'] as String? ?? '',
      fromRole: d['fromRole'] as String? ?? 'customer',
      fromName: d['fromName'] as String? ?? '',
      text: d['text'] as String? ?? '',
      attachments: [
        for (final a in (d['attachments'] as List? ?? const []))
          Map<String, dynamic>.from(a as Map),
      ],
      at: (d['at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

final _messagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, orderId) {
      return ref
          .watch(firestoreProvider)
          .collection('Orders')
          .doc(orderId)
          .collection('Messages')
          .orderBy('at')
          .limitToLast(200)
          .snapshots()
          .map((s) => s.docs.map(ChatMessage.fromFirestore).toList())
          .transform(logStreamErrors('[chat] messages($orderId) failed'));
    });

/// Unread counters for an order's chat.
final chatStateProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, orderId) {
      return ref
          .watch(firestoreProvider)
          .collection('Orders')
          .doc(orderId)
          .collection('ChatState')
          .doc('state')
          .snapshots()
          .map((s) => s.data() ?? const <String, dynamic>{})
          .handleError((Object _) => const <String, dynamic>{});
    });

/// "Message us about this order" — opens the thread.
class OrderChatButton extends ConsumerWidget {
  const OrderChatButton({
    super.key,
    required this.orderId,
    required this.orderLabel,
    required this.asStaff,
  });

  final String orderId;
  final String orderLabel;
  final bool asStaff;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatStateProvider(orderId)).valueOrNull ?? const {};
    final unread =
        (state[asStaff ? 'staffUnread' : 'customerUnread'] as num?)?.toInt() ??
        0;
    return OutlinedButton.icon(
      onPressed: () => showOrderChat(
        context,
        orderId: orderId,
        orderLabel: orderLabel,
        asStaff: asStaff,
      ),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: const Icon(Icons.chat_bubble_outline_rounded),
      ),
      label: Text(
        asStaff ? 'Chat with customer' : AppLocalizations.of(context).messageUs,
      ),
    );
  }
}

Future<void> showOrderChat(
  BuildContext context, {
  required String orderId,
  required String orderLabel,
  required bool asStaff,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.85,
      child: _ChatSheet(
        orderId: orderId,
        orderLabel: orderLabel,
        asStaff: asStaff,
      ),
    ),
  );
}

class _ChatSheet extends ConsumerStatefulWidget {
  const _ChatSheet({
    required this.orderId,
    required this.orderLabel,
    required this.asStaff,
  });

  final String orderId;
  final String orderLabel;
  final bool asStaff;

  @override
  ConsumerState<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends ConsumerState<_ChatSheet> {
  final _text = TextEditingController();
  final List<Map<String, dynamic>> _pending = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _markRead();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    try {
      await ref
          .read(firestoreProvider)
          .collection('Orders')
          .doc(widget.orderId)
          .collection('ChatState')
          .doc('state')
          .update({widget.asStaff ? 'staffUnread' : 'customerUnread': 0});
    } catch (_) {
      // No messages yet (state doc missing) — nothing to clear.
    }
  }

  Future<void> _attach() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'pdf'],
    );
    if (file == null) return;
    if ((await file.length() ?? 0) > 10 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Files must be under 10 MB.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    setState(() => _sending = true);
    try {
      final isPdf = file.name.toLowerCase().endsWith('.pdf');
      final path =
          'chat/${widget.orderId}/${DateTime.now().millisecondsSinceEpoch}_${file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}';
      final task = await ref
          .read(firebaseStorageProvider)
          .ref(path)
          .putData(
            await file.xFile.readAsBytes(),
            SettableMetadata(
              contentType: isPdf
                  ? 'application/pdf'
                  : 'image/${file.name.split('.').last.toLowerCase().replaceAll('jpg', 'jpeg')}',
            ),
          );
      _pending.add({
        'url': await task.ref.getDownloadURL(),
        'name': file.name,
        'type': isPdf ? 'pdf' : 'image',
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty && _pending.isEmpty) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(firestoreProvider)
          .collection('Orders')
          .doc(widget.orderId)
          .collection('Messages')
          .add({
            'from': user.uid,
            'fromRole': widget.asStaff ? 'staff' : 'customer',
            'fromName': widget.asStaff
                ? 'BrightBrush'
                : (user.displayName ?? 'Customer').substring(
                    0,
                    (user.displayName ?? 'Customer').length.clamp(0, 80),
                  ),
            'text': text,
            'attachments': _pending,
            'at': FieldValue.serverTimestamp(),
          });
      _text.clear();
      _pending.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uid = ref.watch(currentUidProvider);
    final messages =
        ref.watch(_messagesProvider(widget.orderId)).valueOrNull ?? const [];
    ref.listen(_messagesProvider(widget.orderId), (_, _) => _markRead());
    final fmt = DateFormat('d MMM, HH:mm');
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Messages · ${widget.orderLabel}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Text(
                      widget.asStaff
                          ? 'No messages yet.'
                          : 'Questions about sizes, placement or delivery? Send us a message.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    children: [
                      for (final m in messages.reversed)
                        Align(
                          alignment: m.from == uid
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 420),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: m.from == uid
                                  ? theme.colorScheme.primaryContainer
                                  : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (m.from != uid)
                                  Text(
                                    m.fromName,
                                    style: theme.textTheme.labelSmall,
                                  ),
                                if (m.text.isNotEmpty) SelectableText(m.text),
                                for (final a in m.attachments)
                                  a['type'] == 'image'
                                      ? GestureDetector(
                                          onTap: () => launchUrl(
                                            Uri.parse(a['url'] as String),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6,
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.network(
                                                a['url'] as String,
                                                height: 160,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                        )
                                      : TextButton.icon(
                                          onPressed: () => launchUrl(
                                            Uri.parse(a['url'] as String),
                                          ),
                                          icon: const Icon(
                                            Icons.picture_as_pdf_outlined,
                                          ),
                                          label: Text('${a['name']}'),
                                        ),
                                Text(
                                  fmt.format(m.at),
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          if (_pending.isNotEmpty)
            Wrap(
              children: [
                for (final a in _pending)
                  Chip(
                    label: Text('${a['name']}'),
                    onDeleted: () => setState(() => _pending.remove(a)),
                  ),
              ],
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Attach photo or PDF',
                    onPressed: _sending ? null : _attach,
                    icon: const Icon(Icons.attach_file_rounded),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                        hintText: 'Write a message',
                        counterText: '',
                      ),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
