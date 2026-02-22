import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ✅ CORE & FEATURE IMPORTS
import 'package:agriyukt_app/core/providers/language_provider.dart';
import 'package:agriyukt_app/features/inspector/screens/inspector_order_detail_screen.dart';

class InspectorOrdersTab extends StatefulWidget {
  final int initialIndex;
  final String? highlightOrderId;

  const InspectorOrdersTab({
    super.key,
    this.initialIndex = 0,
    this.highlightOrderId,
  });

  @override
  State<InspectorOrdersTab> createState() => _InspectorOrdersTabState();
}

class _InspectorOrdersTabState extends State<InspectorOrdersTab>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;

  // ✅ STATE ENGINE
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _allOrders = [];

  // ✅ SEARCH ENGINE
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  // ✅ INDEPENDENT SCROLL CONTROLLERS
  final ScrollController _pendingScroll = ScrollController();
  final ScrollController _activeScroll = ScrollController();
  final ScrollController _historyScroll = ScrollController();
  bool _hasScrolled = false;

  // ✅ THEME: Inspector Deep Purple
  static const Color _primaryPurple = Color(0xFF512DA8);
  static const Color _surfaceBg = Color(0xFFF4F6F8);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(
        length: 3, vsync: this, initialIndex: widget.initialIndex);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        FocusScope.of(context).unfocus();
        HapticFeedback.selectionClick();
      }
    });
    _fetchManagedOrders();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchManagedOrders(isSilent: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    _pendingScroll.dispose();
    _activeScroll.dispose();
    _historyScroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchManagedOrders(isSilent: true);
    }
  }

  // =======================================================================
  // 📦 DATA FETCHING ENGINE (Fixed Inner Join & Null Safety)
  // =======================================================================
  Future<void> _fetchManagedOrders({bool isSilent = false}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      if (!isSilent && _allOrders.isEmpty && mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }

      final response = await _supabase
          .from('orders')
          .select('''
            *,
            crops(id, crop_name, image_url, price, variety, grade),
            buyer:profiles!orders_buyer_id_fkey(first_name, last_name, phone, district, state),
            farmer:profiles!orders_farmer_id_fkey!inner(id, first_name, last_name, phone, district, state, inspector_id, latitude, longitude)
          ''')
          .eq('farmer.inspector_id', user.id)
          .order('created_at', ascending: false)
          .limit(1000);

      if (mounted) {
        setState(() {
          _allOrders = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
          _errorMessage = null;
        });

        if (widget.highlightOrderId != null && !_hasScrolled) {
          _attemptAutoScroll();
        }
      }
    } catch (e) {
      debugPrint("🚨 DB FETCH ERROR: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_allOrders.isEmpty) {
            _errorMessage = "Connection error. Pull to refresh.";
          }
        });
      }
    }
  }

  // =======================================================================
  // 🧭 SEARCH, FILTER & INSTANT SNAP NAVIGATION ENGINE
  // =======================================================================
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _searchQuery = query);
    });
  }

  bool _matchesSearch(Map<String, dynamic> o) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase().trim();

    final rawCrop = o['crops'];
    final crop = rawCrop is Map
        ? rawCrop
        : (rawCrop is List && rawCrop.isNotEmpty ? rawCrop[0] : {});

    final rawFarmer = o['farmer'];
    final farmer = rawFarmer is Map
        ? rawFarmer
        : (rawFarmer is List && rawFarmer.isNotEmpty ? rawFarmer[0] : {});

    final cropName = (crop['crop_name'] ?? '').toString().toLowerCase();
    final variety = (crop['variety'] ?? '').toString().toLowerCase();
    final farmerName =
        "${farmer['first_name'] ?? ''} ${farmer['last_name'] ?? ''}"
            .toLowerCase();
    final orderIdStr = o['id'].toString().toLowerCase();

    return cropName.contains(q) ||
        variety.contains(q) ||
        farmerName.contains(q) ||
        orderIdStr.contains(q);
  }

  List<Map<String, dynamic>> _getPendingOrders() => _allOrders.where((o) {
        final status = (o['status'] ?? '').toString().toLowerCase().trim();
        return (status == 'pending' || status == 'requested') &&
            _matchesSearch(o);
      }).toList();

  List<Map<String, dynamic>> _getActiveOrders() => _allOrders.where((o) {
        final status = (o['status'] ?? '').toString().toLowerCase().trim();
        return [
              'accepted',
              'confirmed',
              'packed',
              'shipped',
              'in transit',
              'out for delivery',
              'processing',
              'verified'
            ].contains(status) &&
            _matchesSearch(o);
      }).toList();

  List<Map<String, dynamic>> _getCompletedOrders() => _allOrders.where((o) {
        final status = (o['status'] ?? '').toString().toLowerCase().trim();
        return ['delivered', 'completed', 'rejected', 'cancelled', 'declined']
                .contains(status) &&
            _matchesSearch(o);
      }).toList();

  void _attemptAutoScroll() {
    if (widget.highlightOrderId == null || _hasScrolled) return;
    final targetOrderIndex = _allOrders
        .indexWhere((o) => o['id'].toString() == widget.highlightOrderId);
    if (targetOrderIndex == -1) return;

    final targetOrder = _allOrders[targetOrderIndex];
    final statusLower =
        (targetOrder['status'] ?? '').toString().toLowerCase().trim();

    int targetTab = 0;
    ScrollController? targetController;

    if ([
      'accepted',
      'confirmed',
      'packed',
      'shipped',
      'in transit',
      'out for delivery',
      'processing',
      'verified'
    ].contains(statusLower)) {
      targetTab = 1;
      targetController = _activeScroll;
    } else if (['delivered', 'completed', 'rejected', 'cancelled', 'declined']
        .contains(statusLower)) {
      targetTab = 2;
      targetController = _historyScroll;
    } else {
      targetTab = 0;
      targetController = _pendingScroll;
    }

    if (_tabController.index != targetTab) {
      _tabController.animateTo(targetTab); // ✅ FIX: Prevents UI desync
    }

    List<Map<String, dynamic>> targetList = targetTab == 0
        ? _getPendingOrders()
        : targetTab == 1
            ? _getActiveOrders()
            : _getCompletedOrders();
    final indexInList = targetList
        .indexWhere((o) => o['id'].toString() == widget.highlightOrderId);

    if (indexInList != -1) {
      _hasScrolled = true;
      _safeScrollTo(targetController, indexInList);
    }
  }

  void _safeScrollTo(ScrollController? controller, int index) {
    if (controller == null) return;
    int retries = 0;
    Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (controller.hasClients) {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && controller.hasClients) {
            final maxScroll = controller.position.maxScrollExtent;
            double targetOffset = index * 271.0;
            if (targetOffset > maxScroll) targetOffset = maxScroll;

            controller.animateTo(
              targetOffset,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
            );
          }
        });
      } else if (retries > 40) {
        timer.cancel();
      }
      retries++;
    });
  }

  // =======================================================================
  // 🛡️ STATUS MUTATION LOGIC
  // =======================================================================
  Future<bool> _updateStatus(dynamic orderId, String newStatus) async {
    HapticFeedback.mediumImpact();
    try {
      String mainStatus = (newStatus == 'Packed' || newStatus == 'Shipped')
          ? 'accepted'
          : (newStatus == 'Delivered' ? 'completed' : newStatus.toLowerCase());

      setState(() {
        final orderIndex = _allOrders
            .indexWhere((o) => o['id'].toString() == orderId.toString());
        if (orderIndex != -1) {
          final updatedCard = Map<String, dynamic>.from(_allOrders[orderIndex]);
          updatedCard['status'] = mainStatus;
          updatedCard['tracking_status'] = newStatus;
          _allOrders[orderIndex] = updatedCard;
        }
      });

      await _supabase
          .from('orders')
          .update({'status': mainStatus, 'tracking_status': newStatus}).eq(
              'id', orderId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              Icon(
                  (newStatus.toLowerCase() == 'accepted' ||
                          newStatus.toLowerCase() == 'verified')
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  color: Colors.white),
              const SizedBox(width: 12),
              Text("Order $newStatus",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ]),
            backgroundColor: (newStatus.toLowerCase() == 'accepted' ||
                    newStatus.toLowerCase() == 'verified')
                ? Colors.green.shade700
                : Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return true;
    } catch (e) {
      debugPrint("Error updating status: $e");
      _fetchManagedOrders(isSilent: true);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<LanguageProvider>(context);
    final myId = _supabase.auth.currentUser?.id;

    if (myId == null) {
      return const Scaffold(
          body: Center(child: Text("Authentication Required")));
    }

    final pending = _getPendingOrders();
    final active = _getActiveOrders();
    final history = _getCompletedOrders();

    return Scaffold(
      backgroundColor: _surfaceBg,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: _primaryPurple,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ],
          ),
          child: TextField(
            controller: _searchController,
            style: GoogleFonts.poppins(color: Colors.black87, fontSize: 13),
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            decoration: InputDecoration(
              hintText: "Search farmer, crop, or Order ID...",
              hintStyle: GoogleFonts.poppins(
                  color: Colors.grey.shade400, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded,
                  color: Colors.grey.shade400, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.cancel_rounded,
                          color: Colors.grey.shade400, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged("");
                        FocusScope.of(context).unfocus();
                      })
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          indicatorColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.6),
          labelStyle:
              GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle:
              GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "Requests"),
            Tab(text: "Active"),
            Tab(text: "History"),
          ],
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _isLoading
            ? ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 4,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (_, __) => const _SkeletonOrderCard(),
              )
            : TabBarView(
                key: const ValueKey('tab_view_data'),
                controller: _tabController,
                children: [
                  _OrderList(
                    orders: pending,
                    isLoading: _isLoading,
                    controller: _pendingScroll,
                    onRefresh: _fetchManagedOrders,
                    onStatusUpdate: _updateStatus,
                    emptyMsg: "No pending requests",
                    emptySubMsg:
                        "Orders waiting for your verification will appear here.",
                    icon: Icons.inbox_rounded,
                    themeColor: _primaryPurple,
                    errorMessage: _errorMessage,
                    highlightOrderId: widget.highlightOrderId,
                    tabType: 'pending',
                  ),
                  _OrderList(
                    orders: active,
                    isLoading: _isLoading,
                    controller: _activeScroll,
                    onRefresh: _fetchManagedOrders,
                    onStatusUpdate: _updateStatus,
                    emptyMsg: "No active orders",
                    emptySubMsg:
                        "Your verified and active orders will be tracked here.",
                    icon: Icons.local_shipping_rounded,
                    themeColor: _primaryPurple,
                    errorMessage: _errorMessage,
                    highlightOrderId: widget.highlightOrderId,
                    tabType: 'active',
                  ),
                  _OrderList(
                    orders: history,
                    isLoading: _isLoading,
                    controller: _historyScroll,
                    onRefresh: _fetchManagedOrders,
                    onStatusUpdate: _updateStatus,
                    emptyMsg: "No past orders",
                    emptySubMsg:
                        "Delivered and cancelled orders will be saved here.",
                    icon: Icons.history_rounded,
                    themeColor: _primaryPurple,
                    errorMessage: _errorMessage,
                    highlightOrderId: widget.highlightOrderId,
                    tabType: 'history',
                  ),
                ],
              ),
      ),
    );
  }
}

// ============================================================================
// ✅ THE LIST ENGINE
// ============================================================================
class _OrderList extends StatefulWidget {
  final List<Map<String, dynamic>> orders;
  final bool isLoading;
  final String? errorMessage;
  final ScrollController controller;
  final Future<void> Function({bool isSilent}) onRefresh;
  final Future<bool> Function(dynamic, String) onStatusUpdate;
  final String emptyMsg;
  final String emptySubMsg;
  final String tabType;
  final IconData icon;
  final String? highlightOrderId;
  final Color themeColor;

  const _OrderList({
    required this.orders,
    required this.isLoading,
    this.errorMessage,
    required this.controller,
    required this.onRefresh,
    required this.onStatusUpdate,
    required this.emptyMsg,
    required this.emptySubMsg,
    required this.tabType,
    required this.icon,
    this.highlightOrderId,
    required this.themeColor,
  });

  @override
  State<_OrderList> createState() => _OrderListState();
}

class _OrderListState extends State<_OrderList>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.lightImpact();
        await widget.onRefresh(isSilent: true);
      },
      color: widget.themeColor,
      backgroundColor: Colors.white,
      child: ListView.separated(
        key: PageStorageKey('list_${widget.tabType}'),
        controller: widget.controller,
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(context).padding.bottom + 40),
        itemCount: widget.orders.isEmpty ? 1 : widget.orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          if (widget.errorMessage != null && widget.orders.isEmpty) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline_rounded,
                      size: 50, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text("Database Error",
                      style: GoogleFonts.poppins(
                          color: Colors.red.shade800,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(widget.errorMessage!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            );
          }

          if (widget.orders.isEmpty) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 16)
                          ]),
                      child: Icon(widget.icon,
                          size: 50, color: widget.themeColor.withOpacity(0.5))),
                  const SizedBox(height: 20),
                  Text(widget.emptyMsg,
                      style: GoogleFonts.poppins(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(widget.emptySubMsg,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          color: Colors.grey.shade500, fontSize: 13)),
                ],
              ),
            );
          }

          final order = widget.orders[index];
          final isHighlighted =
              order['id'].toString() == widget.highlightOrderId;

          return _InspectorOrderCard(
            key: ValueKey('inspector_card_${order['id']}'),
            order: order,
            tabType: widget.tabType,
            onStatusUpdate: widget.onStatusUpdate,
            isHighlighted: isHighlighted,
            themeColor: widget.themeColor,
            onRefresh: () async {
              // ✅ POP CRASH FIX: Ensure parent is mounted before executing callback
              if (mounted) {
                await widget.onRefresh(isSilent: true);
              }
            },
          );
        },
      ),
    );
  }
}

// ============================================================================
// ✅ THE PERFECT GEOMETRY SKELETON
// ============================================================================
class _SkeletonOrderCard extends StatelessWidget {
  const _SkeletonOrderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 255,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(
                      height: 24,
                      width: 24,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade200, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Container(height: 14, width: 100, color: Colors.grey.shade200)
                ]),
                Container(
                    height: 20,
                    width: 60,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(100))),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                      height: 90,
                      width: 90,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12))),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                            height: 16,
                            width: double.infinity,
                            color: Colors.grey.shade200),
                        const SizedBox(height: 8),
                        Container(
                            height: 16,
                            width: 120,
                            color: Colors.grey.shade200),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(height: 12, width: 100, color: Colors.grey.shade200),
                Container(
                    height: 36,
                    width: 120,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(100))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ✅ THE UNCOMPROMISED PREMIUM INSPECTOR CARD (Matches Farmer UI)
// ============================================================================
class _InspectorOrderCard extends StatefulWidget {
  final Map<String, dynamic> order;
  final String tabType;
  final Future<bool> Function(dynamic, String) onStatusUpdate;
  final bool isHighlighted;
  final Color themeColor;
  final VoidCallback onRefresh;

  const _InspectorOrderCard({
    super.key,
    required this.order,
    required this.tabType,
    required this.onStatusUpdate,
    required this.themeColor,
    required this.onRefresh,
    this.isHighlighted = false,
  });

  @override
  State<_InspectorOrderCard> createState() => _InspectorOrderCardState();
}

class _InspectorOrderCardState extends State<_InspectorOrderCard> {
  bool _isAccepting = false;
  bool _isRejecting = false;
  bool _isHighlighted = false;

  @override
  void initState() {
    super.initState();
    if (widget.isHighlighted) {
      _isHighlighted = true;
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _isHighlighted = false);
      });
    }
  }

  String _formatRelativeDate(String? isoDate) {
    if (isoDate == null) return 'Unknown Date';
    final DateTime? date = DateTime.tryParse(isoDate)?.toLocal();
    if (date == null) return 'Unknown Date';

    final DateTime now = DateTime.now();
    final int diffDays = DateTime(now.year, now.month, now.day)
        .difference(DateTime(date.year, date.month, date.day))
        .inDays;

    if (diffDays == 0) return "Today, ${DateFormat('jm').format(date)}";
    if (diffDays == 1) return "Yesterday, ${DateFormat('jm').format(date)}";
    return DateFormat('MMM d, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final String fullId = order['id'].toString();
    final rawStatus = order['status'] ?? 'Pending';
    final statusLower = rawStatus.toString().toLowerCase().trim();

    String displayStatus = rawStatus.toString().toUpperCase();
    Color statusColor = const Color(0xFFF57C00);
    Color statusBg = const Color(0xFFFFF3E0);
    IconData statusIcon = Icons.pending_actions_rounded;

    if (statusLower == 'pending' || statusLower == 'requested') {
      displayStatus = "VERIFICATION PENDING";
      statusIcon = Icons.hourglass_top_rounded;
    } else if (['delivered', 'completed'].contains(statusLower)) {
      displayStatus = "DELIVERED";
      statusColor = const Color(0xFF2E7D32);
      statusBg = const Color(0xFFE8F5E9);
      statusIcon = Icons.check_circle_rounded;
    } else if (['rejected', 'cancelled', 'declined'].contains(statusLower)) {
      displayStatus = "CANCELLED";
      statusColor = const Color(0xFFD32F2F);
      statusBg = const Color(0xFFFFEBEE);
      statusIcon = Icons.cancel_rounded;
    } else {
      displayStatus =
          (order['tracking_status'] ?? rawStatus).toString().toUpperCase();
      statusColor = widget.themeColor;
      statusBg = widget.themeColor.withOpacity(0.1);
      statusIcon = Icons.local_shipping_rounded;
    }

    final rawFarmer = order['farmer'];
    final farmer = rawFarmer is Map
        ? rawFarmer
        : (rawFarmer is List && rawFarmer.isNotEmpty ? rawFarmer[0] : {});
    final String farmerName =
        "${farmer['first_name'] ?? 'Farmer'} ${farmer['last_name'] ?? ''}"
            .trim();

    final String orderDate = _formatRelativeDate(order['created_at']);
    final String orderIdDisplay = "#${fullId.substring(0, 8).toUpperCase()}";

    final priceRaw = order['price_offered'];
    final price =
        priceRaw != null ? (num.tryParse(priceRaw.toString()) ?? 0) : 0;
    final String formattedPrice =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0)
            .format(price);

    final qtyRaw = order['quantity_kg'];
    final qty = qtyRaw != null ? (num.tryParse(qtyRaw.toString()) ?? 0) : 0;

    final rawCrop = order['crops'];
    final crop = rawCrop is Map
        ? rawCrop
        : (rawCrop is List && rawCrop.isNotEmpty ? rawCrop[0] : {});

    String cropName = crop['crop_name'] ?? order['crop_name'] ?? "Crop Item";
    String? imgUrl = crop['image_url'];

    String cropVariety = crop['variety'] ?? order['variety'] ?? '';
    String cropGrade = crop['grade'] ?? order['grade'] ?? '';

    String displayTitle = cropName;
    if (cropVariety.isNotEmpty && cropVariety.toLowerCase() != 'null') {
      displayTitle = "$cropName : $cropVariety";
    }

    return RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(seconds: 1),
        curve: Curves.easeInOut,
        height: 255, // 🔒 EXACT HARDWARE GEOMETRY LOCK
        decoration: BoxDecoration(
          color: _isHighlighted ? const Color(0xFFF3E5F5) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: _isHighlighted ? widget.themeColor : Colors.grey.shade200,
              width: _isHighlighted ? 2.0 : 1.0),
          boxShadow: [
            BoxShadow(
                color: _isHighlighted
                    ? widget.themeColor.withOpacity(0.15)
                    : Colors.black.withOpacity(0.03),
                blurRadius: _isHighlighted ? 20 : 15,
                offset: const Offset(0, 6))
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.tabType != 'pending'
                ? () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        transitionDuration: const Duration(milliseconds: 250),
                        pageBuilder: (_, __, ___) =>
                            InspectorOrderDetailScreen(order: order),
                        transitionsBuilder: (_, anim, __, child) =>
                            FadeTransition(opacity: anim, child: child),
                      ),
                    ).then((_) => widget.onRefresh());
                  }
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 46,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isHighlighted
                        ? Colors.transparent
                        : Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(15),
                        topRight: Radius.circular(15)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            CircleAvatar(
                                radius: 12,
                                backgroundColor:
                                    widget.themeColor.withOpacity(0.1),
                                child: Text(
                                    farmerName.isNotEmpty
                                        ? farmerName[0].toUpperCase()
                                        : "F",
                                    style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: widget.themeColor))),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(farmerName,
                                  style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(100)),
                        child: Row(
                          children: [
                            Icon(statusIcon, size: 10, color: statusColor),
                            const SizedBox(width: 4),
                            Text(displayStatus,
                                style: GoogleFonts.poppins(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 9,
                                    letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(
                    height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 90,
                          width: 90,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(11),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                // ✅ HERO CRASH FIX: Appended tabType to prevent Duplicate Hero Tag errors during transitions
                                child: Hero(
                                  tag:
                                      'inspector_order_img_${fullId}_${widget.tabType}',
                                  child: (imgUrl != null && imgUrl.isNotEmpty)
                                      ? CachedNetworkImage(
                                          imageUrl: imgUrl.startsWith('http')
                                              ? imgUrl
                                              : Supabase.instance.client.storage
                                                  .from('crop_images')
                                                  .getPublicUrl(imgUrl),
                                          fit: BoxFit.cover,
                                          memCacheWidth: 250,
                                          memCacheHeight: 250,
                                          fadeInDuration:
                                              const Duration(milliseconds: 150),
                                          placeholder: (c, u) => Container(
                                              color: Colors.grey.shade100),
                                          errorWidget: (context, url, error) =>
                                              const Icon(
                                                  Icons.image_not_supported,
                                                  color: Colors.grey),
                                        )
                                      : Image.asset(
                                          'assets/images/placeholder_crop.png',
                                          fit: BoxFit.cover),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(displayTitle,
                                    style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                        letterSpacing: -0.5,
                                        height: 1.2),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              if (cropGrade.isNotEmpty &&
                                  cropGrade.toLowerCase() != 'null')
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 4, bottom: 4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                            color: Colors.grey.shade300)),
                                    child: Text("Grade $cropGrade",
                                        style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ),
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(formattedPrice,
                                      style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87)),
                                  const SizedBox(width: 6),
                                  Text("•  $qty kg",
                                      style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade600)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(
                    height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
                Container(
                  height: 60,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (widget.tabType != 'pending') ...[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Ordered: $orderDate",
                                  style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600)),
                              const SizedBox(height: 2),
                              Text(orderIdDisplay,
                                  style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10,
                                      color: Colors.grey.shade400,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.push(
                            context,
                            PageRouteBuilder(
                              transitionDuration:
                                  const Duration(milliseconds: 250),
                              pageBuilder: (_, __, ___) =>
                                  InspectorOrderDetailScreen(order: order),
                              transitionsBuilder: (_, anim, __, child) =>
                                  FadeTransition(opacity: anim, child: child),
                            ),
                          ).then((_) => widget.onRefresh()),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: widget.tabType == 'active'
                                  ? widget.themeColor
                                  : Colors.white,
                              foregroundColor: widget.tabType == 'active'
                                  ? Colors.white
                                  : Colors.black87,
                              side: widget.tabType == 'active'
                                  ? BorderSide.none
                                  : BorderSide(color: Colors.grey.shade300),
                              elevation: 0,
                              minimumSize: const Size(120, 36),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(100)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 0)),
                          child: Text(
                              widget.tabType == 'active'
                                  ? "Manage Status"
                                  : "View Details",
                              style: GoogleFonts.poppins(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                        )
                      ] else ...[
                        // PENDING ACTION BUTTONS
                        Expanded(
                          child: SizedBox(
                            height: 36,
                            child: OutlinedButton(
                              onPressed: (_isAccepting || _isRejecting)
                                  ? null
                                  : () async {
                                      setState(() => _isRejecting = true);
                                      await widget.onStatusUpdate(
                                          fullId, 'Rejected');
                                      if (mounted) {
                                        setState(() => _isRejecting = false);
                                      }
                                    },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                side: BorderSide(color: Colors.red.shade300),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(100)),
                                padding: EdgeInsets.zero,
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: _isRejecting
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2, color: Colors.red))
                                    : Text("Reject",
                                        key: const ValueKey('reject_btn'),
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 36,
                            child: ElevatedButton(
                              onPressed: (_isAccepting || _isRejecting)
                                  ? null
                                  : () async {
                                      setState(() => _isAccepting = true);
                                      await widget.onStatusUpdate(
                                          fullId, 'Accepted');
                                      if (mounted) {
                                        setState(() => _isAccepting = false);
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.themeColor,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(100)),
                                padding: EdgeInsets.zero,
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: _isAccepting
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : Text("Accept",
                                        key: const ValueKey('accept_btn'),
                                        style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
