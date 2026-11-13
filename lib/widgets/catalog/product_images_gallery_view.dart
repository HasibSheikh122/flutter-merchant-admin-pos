// lib/widgets/catalog/product_images_gallery_view.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'catalog_theme_scope.dart';

class _GalleryPickedFile {
  final String name;
  final Uint8List bytes;

  _GalleryPickedFile({required this.name, required this.bytes});
}

class ProductImagesGalleryView extends StatefulWidget {
  final bool isDarkMode;
  final Color brandGreen;
  final VoidCallback? onCatalogChanged;

  const ProductImagesGalleryView({
    super.key,
    required this.isDarkMode,
    required this.brandGreen,
    this.onCatalogChanged,
  });

  @override
  State createState() => _ProductImagesGalleryViewState();
}

class _ProductImagesGalleryViewState extends State {
  @override
  ProductImagesGalleryView get widget =>
      super.widget as ProductImagesGalleryView;

  CatalogThemeConfig _theme = const CatalogThemeConfig();
  bool _isLoading = true;
  bool _isUploading = false;

  List _images = [];
  List _products = [];

  String _searchQuery = '';
  int? _filterProductId;
  String _typeFilter = 'all'; // 'all' | 'cover' | 'additional'

  // Upload Section State
  int? _uploadTargetProductId;
  bool _uploadAsPrimary = false;
  final List _pickedFiles = [];
  Offset? _pointerDownPos;

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initAndFetch();
  }

  @override
  void didUpdateWidget(covariant ProductImagesGalleryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initAndFetch();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future _initAndFetch() async {
    final loadedTheme = await CatalogThemeConfig.load(
      isDarkMode: widget.isDarkMode,
      fallbackBrandGreen: widget.brandGreen,
    );
    if (!mounted) return;
    setState(() {
      _theme = loadedTheme;
      _isLoading = true;
    });

    try {
      final results = await Future.wait([
        http
            .get(
              Uri.parse(
                  '${_theme.apiBase}/api/v1/products/images/?subdomain=${_theme.subdomain}&page_size=1000&limit=1000&ordering=-id&no_page=true'),
              headers: _theme.headers,
            )
            .catchError((_) => http.Response('[]', 500)),
        http
            .get(
              Uri.parse(
                  '${_theme.apiBase}/api/v1/products/?subdomain=${_theme.subdomain}&admin=true&include_inactive=true'),
              headers: _theme.headers,
            )
            .catchError((_) => http.Response('[]', 500)),
      ]);

      if (results[0].statusCode == 200) {
        final iData = jsonDecode(results[0].body);
        if (iData is List) {
          _images = iData;
        } else if (iData is Map && iData['results'] is List) {
          _images = iData['results'];
        }
      }

      if (results[1].statusCode == 200) {
        final pData = jsonDecode(results[1].body);
        if (pData is List) {
          _products = pData;
        } else if (pData is Map && pData['results'] is List) {
          _products = pData['results'];
        }
        if (_uploadTargetProductId == null && _products.isNotEmpty) {
          final firstProd = _products.first;
          if (firstProd is Map) {
            _uploadTargetProductId =
                int.tryParse((firstProd['id'] ?? '').toString());
          }
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? Colors.redAccent : _theme.primaryColor,
        content: Text(
          msg,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Map<String, String> get _multipartHeaders {
    final Map<String, String> h = {
      'Accept': 'application/json',
      'X-Tenant-Subdomain': _theme.subdomain,
      'x-subdomain': _theme.subdomain,
      'X-Tenant-Domain': _theme.subdomain,
    };
    if (_theme.token.isNotEmpty) {
      h['Authorization'] = 'Bearer ${_theme.token}';
    }
    return h;
  }

  String _resolveImageUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return '${_theme.apiBase}$raw';
    return '${_theme.apiBase}/$raw';
  }

  // Cross-Platform Multi-Image Picker Dialog (Works on Android APK, iOS, Desktop & Chrome Web)
  Future _triggerChromeFilePicker() async {
    final TextEditingController urlsCtrl = TextEditingController();
    final TextEditingController nameCtrl =
        TextEditingController(text: 'product_photo.png');
    bool isFetching = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        final t = _theme;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              backgroundColor: t.cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: t.cardBorder),
              ),
              title: Row(
                children: [
                  Icon(Icons.add_photo_alternate_rounded,
                      color: t.primaryColor, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Add Multiple Product Images',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: t.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ek ba ekadhik Direct Image URL (proti line-e 1ti) othoba Base64 Data URL paste korun:',
                        style: TextStyle(fontSize: 12, color: t.secondaryText),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: nameCtrl,
                        style: TextStyle(color: t.primaryText, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Default File Name',
                          labelStyle:
                              TextStyle(color: t.secondaryText, fontSize: 12),
                          prefixIcon: Icon(
                            Icons.insert_drive_file_outlined,
                            color: t.primaryColor,
                            size: 18,
                          ),
                          filled: true,
                          fillColor: t.inputBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: t.cardBorder),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: urlsCtrl,
                        maxLines: 4,
                        style: TextStyle(color: t.primaryText, fontSize: 12.5),
                        decoration: InputDecoration(
                          labelText:
                              'Image URLs (One per line) or Base64 Data URI *',
                          hintText:
                              'https://example.com/photo1.jpg\nhttps://example.com/photo2.png\ndata:image/png;base64,...',
                          labelStyle:
                              TextStyle(color: t.secondaryText, fontSize: 12),
                          hintStyle:
                              TextStyle(color: t.secondaryText, fontSize: 11),
                          filled: true,
                          fillColor: t.inputBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: t.cardBorder),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isFetching ? null : () => Navigator.of(ctx).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: t.secondaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isFetching
                      ? null
                      : () async {
                          final rawInput = urlsCtrl.text.trim();
                          if (rawInput.isEmpty) {
                            _showSnack('Image URL othoba Base64 দিন!',
                                isError: true);
                            return;
                          }
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
                              if (line.contains('base64,')) {
                                final b64 = line.split('base64,').last.trim();
                                final Uint8List bytes = base64Decode(b64);
                                if (mounted) {
                                  setState(() {
                                    _pickedFiles.add(
                                      _GalleryPickedFile(
                                        name: nameCtrl.text.trim().isNotEmpty
                                            ? '${idx + 1}_${nameCtrl.text.trim()}'
                                            : 'photo_${idx + 1}.png',
                                        bytes: bytes,
                                      ),
                                    );
                                  });
                                  added++;
                                }
                              } else if (line.startsWith('http://') ||
                                  line.startsWith('https://')) {
                                final resp = await http.get(Uri.parse(line));
                                if (resp.statusCode == 200 &&
                                    resp.bodyBytes.isNotEmpty) {
                                  final uriSegs = Uri.parse(line).pathSegments;
                                  final lastSeg = uriSegs.isNotEmpty
                                      ? uriSegs.last
                                      : 'photo_${idx + 1}.png';
                                  if (mounted) {
                                    setState(() {
                                      _pickedFiles.add(
                                        _GalleryPickedFile(
                                          name: lastSeg.contains('.')
                                              ? lastSeg
                                              : 'photo_${idx + 1}.png',
                                          bytes: resp.bodyBytes,
                                        ),
                                      );
                                    });
                                    added++;
                                  }
                                }
                              } else {
                                final Uint8List bytes = base64Decode(line);
                                if (mounted) {
                                  setState(() {
                                    _pickedFiles.add(
                                      _GalleryPickedFile(
                                        name: 'photo_${idx + 1}.png',
                                        bytes: bytes,
                                      ),
                                    );
                                  });
                                  added++;
                                }
                              }
                            } catch (_) {}
                          }

                          setModalState(() => isFetching = false);
                          if (added > 0) {
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            _showSnack('$added-ti chobi list-e jukto hoyeche!');
                          } else {
                            _showSnack(
                              'Image load kora jayni! Valid Image URL othoba Base64 দিন।',
                              isError: true,
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: isFetching
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline, size: 16),
                  label: Text(
                    isFetching ? 'Loading...' : 'Add Images',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future _uploadPickedImagesToProduct() async {
    if (_uploadTargetProductId == null) {
      _showSnack('Agey ekta Product select korun!', isError: true);
      return;
    }
    if (_pickedFiles.isEmpty) {
      _showSnack('Agey 1ti ba ekadhik chobi select korun!', isError: true);
      return;
    }

    setState(() => _isUploading = true);
    int uploadedCount = 0;

    try {
      for (int i = 0; _pickedFiles.length > i; i++) {
        final _GalleryPickedFile item = _pickedFiles[i] as _GalleryPickedFile;
        final uri = Uri.parse(
            '${_theme.apiBase}/api/v1/products/$_uploadTargetProductId/upload-image/?subdomain=${_theme.subdomain}');
        final req = http.MultipartRequest('POST', uri);
        req.headers.addAll(_multipartHeaders);
        if (_uploadAsPrimary && i == 0) {
          req.fields['is_primary'] = 'true';
        }
        req.files.add(
          http.MultipartFile.fromBytes(
            'image',
            item.bytes,
            filename: item.name,
          ),
        );
        final streamed = await req.send();
        if (streamed.statusCode == 200 || streamed.statusCode == 201) {
          uploadedCount++;
        }
      }

      if (uploadedCount > 0) {
        _pickedFiles.clear();
        _showSnack('$uploadedCount-ti chobi shofolbhabe upload hoyeche!');
        widget.onCatalogChanged?.call();
        await _initAndFetch();
      } else {
        _showSnack('Image upload korte somossha hoyeche!', isError: true);
      }
    } catch (e) {
      _showSnack('Upload error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future _setAsCoverImage(Map img) async {
    final prodId = img['product'];
    final imgId = img['id'];
    if (prodId == null || imgId == null) return;

    try {
      final res = await http.post(
        Uri.parse(
            '${_theme.apiBase}/api/v1/products/$prodId/images/$imgId/set-primary/?subdomain=${_theme.subdomain}'),
        headers: _theme.headers,
      );
      if (res.statusCode == 200) {
        _showSnack('Cover photo set kora hoyeche!');
        widget.onCatalogChanged?.call();
        await _initAndFetch();
      }
    } catch (_) {}
  }

  Future _deleteImage(Map img) async {
    final imgId = img['id'];
    if (imgId == null) return;

    try {
      final res = await http.delete(
        Uri.parse(
            '${_theme.apiBase}/api/v1/products/images/$imgId/?subdomain=${_theme.subdomain}'),
        headers: _theme.headers,
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        _showSnack('Photo delete kora hoyeche.');
        widget.onCatalogChanged?.call();
        await _initAndFetch();
      }
    } catch (_) {}
  }

  void _openAiMotionStudioModal(Map img) {
    showDialog(
      context: context,
      builder: (_) => _AiMotionStudioDialog(
        theme: _theme,
        imageObj: img,
        resolvedImageUrl:
            _resolveImageUrl((img['image_url'] ?? img['image'])?.toString()),
        onSaved: () {
          widget.onCatalogChanged?.call();
          _initAndFetch();
        },
      ),
    );
  }

  List get _filteredImages {
    return _images.where((raw) {
      if (raw is! Map) return false;
      if (_filterProductId != null &&
          int.tryParse((raw['product'] ?? '').toString()) != _filterProductId) {
        return false;
      }
      if (_typeFilter == 'cover' && raw['is_primary'] != true) return false;
      if (_typeFilter == 'additional' && raw['is_primary'] == true) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final String pName =
            (raw['product_name'] ?? '').toString().toLowerCase();
        if (!pName.contains(_searchQuery.toLowerCase())) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = _theme;
    final filtered = _filteredImages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Header Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: t.useGradient
                          ? null
                          : t.primaryColor.withValues(alpha: 0.15),
                      gradient: t.useGradient ? t.brandGradient : null,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.photo_library_rounded,
                      color: t.useGradient ? Colors.white : t.primaryColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Product Images & 3D AI Studio (${_images.length})',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: t.primaryText,
                          ),
                        ),
                        Text(
                          'Multi-Upload, Cover Photo, AI Cutout & 3D Commercial Staging',
                          style:
                              TextStyle(fontSize: 11, color: t.secondaryText),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _initAndFetch,
                    icon: Icon(Icons.refresh_rounded, color: t.primaryText),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Direct Multi-Image Upload Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.inputBg,
                  borderRadius: BorderRadius.circular(18),
                  border:
                      Border.all(color: t.primaryColor.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upload Multiple Photos to Product',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: t.primaryText,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Product Selector Dropdown
                    DropdownButtonFormField(
                      value: _uploadTargetProductId,
                      dropdownColor: t.cardBg,
                      style: TextStyle(
                          color: t.primaryText,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        labelText: 'Select Product *',
                        labelStyle:
                            TextStyle(color: t.secondaryText, fontSize: 12),
                        prefixIcon: Icon(Icons.shopping_bag_outlined,
                            color: t.primaryColor, size: 18),
                        filled: true,
                        fillColor: t.cardBg,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: t.cardBorder),
                        ),
                      ),
                      items: _products.map((p) {
                        final int pid =
                            int.tryParse((p['id'] ?? 0).toString()) ?? 0;
                        final String pName =
                            (p['name'] ?? 'Product').toString();
                        return DropdownMenuItem(
                          value: pid,
                          child: Text(
                            pName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _uploadTargetProductId = val as int?);
                      },
                    ),
                    const SizedBox(height: 10),

                    // Pointer Listener for Multi-Platform Image Picker
                    Listener(
                      onPointerDown: (e) => _pointerDownPos = e.position,
                      onPointerUp: (e) {
                        if (_pointerDownPos != null &&
                            15 > (e.position - _pointerDownPos!).distance) {
                          _triggerChromeFilePicker();
                        }
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 12),
                          decoration: BoxDecoration(
                            color: t.cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: t.primaryColor),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_rounded,
                                  color: t.primaryColor, size: 22),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _pickedFiles.isEmpty
                                      ? 'Click to Add Multiple Product Images'
                                      : '${_pickedFiles.length} Image(s) Selected — Click to Add More',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                    color: t.primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (_pickedFiles.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(_pickedFiles.length, (i) {
                            final _GalleryPickedFile f =
                                _pickedFiles[i] as _GalleryPickedFile;
                            return Container(
                              width: 74,
                              height: 74,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: t.primaryColor),
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(9),
                                      child: Image.memory(f.bytes,
                                          fit: BoxFit.cover),
                                    ),
                                  ),
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: GestureDetector(
                                      onTap: () => setState(
                                          () => _pickedFiles.removeAt(i)),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.redAccent,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close,
                                            size: 11, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        activeColor: t.primaryColor,
                        title: Text(
                          'Set first image as Product Cover (Primary)',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: t.primaryText),
                        ),
                        value: _uploadAsPrimary,
                        onChanged: (v) => setState(() => _uploadAsPrimary = v),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        height: 42,
                        decoration: BoxDecoration(
                          color: t.useGradient ? null : t.primaryColor,
                          gradient: t.useGradient ? t.brandGradient : null,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _isUploading
                              ? null
                              : _uploadPickedImagesToProduct,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                          ),
                          icon: _isUploading
                              ? const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.cloud_upload_rounded,
                                  size: 18),
                          label: Text(
                            _isUploading
                                ? 'Uploading...'
                                : 'Upload ${_pickedFiles.length} Image(s) Now',
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 12.5),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Search & Filter Bar
              TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
                style: TextStyle(color: t.primaryText, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search images by product name...',
                  hintStyle: TextStyle(color: t.secondaryText, fontSize: 12),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: t.primaryColor, size: 18),
                  filled: true,
                  fillColor: t.inputBg,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: t.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTypeFilterChip(
                        'all', 'All Photos (${_images.length})'),
                    _buildTypeFilterChip('cover', '★ Cover Photos'),
                    _buildTypeFilterChip('additional', 'Additional Gallery'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Gallery Grid / List
        if (_isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: CircularProgressIndicator(color: t.primaryColor),
            ),
          )
        else if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: t.cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: t.cardBorder),
            ),
            child: Center(
              child: Text(
                'Kono product image paoa jayni.',
                style: TextStyle(color: t.secondaryText, fontSize: 13),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.76,
            ),
            itemCount: filtered.length,
            itemBuilder: (ctx, i) {
              final Map img = Map.from(filtered[i] as Map);
              return _buildGalleryCard(img);
            },
          ),
      ],
    );
  }

  Widget _buildTypeFilterChip(String key, String label) {
    final t = _theme;
    final bool selected = _typeFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _typeFilter = key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color:
                selected ? (t.useGradient ? null : t.primaryColor) : t.inputBg,
            gradient: (selected && t.useGradient) ? t.brandGradient : null,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? t.primaryColor : t.cardBorder),
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
      ),
    );
  }

  Widget _buildGalleryCard(Map img) {
    final t = _theme;
    final String prodName = (img['product_name'] ?? 'Product').toString();
    final String imgUrl =
        _resolveImageUrl((img['image_url'] ?? img['image'])?.toString());
    final bool isPrimary = img['is_primary'] == true;

    return Container(
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPrimary ? t.primaryColor : t.cardBorder,
          width: isPrimary ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: Image.network(
                      imgUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.broken_image_outlined,
                        color: t.secondaryText,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                if (isPrimary)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: t.primaryColor,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Text(
                        '★ COVER',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => _deleteImage(img),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_outline,
                          size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prodName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: t.primaryText,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: isPrimary ? null : () => _setAsCoverImage(img),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          decoration: BoxDecoration(
                            color: isPrimary
                                ? t.inputBg
                                : t.primaryColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            isPrimary ? 'Cover' : 'Set Cover',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color:
                                  isPrimary ? t.secondaryText : t.primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: InkWell(
                        onTap: () => _openAiMotionStudioModal(img),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          decoration: BoxDecoration(
                            color: t.useGradient ? null : t.primaryColor,
                            gradient: t.useGradient ? t.brandGradient : null,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            '✨ 3D AI',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 🌟 3D MOTION STUDIO & AI CUTOUT MODAL (Connected to apps/ai_engine/views.py)
// =============================================================================
class _AiMotionStudioDialog extends StatefulWidget {
  final CatalogThemeConfig theme;
  final Map imageObj;
  final String resolvedImageUrl;
  final VoidCallback onSaved;

  const _AiMotionStudioDialog({
    required this.theme,
    required this.imageObj,
    required this.resolvedImageUrl,
    required this.onSaved,
  });

  @override
  State createState() => _AiMotionStudioDialogState();
}

class _AiMotionStudioDialogState extends State {
  @override
  _AiMotionStudioDialog get widget => super.widget as _AiMotionStudioDialog;

  bool _isProcessing = false;
  String _selectedEffectId = 'sea_floral_arch';
  final double _offsetX = 0;
  final double _offsetY = 0;
  double _scale = 1.0;

  Uint8List? _processedBytes;

  static const _scenes = [
    {'id': 'sea_floral_arch', 'name': '🌸 Sea Floral Arch'},
    {'id': 'mossy_forest', 'name': '🌿 Mossy Forest'},
    {'id': 'ocean_cliff', 'name': '🌊 Ocean Cliff'},
    {'id': 'ice_cubes_splash', 'name': '🧊 3D Ice Splash'},
    {'id': 'water_vortex_stage', 'name': '💧 Water Vortex'},
    {'id': 'red_canyon', 'name': '🏜️ Red Canyon'},
    {'id': 'desert_sunset', 'name': '☀️ Desert Sunset'},
    {'id': 'dune_sand', 'name': '🌾 Pampas Dune'},
  ];

  Map<String, String> get _multipartHeaders {
    final Map<String, String> h = {
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

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? Colors.redAccent : widget.theme.primaryColor,
        content: Text(msg,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future _downloadOriginalBytes() async {
    try {
      final res = await http.get(Uri.parse(widget.resolvedImageUrl));
      if (res.statusCode == 200) return res.bodyBytes;
    } catch (_) {}
    return null;
  }

  Future _runAiCutout() async {
    setState(() => _isProcessing = true);
    try {
      final Uint8List? origBytes = await _downloadOriginalBytes() as Uint8List?;
      if (origBytes == null) {
        _showSnack('Original image download kora jayni!', isError: true);
        return;
      }

      final req = http.MultipartRequest(
        'POST',
        Uri.parse(
            '${widget.theme.apiBase}/api/v1/ai/motion/cutout/?subdomain=${widget.theme.subdomain}'),
      );
      req.headers.addAll(_multipartHeaders);
      req.files.add(http.MultipartFile.fromBytes('image', origBytes,
          filename: 'product.png'));

      final streamed = await req.send();
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode == 200) {
        final data = jsonDecode(body);
        if (data is Map && data['cutout'] != null) {
          final String b64 = data['cutout'].toString().split(',').last;
          setState(() => _processedBytes = base64Decode(b64));
          _showSnack('✨ AI Background Cutout shomponno hoyeche!');
        }
      }
    } catch (e) {
      _showSnack('Cutout error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future _apply3DStageEffect() async {
    setState(() => _isProcessing = true);
    try {
      final Uint8List? sourceBytes =
          _processedBytes ?? (await _downloadOriginalBytes() as Uint8List?);
      if (sourceBytes == null) {
        _showSnack('Image load kora jayni!', isError: true);
        return;
      }

      final req = http.MultipartRequest(
        'POST',
        Uri.parse(
            '${widget.theme.apiBase}/api/v1/ai/motion/apply/?subdomain=${widget.theme.subdomain}'),
      );
      req.headers.addAll(_multipartHeaders);
      req.fields['effect_id'] = _selectedEffectId;
      req.fields['offset_x'] = _offsetX.round().toString();
      req.fields['offset_y'] = _offsetY.round().toString();
      req.fields['scale'] = _scale.toStringAsFixed(2);
      req.files.add(http.MultipartFile.fromBytes('image', sourceBytes,
          filename: 'stage_input.png'));

      final streamed = await req.send();
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode == 200) {
        final data = jsonDecode(body);
        if (data is Map && data['composite_image'] != null) {
          final String b64 =
              data['composite_image'].toString().split(',').last;
          setState(() => _processedBytes = base64Decode(b64));
          _showSnack('✨ 3D Commercial Stage apply hoyeche!');
        }
      }
    } catch (e) {
      _showSnack('3D Stage error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future _saveProcessedImageToProduct() async {
    if (_processedBytes == null) return;
    final prodId = widget.imageObj['product'];
    if (prodId == null) return;

    setState(() => _isProcessing = true);
    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse(
            '${widget.theme.apiBase}/api/v1/products/$prodId/upload-image/?subdomain=${widget.theme.subdomain}'),
      );
      req.headers.addAll(_multipartHeaders);
      if (widget.imageObj['is_primary'] == true) {
        req.fields['is_primary'] = 'true';
      }
      req.files.add(http.MultipartFile.fromBytes(
        'image',
        _processedBytes!,
        filename: 'ai_studio_${DateTime.now().millisecondsSinceEpoch}.png',
      ));

      final streamed = await req.send();
      if (streamed.statusCode == 200 || streamed.statusCode == 201) {
        _showSnack('✨ Processed Image Product-e save hoyeche!');
        widget.onSaved();
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      _showSnack('Save error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Dialog(
      backgroundColor: t.cardBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: t.cardBorder),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 740),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: t.primaryColor, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '3D Motion Studio & AI Cutout',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: t.primaryText,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: t.primaryText),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Image Preview Canvas
              Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: t.inputBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.cardBorder),
                ),
                child: _isProcessing
                    ? Center(
                        child:
                            CircularProgressIndicator(color: t.primaryColor))
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: _processedBytes != null
                            ? Image.memory(_processedBytes!,
                                fit: BoxFit.contain)
                            : Image.network(widget.resolvedImageUrl,
                                fit: BoxFit.contain),
                      ),
              ),
              const SizedBox(height: 12),

              // Step 1 & Step 2 Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing ? null : _runAiCutout,
                      icon: const Icon(Icons.content_cut_rounded, size: 16),
                      label: const Text('1. Auto Cutout BG',
                          style: TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _apply3DStageEffect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: t.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                      label: const Text('2. Apply 3D Stage',
                          style: TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Text(
                'Select 3D Commercial Stage:',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: t.primaryText),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _scenes.map((sc) {
                  final String id = sc['id'] ?? '';
                  final bool selected = _selectedEffectId == id;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedEffectId = id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? t.primaryColor : t.inputBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: selected ? t.primaryColor : t.cardBorder),
                      ),
                      child: Text(
                        sc['name'] ?? '',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : t.primaryText,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),

              // Scale Slider
              Row(
                children: [
                  Text('Scale: ${(_scale * 100).round()}%',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: t.primaryText)),
                  Expanded(
                    child: Slider(
                      value: _scale,
                      min: 0.6,
                      max: 1.4,
                      activeColor: t.primaryColor,
                      onChanged: (v) => setState(() => _scale = v),
                    ),
                  ),
                ],
              ),

              if (_processedBytes != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed:
                        _isProcessing ? null : _saveProcessedImageToProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text(
                      'Save 3D / Cutout Image to Product',
                      style:
                          TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}