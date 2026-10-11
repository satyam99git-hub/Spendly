/// Wire models for filing a citizen complaint.
library;

/// `POST /api/complaint` body — the five keys `submitComplaint()` sends
/// (citizen_dashboard.html:841-847), trimmed as it trims them.
///
/// Empty optional fields are sent as `""`, not left out: the website always
/// sends all five, and the handler stores `data.get(key, '')`.
class ComplaintSubmission {
  const ComplaintSubmission({
    required this.fullName,
    required this.incidentDescription,
    this.phone = '',
    this.incidentDate = '',
    this.location = '',
  });

  final String fullName;
  final String phone;

  /// `yyyy-MM-dd`, the format an `<input type="date">` submits, or empty.
  final String incidentDate;
  final String location;
  final String incidentDescription;

  Map<String, dynamic> toJson() => {
        'full_name': fullName.trim(),
        'phone': phone.trim(),
        'incident_date': incidentDate,
        'location': location.trim(),
        'incident_description': incidentDescription.trim(),
      };
}

/// `POST /api/complaint` 201 body: `{tracking_id, status, category,
/// can_file_fir}`.
///
/// Only [trackingId] is ever shown — the website displays nothing else from
/// this response, and the category is the server's keyword guess, which it
/// keeps from the citizen (limitation L7). The rest is parsed so the model
/// says what the server said, not so a screen can use it.
class ComplaintReceipt {
  const ComplaintReceipt({
    required this.trackingId,
    this.status = '',
    this.category = '',
    this.canFileFir = false,
  });

  final String trackingId;
  final String status;
  final String category;
  final bool canFileFir;

  factory ComplaintReceipt.fromJson(Map<String, dynamic> json) {
    String text(String key) => json[key]?.toString().trim() ?? '';
    return ComplaintReceipt(
      trackingId: text('tracking_id'),
      status: text('status'),
      category: text('category'),
      canFileFir: json['can_file_fir'] == true,
    );
  }
}
