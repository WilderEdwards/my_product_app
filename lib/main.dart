import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

/// Case-insensitive substring match plus inclusive price bounds.
bool productMatchesFilters({
  required String name,
  required num price,
  required String query,
  double? minPrice,
  double? maxPrice,
}) {
  final normalizedName = name.trim().toLowerCase();
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isNotEmpty && !normalizedName.contains(normalizedQuery)) {
    return false;
  }
  if (minPrice != null && price < minPrice) return false;
  if (maxPrice != null && price > maxPrice) return false;
  return true;
}

/// Returns a visible error for invalid supplied price bounds, or null.
String? priceRangeError(String minText, String maxText) {
  final minRaw = minText.trim();
  final maxRaw = maxText.trim();
  final min = _parsePriceBound(minRaw);
  final max = _parsePriceBound(maxRaw);
  if (minRaw.isNotEmpty && min == null) {
    return 'Minimum price must be a non-negative number.';
  }
  if (maxRaw.isNotEmpty && max == null) {
    return 'Maximum price must be a non-negative number.';
  }
  if (min != null && max != null && min > max) {
    return 'Minimum price cannot be greater than maximum price.';
  }
  return null;
}

double? _parsePriceBound(String text) {
  if (text.isEmpty) return null;
  final value = double.tryParse(text);
  if (value == null || !value.isFinite || value < 0) return null;
  return value;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Autumn Product Manager',
      home: ProductPage(),
    ),
  );
}

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});
  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final _products = FirebaseFirestore.instance.collection('products');
  late final _productStream = _products.snapshots();

  final _searchController = TextEditingController();
  final _minController = TextEditingController();
  final _maxController = TextEditingController();
  final _deleting = <String>{};

  bool get _hasFilterInput =>
      _searchController.text.trim().isNotEmpty ||
      _minController.text.trim().isNotEmpty ||
      _maxController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _searchController.dispose();
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  Future<void> _createOrUpdate([
    QueryDocumentSnapshot<Map<String, dynamic>>? document,
  ]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (context) =>
          ProductEditor(products: _products, document: document),
    );
  }

  Future<void> _deleteProduct(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final data = document.data();
    final name = data['name'];
    final label = name is String && name.trim().isNotEmpty ? name : document.id;
    setState(() => _deleting.add(document.id));
    try {
      await _products.doc(document.id).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted "$label" (ID: ${document.id}).')),
      );
    } on FirebaseException catch (error) {
      debugPrint('Product delete failed (${error.code}): ${error.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed (${error.code}).')));
    } finally {
      if (mounted) setState(() => _deleting.remove(document.id));
    }
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _minController.clear();
      _maxController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final rangeError = priceRangeError(
      _minController.text,
      _maxController.text,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Autumn Product Manager')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Search by name',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Min price',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _maxController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Max price',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _hasFilterInput ? _resetFilters : null,
                      child: const Text('Reset'),
                    ),
                  ],
                ),
                if (rangeError != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      rangeError,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _buildList(
              rangeError: rangeError,
              query: _searchController.text.trim().toLowerCase(),
              minPrice: _parsePriceBound(_minController.text.trim()),
              maxPrice: _parsePriceBound(_maxController.text.trim()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Create product',
        onPressed: () => _createOrUpdate(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildList({
    required String? rangeError,
    required String query,
    required double? minPrice,
    required double? maxPrice,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _productStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Products could not load. Check connection and permissions.',
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final documents = snapshot.data!.docs;
        if (documents.isEmpty) {
          return const Center(
            child: Text('No products yet. Add one to begin.'),
          );
        }
        if (rangeError != null) {
          return const Center(
            child: Text('Fix the price range above to see products.'),
          );
        }
        final hasFilters =
            query.isNotEmpty || minPrice != null || maxPrice != null;
        final rows = <Widget>[];
        for (final document in documents) {
          final data = document.data();
          final name = data['name'];
          final price = data['price'];
          final valid =
              name is String &&
              name.trim().isNotEmpty &&
              price is num &&
              price.isFinite &&
              price >= 0;
          if (!valid) {
            if (!hasFilters) {
              rows.add(
                ListTile(
                  title: Text(
                    'Invalid product ${document.id}: check name/price types.',
                  ),
                ),
              );
            }
            continue;
          }
          if (!productMatchesFilters(
            name: name,
            price: price,
            query: query,
            minPrice: minPrice,
            maxPrice: maxPrice,
          )) {
            continue;
          }
          rows.add(_buildTile(document));
        }
        if (rows.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No products found.'),
                if (hasFilters)
                  TextButton(
                    onPressed: _resetFilters,
                    child: const Text('Reset'),
                  ),
              ],
            ),
          );
        }
        return ListView(children: rows);
      },
    );
  }

  Widget _buildTile(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    final name = data['name'] as String;
    final price = data['price'] as num;
    final deleting = _deleting.contains(document.id);
    return Card(
      child: ListTile(
        title: Text(name),
        subtitle: Text('${price.toStringAsFixed(2)}\nID: ${document.id}'),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Edit product',
              icon: const Icon(Icons.edit),
              onPressed: deleting ? null : () => _createOrUpdate(document),
            ),
            IconButton(
              tooltip: 'Delete product',
              icon: deleting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete),
              onPressed: deleting ? null : () => _deleteProduct(document),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductEditor extends StatefulWidget {
  const ProductEditor({super.key, required this.products, this.document});

  final CollectionReference<Map<String, dynamic>> products;
  final QueryDocumentSnapshot<Map<String, dynamic>>? document;

  @override
  State<ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<ProductEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.document?.data()['name'] as String? ?? '',
  );
  late final _price = TextEditingController(
    text: widget.document?.data()['price']?.toString() ?? '',
  );
  var _saving = false;
  String? _saveError;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final data = <String, Object>{
      'name': _name.text.trim(),
      'price': double.parse(_price.text.trim()),
    };
    try {
      final document = widget.document;
      if (document == null) {
        await widget.products.add(data);
      } else {
        await widget.products.doc(document.id).update(data);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on FirebaseException catch (error) {
      debugPrint('Product save failed (${error.code}): ${error.message}');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError =
            'Save failed (${error.code}). '
            'Check your connection and permissions.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.document == null ? 'Create product' : 'Edit product',
                ),
                TextFormField(
                  controller: _name,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a product name'
                      : null,
                ),
                TextFormField(
                  controller: _price,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Price'),
                  validator: (value) {
                    final amount = double.tryParse(value?.trim() ?? '');
                    return amount == null || !amount.isFinite || amount < 0
                        ? 'Enter a finite price of zero or more'
                        : null;
                  },
                ),
                if (_saveError != null)
                  Text(
                    _saveError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (_saving)
                  const Text(
                    'Awaiting server acknowledgement. If offline, reconnect. '
                    'This editor stays open until the write succeeds or fails.',
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save'),
                ),
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
