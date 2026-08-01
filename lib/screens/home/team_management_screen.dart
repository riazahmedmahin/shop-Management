import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/team_member.dart';

class TeamManagementScreen extends StatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  final _emailController = TextEditingController();
  String _selectedRole = 'viewer';
  List<TeamMember> _myTeam = [];
  List<TeamMember> _pendingInvitations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTeamData();
  }

  Future<void> _fetchTeamData() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final email = user.email;

      // Fetch team members I have invited
      final myTeamData = await Supabase.instance.client
          .from('team_members')
          .select()
          .eq('owner_id', user.id);
      
      _myTeam = myTeamData.map((e) => TeamMember.fromJson(e)).toList();

      // Fetch invitations sent to me
      if (email != null) {
        final invitesData = await Supabase.instance.client
            .from('team_members')
            .select()
            .eq('member_email', email)
            .eq('status', 'pending');
        
        _pendingInvitations = invitesData.map((e) => TeamMember.fromJson(e)).toList();
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading team data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _inviteMember() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an email address.')),
      );
      return;
    }

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client.from('team_members').insert({
        'owner_id': user.id,
        'member_email': email,
        'role': _selectedRole,
        'status': 'pending',
      });

      _emailController.clear();
      _fetchTeamData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invitation sent to $email')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending invite: $e')),
        );
      }
    }
  }

  Future<void> _updateInvitationStatus(String id, String status) async {
    try {
      await Supabase.instance.client
          .from('team_members')
          .update({'status': status})
          .eq('id', id);
      
      _fetchTeamData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  Future<void> _removeMember(String id) async {
    try {
      await Supabase.instance.client
          .from('team_members')
          .delete()
          .eq('id', id);
      
      _fetchTeamData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing member: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Management'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Invite Section ---
                  const Text(
                    'Invite Team Member',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Member Email',
                            hintText: 'partner@example.com',
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          value: _selectedRole,
                          decoration: const InputDecoration(labelText: 'Role'),
                          items: const [
                            DropdownMenuItem(value: 'editor', child: Text('Editor')),
                            DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedRole = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _inviteMember,
                      icon: const Icon(Icons.person_add),
                      label: const Text('Send Invitation'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- Pending Invitations (To me) ---
                  if (_pendingInvitations.isNotEmpty) ...[
                    const Text(
                      'Pending Invitations (For You)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ..._pendingInvitations.map((inv) => Card(
                      color: Colors.orange[50],
                      child: ListTile(
                        leading: const Icon(Icons.mail_outline, color: Colors.orange),
                        title: Text('Invite from: ${inv.ownerId}'), // Ideally show owner email if joined
                        subtitle: Text('Role: ${inv.role.toUpperCase()}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () => _updateInvitationStatus(inv.id, 'accepted'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => _updateInvitationStatus(inv.id, 'rejected'),
                            ),
                          ],
                        ),
                      ),
                    )),
                    const SizedBox(height: 32),
                  ],

                  // --- My Team Members ---
                  const Text(
                    'My Team Members',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_myTeam.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('You have not invited anyone yet.', style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else
                    ..._myTeam.map((m) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: m.role == 'editor' ? Colors.blue[100] : Colors.grey[200],
                          child: Icon(
                            m.role == 'editor' ? Icons.edit : Icons.remove_red_eye,
                            color: m.role == 'editor' ? Colors.blue : Colors.grey[700],
                          ),
                        ),
                        title: Text(m.memberEmail),
                        subtitle: Text('Role: ${m.role.toUpperCase()} • Status: ${m.status.toUpperCase()}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _removeMember(m.id),
                        ),
                      ),
                    )),
                ],
              ),
            ),
    );
  }
}
