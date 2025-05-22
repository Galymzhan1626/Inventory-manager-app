import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:invent_app_redesign/screens/add_product_screen.dart';
import 'package:invent_app_redesign/screens/barcode_page.dart';
import 'package:invent_app_redesign/screens/history_page.dart';
import 'package:invent_app_redesign/screens/settings_page.dart';
import 'package:invent_app_redesign/screens/login_screen.dart';
import 'package:invent_app_redesign/screens/all_products_page.dart';
import 'package:invent_app_redesign/screens/edit_profile_page.dart'; 
import 'package:invent_app_redesign/screens/orders_page.dart'; 


PreferredSizeWidget? customAppBar(BuildContext context, User? user) {
  if (user == null) return null;

  return AppBar(
    backgroundColor: Colors.white,
    elevation: 4,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        bottom: Radius.circular(20),
      ),
    ),
    title: Row(
      children: [
        const Icon(Icons.inventory_2_outlined, color: Colors.deepPurple),
        const SizedBox(width: 8),
        const Text(
          'Invent',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
    actions: [
      IconButton(
        icon: const Icon(Icons.refresh, color: Colors.black54),
        onPressed: () {
          // Қайта жүктеу логикасы
        },
      ),
      Padding(
        padding: const EdgeInsets.only(right: 12.0),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditProfilePage(user: user),
              ),
            );
          },
          child: CircleAvatar(
            backgroundImage: user.photoURL != null
                ? NetworkImage(user.photoURL!)
                : null,
            backgroundColor: Colors.deepPurple,
            child: user.photoURL == null
                ? const Icon(Icons.person, color: Colors.white)
                : null,
          ),
        ),
      ),
    ],
  );
}



class NetworkStatus extends StatefulWidget {
  @override
  _NetworkStatusState createState() => _NetworkStatusState();
}

class _NetworkStatusState extends State<NetworkStatus>
    with SingleTickerProviderStateMixin {
  bool isOffline = false;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _checkInitialConnection();
    Connectivity().onConnectivityChanged.listen((result) async {
      final newOfflineStatus = result == ConnectivityResult.none;
      if (newOfflineStatus != isOffline) {
        setState(() {
          isOffline = newOfflineStatus;
        });
        if (isOffline) {
          _controller.forward();
        } else {
          _controller.reverse();
          await _syncDrafts();
        }
      }
    });
  }

  Future<void> _checkInitialConnection() async {
    final result = await Connectivity().checkConnectivity();
    final initialOfflineStatus = result == ConnectivityResult.none;
    if (initialOfflineStatus != isOffline) {
      setState(() {
        isOffline = initialOfflineStatus;
      });
      if (isOffline) {
        _controller.forward();
      }
    }
  }

  Future<void> _syncDrafts() async {
    final draftBox = Hive.box('drafts');
    final productBox = Hive.box('products');
    final historyBox = Hive.box('history');

    for (var key in draftBox.keys) {
      final draft = draftBox.get(key) as Map<dynamic, dynamic>;
      if (!(draft['isSynced'] ?? false)) {
        try {
          if (draft['type'] == 'product') {
            final docRef = await FirebaseFirestore.instance
                .collection('products')
                .add({
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
            final docRef = await FirebaseFirestore.instance
                .collection('history')
                .add({
              'title': draft['title'],
              'action': draft['action'],
              'timestamp': FieldValue.serverTimestamp(),
            });
            draft['id'] = docRef.id;
            draft['isSynced'] = true;
            await historyBox.put(docRef.id, draft);
          }
          await draftBox.delete(key);
        } catch (e) {
          print('Error syncing draft: $e');
        }
      }
    }
  }

  void _refreshStatus() async {
    final result = await Connectivity().checkConnectivity();
    final newOfflineStatus = result == ConnectivityResult.none;
    if (newOfflineStatus != isOffline) {
      setState(() {
        isOffline = newOfflineStatus;
      });
      if (!isOffline) {
        await _syncDrafts();
      }
      if (isOffline) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return isOffline
        ? SafeArea(
            child: SizeTransition(
              sizeFactor: _animation,
              child: Container(
                color: Colors.redAccent,
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.wifi_off, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'OFFLINE MODE',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: _refreshStatus,
                      tooltip: 'Check connection',
                    ),
                  ],
                ),
              ),
            ),
          )
        : const SizedBox.shrink();
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isRefreshing = false;

  final user = FirebaseAuth.instance.currentUser;
  bool get isGuest => user == null;

  // Refresh function to update the screen and sync drafts
  Future<void> _refreshScreen() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
    });
    // Sync drafts if online
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      await _syncDrafts();
    }
    // Trigger rebuild
    setState(() {
      _isRefreshing = false;
    });
  }

  // Re-use _syncDrafts from NetworkStatus
  Future<void> _syncDrafts() async {
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
              'timestamp': FieldValue.serverTimestamp(),
            });
            draft['id'] = docRef.id;
            draft['isSynced'] = true;
            await historyBox.put(docRef.id, draft);
          }
          await draftBox.delete(key);
        } catch (e) {
          print('Error syncing draft: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = snapshot.data;
        final bool isGuest = user == null;

        List<Widget> _pages = [
          const DashboardPage(),
          isGuest
              ? GuestBlockPage(onBackToHome: () {
            setState(() {
              _selectedIndex = 0;
            });
          })
              : const BarcodePage(),
          isGuest
              ? GuestBlockPage(onBackToHome: () {
            setState(() {
              _selectedIndex = 0;
            });
          })
              : SettingsPage(),
        ];

        return Scaffold(
          body: Stack(
            children: [
              Column(
                children: [
                  Expanded(child: _pages[_selectedIndex]),
                ],
              ),
              NetworkStatus(),
            ],
          ),
          appBar: customAppBar(context, user),
          bottomNavigationBar: BottomNavigationBar(
            backgroundColor: Colors.white,
            currentIndex: _selectedIndex,
            selectedItemColor: const Color(0xFF111827),
            unselectedItemColor: Colors.grey,
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.qr_code), label: 'Barcode'),
              BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
            ],
          ),
        );
      },
    );
  }
}

class GuestBlockPage extends StatelessWidget {
  final VoidCallback? onBackToHome;

  const GuestBlockPage({super.key, this.onBackToHome});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            const Text(
              'Restricted Access',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Please log in to access this feature.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              },
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const Text(
              "Manage your warehouse",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                QuickActionCard(
                  icon: Icons.list,
                  label: 'All Items',
                  onPressed: () {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Restricted Access'),
                          content: const Text('Please log in to view all products.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => LoginScreen()),
                                );
                              },
                              child: const Text('Login'),
                            ),
                          ],
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AllProductsPage()),
                      );
                    }
                  },
                ),
                QuickActionCard(
                  icon: Icons.add,
                  label: 'Add New',
                  onPressed: () {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Restricted Access'),
                          content: const Text('Please log in to add new items.'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.of(context).popUntil((route) => route.isFirst);
                              },
                              child: const Text('Login'),
                            ),
                          ],
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddProductScreen(),
                        ),
                      );
                    }
                  },
                ),
                QuickActionCard(
                  icon: Icons.shopping_cart,
                  label: 'Orders',
                  onPressed: () {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Restricted Access'),
                          content: const Text('Please log in to create orders.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => LoginScreen()),
                                );
                              },
                              child: const Text('Login'),
                            ),
                          ],
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const OrdersPage()),
                      );
                    }
                  },
                ),
                const QuickActionCard(icon: Icons.add_shopping_cart, label: 'Low Stock'),
                QuickActionCard(
                  icon: Icons.history,
                  label: 'History',
                  onPressed: () {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Restricted Access'),
                          content: const Text('Please log in to view history.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => LoginScreen()),
                                );
                              },
                              child: const Text('Login'),
                            ),
                          ],
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HistoryPage()),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const QuickActionCard({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: Colors.indigo),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                  color: Colors.black87, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}