import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';

class GroupInfoScreen extends StatelessWidget {
  final Room room;
  final List<RoomMember> members;
  final bool isAdmin;

  const GroupInfoScreen({
    super.key,
    required this.room,
    required this.members,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(slivers: [
        // header
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          backgroundColor: AppTheme.surface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              color: AppTheme.surface,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.accent, width: 2),
                    ),
                    child: const Icon(Icons.group, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    room.name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Group · ${members.length} members',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),

        // description
        if (room.description != null)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Description',
                      style: TextStyle(
                          color: AppTheme.accent, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(room.description!,
                      style: const TextStyle(color: AppTheme.textPrimary)),
                ],
              ),
            ),
          ),

        // members header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '${members.length} MEMBERS',
              style: const TextStyle(
                color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),

        // members list
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) {
              final m = members[i];
              return ListTile(
                tileColor: AppTheme.surface,
                leading: UserAvatar(username: m.username, size: 44),
                title: Text(m.username,
                    style: const TextStyle(color: AppTheme.textPrimary)),
                trailing: m.isAdmin
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: AppTheme.accent.withOpacity(0.4)),
                        ),
                        child: const Text('Admin',
                            style: TextStyle(
                                color: AppTheme.accent, fontSize: 11)),
                      )
                    : null,
              );
            },
            childCount: members.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ]),
    );
  }
}
