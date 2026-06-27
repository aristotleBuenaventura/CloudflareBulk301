import 'package:http/http.dart' as http;

class PublicIpInfo {
  const PublicIpInfo({this.ipv4, this.ipv6});

  final String? ipv4;
  final String? ipv6;
}

class PublicIpService {
  Future<PublicIpInfo> fetch() async {
    final ipv4 = await _fetch('https://api4.ipify.org');
    final ipv6 = await _fetch('https://api6.ipify.org');
    return PublicIpInfo(ipv4: ipv4, ipv6: ipv6);
  }

  Future<String?> _fetch(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 5),
          );
      if (response.statusCode == 200) {
        final value = response.body.trim();
        return value.isEmpty ? null : value;
      }
    } catch (_) {}
    return null;
  }
}
