import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../data/services/auth_service.dart';
import '../../../utils/file_picker_helper.dart';
import '../../../utils/toast_helper.dart';
import '../../widgets/shared_header.dart';
import '../../widgets/shared_footer.dart';
import 'learner_home_page.dart';

class MyInformationPage extends StatefulWidget {
  const MyInformationPage({super.key});

  @override
  State<MyInformationPage> createState() => _MyInformationPageState();
}

class _MyInformationPageState extends State<MyInformationPage> {
  final _authService = AuthService();
  bool _isLoading = true;
  int _activeTab = 0; // 0: Information & Contact, 1: Change Password

  // Profile data
  String _fullName = '';
  String _email = '';
  String _username = '';
  String _phoneNumber = '';
  String _gender = 'Male';
  String _dateOfBirth = '';
  String _address = '';
  String _avatarUrl = '';
  String _initials = '';

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final res = await _authService.getProfile();
      if (res['success'] == true) {
        final data = res['data'];
        setState(() {
          _fullName = data['fullName'] ?? '';
          _email = data['email'] ?? '';
          _username = data['username'] ?? '';
          _phoneNumber = data['phoneNumber'] ?? '';
          final rawGender = data['gender'] ?? 'Male';
          if (rawGender.toString().toUpperCase() == 'MALE') {
            _gender = 'Male';
          } else if (rawGender.toString().toUpperCase() == 'FEMALE') {
            _gender = 'Female';
          } else {
            _gender = rawGender;
          }
          _address = data['address'] ?? '';
          _avatarUrl = data['avatarUrl'] ?? '';
          
          if (_fullName.trim().isNotEmpty) {
            final parts = _fullName.trim().split(' ');
            if (parts.isNotEmpty) {
              _initials = parts.last[0].toUpperCase();
            }
          } else {
            _initials = 'L';
          }

          // Format Date of Birth (YYYY-MM-DD -> DD/MM/YYYY)
          if (data['dateOfBirth'] != null) {
            final dobStr = data['dateOfBirth'].toString();
            final parts = dobStr.split('-');
            if (parts.length == 3) {
              _dateOfBirth = '${parts[2]}/${parts[1]}/${parts[0]}';
            } else {
              _dateOfBirth = dobStr;
            }
          } else {
            _dateOfBirth = '';
          }
        });
      } else {
        _showErrorSnackBar('Failed to load profile: ${res['message']}');
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessSnackBar(String msg) {
    ToastHelper.showSuccess(context, msg);
  }

  void _showErrorSnackBar(String msg) {
    ToastHelper.showError(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 992;
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: SharedHeader(
            isDesktop: isDesktop,
            activeTab: '',
          ),
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF28B79B)),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 60 : 16,
                          vertical: 40,
                        ),
                        child: Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: isDesktop
                                ? Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Sidebar Left
                                      _buildSidebar(isDesktop),
                                      const SizedBox(width: 30),
                                      // Panel Right
                                      Expanded(
                                        child: _activeTab == 0
                                            ? _buildInformationTab(isDesktop)
                                            : _buildChangePasswordTab(isDesktop),
                                      ),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _buildSidebar(isDesktop),
                                      const SizedBox(height: 20),
                                      _activeTab == 0
                                          ? _buildInformationTab(isDesktop)
                                          : _buildChangePasswordTab(isDesktop),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      SharedFooter(isDesktop: isDesktop),
                    ],
                  ),
                ),
        );
      },
    );
  }

  // ---------------------------------------------------------
  // SIDEBAR WIDGET
  // ---------------------------------------------------------
  Widget _buildSidebar(bool isDesktop) {
    return Container(
      width: isDesktop ? 280 : double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ACCOUNT',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
              letterSpacing: 1.2,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 16),
          // Tab 0: Information & Contact
          _buildSidebarTabButton(
            index: 0,
            icon: Icons.person_outline_rounded,
            label: 'Information & Contact',
            isDesktop: isDesktop,
          ),
          const SizedBox(height: 8),
          // Tab 1: Change Password
          _buildSidebarTabButton(
            index: 1,
            icon: Icons.lock_reset_rounded,
            label: 'Change Password',
            isDesktop: isDesktop,
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarTabButton({
    required int index,
    required IconData icon,
    required String label,
    required bool isDesktop,
  }) {
    final isActive = _activeTab == index;
    return InkWell(
      onTap: () {
        setState(() {
          _activeTab = index;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFE6FFFA) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? Border.all(color: const Color(0xFF28B79B).withOpacity(0.3))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? const Color(0xFF28B79B) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? const Color(0xFF28B79B) : const Color(0xFF334155),
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // TAB 1: INFORMATION & CONTACT
  // ---------------------------------------------------------
  Widget _buildInformationTab(bool isDesktop) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Information',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                  fontFamily: 'Outfit',
                ),
              ),
              OutlinedButton.icon(
                onPressed: _showUpdateProfileModal,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Update'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF28B79B),
                  side: const BorderSide(color: Color(0xFF28B79B), width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 24),

          // Content Row (Avatar left, Fields right)
          LayoutBuilder(
            builder: (context, box) {
              final isWide = box.maxWidth > 650;
              return isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileDisplayAvatar(),
                        const SizedBox(width: 40),
                        Expanded(child: _buildProfileFieldsGrid(isWide)),
                      ],
                    )
                  : Column(
                      children: [
                        _buildProfileDisplayAvatar(),
                        const SizedBox(height: 30),
                        _buildProfileFieldsGrid(isWide),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDisplayAvatar() {
    return Column(
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: _avatarUrl.isNotEmpty
                ? Image.network(
                    _avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildInitialsLargeAvatar(),
                  )
                : _buildInitialsLargeAvatar(),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _fullName.isNotEmpty ? _fullName : 'Learner Name',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
            fontFamily: 'Outfit',
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildInitialsLargeAvatar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF28B79B), Color(0xFF1F9E84)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          _initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 36,
            fontFamily: 'Outfit',
          ),
        ),
      ),
    );
  }

  Widget _buildProfileFieldsGrid(bool isWide) {
    return Column(
      children: [
        _buildTwoFieldRow(
          isWide,
          _buildReadOnlyField('Full name*', _fullName),
          _buildReadOnlyField('date of birth*', _dateOfBirth.isNotEmpty ? _dateOfBirth : '--/--/----'),
        ),
        const SizedBox(height: 20),
        _buildTwoFieldRow(
          isWide,
          _buildReadOnlyField('Email*', _email),
          _buildReadOnlyField('Gender', _gender),
        ),
        const SizedBox(height: 20),
        _buildTwoFieldRow(
          isWide,
          _buildReadOnlyField('Phone number*', _phoneNumber.isNotEmpty ? _phoneNumber : 'Not provided'),
          _buildReadOnlyField('Address', _address.isNotEmpty ? _address : 'Not provided'),
        ),
      ],
    );
  }

  Widget _buildTwoFieldRow(bool isWide, Widget left, Widget right) {
    if (isWide) {
      return Row(
        children: [
          Expanded(child: left),
          const SizedBox(width: 20),
          Expanded(child: right),
        ],
      );
    }
    return Column(
      children: [
        left,
        const SizedBox(height: 20),
        right,
      ],
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w500,
              fontFamily: 'Outfit',
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------
  // UPDATE PROFILE MODAL DIALOG
  // ---------------------------------------------------------
  void _showUpdateProfileModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _UpdateProfileModal(
        initialFullName: _fullName,
        initialUsername: _username,
        initialPhone: _phoneNumber,
        initialDob: _dateOfBirth,
        initialAddress: _address,
        initialGender: _gender,
        initialAvatarUrl: _avatarUrl,
        initials: _initials,
        onSave: (updatedData) async {
          // Perform save API
          setState(() {
            _isLoading = true;
          });
          try {
            final res = await _authService.updateProfile(updatedData);
            if (res['success'] == true) {
              _showSuccessSnackBar('Profile updated successfully!');
              _fetchProfile(); // reload
            } else {
              _showErrorSnackBar('Failed to update profile: ${res['message']}');
            }
          } catch (e) {
            _showErrorSnackBar('Error updating profile: $e');
          } finally {
            setState(() {
              _isLoading = false;
            });
          }
        },
      ),
    );
  }

  // ---------------------------------------------------------
  // TAB 2: CHANGE PASSWORD
  // ---------------------------------------------------------
  Widget _buildChangePasswordTab(bool isDesktop) {
    return _ChangePasswordPanel(
      onSave: (currentPassword, newPassword) async {
        setState(() {
          _isLoading = true;
        });
        try {
          final res = await _authService.changePassword(currentPassword, newPassword);
          if (res['success'] == true) {
            _showSuccessSnackBar('Password updated successfully!');
            // The prompt says "After the change, you will need to log back in on all devices."
            // We can prompt them or auto log out
            Future.delayed(const Duration(seconds: 2), () {
              _authService.logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => LearnerHomePage()),
                (route) => false,
              );
            });
          } else {
            _showErrorSnackBar('Failed to update password: ${res['message']}');
          }
        } catch (e) {
          _showErrorSnackBar('Error changing password: $e');
        } finally {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );
  }
}

// ------------------------------------------------------------------------
// MODAL DIALOG STATEFUL WIDGET
// ------------------------------------------------------------------------
class _UpdateProfileModal extends StatefulWidget {
  final String initialFullName;
  final String initialUsername;
  final String initialPhone;
  final String initialDob;
  final String initialAddress;
  final String initialGender;
  final String initialAvatarUrl;
  final String initials;
  final Function(Map<String, dynamic>) onSave;

  const _UpdateProfileModal({
    required this.initialFullName,
    required this.initialUsername,
    required this.initialPhone,
    required this.initialDob,
    required this.initialAddress,
    required this.initialGender,
    required this.initialAvatarUrl,
    required this.initials,
    required this.onSave,
  });

  @override
  State<_UpdateProfileModal> createState() => _UpdateProfileModalState();
}

class _UpdateProfileModalState extends State<_UpdateProfileModal> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _phoneController;
  late TextEditingController _dobController;
  late TextEditingController _addressController;
  late String _gender;
  late String _avatarUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialFullName);
    _usernameController = TextEditingController(text: widget.initialUsername);
    _phoneController = TextEditingController(text: widget.initialPhone);
    _dobController = TextEditingController(text: widget.initialDob);
    _addressController = TextEditingController(text: widget.initialAddress);
    _gender = widget.initialGender;
    _avatarUrl = widget.initialAvatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final pickedFile = await pickImage();
      if (pickedFile == null) return;

      setState(() {
        _isUploading = true;
      });

      final url = Uri.parse('https://api.cloudinary.com/v1_1/diqekap4o/image/upload');
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = 'hango_preset'
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          pickedFile.bytes,
          filename: pickedFile.name,
        ));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(responseBody);
        final secureUrl = data['secure_url'] ?? data['url'];
        setState(() {
          _avatarUrl = secureUrl ?? '';
        });
        ToastHelper.showSuccess(context, 'Avatar uploaded successfully!');
      } else {
        ToastHelper.showError(context, 'Avatar upload failed: Cloudinary returned status ${response.statusCode}');
      }
    } catch (e) {
      ToastHelper.showError(context, 'Error uploading avatar: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 16,
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Update Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),

              // Scrollable content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Large Avatar Picker Circle
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
                              ),
                              child: ClipOval(
                                child: _avatarUrl.isNotEmpty
                                    ? Image.network(
                                        _avatarUrl,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        color: const Color(0xFFE6FFFA),
                                        child: Center(
                                          child: Text(
                                            widget.initials,
                                            style: const TextStyle(
                                              color: Color(0xFF28B79B),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 32,
                                              fontFamily: 'Outfit',
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            if (_isUploading)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.4),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: InkWell(
                                onTap: _isUploading ? null : _pickAndUploadAvatar,
                                customBorder: const CircleBorder(),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF28B79B),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Input Fields Row 1
                      _buildFieldsRow([
                        _buildInputField(
                          label: 'Full name*',
                          controller: _nameController,
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                        _buildInputField(
                          label: 'Name account*',
                          controller: _usernameController,
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ]),
                      const SizedBox(height: 20),

                      // Input Fields Row 2
                      _buildFieldsRow([
                        _buildInputField(
                          label: 'Phone number*',
                          controller: _phoneController,
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                        _buildInputField(
                          label: 'date of birth*',
                          controller: _dobController,
                          hint: 'DD/MM/YYYY',
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            final parts = v.split('/');
                            if (parts.length != 3) return 'Format: DD/MM/YYYY';
                            return null;
                          },
                        ),
                      ]),
                      const SizedBox(height: 20),

                      // Input Fields Row 3
                      _buildFieldsRow([
                        _buildInputField(
                          label: 'Address',
                          controller: _addressController,
                        ),
                        _buildGenderToggle(
                          value: ['Male', 'Female'].contains(_gender) ? _gender : 'Male',
                          onChanged: (newVal) {
                            setState(() {
                              _gender = newVal;
                            });
                          },
                        ),
                      ]),
                      const SizedBox(height: 30),

                      // Update Full Width Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              String? formattedDob;
                              if (_dobController.text.isNotEmpty) {
                                final parts = _dobController.text.split('/');
                                if (parts.length == 3) {
                                  formattedDob = '${parts[2]}-${parts[1]}-${parts[0]}';
                                }
                              }
                              
                              final data = {
                                'fullName': _nameController.text.trim(),
                                'username': _usernameController.text.trim(),
                                'phoneNumber': _phoneController.text.trim(),
                                'avatarUrl': _avatarUrl,
                                'gender': _gender,
                                'address': _addressController.text.trim(),
                                if (formattedDob != null) 'dateOfBirth': formattedDob,
                              };
                              widget.onSave(data);
                              Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF28B79B),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Update',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldsRow(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth > 550) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: children[0]),
              const SizedBox(width: 20),
              Expanded(child: children[1]),
            ],
          );
        }
        return Column(
          children: [
            children[0],
            const SizedBox(height: 20),
            children[1],
          ],
        );
      },
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF28B79B), width: 1.5),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildGenderToggle({
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gender',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              _buildGenderOption('Male', Icons.male_rounded, value, onChanged),
              _buildGenderOption('Female', Icons.female_rounded, value, onChanged),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenderOption(
    String label,
    IconData icon,
    String selected,
    ValueChanged<String> onChanged,
  ) {
    final isSelected = selected == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF28B79B).withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? const Color(0xFF28B79B) : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? const Color(0xFF28B79B) : const Color(0xFF64748B),
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------
// CHANGE PASSWORD PANEL
// ------------------------------------------------------------------------
class _ChangePasswordPanel extends StatefulWidget {
  final Function(String, String) onSave;

  const _ChangePasswordPanel({required this.onSave});

  @override
  State<_ChangePasswordPanel> createState() => _ChangePasswordPanelState();
}

class _ChangePasswordPanelState extends State<_ChangePasswordPanel> {
  final _formKey = GlobalKey<FormState>();
  final _currPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurr = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Change Password',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Update your password to protect your account.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 8),
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 24),

            // Password Field
            _buildPasswordField(
              label: 'Password *',
              controller: _currPasswordController,
              obscure: _obscureCurr,
              onToggleObscure: () => setState(() => _obscureCurr = !_obscureCurr),
              validator: (v) => v == null || v.isEmpty ? 'Current password required' : null,
            ),
            const SizedBox(height: 20),

            // New Password Field
            _buildPasswordField(
              label: 'New Password *',
              controller: _newPasswordController,
              obscure: _obscureNew,
              onToggleObscure: () => setState(() => _obscureNew = !_obscureNew),
              showForgetPass: true,
              validator: (v) {
                if (v == null || v.isEmpty) return 'New password required';
                if (v.length < 8) return 'Password must be at least 8 characters';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Confirm Password Field
            _buildPasswordField(
              label: 'Confirm Password *',
              controller: _confirmPasswordController,
              obscure: _obscureConfirm,
              onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Confirmation password required';
                if (v != _newPasswordController.text) return 'Passwords do not match';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Save Action Button Align Right
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 140,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      widget.onSave(
                        _currPasswordController.text,
                        _newPasswordController.text,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF28B79B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Bottom Alert Info Cards Grid
            LayoutBuilder(
              builder: (context, box) {
                final isWide = box.maxWidth > 550;
                return isWide
                    ? Row(
                        children: [
                          Expanded(child: _buildInfoCard(
                            icon: Icons.shield_outlined,
                            iconColor: const Color(0xFF3B82F6),
                            bgColor: const Color(0xFFEFF6FF),
                            title: 'Strong security',
                            desc: 'Use at least 8 characters, including letters, numbers, and special characters.',
                          )),
                          const SizedBox(width: 16),
                          Expanded(child: _buildInfoCard(
                            icon: Icons.info_outline_rounded,
                            iconColor: const Color(0xFFF97316),
                            bgColor: const Color(0xFFFFF7ED),
                            title: 'Note',
                            desc: 'After the change, you will need to log back in on all devices.',
                          )),
                        ],
                      )
                    : Column(
                        children: [
                          _buildInfoCard(
                            icon: Icons.shield_outlined,
                            iconColor: const Color(0xFF3B82F6),
                            bgColor: const Color(0xFFEFF6FF),
                            title: 'Strong security',
                            desc: 'Use at least 8 characters, including letters, numbers, and special characters.',
                          ),
                          const SizedBox(height: 16),
                          _buildInfoCard(
                            icon: Icons.info_outline_rounded,
                            iconColor: const Color(0xFFF97316),
                            bgColor: const Color(0xFFFFF7ED),
                            title: 'Note',
                            desc: 'After the change, you will need to log back in on all devices.',
                          ),
                        ],
                      );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggleObscure,
    bool showForgetPass = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
                fontFamily: 'Outfit',
              ),
            ),
            if (showForgetPass)
              TextButton(
                onPressed: () {
                  ToastHelper.showSuccess(context, 'Please use OTP verification to recover password.');
                },
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Forget Password?',
                  style: TextStyle(
                    color: Color(0xFF28B79B),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          validator: validator,
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 14),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 20,
                color: const Color(0xFF64748B),
              ),
              onPressed: onToggleObscure,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF28B79B), width: 1.5),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: iconColor.withOpacity(0.8),
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF475569),
                    height: 1.4,
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
