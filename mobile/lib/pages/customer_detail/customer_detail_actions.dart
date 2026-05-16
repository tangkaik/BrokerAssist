part of '../customer_detail_page.dart';

extension _CustomerDetailActions on _CustomerDetailPageState {
  Widget _buildCountChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7FB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD4E1EF)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _openCustomerAI() {
    final customer = _customer;
    if (customer == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerAIPage(
          customerId: customer.id,
          customerName: customer.name,
          summary: customer.summary,
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return OutlinedButton.icon(
      onPressed: _showDeleteConfirmDialog,
      icon: const Icon(Icons.delete_outline, color: Colors.red),
      label: const Text('删除客户', style: TextStyle(color: Colors.red)),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red,
        side: const BorderSide(color: Colors.red),
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
