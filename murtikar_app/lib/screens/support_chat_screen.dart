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
        elevation: 1,
        shadowColor: Colors.black12,
        backgroundColor: theme.colorScheme.surface,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.primaryColor.withOpacity(0.1),
              child: Icon(widget.isCustomer ? Icons.storefront_rounded : Icons.person_rounded, size: 20, color: theme.primaryColor),
            ),
            const SizedBox(width: 12),
            Text(
              widget.isCustomer ? 'Message Workshop' : 'Customer Chat',
              style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ],
        ),
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
                : _messages.isEmpty
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 10))
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: theme.primaryColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.forum_rounded, size: 48, color: theme.primaryColor),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Say Hello! 👋',
                                style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Start the conversation securely\nend-to-end.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: isDark ? Colors.grey : Colors.black54, fontSize: 14, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fade().scale(duration: const Duration(milliseconds: 400), curve: Curves.easeOutBack)
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
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              decoration: BoxDecoration(
                                color: isMe ? null : (isDark ? const Color(0xFF222232) : Colors.white),
                                gradient: isMe 
                                    ? LinearGradient(
                                        colors: [theme.primaryColor, Colors.indigo.shade400],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: isMe 
                                      ? theme.primaryColor.withOpacity(0.3) 
                                      : Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                                borderRadius: BorderRadius.circular(24).copyWith(
                                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(24),
                                  bottomLeft: isMe ? const Radius.circular(24) : const Radius.circular(4),
                                ),
                              ),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    msg['content'] ?? '',
                                    style: TextStyle(
                                      color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                                      fontSize: 15,
                                      height: 1.3,
                                    ),
                                  ),
                                  if (time.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          time,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: isMe ? Colors.white70 : (isDark ? Colors.grey : Colors.black54),
                                          ),
                                        ),
                                        if (isMe) ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.done_all_rounded, size: 12, color: Colors.white70),
                                        ]
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ).animate().fade().slideY(begin: 0.1, end: 0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF222232) : Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.08), blurRadius: 20, offset: const Offset(0, 5))
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 15),
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: TextStyle(color: isDark ? Colors.grey : Colors.black38),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [theme.primaryColor, Colors.indigo.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: theme.primaryColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))
                      ]
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: _sendMessage,
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        ),
                      ),
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