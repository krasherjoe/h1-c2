import 'package:shared_preferences/shared_preferences.dart';

const kDefaultMaxPreviewPages = 20;
const kItemsPerPage = 25;

const _key = 'max_document_pages';

int get defaultMaxItems => kDefaultMaxPreviewPages * kItemsPerPage;

Future<int> loadMaxPreviewPages() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt(_key) ?? kDefaultMaxPreviewPages;
}

Future<int> loadMaxPreviewItems() async {
  final pages = await loadMaxPreviewPages();
  return pages * kItemsPerPage;
}

Future<void> saveMaxPreviewPages(int pages) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_key, pages.clamp(5, 55));
}
