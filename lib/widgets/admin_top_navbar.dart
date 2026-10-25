import 'package:flutter/material.dart';

class AdminTopNavbar extends StatelessWidget implements PreferredSizeWidget {
  final String storeName;
  final String? storeLogo;
  final Color brandGreen;
  final int pendingOrders;
  final VoidCallback onMenuTap;
  final VoidCallback onRefreshTap;

  const AdminTopNavbar({
    super.key,
    required this.storeName,
    required this.storeLogo,
    required this.brandGreen,
    required this.pendingOrders,
    required this.onMenuTap,
    required this.onRefreshTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFFF1F6F0),
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, color: Color(0xFF1E3A1A), size: 28),
        onPressed: onMenuTap,
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: brandGreen.withOpacity(0.5), width: 1.5),
            ),
            child: ClipOval(
              child: storeLogo != null
                  ? Image.network(
                      storeLogo!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          Icon(Icons.storefront_rounded, color: brandGreen, size: 20),
                    )
                  : Icon(Icons.storefront_rounded, color: brandGreen, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  storeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1E3A1A),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'Merchant Live Dashboard',
                  style: TextStyle(
                    color: Color(0xFF7A9374),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1E3A1A), size: 22),
          onPressed: onRefreshTap,
          tooltip: 'Sync Backend Data',
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF1E3A1A), size: 24),
              onPressed: () {},
            ),
            if (pendingOrders > 0)
              Positioned(
                right: 8,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$pendingOrders',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}