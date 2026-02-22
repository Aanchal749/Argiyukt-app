import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String targetUserId;
  final String targetName;
  final String orderId;
  final String cropName;
  final String orderStatus;

  const ChatScreen({
    super.key,
    required this.targetUserId,
    required this.targetName,
    required this.orderId,
    required this.cropName,
    required this.orderStatus,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _supabase = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  String? _myUserId;
  bool _isSending = false;

  // ✅ The "Safe Mode" dictionary for professional marketplace communication
  final List<String> _safePhrases = [
    "Hello! 👋",
    "Is the order ready for pickup?",
    "I am currently packing the items. 📦",
    "Items are ready for shipment.",
    "I am on my way to the location. 🚜",
    "I have reached the location.",
    "Please check the live tracking.",
    "I need more time to prepare.",
    "Please share the Delivery OTP.",
    "Order has been delivered.",
    "Thank you! Have a great day. 🙏",
  ];

  List<String> _filteredPhrases = [];

  // Theme Color from Buyer UI
  final Color _primaryGreen = const Color(0xFF1B5E20);

  @override
  void initState() {
    super.initState();
    _myUserId = _supabase.auth.currentUser?.id;
    _filteredPhrases = _safePhrases;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _filteredPhrases = _safePhrases
          .where((phrase) => phrase
              .toLowerCase()
              .contains(_searchController.text.toLowerCase()))
          .toList();
    });
  }

  Future<void> _sendMessage(String text) async {
    if (_myUserId == null || _isSending) return;
    setState(() => _isSending = true);

    try {
      // ✅ Insert into Supabase - synced automatically via Stream
      await _supabase.from('messages').insert({
        'sender_id': _myUserId,
        'receiver_id': widget.targetUserId,
        'order_id': widget.orderId,
        'content': text,
        'is_read': false,
      });

      _searchController.clear();
      FocusScope.of(context).unfocus();
      _scrollToBottom();
    } catch (e) {
      debugPrint("Chat Sync Error: $e");
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6), // Matches Buyer UI Background
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildSmartInputArea(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            size: 20, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _primaryGreen.withOpacity(0.1),
            child: Text(
              widget.targetName.isNotEmpty
                  ? widget.targetName[0].toUpperCase()
                  : "?",
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, color: _primaryGreen),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.targetName,
                  style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "${widget.cropName} • ${widget.orderStatus}",
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase
          .from('messages')
          .stream(primaryKey: ['id'])
          .eq('order_id', widget.orderId)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final messages = snapshot.data!;

        if (messages.isEmpty) {
          return Center(
            child: Text("Search for a message below to start chatting",
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13)),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[index];
            bool isMe = msg['sender_id'] == _myUserId;
            return _buildMessageBubble(
                msg['content'] ?? "", isMe, msg['created_at']);
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(String text, bool isMe, String timestamp) {
    DateTime time = DateTime.parse(timestamp).toLocal();
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? _primaryGreen : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              text,
              style: GoogleFonts.poppins(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 14.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('hh:mm a').format(time),
              style: GoogleFonts.poppins(
                color: isMe ? Colors.white70 : Colors.grey.shade500,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartInputArea() {
    bool isMatch = _safePhrases.any(
      (p) => p.toLowerCase() == _searchController.text.trim().toLowerCase(),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, -5))
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Suggestion Chips (Styled like the Buyer filter chips)
            if (_filteredPhrases.isNotEmpty)
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredPhrases.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ActionChip(
                      label: Text(_filteredPhrases[i],
                          style: GoogleFonts.poppins(
                              fontSize: 13.5, fontWeight: FontWeight.w500)),
                      backgroundColor: const Color(0xFFF1F5F9),
                      side: BorderSide(color: Colors.grey.shade200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      onPressed: () => _sendMessage(_filteredPhrases[i]),
                    ),
                  ),
                ),
              ),

            // Professional Search-Input Field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: GoogleFonts.poppins(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: "Search safe replies...",
                          hintStyle: GoogleFonts.poppins(
                              color: Colors.blueGrey.shade300, fontSize: 14.5),
                          prefixIcon: const Icon(Icons.search_rounded,
                              size: 22, color: Colors.blueGrey),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filled(
                    onPressed: isMatch && !_isSending
                        ? () => _sendMessage(_searchController.text)
                        : null,
                    icon: _isSending
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : const Icon(Icons.send_rounded, size: 24),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          isMatch ? _primaryGreen : Colors.grey.shade300,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(52, 52),
                      shape: const CircleBorder(),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
