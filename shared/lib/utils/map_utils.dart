import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class MapUtils {
  MapUtils._();

  static Future<void> openGoogleMaps(String address) async {
    final encodedAddress = Uri.encodeComponent(address);
    Uri url;

    if (kIsWeb) {
      url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$encodedAddress',
      );
    } else if (Platform.isAndroid) {
      url = Uri.parse('google.navigation:q=$encodedAddress');
    } else {
      // iOS try Google Maps app if installed
      url = Uri.parse(
        'comgooglemaps://?daddr=$encodedAddress&directionsmode=driving',
      );
    }

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      // Fallback to web browser if app not found
      final webUrl = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$encodedAddress',
      );
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> openAppleMaps(String address) async {
    if (kIsWeb || !Platform.isIOS) {
      return openGoogleMaps(address);
    }

    final encodedAddress = Uri.encodeComponent(address);
    final url = Uri.parse(
      'https://maps.apple.com/?daddr=$encodedAddress&dirflg=d',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      await openGoogleMaps(address);
    }
  }
}
