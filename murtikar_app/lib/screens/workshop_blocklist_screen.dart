import 'package:flutter/material.dart';
import '../services/api_service.dart';

class WorkshopBlocklistScreen extends StatefulWidget {
  const WorkshopBlocklistScreen({super.key});

  @override
  State<WorkshopBlocklistScreen> createState() => _WorkshopBlocklistScreenState();
}

class _WorkshopBlocklistScreenState extends State<WorkshopBlocklistScreen> {
  bool _isLoading = true;
  List<dynamic> _blockList = [];

  @override
  void initState() {
    super.initState();
    _loadBlockList();
  }

  Future<void> _loadBlockList() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.getBlockList();
      if (mounted) setState(() => _blockList = list);
    } catch (_) {}
    finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddBlockDialog() {
    final phoneCtrl = TextEditingController();
    final reasonCtrl = TextEditingController(text: 'Customer requested cancellation / dispute');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Block Phone Workshop-Wide', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'A blocked phone number will be immediately denied tracking access across ALL your bookings.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: '10-digit Mobile Number', labelStyle: TextStyle(color: Colors.grey)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Internal Reason for Block', labelStyle: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (phoneCtrl.text.trim().length != 10) return;
              try {
                await ApiService.blockPhone(phoneCtrl.text.trim(), reasonCtrl.text.trim());
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _loadBlockList();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Block Across Workshop', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181824),
        title: const Text('Workshop Block List', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF39C12)))
          : _blockList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.security, size: 64, color: Colors.green),
                      const SizedBox(height: 16),
                      const Text('No Blocked Phone Numbers', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('All authorized customers can access their orders.', style: TextStyle(color: Colors.grey.shade400)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _blockList.length,
                  itemBuilder: (ctx, idx) {
                    final item = _blockList[idx];
                    return Card(
                      color: const Color(0xFF181824),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const Icon(Icons.block, color: Colors.red),
                        title: Text(item['phone_number'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(item['reason'] ?? 'Blocked by artisan', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        trailing: TextButton(
                          onPressed: () async {
                            await ApiService.unblockPhone(item['phone_number']);
                            _loadBlockList();
                          },
                          child: const Text('Unblock', style: TextStyle(color: Colors.green)),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Block Number', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _showAddBlockDialog,
      ),
    );
  }
}
