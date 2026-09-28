import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service.dart';

class SupportChatScreen extends StatefulWidget {
  final String bookingId;
  final bool isCustomer;

  const SupportChatScreen({
    super.key,
    required this.bookingId,
    required this.isCustomer,
  });

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();

  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isFetching = false;
  bool _isSending = false;
  Timer? _timer;

  String get _mySenderType => widget.isCustomer ? 'customer' : 'murtikar';

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    // Auto-refresh every 5 seconds for basic live chat experience
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchMessages(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return true;
    final pos = _scrollController.position;
    return pos.maxScrollExtent - pos.pixels < 80;
  }

  String _cleanError(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _fetchMessages({bool silent = false}) async {
    if (_isFetching) return; // avoid overlapping requests
    _isFetching = true;
    if (!silent) setState(() => _isLoading = true);
    try {
      final msgs = await ApiService.getMessages(widget.bookingId);
      if (!mounted) return;
      final wasNearBottom = _isNearBottom;
      final hasNew = msgs.length > _messages.length;
      setState(() {
        _messages = msgs;
        _isLoading = false;
      });
      // Scroll on first load, or when new messages arrive and the user is at the bottom
      if (!silent || (hasNew && wasNearBottom)) _scrollToBottom();
    } catch (e) {
      if (!silent && mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${_cleanError(e)}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _isSending) return;

    _isSending = true;
    _msgController.clear();

    // Optimistic UI update
    final optimistic = {
      'content': text,
      'sender_type': _mySenderType,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    setState(() => _messages.add(optimistic));
    _scrollToBottom();

    try {
      await ApiService.sendMessage(widget.bookingId, text);
      _fetchMessages(silent: true);
    } catch (e) {
      if (!mounted) return;
      // Roll back the optimistic message and give the text back to the user
      setState(() => _messages.remove(optimistic));
      _msgController.text = text;
      _msgController.selection = TextSelection.collapsed(offset: text.length);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: ${_cleanError(e)}'), backgroundColor: Colors.red),
      );
    } finally {
      _isSending = false;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(dynamic raw) {
    if (raw == null) return '';
    var dt = DateTime.tryParse(raw.toString());
    if (dt == null) return '';
    // Backend timestamps without a timezone are treated as UTC
    if (!dt.isUtc && !raw.toString().contains('+') && !raw.toString().endsWith('Z')) {
      dt = DateTime.utc(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second);
    }
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          widget.isCustomer ? 'Message Workshop' : 'Customer Chat',
          style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: theme.colorScheme.secondary),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 64, color: isDark ? Colors.white24 : Colors.black12),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet.\nStart the conversation!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: isDark ? Colors.grey : Colors.black54),
                            ),
                          ],
                        ),
                      ).animate().fade()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) {
                          final msg = _messages[i];
                          final isMe = msg['sender_type'] == _mySenderType;
                          final time = _formatTime(msg['created_at']);

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? theme.primaryColor : (isDark ? const Color(0xFF222232) : Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(20).copyWith(
                                  bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(20),
                                  bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(0),
                                ),
                              ),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      msg['content'] ?? '',
                                      style: TextStyle(
                                        color: isMe || isDark ? Colors.white : Colors.black87,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  if (time.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      time,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isMe || isDark ? Colors.white70 : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, -5))
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: TextStyle(color: isDark ? Colors.grey : Colors.black54),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF222232) : Colors.grey.shade200,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: theme.primaryColor,
                    radius: 24,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _sendMessage,
                    ),
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