// файл: orders_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:invent_app_redesign/screens/login_screen.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  _OrdersPageState createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  Future<void> _checkConnectivity() async {
    final isOnline = await NetworkService.isOnline();
    setState(() {
      _isOnline = isOnline;
    });
  }

  Future<void> _cacheProducts(List<QueryDocumentSnapshot> products) async {
    final box = Hive.box('products');
    await box.clear();
    for (var product in products) {
      final data = product.data() as Map<String, dynamic>;
      data['id'] = product.id;
      data['isSynced'] = true;
      await box.put(product.id, data);
    }
  }

  Future<void> _syncDrafts() async {
    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection')),
      );
      return;
    }

    final draftBox = Hive.box('drafts');
    final productBox = Hive.box('products');
    final historyBox = Hive.box('history');
    for (var key in draftBox.keys) {
      final draft = draftBox.get(key) as Map<dynamic, dynamic>;
      if (!(draft['isSynced'] ?? false)) {
        try {
          if (draft['type'] == 'product') {
            final docRef = await FirebaseFirestore.instance.collection('products').add({
              'name': draft['name'],
              'company': draft['company'],
              'quantity': draft['quantity'],
              'wholesale_price': draft['wholesale_price'],
              'barcode': draft['barcode'],
              'imageUrl': draft['imageUrl'],
              'timestamp': FieldValue.serverTimestamp(),
            });
            draft['id'] = docRef.id;
            draft['isSynced'] = true;
            await productBox.put(docRef.id, draft);
          } else if (draft['type'] == 'history') {
            final docRef = await FirebaseFirestore.instance.collection('history').add({
              'title': draft['title'],
              'action': draft['action'],
              'quantity': draft['quantity'],
              'timestamp': FieldValue.serverTimestamp(),
              'productId': draft['productId'],
            });
            draft['id'] = docRef.id;
            draft['isSynced'] = true;
            await historyBox.put(docRef.id, draft);
          }
          await draftBox.delete(key);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error syncing: $e')),
          );
        }
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Drafts synced')),
    );
  }

  List<Map<dynamic, dynamic>> _filterProducts(List<Map<dynamic, dynamic>> products) {
    if (_searchQuery.isEmpty) return products;
    return products.where((data) {
      final name = (data['name'] ?? '').toString().toLowerCase();
      final barcode = (data['barcode'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || barcode.contains(_searchQuery);
    }).toList();
  }

  Future<void> _createOrder(String productId, Map<dynamic, dynamic> productData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to create orders')),
      );
      return;
    }

    final TextEditingController quantityController = TextEditingController();
    final int availableQuantity = productData['quantity'] ?? 0;

    final quantity = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order ${productData['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Available: $availableQuantity'),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                hintText: 'Enter quantity to order',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(quantityController.text);
              if (value != null && value > 0 && value <= availableQuantity) {
                Navigator.pop(context, value);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid quantity')),
                );
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (quantity == null) return;

    try {
      final newQuantity = availableQuantity - quantity;
      final timestamp = DateTime.now().toIso8601String();
      final historyEntry = {
        'title': productData['name'],
        'action': 'Ordered',
        'quantity': quantity,
        'timestamp': _isOnline ? FieldValue.serverTimestamp() : DateTime.now().toIso8601String(),
        'productId': productId,
        'isSynced': _isOnline,
        'type': 'history',
      };

      if (_isOnline) {
        // Безопасное списание из Firestore через транзакцию
        await FirebaseFirestore.instance.runTransaction((tx) async {
          final docRef = FirebaseFirestore.instance.collection('products').doc(productId);
          final snapshot = await tx.get(docRef);
          final currentQty = snapshot['quantity'] ?? 0;
          if (currentQty >= quantity) {
            tx.update(docRef, {
              'quantity': currentQty - quantity,
              'timestamp': FieldValue.serverTimestamp(),
            });
          } else {
            throw Exception("Not enough quantity");
          }
        });

        final docRef = await FirebaseFirestore.instance.collection('history').add(historyEntry);
        historyEntry['id'] = docRef.id;
      } else {
        final draftBox = Hive.box('drafts');
        await draftBox.add(historyEntry);
      }

      final productBox = Hive.box('products');
      final historyBox = Hive.box('history');

      productData['quantity'] = newQuantity;
      productData['timestamp'] = timestamp;
      productData['isSynced'] = _isOnline;
      await productBox.put(productId, productData);

      // Создаём копию historyEntry без FieldValue
      final safeHistoryEntry = Map<String, dynamic>.from(historyEntry);
      if (safeHistoryEntry['timestamp'] is FieldValue) {
        safeHistoryEntry['timestamp'] = DateTime.now().toIso8601String();
      }
      await historyBox.put(historyEntry['id'] ?? DateTime.now().toIso8601String(), safeHistoryEntry);


      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ordered $quantity of ${productData['name']}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating order: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Order"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _syncDrafts,
            tooltip: 'Sync Drafts',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search by name or barcode',
              leading: const Icon(Icons.search),
              trailing: [
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  ),
              ],
              elevation: WidgetStateProperty.all(1.0),
              backgroundColor: WidgetStateProperty.all(Colors.grey[100]),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _isOnline
                  ? FirebaseFirestore.instance
                      .collection('products')
                      .orderBy('timestamp', descending: true)
                      .snapshots()
                  : null,
              builder: (context, snapshot) {
                final box = Hive.box('products');

                if (_isOnline && snapshot.connectionState == ConnectionState.waiting) {
                  if (box.isNotEmpty) {
                    final filtered = _filterProducts(box.values.cast<Map>().toList());
                    return _buildProductList(context, filtered);
                  }
                  return const Center(child: CircularProgressIndicator());
                }

                if (_isOnline && snapshot.hasError) {
                  if (box.isNotEmpty) {
                    final filtered = _filterProducts(box.values.cast<Map>().toList());
                    return _buildProductList(context, filtered);
                  }
                  return const Center(child: Text("Error loading products"));
                }

                if (_isOnline && snapshot.hasData) {
                  _cacheProducts(snapshot.data!.docs);
                  final products = snapshot.data!.docs
                      .map((doc) => (doc.data() as Map<String, dynamic>)..['id'] = doc.id)
                      .toList();
                  final filtered = _filterProducts(products);
                  return _buildProductList(context, filtered);
                }

                final offlineProducts = _filterProducts(box.values.cast<Map>().toList());
                return _buildProductList(context, offlineProducts);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList(BuildContext context, List<Map<dynamic, dynamic>> products) {
    if (products.isEmpty) {
      return const Center(child: Text("No products match your search"));
    }
    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (context, index) {
        final data = products[index];
        final bgColor = index % 2 == 0 ? Colors.white : const Color(0xFFF3F4F6);
        final timestamp = data['timestamp'] is Timestamp
            ? (data['timestamp'] as Timestamp).toDate()
            : DateTime.tryParse(data['timestamp']?.toString() ?? '');
        final formattedDate = timestamp != null
            ? DateFormat('dd MMM yyyy, HH:mm').format(timestamp)
            : 'No date';

        return GestureDetector(
          onTap: () => _createOrder(data['id'], data),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: bgColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['name'] ?? 'No name',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Company: ${data['company'] ?? '-'}'),
                    Text('Barcode: ${data['barcode'] ?? '-'}'),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('Quantity: ${data['quantity'] ?? 0}'),
                    const SizedBox(width: 16),
                    Text('Price: ${data['wholesale_price'] ?? 0} ₸'),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Added: $formattedDate', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
