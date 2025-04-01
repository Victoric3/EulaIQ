import 'package:eulaiq/src/features/library/data/models/ebook_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider to store the latest created eBook for smooth transitions
final latestCreatedEbookProvider = StateProvider<EbookModel?>((ref) => null);