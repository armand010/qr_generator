import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

class GenericBarcodePage extends StatefulWidget {
  final String barcodeType;
  final String title;
  final String description;
  final String hintText;
  final IconData icon;

  const GenericBarcodePage({
    super.key,
    required this.barcodeType,
    required this.title,
    required this.description,
    required this.hintText,
    required this.icon,
  });

  @override
  State<GenericBarcodePage> createState() => _GenericBarcodePageState();
}

class _GenericBarcodePageState extends State<GenericBarcodePage> {
  final TextEditingController _codeController = TextEditingController();
  String _barcodeData = '';
  bool _showBarcode = false;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _generateBarcode() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _barcodeData = _codeController.text.trim();
        _showBarcode = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.barcodeType} barcode generated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _clearBarcode() {
    setState(() {
      _codeController.clear();
      _barcodeData = '';
      _showBarcode = false;
    });
  }

  Widget _buildBarcode() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            width: 300,
            height: 100,
            color: Colors.white,
            child: CustomPaint(
              painter: GenericBarcodePainter(_barcodeData),
              size: const Size(300, 100),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _barcodeData,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
            title: Text('${widget.barcodeType} Barcode'),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _codeController,
                            decoration: InputDecoration(
                              labelText: '${widget.barcodeType} Code',
                              hintText: widget.hintText,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              prefixIcon: Icon(widget.icon),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter ${widget.barcodeType} code';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _generateBarcode,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text('Generate ${widget.barcodeType}'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _clearBarcode,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                                  foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                child: const Text('Clear'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_showBarcode && _barcodeData.isNotEmpty)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text(
                              '${widget.barcodeType} Barcode Result:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildBarcode(),
                            const SizedBox(height: 16),
                            // Info text
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'This is a preview of ${widget.barcodeType} barcode. Full implementation with save/share features will be available in future updates.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Generic barcode painter
class GenericBarcodePainter extends CustomPainter {
  final String data;
  
  GenericBarcodePainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // Generate simple barcode pattern based on data hash
    final hash = data.hashCode.abs();
    final barWidth = size.width / 50;
    
    for (int i = 0; i < 50; i++) {
      // Create pseudo-random pattern based on data
      final shouldDraw = ((hash >> (i % 16)) + i + data.length) % 3 == 0;
      
      if (shouldDraw) {
        canvas.drawRect(
          Rect.fromLTWH(i * barWidth, 0, barWidth * 0.8, size.height - 20),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
