import 'package:flutter/material.dart';

class ProductDetailPage extends StatelessWidget {
  final Map<dynamic, dynamic> product;

  const ProductDetailPage({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(product['name'] ?? 'Product Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product['imageUrl'] != null && product['imageUrl'].toString().isNotEmpty)
              Center(
                child: Image.network(
                  product['imageUrl'],
                  height: 200,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image, size: 100),
                ),
              ),
            const SizedBox(height: 20),
            Text('Name: ${product['name'] ?? '-'}', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text('Company: ${product['company'] ?? '-'}'),
            const SizedBox(height: 8),
            Text('Category: ${product['category'] ?? '-'}'), 
            const SizedBox(height: 8),
            Text('Barcode: ${product['barcode'] ?? '-'}'),
            const SizedBox(height: 8),
            Text('Quantity: ${product['quantity'] ?? 0}'),
            const SizedBox(height: 8),
            Text('Wholesale price: ${product['wholesale_price'] ?? 0} ₸'),
          ],
        ),
      ),
    );
  }
}
