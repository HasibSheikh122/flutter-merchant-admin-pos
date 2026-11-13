// lib/widgets/catalog/product_form_modal.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'catalog_theme_scope.dart';

typedef HeaderMap = Map<String, String>;

class _PendingLocalImage {
  final String name;
  final Uint8List bytes;
  bool isPrimary;

  _PendingLocalImage({
    required this.name,
    required this.bytes,
    this.isPrimary = false,
  });
}

class ProductFormModal extends StatefulWidget {
  final CatalogThemeConfig theme;
  final Map? existingProduct;
  final List categories;
  final VoidCallback onSaved;

  const ProductFormModal({
    super.key,
    required this.theme,
    this.existingProduct,
    required this.categories,
    required this.onSaved,
  });

  @override
  State createState() => _ProductFormModalState();
}

class _ProductFormModalState extends State {
  @override
  ProductFormModal get widget => super.widget as ProductFormModal;

  final ImagePicker _imagePicker = ImagePicker();

  bool _isSubmitting = false;
  bool _isAiGenerating = false;
  bool _isGalleryLoading = false;
  Offset? _pointerDownPos;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _unitCtrl = TextEditingController(text: '1 pc');
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _comparePriceCtrl = TextEditingController();
  final TextEditingController _tpCostPriceCtrl = TextEditingController();
  final TextEditingController _tpRemarkCtrl = TextEditingController();
  final TextEditingController _stockCtrl = TextEditingController(text: '10');
  final TextEditingController _skuCtrl = TextEditingController();
  final TextEditingController _barcodeCtrl = TextEditingController();
  final TextEditingController _badgeCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();

  // AI & SEO Controllers
  final TextEditingController _aiFeaturesCtrl = TextEditingController();
  final TextEditingController _metaTitleCtrl = TextEditingController();
  final TextEditingController _metaDescCtrl = TextEditingController();
  final TextEditingController _metaKeywordsCtrl = TextEditingController();

  String _aiLanguage = 'bn';
  String _aiTone = 'catchy';
  Map? _aiResultSuite;

  // Multiple Images State
  List _serverImages = [];
  final List _pendingImages = [];

  final Set _selectedCategoryIds = {};
  bool _isActive = true;
  bool _isFeatured = false;
  bool _isBestseller = false;
  bool _isDealOfDay = false;

  bool get _isEdit => widget.existingProduct != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existingProduct;
    if (p != null) {
      _nameCtrl.text = (p['name'] ?? '').toString();
      _unitCtrl.text = (p['unit'] ?? '1 pc').toString();
      _priceCtrl.text = (p['price'] ?? '').toString();
      _comparePriceCtrl.text = (p['compare_price'] ?? '').toString();
      _tpCostPriceCtrl.text =
          (p['trade_price'] ?? p['cost_price'] ?? '').toString();
      _stockCtrl.text = (p['stock_quantity'] ?? 0).toString();
      _skuCtrl.text = (p['sku'] ?? '').toString();
      _barcodeCtrl.text = (p['barcode'] ?? '').toString();
      _badgeCtrl.text = (p['custom_badge'] ?? '').toString();
      _descCtrl.text = (p['description'] ?? '').toString();
      _metaTitleCtrl.text = (p['meta_title'] ?? '').toString();
      _metaDescCtrl.text = (p['meta_description'] ?? '').toString();
      _metaKeywordsCtrl.text = (p['meta_keywords'] ?? '').toString();

      _isActive = p['is_active'] ?? true;
      _isFeatured = p['is_featured'] ?? false;
      _isBestseller = p['is_bestseller'] ?? false;
      _isDealOfDay = p['is_deal_of_day'] ?? false;

      if (p['category_ids'] is List) {
        for (var id in (p['category_ids'] as List)) {
          final int? parsed = int.tryParse(id.toString());
          if (parsed != null) _selectedCategoryIds.add(parsed);
        }
      } else if (p['category_id'] != null) {
        final int? parsed = int.tryParse(p['category_id'].toString());
        if (parsed != null) _selectedCategoryIds.add(parsed);
      }

      if (p['images'] is List) {
        _serverImages = List.from(p['images'] as List);
      } else if (p['product_images'] is List) {
        _serverImages = List.from(p['product_images'] as List);
      }
      _fetchExistingProductImages();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    _priceCtrl.dispose();
    _comparePriceCtrl.dispose();
    _tpCostPriceCtrl.dispose();
    _tpRemarkCtrl.dispose();
    _stockCtrl.dispose();
    _skuCtrl.dispose();
    _barcodeCtrl.dispose();
    _badgeCtrl.dispose();
    _descCtrl.dispose();
    _aiFeaturesCtrl.dispose();
    _metaTitleCtrl.dispose();
    _metaDescCtrl.dispose();
    _metaKeywordsCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? Colors.redAccent : widget.theme.primaryColor,
        content: Text(
          msg,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ===========================================================================
  // 📸 MESSENGER-STYLE GALLERY, CAMERA & FILE PICKER (ANDROID / IOS / DESKTOP)
  // ===========================================================================

  HeaderMap get _multipartHeaders {
    final HeaderMap h = {
      'Accept': 'application/json',
      'X-Tenant-Subdomain': widget.theme.subdomain,
      'x-subdomain': widget.theme.subdomain,
      'X-Tenant-Domain': widget.theme.subdomain,
    };
    if (widget.theme.token.isNotEmpty) {
      h['Authorization'] = 'Bearer ${widget.theme.token}';
    }
    return h;
  }

  String _resolveFullImageUrl(String rawUrl) {
    if (rawUrl.isEmpty) return '';
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      return rawUrl;
    }
    if (rawUrl.startsWith('/')) {
      return '${widget.theme.apiBase}$rawUrl';
    }
    return '${widget.theme.apiBase}/$rawUrl';
  }

  Future _fetchExistingProductImages() async {
    if (!_isEdit) return;
    final id = widget.existingProduct!['id'];
    setState(() => _isGalleryLoading = true);
    try {
      final res = await http.get(
        Uri.parse(
            '${widget.theme.apiBase}/api/v1/products/$id/images/?subdomain=${widget.theme.subdomain}'),
        headers: widget.theme.headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List && mounted) {
          setState(() => _serverImages = data);
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isGalleryLoading = false);
    }
  }

  /// মেসেঞ্জারের মতো ফোনের গ্যালারি বা ক্যামেরা থেকে প্রাপ্ত XFile ছবিগুলো প্রসেস ও আপলোড করে
  Future _handlePickedXFiles(List pickedFiles) async {
    if (pickedFiles.isEmpty) return;
    setState(() => _isGalleryLoading = true);

    int addedCount = 0;
    try {
      for (final rawFile in pickedFiles) {
        final XFile xfile = rawFile as XFile;
        final Uint8List bytes = await xfile.readAsBytes();
        if (bytes.isEmpty) continue;

        final String fileName = xfile.name.trim().isNotEmpty
            ? xfile.name.trim()
            : 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';

        final newImg = _PendingLocalImage(
          name: fileName,
          bytes: bytes,
          isPrimary: _serverImages.isEmpty &&
              _pendingImages.isEmpty &&
              addedCount == 0,
        );

        if (_isEdit && widget.existingProduct?['id'] != null) {
          final ok = await _uploadSingleImageNow(
              widget.existingProduct!['id'], newImg);
          if (ok) addedCount++;
        } else {
          setState(() {
            _pendingImages.add(newImg);
          });
          addedCount++;
        }
      }

      if (_isEdit && addedCount > 0) {
        await _fetchExistingProductImages();
        widget.onSaved();
      }

      if (addedCount > 0) {
        _showSnack('$addedCountটি ছবি গ্যালারি থেকে যুক্ত হয়েছে!');
      }
    } catch (e) {
      _showSnack('ছবি লোড করতে সমস্যা হয়েছে: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isGalleryLoading = false);
    }
  }

  /// ফোনের গ্যালারি থেকে একসাথে একাধিক ছবি সিলেক্ট করা (Messenger Style Multi-Select)
  Future _pickFromGalleryMulti() async {
    try {
      final List picked = await _imagePicker.pickMultiImage(
        imageQuality: 88,
      );
      if (picked.isNotEmpty) {
        await _handlePickedXFiles(picked);
        return;
      }
    } catch (_) {
      // যদি কোনো কারণে মাল্টি-পিকার না খোলে, তবে সিঙ্গেল গ্যালারি পিকার ফলব্যাক করবে
      try {
        final XFile? single = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 88,
        );
        if (single != null) {
          await _handlePickedXFiles([single]);
          return;
        }
      } catch (err) {
        // Linux Desktop ফলব্যাক (zenity)
        if (!kIsWeb && Platform.isLinux) {
          await _pickLinuxDesktopFiles();
          return;
        }
        _showSnack('গ্যালারি পারমিশন প্রয়োজন: $err', isError: true);
      }
    }
  }

  /// সরাসরি ফোনের ক্যামেরা দিয়ে ছবি তোলা
  Future _pickFromCamera() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 88,
      );
      if (photo != null) {
        await _handlePickedXFiles([photo]);
      }
    } catch (e) {
      _showSnack('ক্যামেরা ওপেন করা যায়নি: $e', isError: true);
    }
  }

  /// Linux Desktop এর জন্য ফাইল পিকার ফলব্যাক
  Future _pickLinuxDesktopFiles() async {
    try {
      final res = await Process.run('zenity', [
        '--file-selection',
        '--multiple',
        '--separator=\n',
        '--title=Select Product Images',
      ]);
      if (res.exitCode == 0) {
        final paths = res.stdout
            .toString()
            .split('\n')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        final List xfiles = paths.map((p) => XFile(p)).toList();
        await _handlePickedXFiles(xfiles);
      }
    } catch (_) {}
  }

  /// মেসেঞ্জারের মতো বটম শিট মেনু: ১. গ্যালারি থেকে একাধিক ছবি ২. ক্যামেরা ৩. ডিরেক্ট লিংক (ঐচ্ছিক)
  Future _pickMultipleImagesFromDevice() async {
    final t = widget.theme;

    await showModalBottomSheet(
      context: context,
      backgroundColor: t.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: t.secondaryText.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.photo_library_rounded,
                        color: t.primaryColor, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'প্রোডাক্টের ছবি আপলোড করুন',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: t.primaryText,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetCtx),
                      icon: Icon(Icons.close_rounded, color: t.secondaryText),
                    ),
                  ],
                ),
                Text(
                  'মেসেঞ্জারের মতো আপনার ফোনের গ্যালারি বা ক্যামেরা থেকে সরাসরি ছবি নিন',
                  style: TextStyle(fontSize: 12, color: t.secondaryText),
                ),
                const SizedBox(height: 16),

                // ১. ফোনের গ্যালারি থেকে একসাথে একাধিক ছবি নেওয়ার মেইন বাটন
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _pickFromGalleryMulti();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: t.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: t.primaryColor.withValues(alpha: 0.45),
                          width: 1.4),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: t.primaryColor,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.collections_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Photo Gallery ও Files থেকে নিন',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: t.primaryText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'গ্যালারি থেকে একসাথে ১টি বা একাধিক ছবি সিলেক্ট করুন',
                                style: TextStyle(
                                    fontSize: 11.5, color: t.secondaryText),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 16, color: t.primaryColor),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // ২. ক্যামেরা দিয়ে সরাসরি ছবি তোলার বাটন
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _pickFromCamera();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: t.inputBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: t.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.blueAccent,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Camera দিয়ে ছবি তুলুন',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: t.primaryText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'সরাসরি ক্যামেরা দিয়ে প্রোডাক্টের ছবি তুলে আপলোড করুন',
                                style: TextStyle(
                                    fontSize: 11.5, color: t.secondaryText),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 16, color: t.secondaryText),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // ৩. ঐচ্ছিক: লিংক বা URL থেকে ছবি যোগ করার অপশন
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _showImageUrlFallbackDialog();
                  },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.link_rounded,
                            size: 16, color: t.secondaryText),
                        const SizedBox(width: 6),
                        Text(
                          'অথবা Direct Image URL / Link দিয়ে যোগ করুন',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: t.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future _showImageUrlFallbackDialog() async {
    final TextEditingController urlsCtrl = TextEditingController();
    bool isFetching = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        final t = widget.theme;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              backgroundColor: t.cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: t.cardBorder),
              ),
              title: Text(
                'Add Image via URL',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: t.primaryText,
                ),
              ),
              content: SizedBox(
                width: 400,
                child: TextField(
                  controller: urlsCtrl,
                  maxLines: 3,
                  style: TextStyle(color: t.primaryText, fontSize: 12.5),
                  decoration: InputDecoration(
                    labelText: 'Image URL (প্রতি লাইনে ১টি)',
                    hintText: 'https://example.com/product.jpg',
                    labelStyle:
                        TextStyle(color: t.secondaryText, fontSize: 12),
                    filled: true,
                    fillColor: t.inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: t.cardBorder),
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isFetching ? null : () => Navigator.of(ctx).pop(),
                  child: Text('Cancel',
                      style: TextStyle(color: t.secondaryText)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isFetching
                      ? null
                      : () async {
                          final rawInput = urlsCtrl.text.trim();
                          if (rawInput.isEmpty) return;
                          setModalState(() => isFetching = true);
                          final lines = rawInput
                              .split('\n')
                              .map((s) => s.trim())
                              .where((s) => s.isNotEmpty)
                              .toList();

                          int added = 0;
                          for (int idx = 0; lines.length > idx; idx++) {
                            final line = lines[idx];
                            try {
                              Uint8List? fileBytes;
                              String resolvedName =
                                  'product_img_${idx + 1}.jpg';
                              if (line.contains('base64,')) {
                                fileBytes = base64Decode(
                                    line.split('base64,').last.trim());
                              } else if (line.startsWith('http')) {
                                final resp = await http.get(Uri.parse(line));
                                if (resp.statusCode == 200) {
                                  fileBytes = resp.bodyBytes;
                                }
                              }
                              if (fileBytes != null && mounted) {
                                final newImg = _PendingLocalImage(
                                  name: resolvedName,
                                  bytes: fileBytes,
                                  isPrimary: _serverImages.isEmpty &&
                                      _pendingImages.isEmpty,
                                );
                                if (_isEdit &&
                                    widget.existingProduct?['id'] != null) {
                                  await _uploadSingleImageNow(
                                      widget.existingProduct!['id'], newImg);
                                  await _fetchExistingProductImages();
                                  widget.onSaved();
                                } else {
                                  setState(() => _pendingImages.add(newImg));
                                }
                                added++;
                              }
                            } catch (_) {}
                          }
                          setModalState(() => isFetching = false);
                          if (added > 0 && ctx.mounted) {
                            Navigator.of(ctx).pop();
                            _showSnack('$addedটি ছবি যুক্ত হয়েছে!');
                          }
                        },
                  child: Text(isFetching ? 'Loading...' : 'Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _uploadSingleImageNow(
      dynamic productId, _PendingLocalImage item) async {
    try {
      final uri = Uri.parse(
          '${widget.theme.apiBase}/api/v1/products/$productId/upload-image/?subdomain=${widget.theme.subdomain}');
      final req = http.MultipartRequest('POST', uri);
      req.headers.addAll(_multipartHeaders);
      req.fields['is_primary'] = item.isPrimary ? 'true' : 'false';
      req.files.add(
        http.MultipartFile.fromBytes(
          'image',
          item.bytes,
          filename: item.name,
        ),
      );
      final streamed = await req.send();
      return streamed.statusCode == 200 || streamed.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future _uploadPendingImagesForProduct(dynamic productId) async {
    if (_pendingImages.isEmpty) return;
    for (final rawItem in _pendingImages) {
      final _PendingLocalImage item = rawItem as _PendingLocalImage;
      await _uploadSingleImageNow(productId, item);
    }
    _pendingImages.clear();
  }

  Future _setServerImagePrimary(int imageId) async {
    if (!_isEdit) return;
    final prodId = widget.existingProduct!['id'];
    setState(() => _isGalleryLoading = true);
    try {
      final res = await http.post(
        Uri.parse(
            '${widget.theme.apiBase}/api/v1/products/$prodId/images/$imageId/set-primary/?subdomain=${widget.theme.subdomain}'),
        headers: widget.theme.headers,
      );
      if (res.statusCode == 200) {
        _showSnack('Cover (Primary) image set kora hoyeche!');
        widget.onSaved();
        await _fetchExistingProductImages();
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isGalleryLoading = false);
    }
  }

  Future _deleteServerImage(int imageId) async {
    if (!_isEdit) return;
    final prodId = widget.existingProduct!['id'];
    setState(() => _isGalleryLoading = true);
    try {
      final res = await http.delete(
        Uri.parse(
            '${widget.theme.apiBase}/api/v1/products/$prodId/images/$imageId/?subdomain=${widget.theme.subdomain}'),
        headers: widget.theme.headers,
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        _showSnack('Image delete kora hoyeche.');
        widget.onSaved();
        await _fetchExistingProductImages();
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isGalleryLoading = false);
    }
  }

  void _setPendingImageAsPrimary(int index) {
    setState(() {
      for (int i = 0; _pendingImages.length > i; i++) {
        final _PendingLocalImage item = _pendingImages[i] as _PendingLocalImage;
        item.isPrimary = (i == index);
      }
    });
  }

  String get _selectedCategoryNames {
    if (_selectedCategoryIds.isEmpty) return 'General';
    final List names = [];
    for (var c in widget.categories) {
      if (c is Map) {
        final int cid = int.tryParse((c['id'] ?? 0).toString()) ?? 0;
        if (_selectedCategoryIds.contains(cid)) {
          names.add((c['name'] ?? '').toString());
        }
      }
    }
    return names.isNotEmpty ? names.join(', ') : 'General';
  }

  // ===========================================================================
  // ✨ AI CONTENT, NLP & SEO GENERATOR
  // ===========================================================================
  Future _generateAiProductContent() async {
    final String prodName = _nameCtrl.text.trim();
    if (prodName.isEmpty) {
      _showSnack('AI Description generate korte agey Product Name likhun!',
          isError: true);
      return;
    }

    setState(() => _isAiGenerating = true);

    final String catLabel = _selectedCategoryNames;
    final String priceStr =
        _priceCtrl.text.trim().isEmpty ? '999' : _priceCtrl.text.trim();
    final String cmpStr = _comparePriceCtrl.text.trim();
    final String extraFeatures = [
      if (_unitCtrl.text.trim().isNotEmpty) _unitCtrl.text.trim(),
      if (_aiFeaturesCtrl.text.trim().isNotEmpty) _aiFeaturesCtrl.text.trim(),
    ].join(', ');

    final Map reqBody = {
      'name': prodName,
      'category': catLabel,
      'price': priceStr,
      'compare_price': cmpStr,
      'features': extraFeatures,
      'tone': _aiTone,
      'language': _aiLanguage,
    };

    try {
      final res = await http.post(
        Uri.parse(
            '${widget.theme.apiBase}/api/v1/ai/generate-product-content/?subdomain=${widget.theme.subdomain}'),
        headers: widget.theme.headers,
        body: jsonEncode(reqBody),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map) {
          final String generatedDesc = (_aiLanguage == 'both'
                  ? (data['bilingual_description'] ?? data['description'])
                  : (_aiLanguage == 'en'
                      ? (data['description_en'] ?? data['description'])
                      : (data['description_bn'] ?? data['description'])))
              .toString();

          final dynamic suiteRaw = data['suite'] ??
              (data['data'] is Map ? data['data']['suite'] : null);
          Map suiteMap = {};
          if (suiteRaw is Map) {
            suiteMap = Map.from(suiteRaw);
          }

          final dynamic contentObj =
              suiteMap['content'] ?? suiteMap['bn'] ?? suiteMap;
          final dynamic seoEngine =
              (contentObj is Map) ? contentObj['seo_engine'] : null;

          setState(() {
            if (generatedDesc.isNotEmpty) {
              _descCtrl.text = generatedDesc;
            }
            if (seoEngine is Map) {
              if ((seoEngine['meta_title'] ?? '').toString().isNotEmpty) {
                _metaTitleCtrl.text = seoEngine['meta_title'].toString();
              } else {
                _metaTitleCtrl.text = '$prodName - Best Price in Bangladesh';
              }
              if ((seoEngine['meta_description'] ?? '').toString().isNotEmpty) {
                _metaDescCtrl.text = seoEngine['meta_description'].toString();
              }
              if (seoEngine['focus_keywords'] is List) {
                _metaKeywordsCtrl.text =
                    (seoEngine['focus_keywords'] as List).join(', ');
              }
            } else {
              _metaTitleCtrl.text = '$prodName - Best Price in BD';
              _metaDescCtrl.text =
                  'Order authentic $prodName ($catLabel) online at ৳$priceStr with nationwide Cash on Delivery.';
              _metaKeywordsCtrl.text =
                  '${prodName.toLowerCase()}, $prodName price in bd, ${catLabel.toLowerCase()}';
            }
            _aiResultSuite = suiteMap;
          });

          _showSnack(
              '✨ AI Description, NLP Specs o SEO Suite generate hoyeche!');
          return;
        }
      }
      _applyLocalSmartAiFallback(prodName, catLabel, priceStr);
    } catch (_) {
      _applyLocalSmartAiFallback(prodName, catLabel, priceStr);
    } finally {
      if (mounted) setState(() => _isAiGenerating = false);
    }
  }

  void _applyLocalSmartAiFallback(
      String prodName, String catLabel, String priceStr) {
    final String unit =
        _unitCtrl.text.trim().isEmpty ? '1 pc' : _unitCtrl.text.trim();
    final String bnText =
        '**১০০% খাঁটি ও প্রিমিয়াম মানের নিশ্চয়তা: $prodName**\n'
        '_$catLabel ক্যাটাগরিতে বিশ্বস্ত ও যাচাইকৃত মানের সেরা সংযোজন ($unit)।_\n\n'
        'আপনার ও আপনার পরিবারের জন্য শতভাগ যাচাইকৃত মানের $prodName। সাশ্রয়ী মূল্যে এখন পাচ্ছেন মাত্র ৳$priceStr টাকায়।\n\n'
        '**মূল বৈশিষ্ট্য ও সুবিধাসমূহ:**\n'
        '• ১০০% অরিজিনাল কোয়ালিটি ও প্রি-ডিসপ্যাচ চেকিং\n'
        '• পরিমাণ/ইউনিট: $unit — নিখুঁত প্যাকেজিং\n'
        '• সারা বাংলাদেশে দ্রুত ক্যাশ অন ডেলিভারি (COD) সুবিধা\n'
        '• ডেলিভারির সময় পার্সেল দেখে বুঝে নেওয়ার শতভাগ নিশ্চয়তা';

    final String enText =
        '**100% Authentic & Premium Quality: $prodName**\n'
        '_Thoughtfully curated $catLabel ($unit) designed for dependable everyday value._\n\n'
        'Elevate your experience with authentic $prodName. Available now at an honest value of ৳$priceStr.\n\n'
        '**Key Features & Benefits:**\n'
        '• 100% Verified Authentic Grade with Pre-Dispatch Inspection\n'
        '• Pack / Unit: $unit — Intact Hygienic Packaging\n'
        '• Nationwide Home Delivery with Cash on Delivery (COD)\n'
        '• Easy Doorstep Parcel Verification Support';

    setState(() {
      _descCtrl.text = _aiLanguage == 'both'
          ? '🇧🇩 **বাংলা বিবরণ:**\n$bnText\n\n🇬🇧 **English Description:**\n$enText'
          : (_aiLanguage == 'en' ? enText : bnText);
      _metaTitleCtrl.text = '$prodName - Best Price in Bangladesh';
      _metaDescCtrl.text =
          'Order authentic $prodName ($catLabel) online at ৳$priceStr with fast Cash on Delivery across Bangladesh.';
      _metaKeywordsCtrl.text =
          '${prodName.toLowerCase()}, $prodName price in bd, ${catLabel.toLowerCase()}';
    });
    _showSnack('✨ Smart AI Template Description & SEO set kora hoyeche!');
  }

  Future _submitProduct() async {
    final String name = _nameCtrl.text.trim();
    final String priceStr = _priceCtrl.text.trim();

    if (name.isEmpty) {
      _showSnack('Product-er nam likhun!', isError: true);
      return;
    }
    if (priceStr.isEmpty || double.tryParse(priceStr) == null) {
      _showSnack('Sothik selling price likhun!', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    final Map payload = {
      'name': name,
      'unit': _unitCtrl.text.trim().isEmpty ? '1 pc' : _unitCtrl.text.trim(),
      'price': priceStr,
      'compare_price': _comparePriceCtrl.text.trim().isEmpty
          ? null
          : _comparePriceCtrl.text.trim(),
      'cost_price': _tpCostPriceCtrl.text.trim().isEmpty
          ? null
          : _tpCostPriceCtrl.text.trim(),
      'trade_price': _tpCostPriceCtrl.text.trim().isEmpty
          ? null
          : _tpCostPriceCtrl.text.trim(),
      'tp_remark': _tpRemarkCtrl.text.trim().isEmpty
          ? (_isEdit
              ? 'Updated via Mobile App Edit'
              : 'Initial TP via Mobile App')
          : _tpRemarkCtrl.text.trim(),
      'stock': int.tryParse(_stockCtrl.text.trim()) ?? 0,
      'stock_quantity': int.tryParse(_stockCtrl.text.trim()) ?? 0,
      'sku': _skuCtrl.text.trim(),
      'barcode': _barcodeCtrl.text.trim(),
      'custom_badge': _badgeCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'meta_title': _metaTitleCtrl.text.trim(),
      'meta_description': _metaDescCtrl.text.trim(),
      'meta_keywords': _metaKeywordsCtrl.text.trim(),
      'category_ids': _selectedCategoryIds.toList(),
      'category_id': _selectedCategoryIds.isNotEmpty
          ? _selectedCategoryIds.first
          : null,
      'is_active': _isActive,
      'is_featured': _isFeatured,
      'is_bestseller': _isBestseller,
      'is_deal_of_day': _isDealOfDay,
    };

    try {
      late http.Response res;
      dynamic targetProductId;

      if (_isEdit) {
        targetProductId = widget.existingProduct!['id'];
        res = await http.patch(
          Uri.parse(
              '${widget.theme.apiBase}/api/v1/products/$targetProductId/?subdomain=${widget.theme.subdomain}'),
          headers: widget.theme.headers,
          body: jsonEncode(payload),
        );
      } else {
        res = await http.post(
          Uri.parse(
              '${widget.theme.apiBase}/api/v1/products/?subdomain=${widget.theme.subdomain}'),
          headers: widget.theme.headers,
          body: jsonEncode(payload),
        );
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        final savedData = jsonDecode(res.body);
        if (savedData is Map && savedData['id'] != null) {
          targetProductId = savedData['id'];
        }

        if (targetProductId != null && _pendingImages.isNotEmpty) {
          await _uploadPendingImagesForProduct(targetProductId);
        }

        _showSnack(_isEdit
            ? 'Product o Images shofolbhabe update hoyeche!'
            : 'Notun Product o Images shofolbhabe add hoyeche!');
        widget.onSaved();
        if (mounted) Navigator.of(context).pop();
      } else {
        _showSnack('Error (${res.statusCode}): ${res.body}', isError: true);
      }
    } catch (e) {
      _showSnack('Network error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildChromeSyncClickArea({
    required VoidCallback onTrigger,
    required Widget child,
  }) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) => _pointerDownPos = e.position,
      onPointerUp: (e) {
        if (_pointerDownPos != null &&
            15 > (e.position - _pointerDownPos!).distance) {
          onTrigger();
        }
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Dialog(
      backgroundColor: t.cardBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: t.cardBorder),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 780),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: t.useGradient ? null : t.primaryColor,
                gradient: t.useGradient ? t.brandGradient : null,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isEdit ? Icons.edit_note_rounded : Icons.add_box_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isEdit
                          ? 'Edit Product, Images & AI Suite'
                          : 'Add Product, Images & AI Suite',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Form Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMultipleImagesSection(),
                    const SizedBox(height: 14),
                    _buildInput('Product Name *', _nameCtrl,
                        Icons.shopping_bag_outlined),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInput(
                            'Selling Price (৳) *',
                            _priceCtrl,
                            Icons.sell_outlined,
                            isNumber: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildInput(
                            'Compare Price (৳)',
                            _comparePriceCtrl,
                            Icons.money_off_csred_outlined,
                            isNumber: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInput(
                            'TP / Trade Price (কেনা দাম ৳)',
                            _tpCostPriceCtrl,
                            Icons.price_change_outlined,
                            isNumber: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildInput(
                            'Stock Quantity *',
                            _stockCtrl,
                            Icons.inventory_2_outlined,
                            isNumber: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInput(
                      'TP Change Note / Remark (Optional)',
                      _tpRemarkCtrl,
                      Icons.history_edu_rounded,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInput(
                              'Unit (e.g. 1 pc, 1 kg)', _unitCtrl, Icons.scale),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildInput('Custom Badge (e.g. 20% OFF)',
                              _badgeCtrl, Icons.local_offer_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInput(
                              'SKU (Auto if empty)', _skuCtrl, Icons.qr_code),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildInput('Barcode', _barcodeCtrl,
                              Icons.qr_code_scanner_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Select Categories (${_selectedCategoryIds.length} selected)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: t.primaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (widget.categories.isEmpty)
                      Text(
                        'Kono category paoa jayni. Agey Category create korun.',
                        style: TextStyle(fontSize: 11, color: t.secondaryText),
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: widget.categories.map((cat) {
                          final int catId =
                              int.tryParse((cat['id'] ?? 0).toString()) ?? 0;
                          final String catName =
                              (cat['name'] ?? 'Category').toString();
                          final String shopName =
                              (cat['shop_name'] ?? 'Main Store').toString();
                          final bool selected =
                              _selectedCategoryIds.contains(catId);

                          return FilterChip(
                            selected: selected,
                            selectedColor: t.primaryColor,
                            checkmarkColor: Colors.white,
                            backgroundColor: t.inputBg,
                            side: BorderSide(
                              color: selected ? t.primaryColor : t.cardBorder,
                            ),
                            label: Text(
                              shopName != 'Main Store'
                                  ? '$catName ($shopName)'
                                  : catName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: selected ? Colors.white : t.primaryText,
                              ),
                            ),
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  _selectedCategoryIds.add(catId);
                                } else {
                                  _selectedCategoryIds.remove(catId);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 16),
                    _buildAiContentStudioBox(),
                    const SizedBox(height: 14),
                    _buildInput(
                      'Product Description (AI or Manual)',
                      _descCtrl,
                      Icons.description_outlined,
                      maxLines: 5,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'SEO & Google SERP Optimization',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: t.primaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildInput(
                        'SEO Meta Title', _metaTitleCtrl, Icons.travel_explore),
                    const SizedBox(height: 10),
                    _buildInput('SEO Meta Description', _metaDescCtrl,
                        Icons.manage_search_rounded,
                        maxLines: 2),
                    const SizedBox(height: 10),
                    _buildInput('Focus Keywords (comma separated)',
                        _metaKeywordsCtrl, Icons.tag_rounded),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildFlagChip('Active', _isActive,
                            (v) => setState(() => _isActive = (v == true))),
                        _buildFlagChip('Featured', _isFeatured,
                            (v) => setState(() => _isFeatured = (v == true))),
                        _buildFlagChip('Bestseller', _isBestseller,
                            (v) => setState(() => _isBestseller = (v == true))),
                        _buildFlagChip('Deal of Day', _isDealOfDay,
                            (v) => setState(() => _isDealOfDay = (v == true))),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Save Bar
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: t.cardBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: t.cardBorder),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                            color: t.secondaryText,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: t.useGradient ? null : t.primaryColor,
                        gradient: t.useGradient ? t.brandGradient : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submitProduct,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle_outline, size: 18),
                        label: Text(
                          _isEdit
                              ? 'Update Product'
                              : (_pendingImages.isNotEmpty
                                  ? 'Save & Upload (${_pendingImages.length})'
                                  : 'Save Product'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultipleImagesSection() {
    final t = widget.theme;
    final int totalCount = _serverImages.length + _pendingImages.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.inputBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_library_rounded,
                  color: t.primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Product Images Gallery ($totalCount)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: t.primaryText,
                      ),
                    ),
                    Text(
                      'গ্যালারি বা ক্যামেরা থেকে একসাথে একাধিক ছবি আপলোড করুন',
                      style: TextStyle(fontSize: 10.5, color: t.secondaryText),
                    ),
                  ],
                ),
              ),
              _buildChromeSyncClickArea(
                onTrigger: _pickMultipleImagesFromDevice,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: t.useGradient ? null : t.primaryColor,
                    gradient: t.useGradient ? t.brandGradient : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_photo_alternate_rounded,
                          size: 16, color: Colors.white),
                      SizedBox(width: 5),
                      Text(
                        '+ Add Images',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_isGalleryLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: t.primaryColor),
                ),
              ),
            )
          else if (_serverImages.isEmpty && _pendingImages.isEmpty)
            Row(
              children: [
                Expanded(
                  child: _buildChromeSyncClickArea(
                    onTrigger: _pickFromGalleryMulti,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: t.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: t.primaryColor.withValues(alpha: 0.45)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.collections_rounded,
                              size: 28, color: t.primaryColor),
                          const SizedBox(height: 6),
                          Text(
                            'Open Gallery',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: t.primaryText,
                            ),
                          ),
                          Text(
                            'Multiple Photos',
                            style: TextStyle(
                                fontSize: 10, color: t.secondaryText),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildChromeSyncClickArea(
                    onTrigger: _pickFromCamera,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: t.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: t.cardBorder),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.camera_alt_rounded,
                              size: 28, color: t.primaryColor),
                          const SizedBox(height: 6),
                          Text(
                            'Take Photo',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: t.primaryText,
                            ),
                          ),
                          Text(
                            'Use Camera',
                            style: TextStyle(
                                fontSize: 10, color: t.secondaryText),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ..._serverImages.map((rawImg) {
                    if (rawImg is! Map) return const SizedBox.shrink();
                    final int imgId =
                        int.tryParse((rawImg['id'] ?? 0).toString()) ?? 0;
                    final String rawUrl =
                        (rawImg['image_url'] ?? rawImg['image'] ?? '')
                            .toString();
                    final String fullUrl = _resolveFullImageUrl(rawUrl);
                    final bool isPrimary = rawImg['is_primary'] == true;

                    return Container(
                      width: 96,
                      height: 112,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: t.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isPrimary ? t.primaryColor : t.cardBorder,
                          width: isPrimary ? 2 : 1,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                fullUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.broken_image_outlined,
                                  color: t.secondaryText,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _deleteServerImage(imgId),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 4,
                            right: 4,
                            bottom: 4,
                            child: GestureDetector(
                              onTap: isPrimary
                                  ? null
                                  : () => _setServerImagePrimary(imgId),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 3),
                                decoration: BoxDecoration(
                                  color: isPrimary
                                      ? t.primaryColor
                                      : Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  isPrimary ? '★ COVER' : 'Set Cover',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  ...List.generate(_pendingImages.length, (idx) {
                    final _PendingLocalImage item =
                        _pendingImages[idx] as _PendingLocalImage;
                    return Container(
                      width: 96,
                      height: 112,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: t.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: item.isPrimary ? t.primaryColor : Colors.amber,
                          width: 2,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                item.bytes,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade800,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _pendingImages.removeAt(idx);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 4,
                            right: 4,
                            bottom: 4,
                            child: GestureDetector(
                              onTap: () => _setPendingImageAsPrimary(idx),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 3),
                                decoration: BoxDecoration(
                                  color: item.isPrimary
                                      ? t.primaryColor
                                      : Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  item.isPrimary ? '★ COVER' : 'Set Cover',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  _buildChromeSyncClickArea(
                    onTrigger: _pickFromGalleryMulti,
                    child: Container(
                      width: 82,
                      height: 112,
                      decoration: BoxDecoration(
                        color: t.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: t.cardBorder),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined,
                              color: t.primaryColor, size: 22),
                          const SizedBox(height: 4),
                          Text(
                            'Add More',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: t.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAiContentStudioBox() {
    final t = widget.theme;

    int? seoScore;
    String? seoGrade;
    String? readabilityGrade;
    int? wordCount;
    String? fbAdText;

    if (_aiResultSuite != null) {
      final dynamic seoAnalytics = _aiResultSuite!['seo_analytics'];
      if (seoAnalytics is Map && seoAnalytics['seo_audit'] is Map) {
        seoScore = int.tryParse(
            (seoAnalytics['seo_audit']['seo_score'] ?? '').toString());
        seoGrade = seoAnalytics['seo_audit']['grade']?.toString();
      }
      final dynamic qualityAudit = _aiResultSuite!['quality_audit'];
      if (qualityAudit is Map) {
        readabilityGrade = qualityAudit['quality_grade']?.toString();
        if (qualityAudit['readability'] is Map) {
          wordCount = int.tryParse(
              (qualityAudit['readability']['word_count'] ?? '').toString());
        }
      }
      final dynamic contentMap =
          _aiResultSuite!['content'] ?? _aiResultSuite!['bn'];
      if (contentMap is Map && contentMap['social_media_suite'] is Map) {
        fbAdText =
            contentMap['social_media_suite']['facebook_feed_ad']?.toString();
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.primaryColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: t.primaryColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'XyloSaaS AI Copywriter, NLP & SEO Engine (V5.0)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: t.primaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildSmallSelectorChip(
                label: '🇧🇩 বাংলা',
                selected: _aiLanguage == 'bn',
                onTap: () => setState(() => _aiLanguage = 'bn'),
              ),
              const SizedBox(width: 6),
              _buildSmallSelectorChip(
                label: '🇬🇧 English',
                selected: _aiLanguage == 'en',
                onTap: () => setState(() => _aiLanguage = 'en'),
              ),
              const SizedBox(width: 6),
              _buildSmallSelectorChip(
                label: '🌐 Bilingual (Both)',
                selected: _aiLanguage == 'both',
                onTap: () => setState(() => _aiLanguage = 'both'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSmallSelectorChip(
                  label: '🔥 Catchy',
                  selected: _aiTone == 'catchy',
                  onTap: () => setState(() => _aiTone = 'catchy'),
                ),
                const SizedBox(width: 6),
                _buildSmallSelectorChip(
                  label: '👑 Luxury',
                  selected: _aiTone == 'luxury',
                  onTap: () => setState(() => _aiTone = 'luxury'),
                ),
                const SizedBox(width: 6),
                _buildSmallSelectorChip(
                  label: '😊 Friendly',
                  selected: _aiTone == 'casual',
                  onTap: () => setState(() => _aiTone = 'casual'),
                ),
                const SizedBox(width: 6),
                _buildSmallSelectorChip(
                  label: '⚙️ Technical',
                  selected: _aiTone == 'technical',
                  onTap: () => setState(() => _aiTone = 'technical'),
                ),
                const SizedBox(width: 6),
                _buildSmallSelectorChip(
                  label: '🚨 Flash Deal',
                  selected: _aiTone == 'urgent',
                  onTap: () => setState(() => _aiTone = 'urgent'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildInput(
            'Raw Notes / Attributes (e.g. 500g, Pure Cotton, Black, Organic)',
            _aiFeaturesCtrl,
            Icons.psychology_outlined,
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 42,
            decoration: BoxDecoration(
              color: t.useGradient ? null : t.primaryColor,
              gradient: t.useGradient ? t.brandGradient : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton.icon(
              onPressed: _isAiGenerating ? null : _generateAiProductContent,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isAiGenerating
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome, size: 16),
              label: Text(
                _isAiGenerating
                    ? 'Generating AI Copy & SEO...'
                    : '✨ Generate AI Description & SEO Suite',
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
          ),
          if (seoScore != null ||
              readabilityGrade != null ||
              (fbAdText != null && fbAdText.isNotEmpty)) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (seoScore != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: t.primaryColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'SEO Score: $seoScore/100 (${seoGrade ?? "Optimized"})',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: t.primaryColor,
                      ),
                    ),
                  ),
                if (readabilityGrade != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'NLP Grade: $readabilityGrade ${wordCount != null ? "• $wordCount words" : ""}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.amber.shade800,
                      ),
                    ),
                  ),
                if (fbAdText != null && fbAdText.isNotEmpty)
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: fbAdText!));
                      _showSnack('Facebook Ad Copy clipboard-e copy hoyeche!');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded,
                              size: 12, color: Colors.blueAccent),
                          SizedBox(width: 4),
                          Text(
                            'Copy Facebook Ad Copy',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.blueAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSmallSelectorChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final t = widget.theme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? (t.useGradient ? null : t.primaryColor) : t.cardBg,
          gradient: (selected && t.useGradient) ? t.brandGradient : null,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? t.primaryColor : t.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : t.primaryText,
          ),
        ),
      ),
    );
  }

  Widget _buildFlagChip(String label, bool value, ValueChanged onChanged) {
    final t = widget.theme;
    return FilterChip(
      selected: value,
      selectedColor: t.primaryColor.withValues(alpha: 0.2),
      checkmarkColor: t.primaryColor,
      backgroundColor: t.inputBg,
      side: BorderSide(color: value ? t.primaryColor : t.cardBorder),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: value ? t.primaryColor : t.secondaryText,
        ),
      ),
      onSelected: onChanged,
    );
  }

  Widget _buildInput(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    int maxLines = 1,
    bool isNumber = false,
  }) {
    final t = widget.theme;
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: TextStyle(
          color: t.primaryText, fontSize: 13, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: t.secondaryText, fontSize: 12),
        prefixIcon: Icon(icon, color: t.primaryColor, size: 18),
        filled: true,
        fillColor: t.inputBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: t.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: t.cardBorder),
        ),
      ),
    );
  }
}