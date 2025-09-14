import 'package:flutter/material.dart';
import 'dart:async';
import '../services/google_places_service.dart';
import '../theme/app_theme_v3.dart';

/// Advanced address input widget with Google Places autocomplete
/// Provides real-time address suggestions and validation
class AddressAutocompleteWidget extends StatefulWidget {
  final String? initialValue;
  final String? hintText;
  final Function(PlaceDetails)? onAddressSelected;
  final Function(String)? onTextChanged;
  final bool isRequired;
  final String? label;

  const AddressAutocompleteWidget({
    super.key,
    this.initialValue,
    this.hintText = 'Enter your address',
    this.onAddressSelected,
    this.onTextChanged,
    this.isRequired = false,
    this.label = 'Address',
  });

  @override
  State<AddressAutocompleteWidget> createState() => _AddressAutocompleteWidgetState();
}

class _AddressAutocompleteWidgetState extends State<AddressAutocompleteWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  
  List<PlacesSuggestion> _suggestions = [];
  bool _isLoading = false;
  Timer? _debounceTimer;
  OverlayEntry? _overlayEntry;
  
  // Session token for Google Places billing optimization
  String? _sessionToken;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }
    
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _removeOverlay();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    widget.onTextChanged?.call(text);
    
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    if (text.trim().isEmpty) {
      _clearSuggestions();
      return;
    }

    // Debounce the search to avoid too many API calls
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _searchAddresses(text);
    });
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && _controller.text.isNotEmpty) {
      _showSuggestionsOverlay();
    } else {
      // Delay hiding to allow for suggestion selection
      Timer(const Duration(milliseconds: 150), _removeOverlay);
    }
  }

  Future<void> _searchAddresses(String query) async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Generate session token for billing optimization
      _sessionToken ??= DateTime.now().millisecondsSinceEpoch.toString();
      
      // Get user location for better suggestions
      final userLocation = await GooglePlacesService.instance.getCurrentLocation();
      
      final suggestions = await GooglePlacesService.instance.getAddressSuggestions(
        query,
        sessionToken: _sessionToken,
        location: userLocation,
      );

      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _isLoading = false;
        });
        
        if (suggestions.isNotEmpty && _focusNode.hasFocus) {
          _showSuggestionsOverlay();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _suggestions = [];
        });
      }
    }
  }

  void _showSuggestionsOverlay() {
    _removeOverlay();
    
    if (_suggestions.isEmpty) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: context.size?.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 60), // Position below the text field
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppThemeV3.border),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = _suggestions[index];
                  return _buildSuggestionTile(suggestion);
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildSuggestionTile(PlacesSuggestion suggestion) {
    return InkWell(
      onTap: () => _selectSuggestion(suggestion),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppThemeV3.border.withOpacity(0.3),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.location_on,
              color: AppThemeV3.accent,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.mainText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (suggestion.secondaryText.isNotEmpty)
                    Text(
                      suggestion.secondaryText,
                      style: TextStyle(
                        color: AppThemeV3.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectSuggestion(PlacesSuggestion suggestion) async {
    _removeOverlay();
    _controller.text = suggestion.description;
    _focusNode.unfocus();
    
    // Clear suggestions and show loading
    setState(() {
      _suggestions = [];
      _isLoading = true;
    });

    try {
      // Get detailed place information
      final placeDetails = await GooglePlacesService.instance.getPlaceDetails(
        suggestion.placeId,
        sessionToken: _sessionToken,
      );
      
      if (placeDetails != null && mounted) {
        widget.onAddressSelected?.call(placeDetails);
      }
      
      // Reset session token after successful selection
      _sessionToken = null;
    } catch (e) {
      debugPrint('Error getting place details: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _clearSuggestions() {
    setState(() {
      _suggestions = [];
      _isLoading = false;
    });
    _removeOverlay();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.label != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                widget.label!,
                style: AppThemeV3.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          TextFormField(
            controller: _controller,
            focusNode: _focusNode,
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(color: AppThemeV3.textSecondary),
              prefixIcon: Icon(
                Icons.location_on_outlined,
                color: AppThemeV3.accent,
              ),
              suffixIcon: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controller.clear();
                            _clearSuggestions();
                            widget.onTextChanged?.call('');
                          },
                        )
                      : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppThemeV3.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppThemeV3.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppThemeV3.accent, width: 2),
              ),
              filled: true,
              fillColor: AppThemeV3.surface,
            ),
            validator: widget.isRequired
                ? (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter an address';
                    }
                    return null;
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

/// Simple address validation widget for quick validation
class AddressValidationCard extends StatefulWidget {
  final String address;
  final Function(AddressValidationResult)? onValidationComplete;

  const AddressValidationCard({
    super.key,
    required this.address,
    this.onValidationComplete,
  });

  @override
  State<AddressValidationCard> createState() => _AddressValidationCardState();
}

class _AddressValidationCardState extends State<AddressValidationCard> {
  AddressValidationResult? _validationResult;
  bool _isValidating = false;

  @override
  void initState() {
    super.initState();
    _validateAddress();
  }

  @override
  void didUpdateWidget(AddressValidationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.address != widget.address) {
      _validateAddress();
    }
  }

  Future<void> _validateAddress() async {
    if (widget.address.trim().isEmpty) return;

    setState(() {
      _isValidating = true;
      _validationResult = null;
    });

    try {
      final result = await GooglePlacesService.instance.validateAddress(widget.address);
      
      if (mounted) {
        setState(() {
          _validationResult = result;
          _isValidating = false;
        });
        
        widget.onValidationComplete?.call(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isValidating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isValidating) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                'Validating address...',
                style: AppThemeV3.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    if (_validationResult == null) return const SizedBox.shrink();

    return Card(
      color: _validationResult!.isValid 
          ? Colors.green.shade50 
          : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _validationResult!.isValid ? Icons.check_circle : Icons.error,
                  color: _validationResult!.isValid ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _validationResult!.isValid ? 'Address Validated' : 'Address Issue',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _validationResult!.isValid ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_validationResult!.isValid && _validationResult!.standardizedAddress != null)
              Text(
                'Standardized: ${_validationResult!.standardizedAddress}',
                style: AppThemeV3.textTheme.bodySmall,
              ),
            if (!_validationResult!.isValid && _validationResult!.error != null)
              Text(
                _validationResult!.error!,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 12,
                ),
              ),
            if (_validationResult!.confidence != null)
              Text(
                'Confidence: ${(_validationResult!.confidence! * 100).toInt()}%',
                style: AppThemeV3.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
