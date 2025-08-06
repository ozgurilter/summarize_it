import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:summarize_it/model/user.dart';

class ProfilePage extends StatefulWidget {
  final User user;
  final VoidCallback onLogout;

  const ProfilePage({
    Key? key,
    required this.user,
    required this.onLogout,
  }) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final createdAt = widget.user.createdAt ?? DateTime.now();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Profil Avatar
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.deepPurple.shade100,
              border: Border.all(
                color: Colors.deepPurple,
                width: 3,
              ),
            ),
            child: Center(
              child: Text(
                widget.user.nameSurname
                    .split(' ')
                    .map((e) => e.isNotEmpty ? e[0] : '')
                    .join()
                    .toUpperCase(),
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Kullanıcı Bilgileri
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildProfileItem(
                    icon: Icons.person,
                    title: 'Ad Soyad',
                    value: widget.user.nameSurname,
                  ),
                  const Divider(height: 30),
                  _buildProfileItem(
                    icon: Icons.email,
                    title: 'E-posta',
                    value: widget.user.email,
                  ),
                  const Divider(height: 30),
                  _buildProfileItem(
                    icon: Icons.lock,
                    title: 'Şifre',
                    value: widget.user.password,
                    isPassword: true,
                  ),
                  const Divider(height: 30),
                  _buildProfileItem(
                    icon: Icons.calendar_today,
                    title: 'Üyelik Tarihi',
                    value: DateFormat('dd MMMM yyyy').format(createdAt),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),

          // Çıkış Butonu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Çıkış Yap'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.red.shade200),
                ),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    elevation: 8,
                    icon: Icon(Icons.exit_to_app_rounded,
                        size: 36,
                        color: Colors.red.shade400),
                    title: Text('Çıkış Yap',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        )),
                    content: Text('Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        )),
                    actionsAlignment: MainAxisAlignment.center,
                    actions: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(color: Colors.grey.shade400),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text('İptal',
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  )),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                widget.onLogout();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade400,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.logout_rounded, size: 20),
                                  const SizedBox(width: 6),
                                  Text('Çıkış Yap',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w500,
                                      )),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem({
    required IconData icon,
    required String title,
    required String value,
    bool isPassword = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.deepPurple, size: 28),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              isPassword
                  ? Row(
                children: [
                  Text(
                    _obscurePassword ? '•' * 8 : value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      size: 18,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ],
              )
                  : Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
