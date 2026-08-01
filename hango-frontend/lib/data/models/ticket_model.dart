class TicketModel {
  final int id;
  final String ticketCode;
  final int? userId;
  final String? userName;
  final String? userEmail;
  final String userRole;
  final String category;
  final String priority;
  final String status; // PENDING, PROCESSING, APPROVED, REJECTED
  final String title;
  final String description;
  final String? adminResponse;
  final String? rejectionReason;
  final String? processedByName;
  final String? processedAt;
  final String createdAt;
  final String updatedAt;
  final List<TicketMessageModel> messages;

  TicketModel({
    required this.id,
    required this.ticketCode,
    this.userId,
    this.userName,
    this.userEmail,
    required this.userRole,
    required this.category,
    required this.priority,
    required this.status,
    required this.title,
    required this.description,
    this.adminResponse,
    this.rejectionReason,
    this.processedByName,
    this.processedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    var rawMsgs = json['messages'] as List? ?? [];
    List<TicketMessageModel> msgList =
        rawMsgs.map((m) => TicketMessageModel.fromJson(m)).toList();

    return TicketModel(
      id: json['id'] ?? 0,
      ticketCode: json['ticketCode'] ?? '',
      userId: json['userId'],
      userName: json['userName'],
      userEmail: json['userEmail'],
      userRole: json['userRole'] ?? 'LEARNER',
      category: json['category'] ?? 'GENERAL_ENQUIRY',
      priority: json['priority'] ?? 'MEDIUM',
      status: json['status'] ?? 'PENDING',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      adminResponse: json['adminResponse'],
      rejectionReason: json['rejectionReason'],
      processedByName: json['processedByName'],
      processedAt: json['processedAt'],
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
      messages: msgList,
    );
  }
}

class TicketMessageModel {
  final int id;
  final int ticketId;
  final int senderId;
  final String senderName;
  final String senderEmail;
  final String senderRole;
  final String message;
  final String? attachmentUrls;
  final String createdAt;

  TicketMessageModel({
    required this.id,
    required this.ticketId,
    required this.senderId,
    required this.senderName,
    required this.senderEmail,
    required this.senderRole,
    required this.message,
    this.attachmentUrls,
    required this.createdAt,
  });

  factory TicketMessageModel.fromJson(Map<String, dynamic> json) {
    return TicketMessageModel(
      id: json['id'] ?? 0,
      ticketId: json['ticketId'] ?? 0,
      senderId: json['senderId'] ?? 0,
      senderName: json['senderName'] ?? '',
      senderEmail: json['senderEmail'] ?? '',
      senderRole: json['senderRole'] ?? '',
      message: json['message'] ?? '',
      attachmentUrls: json['attachmentUrls'],
      createdAt: json['createdAt'] ?? '',
    );
  }
}
