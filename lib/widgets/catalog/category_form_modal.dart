// lib/widgets/catalog/category_form_modal.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'catalog_theme_scope.dart';

typedef JsonMap = Map<String, dynamic>;
typedef HeaderMap = Map<String, String>;

class CategoryFormModal extends StatefulWidget {
  final CatalogThemeConfig theme;
  final JsonMap? existingCategory;
  final VoidCallback onSaved;

  const CategoryFormModal({
    super.key,
    required this.theme,
    this.existingCategory,
    required this.onSaved,
  });

  @override
  State createState() => _CategoryFormModalState();
}

class _CategoryFormModalState extends State {
  @override
  CategoryFormModal get widget => super.widget as CategoryFormModal;

  final ImagePicker _imagePicker = ImagePicker();

  bool _isSubmitting = false;
  bool _isAiLoading = false;
  String _aiLang = 'bn'; // 'bn' | 'en'
  Offset? _pointerDownPos;

  // Category Image State (Local Picked Bytes + Existing Server Image URL)
  Uint8List? _selectedImageBytes;
  String _selectedImageName = 'category_img.jpg';
  String _existingImageUrl = '';

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _iconCtrl = TextEditingController(text: '🛍️');
  final TextEditingController _orderCtrl = TextEditingController(text: '0');
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _metaTitleCtrl = TextEditingController();
  final TextEditingController _metaDescCtrl = TextEditingController();
  bool _showOnHomepage = true;

  static const _quickEmojis = [
    '🛍️', '🛒', '🍯', '🧈', '🌶️', '🍎', '🥦', '🐟',
    '🥩', '👗', '🥻', '👕', '👟', '👜', '💎', '🧴',
    '💄', '📱', '💻', '🎧', '🍳', '🛋️', '👶', '🧸',
  ];

  bool get _isEdit => widget.existingCategory != null;

  @override
  void initState() {
    super.initState();
    final c = widget.existingCategory;
    if (c != null) {
      _nameCtrl.text = (c['name'] ?? '').toString();
      _iconCtrl.text = (c['icon'] ?? '🛍️').toString();
      _orderCtrl.text = (c['display_order'] ?? 0).toString();
      _descCtrl.text = (c['description'] ?? '').toString();
      _metaTitleCtrl.text = (c['meta_title'] ?? '').toString();
      _metaDescCtrl.text = (c['meta_description'] ?? '').toString();
      _showOnHomepage = c['show_on_homepage'] ?? true;

      final rawImg = (c['image_url'] ?? c['image'] ?? '').toString().trim();
      if (rawImg.isNotEmpty) {
        _existingImageUrl = _resolveFullImageUrl(rawImg);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _iconCtrl.dispose();
    _orderCtrl.dispose();
    _descCtrl.dispose();
    _metaTitleCtrl.dispose();
    _metaDescCtrl.dispose();
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
  // 📸 MESSENGER-STYLE CATEGORY IMAGE PICKER (GALLERY / CAMERA / FILES / URL)
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

  Future _applyPickedXFile(XFile xfile) async {
    try {
      final Uint8List bytes = await xfile.readAsBytes();
      if (bytes.isEmpty) return;
      final String fileName = xfile.name.trim().isNotEmpty
          ? xfile.name.trim()
          : 'category_${DateTime.now().millisecondsSinceEpoch}.jpg';

      if (mounted) {
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = fileName;
        });
        _showSnack('ক্যাটাগরির ছবি সিলেক্ট হয়েছে!');
      }
    } catch (e) {
      _showSnack('ছবি লোড করতে সমস্যা হয়েছে: $e', isError: true);
    }
  }

  Future _pickCategoryImageFromGallery() async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
      );
      if (picked != null) {
        await _applyPickedXFile(picked);
        return;
      }
    } catch (err) {
      if (!kIsWeb && Platform.isLinux) {
        await _pickLinuxDesktopFile();
        return;
      }
      _showSnack('গ্যালারি পারমিশন প্রয়োজন: $err', isError: true);
    }
  }

  Future _pickCategoryImageFromCamera() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 88,
      );
      if (photo != null) {
        await _applyPickedXFile(photo);
      }
    } catch (e) {
      _showSnack('ক্যামেরা ওপেন করা যায়নি: $e', isError: true);
    }
  }

  Future _pickLinuxDesktopFile() async {
    try {
      final res = await Process.run('zenity', [
        '--file-selection',
        '--title=Select Category Image',
      ]);
      if (res.exitCode == 0) {
        final path = res.stdout.toString().trim();
        if (path.isNotEmpty) {
          await _applyPickedXFile(XFile(path));
        }
      }
    } catch (_) {}
  }

  Future _openCategoryImagePickerSheet() async {
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
                        'ক্যাটাগরির ছবি আপলোড করুন',
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

                // ১. ফোনের গ্যালারি থেকে ছবি নেওয়া
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _pickCategoryImageFromGallery();
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
                                'ফোনের গ্যালারি বা ফাইল থেকে ক্যাটাগরির ছবি সিলেক্ট করুন',
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

                // ২. ক্যামেরা দিয়ে ছবি তোলা
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _pickCategoryImageFromCamera();
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
                                'সরাসরি ক্যামেরা দিয়ে ক্যাটাগরির ছবি তুলুন',
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

                // ৩. ঐচ্ছিক: Image URL থেকে নেওয়া
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _showCategoryImageUrlDialog();
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

  Future _showCategoryImageUrlDialog() async {
    final TextEditingController urlCtrl = TextEditingController();
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
                'Add Category Image via URL',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: t.primaryText,
                ),
              ),
              content: SizedBox(
                width: 380,
                child: TextField(
                  controller: urlCtrl,
                  style: TextStyle(color: t.primaryText, fontSize: 12.5),
                  decoration: InputDecoration(
                    labelText: 'Direct Image URL',
                    hintText: 'https://example.com/category.png',
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
                          final raw = urlCtrl.text.trim();
                          if (raw.isEmpty) return;
                          setModalState(() => isFetching = true);
                          try {
                            Uint8List? bytes;
                            if (raw.contains('base64,')) {
                              bytes = base64Decode(
                                  raw.split('base64,').last.trim());
                            } else if (raw.startsWith('http')) {
                              final resp = await http.get(Uri.parse(raw));
                              if (resp.statusCode == 200) {
                                bytes = resp.bodyBytes;
                              }
                            }
                            if (bytes != null && mounted) {
                              setState(() {
                                _selectedImageBytes = bytes;
                                _selectedImageName = 'category_url_img.jpg';
                              });
                              if (ctx.mounted) Navigator.of(ctx).pop();
                              _showSnack('ক্যাটাগরির ছবি যুক্ত হয়েছে!');
                            }
                          } catch (_) {
                            _showSnack('ইমেজ লোড করা যায়নি!', isError: true);
                          } finally {
                            setModalState(() => isFetching = false);
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

  // ✨ AI Category Tagline, SEO & Auto Emoji Icon Generator
  Future _generateAiCategorySuite() async {
    final String catName = _nameCtrl.text.trim();
    if (catName.isEmpty) {
      _showSnack('Agey Category-er nam likhun!', isError: true);
      return;
    }

    setState(() => _isAiLoading = true);

    try {
      final res = await http.post(
        Uri.parse(
            '${widget.theme.apiBase}/api/v1/ai/generate-product-content/?subdomain=${widget.theme.subdomain}'),
        headers: widget.theme.headers,
        body: jsonEncode({
          'mode': 'category_only',
          'name': catName,
          'language': _aiLang,
        }),
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is Map) {
          final dynamic data = body['data'] ?? body;
          final String icon = (body['suggested_icon'] ??
                  (data is Map ? data['suggested_icon'] : null) ??
                  CatalogThemeConfig.guessCategoryIcon(catName))
              .toString();
          final String desc = (body['description'] ??
                  (data is Map ? data['short_description'] : null) ??
                  '')
              .toString();
          final String mTitle =
              (data is Map ? (data['meta_title'] ?? '') : '').toString();
          final String mDesc =
              (data is Map ? (data['meta_description'] ?? '') : '').toString();

          setState(() {
            _iconCtrl.text = icon;
            if (desc.isNotEmpty) _descCtrl.text = desc;
            if (mTitle.isNotEmpty) _metaTitleCtrl.text = mTitle;
            if (mDesc.isNotEmpty) _metaDescCtrl.text = mDesc;
          });
          _showSnack('✨ AI Category Icon, Tagline o SEO set hoyeche!');
          return;
        }
      }
      _applyLocalCategoryFallback(catName);
    } catch (_) {
      _applyLocalCategoryFallback(catName);
    } finally {
      if (mounted) setState(() => _isAiLoading = false);
    }
  }

  void _applyLocalCategoryFallback(String catName) {
    final String icon = CatalogThemeConfig.guessCategoryIcon(catName);
    setState(() {
      _iconCtrl.text = icon;
      _descCtrl.text = _aiLang == 'en'
          ? 'Explore our authentic $catName collection with 100% verified quality and fast nationwide Cash on Delivery.'
          : '$catName কালেকশনে পাচ্ছেন ১০০% খাঁটি ও বাছাইকৃত মানের নিশ্চয়তা এবং সারা দেশে দ্রুত হোম ডেলিভারি সুবিধা।';
      _metaTitleCtrl.text = _aiLang == 'en'
          ? 'Buy $catName Online in BD | Best Price'
          : '$catName - সেরা দামে অনলাইনে কিনুন বাংলাদেশে';
      _metaDescCtrl.text = _descCtrl.text;
    });
    _showSnack('✨ Smart Category Icon o Tagline set kora hoyeche!');
  }

  Future _submitCategory() async {
    final String name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showSnack('Category-er nam likhun!', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    final String resolvedIcon = _iconCtrl.text.trim().isEmpty
        ? CatalogThemeConfig.guessCategoryIcon(name)
        : _iconCtrl.text.trim();
    final int resolvedOrder = int.tryParse(_orderCtrl.text.trim()) ?? 0;

    try {
      final String urlStr = _isEdit
          ? '${widget.theme.apiBase}/api/v1/products/categories/${widget.existingCategory!['id']}/?subdomain=${widget.theme.subdomain}'
          : '${widget.theme.apiBase}/api/v1/products/categories/?subdomain=${widget.theme.subdomain}';

      int statusCode = 500;
      String responseBody = '';

      // যদি গ্যালারি/ক্যামেরা থেকে ছবি সিলেক্ট করা থাকে তবে Multipart Request পাঠানো হবে
      if (_selectedImageBytes != null) {
        final req = http.MultipartRequest(
          _isEdit ? 'PATCH' : 'POST',
          Uri.parse(urlStr),
        );
        req.headers.addAll(_multipartHeaders);
        req.fields['name'] = name;
        req.fields['icon'] = resolvedIcon;
        req.fields['display_order'] = resolvedOrder.toString();
        req.fields['description'] = _descCtrl.text.trim();
        req.fields['meta_title'] = _metaTitleCtrl.text.trim();
        req.fields['meta_description'] = _metaDescCtrl.text.trim();
        req.fields['show_on_homepage'] = _showOnHomepage ? 'true' : 'false';
        req.files.add(
          http.MultipartFile.fromBytes(
            'image',
            _selectedImageBytes!,
            filename: _selectedImageName,
          ),
        );
        final streamed = await req.send();
        final res = await http.Response.fromStream(streamed);
        statusCode = res.statusCode;
        responseBody = res.body;
      } else {
        final JsonMap payload = {
          'name': name,
          'icon': resolvedIcon,
          'display_order': resolvedOrder,
          'description': _descCtrl.text.trim(),
          'meta_title': _metaTitleCtrl.text.trim(),
          'meta_description': _metaDescCtrl.text.trim(),
          'show_on_homepage': _showOnHomepage,
        };
        final res = _isEdit
            ? await http.patch(
                Uri.parse(urlStr),
                headers: widget.theme.headers,
                body: jsonEncode(payload),
              )
            : await http.post(
                Uri.parse(urlStr),
                headers: widget.theme.headers,
                body: jsonEncode(payload),
              );
        statusCode = res.statusCode;
        responseBody = res.body;
      }

      if (statusCode == 200 || statusCode == 201) {
        _showSnack(_isEdit
            ? 'Category shofolbhabe update hoyeche!'
            : 'Notun Category shofolbhabe create hoyeche!');
        widget.onSaved();
        if (mounted) Navigator.of(context).pop();
      } else {
        _showSnack('Error ($statusCode): $responseBody', isError: true);
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

  Widget _buildCategoryImageSection() {
    final t = widget.theme;
    final bool hasImage =
        _selectedImageBytes != null || _existingImageUrl.isNotEmpty;

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
              Icon(Icons.image_outlined, color: t.primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Category Image / Banner',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: t.primaryText,
                      ),
                    ),
                    Text(
                      'গ্যালারি বা ক্যামেরা থেকে ক্যাটাগরির ছবি আপলোড করুন',
                      style: TextStyle(fontSize: 10.5, color: t.secondaryText),
                    ),
                  ],
                ),
              ),
              _buildChromeSyncClickArea(
                onTrigger: _openCategoryImagePickerSheet,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: t.useGradient ? null : t.primaryColor,
                    gradient: t.useGradient ? t.brandGradient : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_a_photo_rounded,
                          size: 15, color: Colors.white),
                      SizedBox(width: 5),
                      Text(
                        '+ Upload Image',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
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

          if (!hasImage)
            Row(
              children: [
                Expanded(
                  child: _buildChromeSyncClickArea(
                    onTrigger: _pickCategoryImageFromGallery,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: t.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: t.primaryColor.withValues(alpha: 0.45)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.collections_rounded,
                              size: 24, color: t.primaryColor),
                          const SizedBox(height: 4),
                          Text(
                            'Open Gallery',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: t.primaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildChromeSyncClickArea(
                    onTrigger: _pickCategoryImageFromCamera,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: t.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: t.cardBorder),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.camera_alt_rounded,
                              size: 24, color: t.primaryColor),
                          const SizedBox(height: 4),
                          Text(
                            'Take Photo',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: t.primaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: t.cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: t.primaryColor, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _selectedImageBytes != null
                        ? Image.memory(_selectedImageBytes!, fit: BoxFit.cover)
                        : Image.network(
                            _existingImageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.broken_image_outlined,
                              color: t.secondaryText,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedImageBytes != null
                            ? _selectedImageName
                            : 'Current Category Image',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: t.primaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _openCategoryImagePickerSheet,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: t.primaryColor),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                            ),
                            icon: Icon(Icons.sync_rounded,
                                size: 14, color: t.primaryColor),
                            label: Text(
                              'Change',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: t.primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Remove Image',
                            onPressed: () {
                              setState(() {
                                _selectedImageBytes = null;
                                _existingImageUrl = '';
                              });
                            },
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: Colors.redAccent, size: 20),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Dialog(
      backgroundColor: t.cardBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: t.cardBorder),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                      _isEdit
                          ? Icons.edit_attributes_rounded
                          : Icons.create_new_folder_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isEdit
                            ? 'Edit Category, Image & AI SEO'
                            : 'Add Category, Image & AI SEO',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon:
                          const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCategoryImageSection(),
                    const SizedBox(height: 14),

                    TextField(
                      controller: _nameCtrl,
                      onChanged: (val) {
                        if (!_isEdit && val.trim().isNotEmpty) {
                          setState(() {
                            _iconCtrl.text =
                                CatalogThemeConfig.guessCategoryIcon(val);
                          });
                        }
                      },
                      style: TextStyle(
                          color: t.primaryText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText:
                            'Category Name * (e.g. সুন্দরবনের মধু / Shoes)',
                        labelStyle:
                            TextStyle(color: t.secondaryText, fontSize: 12),
                        prefixIcon: Icon(Icons.category_outlined,
                            color: t.primaryColor, size: 18),
                        filled: true,
                        fillColor: t.inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: t.cardBorder),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ✨ AI Auto Icon, Tagline & SEO Bar
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: t.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: t.primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => setState(() =>
                                _aiLang = _aiLang == 'bn' ? 'en' : 'bn'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: t.cardBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: t.cardBorder),
                              ),
                              child: Text(
                                _aiLang == 'bn' ? '🇧🇩 বাংলা' : '🇬🇧 EN',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: t.primaryText,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isAiLoading
                                  ? null
                                  : _generateAiCategorySuite,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: t.primaryColor,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 9),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: _isAiLoading
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.auto_awesome, size: 15),
                              label: const Text(
                                '✨ AI Auto Icon, Tagline & SEO',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _buildInput('Emoji / Icon', _iconCtrl,
                              Icons.emoji_emotions_outlined),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildInput('Display Order', _orderCtrl,
                              Icons.sort_rounded,
                              isNumber: true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Quick Emoji Select:',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: t.primaryText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _quickEmojis.map((em) {
                        final bool selected = _iconCtrl.text.trim() == em;
                        return GestureDetector(
                          onTap: () => setState(() => _iconCtrl.text = em),
                          child: Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected
                                  ? t.primaryColor.withValues(alpha: 0.2)
                                  : t.inputBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color:
                                    selected ? t.primaryColor : t.cardBorder,
                              ),
                            ),
                            child:
                                Text(em, style: const TextStyle(fontSize: 16)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    _buildInput('Category Description / Tagline', _descCtrl,
                        Icons.description_outlined,
                        maxLines: 2),
                    const SizedBox(height: 10),
                    _buildInput('SEO Meta Title', _metaTitleCtrl,
                        Icons.travel_explore_rounded),
                    const SizedBox(height: 10),
                    _buildInput('SEO Meta Description', _metaDescCtrl,
                        Icons.manage_search_rounded,
                        maxLines: 2),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: t.primaryColor,
                      title: Text(
                        'Show on Storefront Homepage',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: t.primaryText,
                        ),
                      ),
                      value: _showOnHomepage,
                      onChanged: (val) =>
                          setState(() => _showOnHomepage = val),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      height: 44,
                      decoration: BoxDecoration(
                        color: t.useGradient ? null : t.primaryColor,
                        gradient: t.useGradient ? t.brandGradient : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submitCategory,
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
                          _isEdit ? 'Update Category' : 'Create Category',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 13),
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
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
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