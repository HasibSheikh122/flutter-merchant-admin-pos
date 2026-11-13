# xylo_merchant_admin

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

flutter run -d chrome --dart-define=STORE_DOMAIN=bestbdbazar.shop.xylotechsolution.com

আপনার প্রজেক্ট ফোল্ডারে (xylo_merchant_admin) টার্মিনালে নিচের কমান্ডটি রান ক

যদি আপনি চান অ্যাপের ভেতরে সাবডোমেইন ও ব্র্যান্ডিং তথ্যও একসাথে কম্পাইল হোক, তবে নিচের পূর্ণাঙ্গ কমান্ডটিও ব্যবহার করতে পারেন):
sed -i 's/Insert_drive_file_outlined/insert_drive_file_outlined/g' lib/widgets/catalog/product_images_gallery_view.dart && flutter build apk --release \
  --android-skip-build-dependency-validation \
  --dart-define=STORE_DOMAIN=nextlook.shop.xylotechsolution.com \
  --dart-define=TENANT_SUBDOMAIN=nextlook \
  --dart-define=DEFAULT_TENANT_DOMAIN=nextlook.shop.xylotechsolution.com \
  --dart-define=IS_MERCHANT_ADMIN=trueরুন:
flutter build apk --release --dart-define=STORE_DOMAIN=nextlook.shop.xylotechsolution.com


<!-- Buynara -->
flutter build apk --release -t lib/main.dart --android-skip-build-dependency-validation --dart-define=STORE_DOMAIN=buynarabd.com --dart-define=TENANT_SUBDOMAIN=buynarabd --dart-define=DEFAULT_TENANT_DOMAIN=buynarabd.com --dart-define=IS_MERCHANT_ADMIN=true