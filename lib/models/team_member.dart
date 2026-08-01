class TeamMember {
  final String id;
  final String ownerId;
  final String memberEmail;
  final String role; // 'editor' or 'viewer'
  final String status; // 'pending' or 'accepted'

  TeamMember({
    required this.id,
    required this.ownerId,
    required this.memberEmail,
    required this.role,
    required this.status,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      memberEmail: json['member_email'] as String,
      role: json['role'] as String,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'member_email': memberEmail,
      'role': role,
      'status': status,
    };
  }
}
