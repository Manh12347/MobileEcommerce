class AppNotification {
  final int notificationId;
  final int accountId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime createdOn;

  AppNotification({
    required this.notificationId,
    required this.accountId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdOn,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawId =
        json['notificationId'] ?? json['notification_id'] ?? json['id'];
    final rawAccountId =
        json['accountId'] ??
        json['account_id'] ??
        json['account']?['accountId'];
    final rawCreatedOn = json['createdOn'] ?? json['created_on'];

    return AppNotification(
      notificationId: rawId is int ? rawId : int.tryParse('$rawId') ?? 0,
      accountId: rawAccountId is int
          ? rawAccountId
          : int.tryParse('$rawAccountId') ?? 0,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      type: json['type'] as String? ?? 'system',
      isRead: json['isRead'] as bool? ?? json['is_read'] as bool? ?? false,
      createdOn: rawCreatedOn != null
          ? DateTime.tryParse(rawCreatedOn.toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'notificationId': notificationId,
    'accountId': accountId,
    'title': title,
    'message': message,
    'type': type,
    'isRead': isRead,
    'createdOn': createdOn.toIso8601String(),
  };
}
