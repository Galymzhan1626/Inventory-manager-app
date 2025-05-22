import 'package:flutter/material.dart';

class Product {
  final String name;
  final int quantity;

  Product({required this.name, required this.quantity});
}

class LowStockPage extends StatelessWidget {
  final List<Product> allProducts;

  const LowStockPage({Key? key, required this.allProducts}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Customize the threshold as needed
    const lowStockThreshold = 5;
    final lowStockItems = allProducts.where((p) => p.quantity <= lowStockThreshold).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Low Stock Items"),
      ),
      body: lowStockItems.isEmpty
          ? const Center(child: Text("All items are sufficiently stocked."))
          : ListView.builder(
        itemCount: lowStockItems.length,
        itemBuilder: (context, index) {
          final product = lowStockItems[index];
          return ListTile(
            leading: const Icon(Icons.warning, color: Colors.red),
            title: Text(product.name),
            subtitle: Text("Quantity left: ${product.quantity}"),
          );
        },
      ),
    );
  }
}
