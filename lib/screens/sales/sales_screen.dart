import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/pdf_helper.dart';
import '../../models/models.dart';
import '../reports/shift_report_screen.dart';
import '../shifts/shift_management_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  List<Product> _products = [];
  List<CartItem> _cart = [];
  String _searchQuery = '';
  int? _selectedCategoryId;
  String _selectedPaymentMethod = 'cash';
  double _discountAmount = 0;
  Customer? _selectedCustomer;

  late Future<List<Category>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    final appProvider = context.read<AppProvider>();
    _categoriesFuture = appProvider.getCategories();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final appProvider = context.read<AppProvider>();
    final products = await appProvider.getProducts();
    if (mounted) {
      setState(() {
        _products = products.where((p) => p.isAvailable).toList();
      });
    }
  }

  List<Product> get _filteredProducts {
    var filtered = _products;
    if (_selectedCategoryId != null) {
      filtered = filtered.where((p) => p.categoryId == _selectedCategoryId).toList();
    }
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    return filtered;
  }

  void _addToCart(Product product) {
    setState(() {
      final existingIndex = _cart.indexWhere((c) => c.productId == product.id);
      if (existingIndex >= 0) {
        _cart[existingIndex].quantity++;
      } else {
        _cart.add(CartItem(
          productId: product.id!,
          productName: product.name,
          price: product.price,
          quantity: 1,
        ));
      }
    });
  }

  void _removeFromCart(int productId) {
    setState(() {
      _cart.removeWhere((c) => c.productId == productId);
    });
  }

  void _updateQuantity(int productId, int quantity) {
    setState(() {
      final index = _cart.indexWhere((c) => c.productId == productId);
      if (index >= 0) {
        if (quantity <= 0) {
          _cart.removeAt(index);
        } else {
          _cart[index].quantity = quantity;
        }
      }
    });
  }

  double get _subtotalAmount => _cart.fold(0.0, (sum, item) => sum + item.total);
  double get _totalAmount => (_subtotalAmount - _discountAmount).clamp(0, double.infinity).toDouble();


  Future<double?> _showDiscountDialog() async {
    final controller = TextEditingController(text: _discountAmount.toStringAsFixed(2));
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('خصم على الفاتورة'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'قيمة الخصم',
            prefixText: 'ج.س ',
            helperText: 'الحد الأقصى ${_subtotalAmount.toStringAsFixed(2)} ج.س',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final value = (double.tryParse(controller.text) ?? 0).clamp(0, _subtotalAmount).toDouble();
              Navigator.pop(dialogContext, value);
            },
            child: const Text('حفظ الخصم'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }
  Future<Map<String, double>?> _showCheckoutDialog() async {
    final discountController = TextEditingController(text: _discountAmount.toStringAsFixed(2));
    final paidController = TextEditingController(text: _totalAmount.toStringAsFixed(2));
    final result = await showDialog<Map<String, double>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final discount = double.tryParse(discountController.text) ?? 0;
          final safeDiscount = discount.clamp(0, _subtotalAmount).toDouble();
          final net = (_subtotalAmount - safeDiscount).clamp(0, double.infinity).toDouble();
          final paid = double.tryParse(paidController.text) ?? 0;
          final change = (paid - net).clamp(0, double.infinity).toDouble();
          return AlertDialog(
            title: const Text('تأكيد عملية البيع'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      child: Icon(_selectedCustomer == null ? Icons.person_add_alt_1 : Icons.person),
                    ),
                    title: Text(_selectedCustomer?.name ?? 'إضافة عميل للفاتورة'),
                    subtitle: Text(_selectedCustomer == null ? 'اختياري — يفعّل نقاط الولاء وسجل المشتريات' : '${_selectedCustomer!.points} نقطة • ${_selectedCustomer!.phone ?? 'بدون هاتف'}'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: _selectCustomer,
                  ),
                  const Divider(),
                  _summaryRow('الإجمالي الفرعي', _subtotalAmount),
                  const SizedBox(height: 8),
                  TextField(
                    controller: discountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'الخصم', prefixText: 'ج.س '),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 8),
                  _summaryRow('الإجمالي بعد الخصم', net, emphasized: true),
                  if (_selectedPaymentMethod == 'cash') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: paidController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'المبلغ المستلم', prefixText: 'ج.س '),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 8),
                    _summaryRow('الباقي', change),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('رجوع')),
              FilledButton(
                onPressed: _selectedPaymentMethod == 'cash' && paid < net ? null : () => Navigator.pop(dialogContext, {
                  'discount': safeDiscount,
                  'paid': _selectedPaymentMethod == 'cash' ? paid : net,
                  'change': _selectedPaymentMethod == 'cash' ? change : 0,
                }),
                child: const Text('إتمام البيع'),
              ),
            ],
          );
        },
      ),
    );
    discountController.dispose();
    paidController.dispose();
    return result;
  }

  
  Future<void> _selectCustomer() async {
    final provider = context.read<AppProvider>();
    final searchController = TextEditingController();
    Customer? selected = _selectedCustomer;
    final result = await showDialog<Customer?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('العميل'),
            content: SizedBox(
              width: 460,
              height: 430,
              child: Column(
                children: [
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: 'بحث بالاسم أو رقم الهاتف',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 10),
                  if (selected != null)
                    ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(selected!.name),
                      subtitle: Text('${selected!.points} نقطة • ${selected!.visitCount} زيارة'),
                      trailing: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () { selected = null; setDialogState(() {}); },
                      ),
                    ),
                  Expanded(
                    child: FutureBuilder<List<Customer>>(
                      future: provider.getCustomers(query: searchController.text),
                      builder: (context, snapshot) {
                        final customers = snapshot.data ?? [];
                        if (customers.isEmpty) return const Center(child: Text('لا يوجد عملاء مطابقون'));
                        return ListView.builder(
                          itemCount: customers.length,
                          itemBuilder: (_, i) {
                            final c = customers[i];
                            return ListTile(
                              leading: const Icon(Icons.person_outline),
                              title: Text(c.name),
                              subtitle: Text(c.phone?.isNotEmpty == true ? '${c.phone} • ${c.points} نقطة' : '${c.points} نقطة'),
                              onTap: () { selected = c; setDialogState(() {}); },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, selected), child: const Text('اختيار')),
            ],
          );
        },
      ),
    );
    searchController.dispose();
    if (result != null || _selectedCustomer != null) setState(() => _selectedCustomer = result);
  }

Widget _summaryRow(String label, double value, {bool emphasized = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontWeight: emphasized ? FontWeight.bold : FontWeight.normal)),
      Text('${value.toStringAsFixed(2)} ج.س', style: TextStyle(fontWeight: FontWeight.bold, color: emphasized ? AppTheme.primaryColor : null)),
    ]),
  );

  Future<void> _saveInvoice() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('السلة فارغة')),
      );
      return;
    }

    final checkout = await _showCheckoutDialog();
    if (checkout == null) return;
    final discount = checkout['discount'] ?? 0;
    final paid = checkout['paid'] ?? _totalAmount;
    final change = checkout['change'] ?? 0;
    final appProvider = context.read<AppProvider>();
    final invoiceNumber = await appProvider.getNextInvoiceNumber();

    final invoice = Invoice(
      invoiceNumber: invoiceNumber,
      subtotalAmount: _subtotalAmount,
      discountAmount: discount,
      totalAmount: (_subtotalAmount - discount).clamp(0, double.infinity).toDouble(),
      paidAmount: paid,
      changeAmount: change,
      status: 'completed',
      paymentMethod: _selectedPaymentMethod,
      customerId: _selectedCustomer?.id,
    );

    try {
      final invoiceId = await appProvider.createInvoice(invoice, _cart);

      if (mounted) {
        // Check for low stock warning
        final savedInvoice = await appProvider.getInvoiceById(invoiceId);
        if (savedInvoice?.notes != null && savedInvoice!.notes!.startsWith('تحذير:')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${savedInvoice.notes}\nتم حفظ الفاتورة بنجاح',
              ),
              backgroundColor: AppTheme.warningColor,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'طباعة',
                textColor: Colors.white,
                onPressed: () {
                  PdfHelper.showPrintOptions(context, savedInvoice);
                },
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('تم حفظ الفاتورة بنجاح'),
              backgroundColor: AppTheme.successColor,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'طباعة',
                textColor: Colors.white,
                onPressed: () {
                  if (savedInvoice != null) {
                    PdfHelper.showPrintOptions(context, savedInvoice);
                  }
                },
              ),
            ),
          );
        }
        setState(() {
          _cart.clear();
          _selectedPaymentMethod = 'cash';
          _discountAmount = 0;
          _selectedCustomer = null;
        });
        _loadProducts();
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('خطأ في إتمام البيع'),
            content: Text(
              e.toString().replaceAll('Exception: ', ''),
              style: TextStyle(color: AppTheme.errorColor),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('حسنًا'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _parkCurrentOrder() async {
    if (_cart.isEmpty) return;
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تعليق الطلب'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'اسم العميل أو وصف الطلب (اختياري)',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, nameController.text.trim()), child: const Text('تعليق الطلب')),
        ],
      ),
    );
    nameController.dispose();
    if (name == null) return;
    try {
      await context.read<AppProvider>().savePendingOrder(
        _cart,
        customerName: name.isEmpty ? null : name,
        discountAmount: _discountAmount,
        paymentMethod: _selectedPaymentMethod,
      );
      if (mounted) {
        setState(() { _cart.clear(); _discountAmount = 0; _selectedPaymentMethod = 'cash'; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تعليق الطلب بنجاح')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
    }
  }

  Future<void> _showPendingOrders() async {
    final provider = context.read<AppProvider>();
    final orders = await provider.getPendingOrders();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.72,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Row(children: [
                  Icon(Icons.pause_circle_outline, color: AppTheme.primaryColor),
                  SizedBox(width: 8),
                  Text('الطلبات المعلقة', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                ]),
              ),
              Expanded(
                child: orders.isEmpty
                    ? const Center(child: Text('لا توجد طلبات معلقة'))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final o = orders[index];
                          final customer = (o['customer_name'] as String?) ?? 'طلب بدون اسم';
                          final subtotal = (o['subtotal'] as num?)?.toDouble() ?? 0;
                          final count = (o['item_count'] as num?)?.toInt() ?? 0;
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.receipt_long_outlined)),
                              title: Text(customer, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('$count قطعة • ${subtotal.toStringAsFixed(2)} ج.س'),
                              trailing: Wrap(
                                children: [
                                  IconButton(
                                    tooltip: 'استكمال',
                                    icon: const Icon(Icons.play_arrow, color: AppTheme.successColor),
                                    onPressed: () async {
                                      final data = await provider.getPendingOrderById(o['id'] as int);
                                      if (data == null || !mounted) return;
                                      final rows = data['items'] as List<Map<String, dynamic>>;
                                      setState(() {
                                        _cart = rows.map((r) => CartItem(
                                          productId: r['product_id'] as int,
                                          productName: r['product_name'] as String,
                                          price: (r['price'] as num).toDouble(),
                                          quantity: r['quantity'] as int,
                                        )).toList();
                                        _discountAmount = (data['order']['discount_amount'] as num?)?.toDouble() ?? 0;
                                        _selectedPaymentMethod = data['order']['payment_method']?.toString() ?? 'cash';
                                      });
                                      await provider.deletePendingOrder(o['id'] as int);
                                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'حذف',
                                    icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                                    onPressed: () async {
                                      await provider.deletePendingOrder(o['id'] as int);
                                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                                      if (mounted) _showPendingOrders();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildProductsGrid() {
    if (_filteredProducts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 56, color: AppTheme.textHint),
            SizedBox(height: 12),
            Text('لا توجد منتجات مطابقة', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 170,
        mainAxisSpacing: 10,
        childAspectRatio: 0.92,
      ),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) => _buildProductCard(_filteredProducts[index]),
    );
  }

  Widget _buildProductCard(Product product) {
    final quantity = _cart
        .where((item) => item.productId == product.id)
        .fold<int>(0, (sum, item) => sum + item.quantity);

    return Material(
      color: AppTheme.cardBackground,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _addToCart(product),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: quantity > 0
                  ? AppTheme.primaryColor.withOpacity(0.55)
                  : AppTheme.textHint.withOpacity(0.18),
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.16),
                            AppTheme.primaryColor.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.fastfood_rounded, color: AppTheme.primaryColor, size: 30),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${product.price.toStringAsFixed(2)} ج.س',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (quantity > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 28),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$quantity',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartPanel() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          color: AppTheme.primaryColor.withOpacity(0.06),
          child: Row(
            children: [
              const Icon(Icons.shopping_cart_rounded, size: 21, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text('السلة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const Spacer(),
              if (_cart.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_cart.fold<int>(0, (sum, item) => sum + item.quantity)} قطعة',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.primaryColor),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _cart.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_basket_outlined, size: 52, color: AppTheme.textHint),
                      SizedBox(height: 8),
                      Text('السلة فارغة', style: TextStyle(color: AppTheme.textSecondary)),
                      SizedBox(height: 4),
                      Text('اضغط على المنتج لإضافته', style: TextStyle(color: AppTheme.textHint, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _cart.length,
                  itemBuilder: (context, index) {
                    final item = _cart[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 7),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppTheme.textHint.withOpacity(0.15)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  Text('${item.price.toStringAsFixed(2)} ج.س', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'إنقاص',
                              icon: const Icon(Icons.remove_circle_outline, size: 21),
                              onPressed: () => _updateQuantity(item.productId, item.quantity - 1),
                              visualDensity: VisualDensity.compact,
                            ),
                            Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.w800)),
                            IconButton(
                              tooltip: 'زيادة',
                              icon: const Icon(Icons.add_circle_outline, size: 21, color: AppTheme.primaryColor),
                              onPressed: () => _updateQuantity(item.productId, item.quantity + 1),
                              visualDensity: VisualDensity.compact,
                            ),
                            SizedBox(
                              width: 78,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${item.total.toStringAsFixed(2)} ج.س', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryColor, fontSize: 12)),
                                  IconButton(
                                    tooltip: 'حذف',
                                    icon: const Icon(Icons.close, size: 17, color: AppTheme.errorColor),
                                    onPressed: () => _removeFromCart(item.productId),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        _buildCartSummary(),
      ],
    );
  }

  Widget _buildCartSummary() {
    final totalItems = _cart.fold<int>(0, (sum, item) => sum + item.quantity);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, -3))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(child: Text('الإجمالي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
              Text('${_totalAmount.toStringAsFixed(2)} ج.س', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: AppTheme.primaryColor)),
            ],
          ),
          if (_discountAmount > 0) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                const Expanded(child: Text('الخصم', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary))),
                Text('- ${_discountAmount.toStringAsFixed(2)} ج.س', style: const TextStyle(fontSize: 11, color: AppTheme.successColor, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _cart.isEmpty ? null : _parkCurrentOrder,
                  icon: const Icon(Icons.pause_circle_outline, size: 18),
                  label: const Text('تعليق'),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _cart.isEmpty ? null : () async {
                    final result = await _showDiscountDialog();
                    if (result != null && mounted) setState(() => _discountAmount = result);
                  },
                  icon: const Icon(Icons.discount_outlined, size: 18),
                  label: Text(_discountAmount > 0 ? 'تعديل الخصم' : 'خصم'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: Row(
              children: [
                _paymentChip('cash', 'نقداً', Icons.payments_outlined),
                const SizedBox(width: 6),
                _paymentChip('bank', 'تحويل', Icons.account_balance_outlined),
                const SizedBox(width: 6),
                _paymentChip('card', 'بطاقة', Icons.credit_card_outlined),
              ],
            ),
          ),
          const SizedBox(height: 7),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _cart.isEmpty ? null : _saveInvoice,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(totalItems > 0 ? 'إتمام البيع • ${_totalAmount.toStringAsFixed(2)} ج.س' : 'إتمام البيع'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                minimumSize: const Size.fromHeight(46),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentChip(String value, String label, IconData icon) {
    final selected = _selectedPaymentMethod == value;
    return Expanded(
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) => setState(() => _selectedPaymentMethod = value),
        avatar: Icon(icon, size: 15, color: selected ? Colors.white : AppTheme.primaryColor),
        label: Text(label),
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : AppTheme.textSecondary,
        ),
        selectedColor: AppTheme.primaryColor,
        backgroundColor: AppTheme.backgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المبيعات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined, size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShiftReportScreen()),
              );
            },
            tooltip: 'تقرير تقفيل الوردية',
          ),
          IconButton(
            icon: const Icon(Icons.pause_circle_outline),
            tooltip: 'الطلبات المعلقة',
            onPressed: _showPendingOrders,
          ),
          if (_cart.isNotEmpty)
            TextButton.icon(
              onPressed: _clearCart,
              icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
              label: const Text('مسح', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          FutureBuilder<Shift?>(
            future: context.read<AppProvider>().getCurrentUserOpenShift(),
            builder: (context, snapshot) {
              final shift = snapshot.data;
              if (shift != null) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  const Icon(Icons.lock_clock_outlined, color: AppTheme.warningColor),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('لا توجد وردية مفتوحة. افتح وردية قبل تسجيل أي بيع.', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShiftManagementScreen())),
                    child: const Text('فتح وردية'),
                  ),
                ]),
              );
            },
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'البحث عن منتج...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Category filter chips
          FutureBuilder<List<Category>>(
            future: _categoriesFuture,
            builder: (context, snapshot) {
              final categories = snapshot.data ?? [];
              return SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    FilterChip(
                      label: const Text('الكل'),
                      selected: _selectedCategoryId == null,
                      onSelected: (_) => setState(() => _selectedCategoryId = null),
                      backgroundColor: AppTheme.backgroundColor,
                      selectedColor: AppTheme.primaryColor,
                      labelStyle: TextStyle(
                        color: _selectedCategoryId == null ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ...categories.map((c) => FilterChip(
                      label: Text(c.name),
                      selected: _selectedCategoryId == c.id,
                      onSelected: (_) => setState(() => _selectedCategoryId = c.id),
                      backgroundColor: AppTheme.backgroundColor,
                      selectedColor: AppTheme.primaryColor,
                      labelStyle: TextStyle(
                        color: _selectedCategoryId == c.id ? Colors.white : AppTheme.textPrimary,
                      ),
                    )),
                  ],
                ),
              );
            },
          ),

          const Divider(height: 1),

          // POS workspace: responsive for tablets, desktop and phones.
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 900;
                final products = _buildProductsGrid();
                final cart = _buildCartPanel();
                if (compact) {
                  return Column(
                    children: [
                      Expanded(child: products),
                      SizedBox(height: 360, child: cart),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(flex: 3, child: products),
                    const VerticalDivider(width: 1),
                    Expanded(flex: 2, child: cart),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
