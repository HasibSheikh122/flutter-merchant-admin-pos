// lib/widgets/catalog/product_reviews_view.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'catalog_theme_scope.dart';

class ProductReviewsView extends StatefulWidget {
  final bool isDarkMode;
  final Color brandGreen;
  final VoidCallback? onDataChanged;

  const ProductReviewsView({
    super.key,
    required this.isDarkMode,
    this.brandGreen = const Color(0xFF5B9A42),
    this.onDataChanged,
  });

  @override
  State<ProductReviewsView> createState() => _ProductReviewsViewState();
}

class _ProductReviewsViewState extends State<ProductReviewsView> {
  CatalogThemeConfig _theme = const CatalogThemeConfig();

  bool _isLoading = true;
  List<dynamic> _reviews = [];
  List<dynamic> _products = [];
  String _apiBase = 'https://nextlook.shop.xylotechsolution.com';
  String _subdomain = 'bestbdbazar';

  String _searchQuery = '';
  int _selectedStarFilter = 0; // 0 = All, 1..5 = specific star
  String _replyFilter = 'all'; // 'all', 'replied', 'unreplied'

  int? _activeReplyReviewId;
  final TextEditingController _replyCtrl = TextEditingController();
  bool _isSubmittingReply = false;
  int? _aiGeneratingReviewId;
  String? _aiGeneratingLang;

  Color get _cardBg => _theme.cardBg;
  Color get _softBg => _theme.inputBg;
  Color get _borderCol => _theme.cardBorder;
  Color get _textPrimary => _theme.primaryText;
  Color get _textSecondary => _theme.secondaryText;

  BoxDecoration _primaryDecoration({double radius = 12}) {
    return BoxDecoration(
      gradient: _theme.useGradient ? _theme.brandGradient : null,
      color: _theme.useGradient ? null : _theme.primaryColor,
      borderRadius: BorderRadius.circular(radius),
    );
  }

  @override
  void initState() {
    super.initState();
    _initAndFetch();
  }

  @override
  void didUpdateWidget(covariant ProductReviewsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDarkMode != widget.isDarkMode ||
        oldWidget.brandGreen != widget.brandGreen) {
      _loadTheme();
    }
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTheme() async {
    final t = await CatalogThemeConfig.load(
      isDarkMode: widget.isDarkMode,
      fallbackBrandGreen: widget.brandGreen,
    );
    if (mounted) {
      setState(() {
        _theme = t;
        _apiBase = t.apiBase;
        _subdomain = t.subdomain;
      });
    }
  }

  Future<void> _initAndFetch() async {
    await _loadTheme();
    await _fetchReviewsAndProducts();
  }

  Map<String, String> _buildHeaders(String token, String subdomain) {
    return {
      'Accept': 'application/json',
      'X-Tenant-Subdomain': subdomain,
      'x-subdomain': subdomain,
      'x-tenant-id': subdomain,
      'X-Branch-ID': 'all',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  String _resolveMediaUrl(String raw) {
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') ||
        raw.startsWith('https://') ||
        raw.startsWith('data:')) {
      return raw;
    }
    if (raw.startsWith('/')) return '$_apiBase$raw';
    return '$_apiBase/$raw';
  }

  Future<void> _fetchReviewsAndProducts() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('merchant_token') ?? '';
      _subdomain = prefs.getString('active_subdomain') ?? 'bestbdbazar';
      _apiBase = prefs.getString('api_base_url') ?? 'https://nextlook.shop.xylotechsolution.com';
      if (_apiBase.endsWith('/')) {
        _apiBase = _apiBase.substring(0, _apiBase.length - 1);
      }

      final headers = _buildHeaders(token, _subdomain);

      final responses = await Future.wait([
        http
            .get(
              Uri.parse(
                '$_apiBase/api/v1/reviews/?subdomain=$_subdomain&admin=true&all_branches=true',
              ),
              headers: headers,
            )
            .catchError((_) => http.Response('[]', 500)),
        http
            .get(
              Uri.parse(
                '$_apiBase/api/v1/products/?subdomain=$_subdomain&all_branches=true&page_size=500',
              ),
              headers: headers,
            )
            .catchError((_) => http.Response('[]', 500)),
      ]);

      if (responses[0].statusCode == 200) {
        final rawRev = jsonDecode(responses[0].body);
        if (rawRev is List) {
          _reviews = rawRev;
        } else if (rawRev is Map && rawRev['results'] is List) {
          _reviews = rawRev['results'];
        }
      }

      if (responses[1].statusCode == 200) {
        final rawProd = jsonDecode(responses[1].body);
        if (rawProd is List) {
          _products = rawProd;
        } else if (rawProd is Map && rawProd['results'] is List) {
          _products = rawProd['results'];
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateAiSmartReply(Map rev, String lang) async {
    final int revId = int.tryParse((rev['id'] ?? 0).toString()) ?? 0;
    setState(() {
      _aiGeneratingReviewId = revId;
      _aiGeneratingLang = lang;
    });

    final String custName =
        (rev['customer_display_name'] ?? '').toString().trim().isNotEmpty
            ? rev['customer_display_name'].toString().trim()
            : (lang == 'en' ? 'Valued Customer' : 'প্রিয় গ্রাহক');
    final int rating = int.tryParse((rev['rating'] ?? 5).toString()) ?? 5;
    final String reviewContent =
        (rev['content'] ?? rev['title'] ?? '').toString().trim();
    final String productName =
        (rev['product_name'] ?? 'Product #${rev['product'] ?? ''}').toString();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('merchant_token') ?? '';
      final headers = {
        ..._buildHeaders(token, _subdomain),
        'Content-Type': 'application/json',
      };

      final res = await http.post(
        Uri.parse(
          '$_apiBase/api/v1/ai/generate-product-content/?subdomain=$_subdomain',
        ),
        headers: headers,
        body: jsonEncode({
          'mode': 'review_reply',
          'customer_name': custName,
          'rating': rating,
          'review_content': reviewContent.isNotEmpty
              ? reviewContent
              : (lang == 'en' ? 'Great product' : 'ভালো পণ্য'),
          'product_name': productName,
          'language': lang,
        }),
      );

      String generatedReply = '';
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) {
          final inner = decoded['data'];
          if (inner is Map && inner['reply'] != null) {
            generatedReply = inner['reply'].toString().trim();
          } else if (decoded['reply'] != null) {
            generatedReply = decoded['reply'].toString().trim();
          }
        }
      }

      if (generatedReply.isEmpty) {
        generatedReply = _buildFallbackReply(custName, rating, lang);
      }

      if (mounted) {
        setState(() {
          _replyCtrl.text = generatedReply;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _replyCtrl.text = _buildFallbackReply(custName, rating, lang);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _aiGeneratingReviewId = null;
          _aiGeneratingLang = null;
        });
      }
    }
  }

  String _buildFallbackReply(String custName, int rating, String lang) {
    if (lang == 'en') {
      if (rating >= 4) {
        return 'Dear $custName, thank you so much for your wonderful $rating-star review! ❤️ We are thrilled to know you loved the product. Your trust inspires us, and we look forward to serving you again soon!';
      }
      return 'Dear $custName, we sincerely apologize for your experience. Customer satisfaction is our top priority. Please reach out to our support helpline with your Order ID, and we will resolve this promptly for you.';
    } else {
      if (rating >= 4) {
        return 'প্রিয় $custName, আপনার চমৎকার মতামতের জন্য আন্তরিক ধন্যবাদ! ❤️ পণ্যটি আপনার পছন্দ হয়েছে জেনে আমরা অত্যন্ত আনন্দিত। আপনার আস্থাই আমাদের এগিয়ে চলার অনুপ্রেরণা। ভবিষ্যতে আবারও আপনার সেবায় নিয়োজিত থাকার অপেক্ষায় রইলাম!';
      }
      return 'প্রিয় $custName, আপনার অনাকাঙ্ক্ষিত অভিজ্ঞতার জন্য আমরা আন্তরিকভাবে দুঃখিত। গ্রাহক সন্তুষ্টিই আমাদের প্রধান লক্ষ্য। সমস্যাটির দ্রুত সমাধানের জন্য অনুগ্রহ করে আমাদের হেল্পলাইনে যোগাযোগ করুন অথবা ইনবক্সে অর্ডার নম্বরটি জানান।';
    }
  }

  Future<void> _sendOwnerReply(int reviewId) async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSubmittingReply = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('merchant_token') ?? '';
      final headers = {
        ..._buildHeaders(token, _subdomain),
        'Content-Type': 'application/json',
      };

      final res = await http.post(
        Uri.parse('$_apiBase/api/v1/reviews/replies/?subdomain=$_subdomain'),
        headers: headers,
        body: jsonEncode({
          'review': reviewId,
          'content': text,
        }),
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        _replyCtrl.clear();
        setState(() => _activeReplyReviewId = null);
        await _fetchReviewsAndProducts();
        widget.onDataChanged?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Reply posted successfully!'),
              backgroundColor: _theme.primaryColor,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to submit reply (${res.statusCode})'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingReply = false);
    }
  }

  Future<void> _markHelpful(int reviewId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('merchant_token') ?? '';
      final headers = _buildHeaders(token, _subdomain);

      final res = await http.post(
        Uri.parse(
          '$_apiBase/api/v1/reviews/$reviewId/helpful/?subdomain=$_subdomain',
        ),
        headers: headers,
      );
      if (res.statusCode == 200) {
        await _fetchReviewsAndProducts();
      }
    } catch (_) {}
  }

  Future<void> _deleteReview(int reviewId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Customer Review?',
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        content: Text(
          'Are you sure you want to permanently remove this customer review?',
          style: TextStyle(color: _textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('merchant_token') ?? '';
      final headers = _buildHeaders(token, _subdomain);

      final res = await http.delete(
        Uri.parse('$_apiBase/api/v1/reviews/$reviewId/?subdomain=$_subdomain'),
        headers: headers,
      );

      if (res.statusCode == 200 || res.statusCode == 204) {
        await _fetchReviewsAndProducts();
        widget.onDataChanged?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Review deleted successfully.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _openAddReviewDialog() async {
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please create at least one product first.'),
        ),
      );
      return;
    }

    int? selectedProdId =
        int.tryParse((_products.first['id'] ?? '').toString());
    int selectedRating = 5;
    final nameCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    bool isSubmitting = false;

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
                border: Border.all(color: _borderCol),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _borderCol,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: _primaryDecoration(radius: 12),
                          child: const Icon(
                            Icons.rate_review_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add Customer Review',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: _textPrimary,
                                ),
                              ),
                              Text(
                                'Post a verified product review directly to your storefront',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          icon: Icon(Icons.close_rounded, color: _textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Select Product',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: _softBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _borderCol),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selectedProdId,
                          isExpanded: true,
                          dropdownColor: _cardBg,
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          items: _products.map((p) {
                            final pid =
                                int.tryParse((p['id'] ?? 0).toString()) ?? 0;
                            final pname =
                                (p['name'] ?? 'Product #$pid').toString();
                            return DropdownMenuItem<int>(
                              value: pid,
                              child: Text(
                                pname,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => selectedProdId = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Rating Stars',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: List.generate(5, (idx) {
                        final starVal = idx + 1;
                        final active = starVal <= selectedRating;
                        return GestureDetector(
                          onTap: () =>
                              setModalState(() => selectedRating = starVal),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(
                              active
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: active
                                  ? const Color(0xFFF59E0B)
                                  : _textSecondary,
                              size: 32,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      style: TextStyle(color: _textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Customer Name (e.g. Rahim Uddin)',
                        labelStyle:
                            TextStyle(color: _textSecondary, fontSize: 12),
                        filled: true,
                        fillColor: _softBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _borderCol),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: titleCtrl,
                      style: TextStyle(color: _textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Review Title (Optional)',
                        labelStyle:
                            TextStyle(color: _textSecondary, fontSize: 12),
                        filled: true,
                        fillColor: _softBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _borderCol),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: contentCtrl,
                      maxLines: 3,
                      style: TextStyle(color: _textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Customer Feedback / Review Content *',
                        labelStyle:
                            TextStyle(color: _textSecondary, fontSize: 12),
                        filled: true,
                        fillColor: _softBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _borderCol),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: isSubmitting
                          ? null
                          : () async {
                              if (selectedProdId == null ||
                                  contentCtrl.text.trim().isEmpty) {
                                return;
                              }
                              setModalState(() => isSubmitting = true);
                              try {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                final token =
                                    prefs.getString('merchant_token') ?? '';
                                final headers = {
                                  ..._buildHeaders(token, _subdomain),
                                  'Content-Type': 'application/json',
                                };
                                final res = await http.post(
                                  Uri.parse(
                                    '$_apiBase/api/v1/reviews/?subdomain=$_subdomain',
                                  ),
                                  headers: headers,
                                  body: jsonEncode({
                                    'product': selectedProdId,
                                    'rating': selectedRating,
                                    'reviewer_name': nameCtrl.text.trim().isEmpty
                                        ? 'Verified Buyer'
                                        : nameCtrl.text.trim(),
                                    'title': titleCtrl.text.trim(),
                                    'content': contentCtrl.text.trim(),
                                  }),
                                );
                                if (res.statusCode >= 200 &&
                                    res.statusCode < 300) {
                                  if (ctx.mounted) Navigator.pop(ctx, true);
                                }
                              } catch (_) {}
                              if (ctx.mounted) {
                                setModalState(() => isSubmitting = false);
                              }
                            },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: _primaryDecoration(radius: 14),
                        alignment: Alignment.center,
                        child: Text(
                          isSubmitting ? 'Submitting...' : 'Submit Review',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (created == true) {
      await _fetchReviewsAndProducts();
      widget.onDataChanged?.call();
    }
  }

  void _showImageZoomDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  width: 240,
                  height: 240,
                  color: _cardBg,
                  alignment: Alignment.center,
                  child:
                      Icon(Icons.broken_image_rounded, color: _textSecondary),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black87,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 18),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<dynamic> get _filteredReviews {
    return _reviews.where((r) {
      if (r is! Map) return false;
      final q = _searchQuery.trim().toLowerCase();
      if (q.isNotEmpty) {
        final cust =
            (r['customer_display_name'] ?? '').toString().toLowerCase();
        final title = (r['title'] ?? '').toString().toLowerCase();
        final content = (r['content'] ?? '').toString().toLowerCase();
        final prod = (r['product_name'] ?? '').toString().toLowerCase();
        if (!cust.contains(q) &&
            !title.contains(q) &&
            !content.contains(q) &&
            !prod.contains(q)) {
          return false;
        }
      }

      final rating = int.tryParse((r['rating'] ?? 5).toString()) ?? 5;
      if (_selectedStarFilter > 0 && rating != _selectedStarFilter) {
        return false;
      }

      final replies = (r['replies'] is List) ? (r['replies'] as List) : [];
      if (_replyFilter == 'replied' && replies.isEmpty) return false;
      if (_replyFilter == 'unreplied' && replies.isNotEmpty) return false;

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final total = _reviews.length;
    double sumRating = 0;
    int verifiedCount = 0;
    int repliedCount = 0;
    final starCounts = <int, int>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

    for (final r in _reviews) {
      if (r is Map) {
        final rt =
            (int.tryParse((r['rating'] ?? 5).toString()) ?? 5).clamp(1, 5);
        sumRating += rt;
        starCounts[rt] = (starCounts[rt] ?? 0) + 1;
        if (r['verified_purchase'] == true ||
            (r['verification_status'] ?? '') == 'verified') {
          verifiedCount++;
        }
        if (r['replies'] is List && (r['replies'] as List).isNotEmpty) {
          repliedCount++;
        }
      }
    }

    final double avgRating = total > 0 ? (sumRating / total) : 0.0;
    final int replyRate =
        total > 0 ? ((repliedCount / total) * 100).round() : 0;
    final filtered = _filteredReviews;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTopHeroSummaryCard(
          total: total,
          avgRating: avgRating,
          verifiedCount: verifiedCount,
          replyRate: replyRate,
          starCounts: starCounts,
        ),
        const SizedBox(height: 14),
        _buildSearchAndFiltersCard(),
        const SizedBox(height: 14),
        if (_isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: CircularProgressIndicator(color: _theme.primaryColor),
            ),
          )
        else if (filtered.isEmpty)
          _buildEmptyStateCard()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final rev = filtered[index] as Map;
              return _buildReviewItemCard(rev);
            },
          ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildTopHeroSummaryCard({
    required int total,
    required double avgRating,
    required int verifiedCount,
    required int replyRate,
    required Map<int, int> starCounts,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _primaryDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFFDE047),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Product Reviews & AI Reputation',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'View feedback, reply with Bangla/English AI & manage ratings',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _openAddReviewDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_comment_rounded,
                        size: 14,
                        color: _theme.primaryColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Add Review',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: _theme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            child: Row(
              children: [
                Column(
                  children: [
                    Text(
                      avgRating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (i) {
                        return Icon(
                          i < avgRating.round()
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: const Color(0xFFFDE047),
                          size: 14,
                        );
                      }),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$total Reviews',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [5, 4, 3, 2, 1].map((star) {
                      final count = starCounts[star] ?? 0;
                      final ratio = total > 0 ? (count / total) : 0.0;
                      final isSelected = _selectedStarFilter == star;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedStarFilter =
                                _selectedStarFilter == star ? 0 : star;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Text(
                                '$star★',
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFFFDE047)
                                      : Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: ratio,
                                    minHeight: 6,
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.18),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                      Color(0xFFFDE047),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: 22,
                                child: Text(
                                  '$count',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMiniHeroBadge(
                Icons.verified_rounded,
                '$verifiedCount Verified',
              ),
              const SizedBox(width: 8),
              _buildMiniHeroBadge(
                Icons.reply_all_rounded,
                '$replyRate% Replied',
              ),
              const SizedBox(width: 8),
              _buildMiniHeroBadge(
                Icons.auto_awesome_rounded,
                'Bangla & EN AI',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniHeroBadge(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 13),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFiltersCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: TextStyle(color: _textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search customer, product or review text...',
                    hintStyle: TextStyle(color: _textSecondary, fontSize: 12),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: _theme.primaryColor,
                      size: 19,
                    ),
                    filled: true,
                    fillColor: _softBg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: _borderCol),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: _borderCol),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: _theme.primaryColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _fetchReviewsAndProducts,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: _theme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _theme.primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(
                    Icons.refresh_rounded,
                    color: _theme.primaryColor,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStarFilterChip(0, 'All Stars'),
                const SizedBox(width: 6),
                _buildStarFilterChip(5, '5 ★'),
                const SizedBox(width: 6),
                _buildStarFilterChip(4, '4 ★'),
                const SizedBox(width: 6),
                _buildStarFilterChip(3, '3 ★'),
                const SizedBox(width: 6),
                _buildStarFilterChip(2, '2 ★'),
                const SizedBox(width: 6),
                _buildStarFilterChip(1, '1 ★'),
                const SizedBox(width: 10),
                _buildReplyFilterChip('all', 'All Status'),
                const SizedBox(width: 6),
                _buildReplyFilterChip('unreplied', 'Needs Reply'),
                const SizedBox(width: 6),
                _buildReplyFilterChip('replied', 'Replied'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarFilterChip(int starValue, String label) {
    final bool selected = _selectedStarFilter == starValue;
    return GestureDetector(
      onTap: () => setState(() => _selectedStarFilter = starValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: selected
            ? _primaryDecoration(radius: 10)
            : BoxDecoration(
                color: _softBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _borderCol),
              ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : _textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildReplyFilterChip(String key, String label) {
    final bool selected = _replyFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _replyFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: selected
            ? _primaryDecoration(radius: 10)
            : BoxDecoration(
                color: _softBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _borderCol),
              ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : _textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStateCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderCol),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _theme.primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.reviews_rounded,
              size: 36,
              color: _theme.primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No Product Reviews Found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Customer reviews submitted on your storefront products will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: _textSecondary),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _openAddReviewDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: _primaryDecoration(radius: 12),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Add First Product Review',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItemCard(Map rev) {
    final int revId = int.tryParse((rev['id'] ?? 0).toString()) ?? 0;
    final String custName =
        (rev['customer_display_name'] ?? 'Verified Customer').toString();
    final String prodName =
        (rev['product_name'] ?? 'Product #${rev['product'] ?? ''}').toString();
    final int rating =
        (int.tryParse((rev['rating'] ?? 5).toString()) ?? 5).clamp(1, 5);
    final bool verifiedPurchase = rev['verified_purchase'] == true ||
        (rev['verification_status'] ?? '') == 'verified';
    final String title = (rev['title'] ?? '').toString().trim();
    final String content = (rev['content'] ?? '').toString().trim();
    final int helpfulCount =
        int.tryParse((rev['helpful_count'] ?? 0).toString()) ?? 0;
    final String rawCreated = (rev['created_at'] ?? '').toString();
    final String dateStr =
        rawCreated.length >= 10 ? rawCreated.substring(0, 10) : 'Recent';

    final List<String> mediaUrls = [];
    if (rev['images'] is List) {
      for (final img in (rev['images'] as List)) {
        final u = _resolveMediaUrl(img.toString());
        if (u.isNotEmpty) mediaUrls.add(u);
      }
    }
    if (rev['review_photos'] is List) {
      for (final p in (rev['review_photos'] as List)) {
        if (p is Map && p['media_file'] != null) {
          final u = _resolveMediaUrl(p['media_file'].toString());
          if (u.isNotEmpty && !mediaUrls.contains(u)) mediaUrls.add(u);
        }
      }
    }

    final List<dynamic> replies =
        (rev['replies'] is List) ? (rev['replies'] as List) : [];
    final bool isReplyBoxOpen = _activeReplyReviewId == revId;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isReplyBoxOpen
              ? _theme.primaryColor.withValues(alpha: 0.6)
              : _borderCol,
          width: isReplyBoxOpen ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: widget.isDarkMode ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: _primaryDecoration(radius: 12),
                child: Text(
                  custName.isNotEmpty ? custName[0].toUpperCase() : 'C',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          custName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: _textPrimary,
                          ),
                        ),
                        if (verifiedPurchase)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 11,
                                  color: Color(0xFF10B981),
                                ),
                                SizedBox(width: 3),
                                Text(
                                  'Verified Purchase',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ...List.generate(5, (i) {
                          return Icon(
                            i < rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 15,
                            color: i < rating
                                ? const Color(0xFFF59E0B)
                                : _textSecondary.withValues(alpha: 0.4),
                          );
                        }),
                        const SizedBox(width: 6),
                        Text(
                          '• $dateStr',
                          style: TextStyle(
                            fontSize: 11,
                            color: _textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => _deleteReview(revId),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 17,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _theme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _theme.primaryColor.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 13,
                  color: _theme.primaryColor,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    prodName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _theme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            content.isNotEmpty ? content : 'No written comment provided.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: _textPrimary.withValues(alpha: 0.88),
            ),
          ),
          if (mediaUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 68,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: mediaUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final imgUrl = mediaUrls[idx];
                  return GestureDetector(
                    onTap: () => _showImageZoomDialog(imgUrl),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: _softBg,
                          border: Border.all(color: _borderCol),
                        ),
                        child: Image.network(
                          imgUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.image_not_supported_outlined,
                            color: _textSecondary,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          if (replies.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(left: 10),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: _theme.primaryColor.withValues(alpha: 0.55),
                    width: 2.5,
                  ),
                ),
              ),
              child: Column(
                children: replies.map((rep) {
                  if (rep is! Map) return const SizedBox.shrink();
                  final repAuthor =
                      (rep['user_name'] ?? 'Outlet Store Manager').toString();
                  final repContent = (rep['content'] ?? '').toString();
                  final repDateRaw = (rep['created_at'] ?? '').toString();
                  final repDate = repDateRaw.length >= 10
                      ? repDateRaw.substring(0, 10)
                      : 'Today';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _softBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderCol),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.subdirectory_arrow_right_rounded,
                              size: 14,
                              color: _theme.primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              repAuthor,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                color: _theme.primaryColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '• $repDate',
                              style: TextStyle(
                                fontSize: 10,
                                color: _textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          repContent,
                          style: TextStyle(
                            fontSize: 12,
                            color: _textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Divider(height: 1, color: _borderCol),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (_activeReplyReviewId == revId) {
                          _activeReplyReviewId = null;
                          _replyCtrl.clear();
                        } else {
                          _activeReplyReviewId = revId;
                          _replyCtrl.clear();
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: isReplyBoxOpen
                          ? _primaryDecoration(radius: 10)
                          : BoxDecoration(
                              color: _softBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _borderCol),
                            ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.reply_rounded,
                            size: 14,
                            color: isReplyBoxOpen
                                ? Colors.white
                                : _theme.primaryColor,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isReplyBoxOpen
                                ? 'Cancel Reply'
                                : 'Reply to Customer',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color:
                                  isReplyBoxOpen ? Colors.white : _textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _markHelpful(revId),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _softBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _borderCol),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.thumb_up_alt_outlined,
                            size: 13,
                            color: _textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Helpful ($helpfulCount)',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: _textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (isReplyBoxOpen)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildAiSmartReplyButton(
                      rev: rev,
                      lang: 'bn',
                      label: 'AI Reply (বাংলা)',
                      accentColor: const Color(0xFF10B981),
                    ),
                    _buildAiSmartReplyButton(
                      rev: rev,
                      lang: 'en',
                      label: 'AI Reply (English)',
                      accentColor: const Color(0xFF3B82F6),
                    ),
                  ],
                ),
            ],
          ),
          if (isReplyBoxOpen) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _replyCtrl,
              maxLines: 3,
              style: TextStyle(color: _textPrimary, fontSize: 12.5),
              decoration: InputDecoration(
                hintText:
                    'কাস্টমারকে উত্তর লিখুন অথবা উপরের AI Reply বাটনে ক্লিক করুন...',
                hintStyle: TextStyle(color: _textSecondary, fontSize: 11.5),
                filled: true,
                fillColor: _softBg,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _borderCol),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: _theme.primaryColor,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.favorite_rounded,
                        size: 13,
                        color: _theme.primaryColor,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'প্রফেশনাল ও বিনয়ী উত্তর কাস্টমারের আস্থা বাড়ায়',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: _textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _isSubmittingReply
                      ? null
                      : () => _sendOwnerReply(revId),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    decoration: _primaryDecoration(radius: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isSubmittingReply)
                          const SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        else
                          const Icon(
                            Icons.send_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        const SizedBox(width: 6),
                        const Text(
                          'Send Reply',
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
          ],
        ],
      ),
    );
  }

  Widget _buildAiSmartReplyButton({
    required Map rev,
    required String lang,
    required String label,
    required Color accentColor,
  }) {
    final int revId = int.tryParse((rev['id'] ?? 0).toString()) ?? 0;
    final bool isBusy =
        _aiGeneratingReviewId == revId && _aiGeneratingLang == lang;

    return InkWell(
      onTap: _aiGeneratingReviewId != null
          ? null
          : () => _generateAiSmartReply(rev, lang),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: accentColor.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isBusy)
              SizedBox(
                width: 11,
                height: 11,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: accentColor,
                ),
              )
            else
              Icon(Icons.auto_awesome_rounded, size: 12, color: accentColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}