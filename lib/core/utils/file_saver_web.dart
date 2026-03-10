import 'dart:html' as html;
import 'dart:typed_data';

/// Web: trigger browser download directly
Future<void> saveFile(List<int> bytes, String fileName) async {
  final blob = html.Blob([Uint8List.fromList(bytes)]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
