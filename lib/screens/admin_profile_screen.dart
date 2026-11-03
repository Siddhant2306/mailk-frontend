import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_palette.dart';
import '../models/app_user.dart';
import '../models/pending_user.dart';
import '../services/admin_user_service.dart';
import '../services/brand_service.dart';
import '../services/converter_service.dart';
import '../services/session_cache.dart';
import '../widgets/profile/admin_profile_sections.dart';
import '../widgets/profile/bulk_import_sheet.dart';
import '../widgets/profile/converter_form_sheet.dart';
import 'login.dart';

/// Administrative account tools. This screen is rendered only after the
/// backend has identified the signed-in account as an approved administrator.
class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({
    required this.user,
    super.key,
    this.isSessionVerified = true,
    this.converterService,
    this.brandService,
    this.adminUserService,
  });

  final AppUser user;
  final bool isSessionVerified;
  final ConverterService? converterService;
  final BrandService? brandService;
  final AdminUserService? adminUserService;

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  AdminUserService get _adminUserService =>
      widget.adminUserService ?? AdminUserService();
  ConverterService get _converterService =>
      widget.converterService ?? ConverterService();
  List<PendingUser> _pendingUsers = const [];
  int? _workingUserId;
  String? _approvalError;
  var _isLoadingApprovals = true;

  @override
  void initState() {
    super.initState();
    if (widget.user.isAdmin && widget.isSessionVerified) {
      _refreshPendingUsers();
    } else {
      _isLoadingApprovals = false;
    }
  }

  Future<void> _openConverterForm(BuildContext context) async {
    final converterId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => ConverterFormSheet(
        converterService: _converterService,
        brandService: widget.brandService,
      ),
    );
    if (converterId != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Converter #$converterId was added.')),
      );
    }
  }

  Future<void> _openBulkImport(BuildContext context) async {
    final importedCount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => BulkImportSheet(converterService: _converterService),
    );
    if (importedCount != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$importedCount converters were imported.')),
      );
    }
  }

  Future<void> _signOut(BuildContext context) async {
    await SessionCache().clear();
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _refreshPendingUsers() async {
    setState(() {
      _isLoadingApprovals = true;
      _approvalError = null;
    });
    try {
      final pendingUsers = await _adminUserService.getPendingUsers();
      if (!mounted) return;
      setState(() {
        _pendingUsers = pendingUsers;
        _isLoadingApprovals = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _approvalError = _adminUserService.messageFor(error);
        _isLoadingApprovals = false;
      });
    }
  }

  Future<void> _reviewUser(
    PendingUser pendingUser, {
    required bool approve,
  }) async {
    setState(() => _workingUserId = pendingUser.id);
    try {
      if (approve) {
        await _adminUserService.approveUser(pendingUser.id);
      } else {
        await _adminUserService.rejectUser(pendingUser.id);
      }
      if (!mounted) return;
      setState(() {
        _pendingUsers = _pendingUsers
            .where((user) => user.id != pendingUser.id)
            .toList();
      });
      await _refreshPendingUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? '${pendingUser.displayName} approved.'
                : '${pendingUser.displayName} rejected.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_adminUserService.messageFor(error))),
      );
    } finally {
      if (mounted) setState(() => _workingUserId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            const ProfileHeading(),
            const SizedBox(height: 16),
            ProfileAccountCard(user: widget.user),
            if (widget.user.isAdmin && widget.isSessionVerified) ...[
              const SizedBox(height: 14),
              const AdminCapabilities(),
              const SizedBox(height: 16),
              const ProfileSectionTitle('ADMIN ACTIONS'),
              const SizedBox(height: 8),
              ProfilePrimaryAction(
                icon: Icons.add_circle_outline,
                label: 'Add converter',
                onPressed: () => _openConverterForm(context),
              ),
              const SizedBox(height: 8),
              ProfileSecondaryAction(
                icon: Icons.upload_file_outlined,
                label: 'Bulk import · CSV / Excel',
                onPressed: () => _openBulkImport(context),
              ),
              const SizedBox(height: 16),
              _buildPendingApprovals(),
              const SizedBox(height: 16),
              const AdminSecurityCard(),
              const SizedBox(height: 16),
            ],
            const ProfileSectionTitle('ACCOUNT SETTINGS'),
            const SizedBox(height: 8),
            ProfileSecondaryAction(
              icon: Icons.logout_rounded,
              label: 'Sign out',
              danger: true,
              onPressed: () => _signOut(context),
            ),
            const SizedBox(height: 22),
            Text(
              '© MALIK ENTERPRISES · CATALOGUE',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingApprovals() {
    final palette = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: ProfileSectionTitle('PENDING APPROVALS')),
            if (_isLoadingApprovals)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              )
            else
              Text(
                _pendingUsers.isEmpty
                    ? 'All caught up'
                    : '${_pendingUsers.length} waiting',
                style: TextStyle(color: palette.textMuted, fontSize: 11),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_approvalError case final error?)
          _ApprovalMessage(
            icon: Icons.error_outline,
            title: 'Could not load approvals',
            message: error,
            actionLabel: 'Retry',
            onAction: _refreshPendingUsers,
          )
        else if (_isLoadingApprovals && _pendingUsers.isEmpty)
          const _ApprovalMessage(
            icon: Icons.hourglass_empty,
            title: 'Loading approval queue',
            message: 'Checking for new account requests.',
          )
        else if (_pendingUsers.isEmpty)
          const _ApprovalMessage(
            icon: Icons.verified_outlined,
            title: 'Queue is clear',
            message: 'No one is waiting for approval. New registrations will appear here.',
          )
        else
          for (final pendingUser in _pendingUsers)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _PendingApprovalCard(
                user: pendingUser,
                isWorking: _workingUserId == pendingUser.id,
                actionsEnabled: _workingUserId == null,
                onApprove: () => _reviewUser(pendingUser, approve: true),
                onReject: () => _reviewUser(pendingUser, approve: false),
              ),
            ),
      ],
    );
  }
}

class _PendingApprovalCard extends StatelessWidget {
  const _PendingApprovalCard({
    required this.user,
    required this.isWorking,
    required this.actionsEnabled,
    required this.onApprove,
    required this.onReject,
  });

  final PendingUser user;
  final bool isWorking;
  final bool actionsEnabled;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final initial = user.displayName.trim().isEmpty
        ? '?'
        : user.displayName.trim().substring(0, 1).toUpperCase();
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: palette.surfaceSubtle,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: palette.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.textMuted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              if (isWorking)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: actionsEnabled ? onApprove : null,
                    icon: const Icon(Icons.check_circle_outline, size: 17),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: actionsEnabled ? onReject : null,
                    icon: const Icon(Icons.block_outlined, size: 17),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.negative,
                      side: BorderSide(color: palette.border),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApprovalMessage extends StatelessWidget {
  const _ApprovalMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.accent, size: 30),
          const SizedBox(height: 9),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class AdminRestrictedScreen extends StatelessWidget {
  const AdminRestrictedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return ColoredBox(
      color: palette.background,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, color: palette.accent, size: 36),
                const SizedBox(height: 14),
                Text(
                  'Admin profile',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Converter management is available only to approved admin accounts.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.textMuted, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
