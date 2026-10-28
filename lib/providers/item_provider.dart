import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/item_model.dart';
import '../services/item_service.dart';

/// Manages state for creating and listing item reports.
///
/// Used by the Report Item screen to submit lost/found reports
/// and later by feed screens to display them.
class ItemProvider extends ChangeNotifier {
  final ItemService _itemService = ItemService();

  bool _isLoading = false;
  ItemModel? _lastCreatedItem;

  /// True while a create/fetch operation is in progress.
  bool get isLoading => _isLoading;

  /// The most recently created item (useful for confirmation UX).
  ItemModel? get lastCreatedItem => _lastCreatedItem;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Exposes the item service instance.
  ItemService get itemService => _itemService;

  /// Provides real-time stream of items filtered by type ('lost' or 'found').
  Stream<List<ItemModel>> getItemsStream({String? type}) {
    return _itemService.getItemsStream(type: type);
  }

  // ─── Create ───────────────────────────────────────────────────────────────

  /// Submits a new item report. If [imageFile] is provided, it is uploaded
  /// to Firebase Storage and attached to the report.
  /// Returns an error message on failure, or null on success.
  Future<String?> reportItem({
    required String ownerId,
    required String type,
    required String title,
    required String description,
    required String category,
    required String location,
    required DateTime date,
    XFile? imageFile,
  }) async {
    _setLoading(true);
    try {
      String? photoUrl;
      if (imageFile != null) {
        photoUrl = await _itemService.uploadItemPhoto(imageFile);
      }

      _lastCreatedItem = await _itemService.createItem(
        ownerId: ownerId,
        type: type,
        title: title,
        description: description,
        category: category,
        location: location,
        date: date,
        photoUrl: photoUrl,
      );
      return null; // null = success
    } catch (e) {
      return 'Failed to submit report. Please try again.';
    } finally {
      _setLoading(false);
    }
  }
}

