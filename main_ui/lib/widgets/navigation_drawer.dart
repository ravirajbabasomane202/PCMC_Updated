import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:main_ui/l10n/app_localizations.dart';
import 'package:main_ui/providers/auth_provider.dart';
import 'package:main_ui/providers/user_provider.dart';

// ─────────────────── Design Tokens ───────────────────────────────────────────
const Color _bg         = Color(0xFF050B18);
const Color _surface    = Color(0xFF0D1829);
const Color _surfaceAlt = Color(0xFF0F2040);
const Color _cyan       = Color(0xFF00E5FF);
const Color _cyanDim    = Color(0xFF0097A7);
const Color _amber      = Color(0xFFFFB300);
const Color _green      = Color(0xFF00E676);
const Color _red        = Color(0xFFFF1744);
const Color _orange     = Color(0xFFFF6D00);
const Color _purple     = Color(0xFFD500F9);
const Color _gold       = Color(0xFFFFD700);
const Color _text1      = Color(0xFFE8F4FD);
const Color _text2      = Color(0xFF8BA3BE);
const Color _border     = Color(0xFF1A3050);

// Role-specific accent colors & metadata
_RoleTheme _roleTheme(String? role) {
  switch (role?.toUpperCase()) {
    case 'SUPER_USER':
      return _RoleTheme(
        accent: _gold,
        headerGradient: [const Color(0xFF1A1200), const Color(0xFF302000)],
        label: 'SUPER USER',
        icon: Icons.shield_moon,
        badge: '✦',
      );
    case 'ADMIN':
      return _RoleTheme(
        accent: _cyan,
        headerGradient: [const Color(0xFF001220), const Color(0xFF001830)],
        label: 'ADMINISTRATOR',
        icon: Icons.admin_panel_settings,
        badge: '⬡',
      );
    case 'FIELD_STAFF':
      return _RoleTheme(
        accent: _orange,
        headerGradient: [const Color(0xFF180800), const Color(0xFF200D00)],
        label: 'FIELD STAFF',
        icon: Icons.engineering,
        badge: '▲',
      );
    case 'MEMBER_HEAD':
      return _RoleTheme(
        accent: _purple,
        headerGradient: [const Color(0xFF0D0020), const Color(0xFF140030)],
        label: 'MEMBER HEAD',
        icon: Icons.verified_user,
        badge: '◆',
      );
    default:
      return _RoleTheme(
        accent: _green,
        headerGradient: [const Color(0xFF001810), const Color(0xFF002018)],
        label: 'CITIZEN',
        icon: Icons.person,
        badge: '●',
      );
  }
}

class _RoleTheme {
  final Color accent;
  final List<Color> headerGradient;
  final String label;
  final IconData icon;
  final String badge;
  const _RoleTheme({
    required this.accent, required this.headerGradient,
    required this.label, required this.icon, required this.badge,
  });
}

// ─────────────────────────── Drawer ──────────────────────────────────────────
class CustomNavigationDrawer extends ConsumerStatefulWidget {
  const CustomNavigationDrawer({super.key});
  @override
  ConsumerState<CustomNavigationDrawer> createState() => _CustomNavigationDrawerState();
}

class _CustomNavigationDrawerState extends ConsumerState<CustomNavigationDrawer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc  = AppLocalizations.of(context)!;
    final user = ref.watch(userNotifierProvider);
    final role = user?.role?.toUpperCase();
    final rt   = _roleTheme(role);

    return Drawer(
      backgroundColor: _bg,
      child: Column(children: [
        _buildHeader(rt, user?.name, user?.email, role),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(children: [

              // Home
              _item(context, icon: Icons.home, label: loc.home ?? 'Home',
                  color: rt.accent, onTap: () => _goHome(context, role, loc)),

              // Role-specific sections
              if (role == 'SUPER_USER') ..._superUserItems(context, loc, rt),
              if (role == 'ADMIN')      ..._adminItems(context, loc, rt),
              if (role == 'MEMBER_HEAD')..._memberHeadItems(context, loc, rt),
              if (role == 'CITIZEN')    ..._citizenItems(context, loc, rt),

              _divider(),

              // Common
              _item(context, icon: Icons.person, label: loc.profile, route: '/profile'),
              _item(context, icon: Icons.settings, label: loc.settings, route: '/settings'),
              _item(context, icon: Icons.announcement, label: loc.announcements, route: '/announcements'),
              _item(context, icon: Icons.privacy_tip, label: loc.privacyPolicy, route: '/privacy-policy'),
              _item(context, icon: Icons.help, label: loc.faqs, route: '/faqs'),
              _item(context, icon: Icons.support_agent, label: loc.contactSupport, route: '/contact-support'),
              _item(context, icon: Icons.info_outline, label: loc.appVersion, route: '/app-version'),

              _divider(),

              // Logout
              _item(context, icon: Icons.logout, label: loc.logout,
                  color: _red,
                  onTap: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
                    }
                  }),
              const SizedBox(height: 12),
            ]),
          ),
        ),
        // Footer
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: _border))),
          child: Row(children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Container(width: 6, height: 6,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: _green,
                      boxShadow: [BoxShadow(color: _green.withOpacity(0.3 + _pulse.value * 0.7), blurRadius: 6)])),
            ),
            const SizedBox(width: 8),
            Text('PCMC GRIEVANCE SYSTEM', style: TextStyle(color: _text2, fontSize: 9, letterSpacing: 1.5)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildHeader(_RoleTheme rt, String? name, String? email, String? role) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 52, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: rt.headerGradient,
        ),
        border: Border(bottom: BorderSide(color: rt.accent.withOpacity(0.3))),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Avatar
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: rt.accent.withOpacity(0.15),
              border: Border.all(color: rt.accent.withOpacity(0.5), width: 2),
              boxShadow: [BoxShadow(color: rt.accent.withOpacity(0.3), blurRadius: 12)],
            ),
            child: Center(child: Icon(rt.icon, color: rt.accent, size: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name ?? 'User', style: TextStyle(color: _text1, fontSize: 15, fontWeight: FontWeight.w700)),
            if (email != null)
              Text(email, style: TextStyle(color: _text2, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
        ]),
        const SizedBox(height: 12),
        // Role badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: rt.accent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: rt.accent.withOpacity(0.5)),
            boxShadow: [BoxShadow(color: rt.accent.withOpacity(0.2), blurRadius: 8)],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(rt.badge, style: TextStyle(color: rt.accent, fontSize: 10)),
            const SizedBox(width: 6),
            Text(rt.label,
                style: TextStyle(color: rt.accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          ]),
        ),
      ]),
    );
  }

  // ─────────────── Menu items by role ──────────────────────────────────────────

  List<Widget> _superUserItems(BuildContext ctx, AppLocalizations loc, _RoleTheme rt) => [
    _sectionHeader('SUPER CONTROLS', rt.accent),
    _item(ctx, icon: Icons.shield, label: 'System Overview', color: _gold, route: '/admin/home'),
    _item(ctx, icon: Icons.report, label: loc.complaintManagement, color: _gold, route: '/admin/complaints'),
    _item(ctx, icon: Icons.people, label: loc.manageUsers, color: _gold, route: '/admin/users'),
    _item(ctx, icon: Icons.bar_chart, label: 'Full Analytics', color: _gold, route: '/admin/analytics'),
    _item(ctx, icon: Icons.manage_accounts, label: 'Manage Admins', color: _gold, route: '/admin/users'),
    _item(ctx, icon: Icons.subject, label: loc.manageSubjects, route: '/admin/subjects'),
    _item(ctx, icon: Icons.location_on, label: loc.manageAreas, route: '/admin/areas'),
    _item(ctx, icon: Icons.settings_applications, label: loc.manageConfigs, route: '/admin/configs'),
    _item(ctx, icon: Icons.campaign, label: 'Advertisements', route: '/admin/ads'),
    _item(ctx, icon: Icons.map, label: 'Nearby Places', route: '/admin/nearby'),
    _item(ctx, icon: Icons.history, label: 'User History', route: '/admin/all_users_history'),
    _item(ctx, icon: Icons.security, label: 'Audit Logs', route: '/admin/audit'),
    _divider(),
  ];

  List<Widget> _adminItems(BuildContext ctx, AppLocalizations loc, _RoleTheme rt) => [
    _sectionHeader('ADMINISTRATION', rt.accent),
    _item(ctx, icon: Icons.report, label: loc.complaintManagement, color: rt.accent, route: '/admin/complaints'),
    _item(ctx, icon: Icons.people, label: loc.manageUsers, route: '/admin/users'),
    _item(ctx, icon: Icons.subject, label: loc.manageSubjects, route: '/admin/subjects'),
    _item(ctx, icon: Icons.location_on, label: loc.manageAreas, route: '/admin/areas'),
    _item(ctx, icon: Icons.settings_applications, label: loc.manageConfigs, route: '/admin/configs'),
    _item(ctx, icon: Icons.campaign, label: 'Advertisements', route: '/admin/ads'),
    _item(ctx, icon: Icons.map, label: 'Nearby Places', route: '/admin/nearby'),
    _item(ctx, icon: Icons.history, label: 'User History', route: '/admin/all_users_history'),
    _item(ctx, icon: Icons.security, label: 'Audit Logs', route: '/admin/audit'),
    _divider(),
  ];

  List<Widget> _memberHeadItems(BuildContext ctx, AppLocalizations loc, _RoleTheme rt) => [
    _sectionHeader('OVERSIGHT', rt.accent),
    _item(ctx, icon: Icons.list_alt, label: 'View Grievances', color: rt.accent, route: '/member_head/grievances'),
    _divider(),
  ];

  List<Widget> _citizenItems(BuildContext ctx, AppLocalizations loc, _RoleTheme rt) => [
    _sectionHeader('MY COMPLAINTS', rt.accent),
    _item(ctx, icon: Icons.add_circle, label: 'Submit Complaint', color: rt.accent, route: '/citizen/submit'),
    _item(ctx, icon: Icons.track_changes, label: 'Track Complaint', route: '/citizen/track'),
    _item(ctx, icon: Icons.location_on, label: 'Nearby Me', route: '/citizen/nearby'),
    _divider(),
  ];

  // ─────────────── Helper widgets ──────────────────────────────────────────────

  Widget _sectionHeader(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(children: [
        Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 2)),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: color.withOpacity(0.2))),
      ]),
    );
  }

  Widget _divider() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    height: 1,
    color: _border,
  );

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String label,
    Color? color,
    String? route,
    VoidCallback? onTap,
  }) {
    final c = color ?? _text2;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () {
          if (route == null) return;
          Navigator.pop(context);
          Navigator.pushNamed(context, route);
        },
        borderRadius: BorderRadius.circular(8),
        splashColor: c.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            dense: true,
            leading: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: c.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.withOpacity(0.2)),
              ),
              child: Icon(icon, color: c, size: 16),
            ),
            title: Text(label, style: TextStyle(
                color: color != null ? _text1 : _text2,
                fontSize: 13, fontWeight: color != null ? FontWeight.w600 : FontWeight.w400)),
            trailing: Icon(Icons.chevron_right, color: c.withOpacity(0.3), size: 16),
          ),
        ),
      ),
    );
  }

  void _goHome(BuildContext context, String? role, AppLocalizations loc) {
    Navigator.pop(context);
    final route = _homeRouteForRole(role);
    if (route == null) return;
    Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
  }

  static String? _homeRouteForRole(String? role) {
    switch (role) {
      case 'SUPER_USER':
      case 'ADMIN':       return '/admin/home';
      case 'CITIZEN':     return '/citizen/home';
      case 'MEMBER_HEAD': return '/member_head/home';
      case 'FIELD_STAFF': return '/field_staff/home';
      default:            return null;
    }
  }
}
