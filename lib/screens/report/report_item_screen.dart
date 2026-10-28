import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/item_provider.dart';

/// Screen where users fill out a form to report a lost or found item.
///
/// Fields: type (lost/found), title, description, category dropdown,
/// campus location dropdown, date picker, and photo upload.
class ReportItemScreen extends StatefulWidget {
  const ReportItemScreen({super.key});

  @override
  State<ReportItemScreen> createState() => _ReportItemScreenState();
}

class _ReportItemScreenState extends State<ReportItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String _type = 'lost';      // 'lost' or 'found'
  String? _category;          // selected category
  String? _campusLocation;    // selected campus location
  DateTime? _date;            // date lost/found
  XFile? _selectedImage;      // picked image file
  Uint8List? _selectedImageBytes; // bytes for preview across all platforms
  String? _errorMessage;

  // ── Dropdown options ──────────────────────────────────────────────────────

  static const List<String> _categories = [
    'Electronics',
    'Clothing',
    'ID / Cards',
    'Books / Notes',
    'Bags / Wallets',
    'Keys',
    'Accessories',
    'Documents',
    'Water Bottle / Tumbler',
    'Other',
  ];

  static const List<String> _campusLocations = [
    'Main Academic Building',
    'College of Engineering',
    'College of Arts & Sciences',
    'College of Informatics & Computing Sciences',
    'College of Industrial Technology',
    'College of Nursing',
    'Library',
    'Gymnasium',
    'Canteen / Food Court',
    'Student Center',
    'Parking Area',
    'Covered Court',
    'Gate 1 Entrance',
    'Gate 2 Entrance',
    'Other',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ─── Actions ──────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      helpText: _type == 'lost' ? 'When did you lose it?' : 'When did you find it?',
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  /// Picks an image from the specified [source] and compresses it
  /// using built-in quality and dimension constraints.
  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 75, // Compress image before upload
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedImage = pickedFile;
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  /// Opens a bottom sheet to let the user choose camera or gallery.
  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Upload Item Photo',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Images are automatically compressed before upload',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: const Text('Take a photo'),
                subtitle: const Text('Use camera to photograph item'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.photo_library_rounded,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                title: const Text('Choose from gallery'),
                subtitle: const Text('Select an existing photo'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
    });
  }

  Future<void> _submit() async {
    // Hide keyboard
    FocusScope.of(context).unfocus();

    // Clear previous error
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    // Extra validation for fields not covered by TextFormField validators
    if (_date == null) {
      setState(() => _errorMessage = 'Please select the date.');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final itemProvider = context.read<ItemProvider>();

    final error = await itemProvider.reportItem(
      ownerId: authProvider.currentUser!.id,
      type: _type,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _category!,
      location: _campusLocation!,
      date: _date!,
      imageFile: _selectedImage,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() => _errorMessage = error);
    } else {
      // Show success and pop back
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _type == 'lost'
                ? 'Lost item report submitted!'
                : 'Found item report submitted!',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLoading = context.watch<ItemProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report an Item'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Type Toggle (Lost / Found) ──────────────────────────
              _buildTypeToggle(colorScheme),
              const SizedBox(height: 20),

              // ── Title ───────────────────────────────────────────────
              _buildTitleField(),
              const SizedBox(height: 16),

              // ── Description ─────────────────────────────────────────
              _buildDescriptionField(),
              const SizedBox(height: 16),

              // ── Category Dropdown ───────────────────────────────────
              _buildCategoryDropdown(),
              const SizedBox(height: 16),

              // ── Campus Location Dropdown ────────────────────
              _buildLocationDropdown(),
              const SizedBox(height: 16),

              // ── Date Picker ─────────────────────────────────────────
              _buildDatePicker(colorScheme),
              const SizedBox(height: 16),

              // ── Photo Upload Section ────────────────────────────────
              _buildPhotoUploadSection(colorScheme),
              const SizedBox(height: 16),

              // ── Error Banner ────────────────────────────────────────
              if (_errorMessage != null) ...[
                _buildErrorBanner(_errorMessage!),
                const SizedBox(height: 12),
              ],

              // ── Submit Button ───────────────────────────────────────
              const SizedBox(height: 8),
              _buildSubmitButton(isLoading),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Widget Helpers ─────────────────────────────────────────────────────

  /// Segmented button to toggle between "Lost" and "Found".
  Widget _buildTypeToggle(ColorScheme colorScheme) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'lost',
          label: Text('I Lost Something'),
          icon: Icon(Icons.search_rounded),
        ),
        ButtonSegment(
          value: 'found',
          label: Text('I Found Something'),
          icon: Icon(Icons.inventory_2_outlined),
        ),
      ],
      selected: {_type},
      onSelectionChanged: (selection) {
        setState(() => _type = selection.first);
      },
      showSelectedIcon: false,
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: 'Item title',
        hintText: 'e.g. Blue Umbrella, Black Wallet',
        prefixIcon: const Icon(Icons.title_rounded),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter a title for the item.';
        }
        if (value.trim().length < 3) {
          return 'Title must be at least 3 characters.';
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      textInputAction: TextInputAction.newline,
      textCapitalization: TextCapitalization.sentences,
      maxLines: 4,
      decoration: InputDecoration(
        labelText: 'Description',
        hintText: 'Color, brand, distinguishing marks, etc.',
        alignLabelWithHint: true,
        prefixIcon: const Padding(
          padding: EdgeInsets.only(bottom: 60),
          child: Icon(Icons.description_outlined),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please describe the item.';
        }
        if (value.trim().length < 10) {
          return 'Description must be at least 10 characters.';
        }
        return null;
      },
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _category,
      decoration: InputDecoration(
        labelText: 'Category',
        prefixIcon: const Icon(Icons.category_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: _categories
          .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
          .toList(),
      onChanged: (value) => setState(() => _category = value),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a category.';
        }
        return null;
      },
    );
  }

  Widget _buildLocationDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _campusLocation,
      decoration: InputDecoration(
        labelText: 'Campus location',
        prefixIcon: const Icon(Icons.location_on_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      isExpanded: true,
      items: _campusLocations
          .map((loc) => DropdownMenuItem(value: loc, child: Text(loc)))
          .toList(),
      onChanged: (value) => setState(() => _campusLocation = value),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a campus location.';
        }
        return null;
      },
    );
  }

  Widget _buildDatePicker(ColorScheme colorScheme) {
    final dateText = _date != null
        ? '${_date!.month}/${_date!.day}/${_date!.year}'
        : 'Select date';

    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: _type == 'lost' ? 'Date lost' : 'Date found',
          prefixIcon: const Icon(Icons.calendar_today_rounded),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          dateText,
          style: TextStyle(
            color: _date != null
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  /// Photo selection and preview container.
  Widget _buildPhotoUploadSection(ColorScheme colorScheme) {
    if (_selectedImageBytes != null) {
      // Image is selected — show preview card with remove & replace actions
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Item Photo',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              TextButton.icon(
                onPressed: _showImageSourcePicker,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Change'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Stack(
            children: [
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.memory(
                    _selectedImageBytes!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: InkWell(
                  onTap: _removeImage,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // No image selected — show upload prompt
    return InkWell(
      onTap: _showImageSourcePicker,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_a_photo_outlined,
                size: 28,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Add Photo (Optional)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Take a picture or choose from gallery',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(bool isLoading) {
    final hasPhoto = _selectedImage != null;
    return FilledButton.icon(
      onPressed: isLoading ? null : _submit,
      icon: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
            )
          : const Icon(Icons.send_rounded),
      label: Text(
        isLoading
            ? (hasPhoto ? 'Uploading photo & submitting…' : 'Submitting…')
            : 'Submit Report',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
