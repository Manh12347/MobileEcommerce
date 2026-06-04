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
    return AppNotification(
      notificationId: json['notificationId'] as int,
      accountId: json['account']?['accountId'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      type: json['type'] as String? ?? 'system',
      isRead: json['isRead'] as bool? ?? false,
      createdOn: json['createdOn'] != null
          ? DateTime.tryParse(json['createdOn'].toString()) ?? DateTime.now()
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
