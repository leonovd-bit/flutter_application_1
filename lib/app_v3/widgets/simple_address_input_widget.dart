import 'package:flutter/material.dart';
import 'dart:async';
import '../services/maps/simple_google_maps_service.dart';
import '../theme/app_theme_v3.dart';

/// Simple address input widget - no complex autocomplete, just validation
class SimpleAddressInputWidget extends StatefulWidget {
  final String? initialValue;
  final String? hintText;
  final Function(AddressResult)? onAddressValidated;
  final Function(String)? onTextChanged;
  final bool isRequired;
  final String? label;

  const SimpleAddressInputWidget({
    super.key,
    this.initialValue,
    this.hintText = 'Enter your address',
    this.onAddressValidated,
    this.onTextChanged,
    this.isRequired = false,
    this.label = 'Address',
  });

  @override
  State<SimpleAddressInputWidget> createState() => _SimpleAddressInputWidgetState();
}

class _SimpleAddressInputWidgetState extends State<SimpleAddressInputWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  AddressResult? _validatedAddress;
  bool _isValidating = false;
  String? _errorMessage;
  Timer? _debounceTimer;

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
      setState(() {
        _validatedAddress = null;
        _errorMessage = null;
      });
      return;
    }

    // Debounce validation
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      _validateAddress(text);
    });
  }

  void _onFocusChanged() {
    // Validate when user finishes editing
    if (!_focusNode.hasFocus && _controller.text.isNotEmpty) {
      _validateAddress(_controller.text);
    }
  }

  Future<void> _validateAddress(String address) async {
    if (!mounted) return;
    
    debugPrint('[AddressWidget] Starting validation for: $address');
    
    setState(() {
      _isValidating = true;
      _errorMessage = null;
    });

    try {
      final result = await SimpleGoogleMapsService.instance.validateAddress(address);
      
      debugPrint('[AddressWidget] Validation result: ${result?.formattedAddress ?? 'null'}');
      
      if (mounted) {
        setState(() {
          _validatedAddress = result;
          _isValidating = false;
          
          if (result == null) {
            _errorMessage = 'Address not found. Please check and try again.';
            debugPrint('[AddressWidget] No address found');
          } else if (!result.isInDeliveryArea) {
            _errorMessage = 'Sorry, we don\'t deliver to this area yet.';
            debugPrint('[AddressWidget] Address outside delivery area');
          } else {
            _errorMessage = null;
            debugPrint('[AddressWidget] Address validated successfully, calling callback');
            widget.onAddressValidated?.call(result);
          }
        });
      }
    } catch (e) {
      debugPrint('[AddressWidget] Validation error: $e');
      if (mounted) {
        setState(() {
          _isValidating = false;
          if (e.toString().contains('API key restricted')) {
            _errorMessage = 'API key issue - check console for details';
          } else {
            _errorMessage = 'Unable to validate address. Please try again.';
          }
        });
      }
    }
  }

  Color get _borderColor {
    if (_errorMessage != null) return Colors.red;
    if (_validatedAddress != null) return Colors.green;
    return AppThemeV3.border;
  }

  Widget? get _suffixIcon {
    if (_isValidating) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    
    if (_validatedAddress != null) {
      return const Icon(Icons.check_circle, color: Colors.green);
    }
    
    if (_errorMessage != null) {
      return const Icon(Icons.error, color: Colors.red);
    }
    
    if (_controller.text.isNotEmpty) {
      return IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          _controller.clear();
          setState(() {
            _validatedAddress = null;
            _errorMessage = null;
          });
          widget.onTextChanged?.call('');
        },
      );
    }
    
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
            suffixIcon: _suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _borderColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            filled: true,
            fillColor: AppThemeV3.surface,
            errorText: _errorMessage,
          ),
          validator: widget.isRequired
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an address';
                  }
                  if (_errorMessage != null) {
                    return _errorMessage;
                  }
                  return null;
                }
              : null,
        ),
        
        // Manual validation button for testing
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () => _validateAddress(_controller.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Validate Address'),
        ),
        
        // Show validation result
        if (_validatedAddress != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Address Validated',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _validatedAddress!.formattedAddress,
                  style: const TextStyle(fontSize: 12),
                ),
                if (_validatedAddress!.city.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${_validatedAddress!.city}, ${_validatedAddress!.state} ${_validatedAddress!.zipCode}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppThemeV3.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
