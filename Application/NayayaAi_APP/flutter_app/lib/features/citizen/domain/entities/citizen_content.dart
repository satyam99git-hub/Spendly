/// The Citizen portal's static content, transcribed from the website.
///
/// ---------------------------------------------------------------------------
/// WHY THIS IS A CONSTANT AND NOT AN ENDPOINT
///
/// Every list here is hard-coded HTML in
/// `website/templates/citizen_dashboard.html` — the helplines, the safety tips,
/// the rights topics and the questions they send. No route serves them and no
/// table holds them, so the app carries its own copy, verbatim, the same way
/// `legal_reference.dart` carries the police console's glossary.
///
/// Which means it can drift: an edit to the template does not follow here. The
/// line numbers on each list are where to look when it does.
///
/// ONE DELIBERATE DEVIATION: the website's Ambulance card prints 108 but its
/// link dials `tel:102` (citizen_dashboard.html:686-687). The project owner
/// decided (parity spec, decision D-2) that the app shows and dials 108.
/// ---------------------------------------------------------------------------
library;

/// One helpline card.
class EmergencyContact {
  const EmergencyContact({
    required this.number,
    required this.title,
    required this.description,
  });

  /// What the card shows and what it dials.
  final String number;
  final String title;
  final String description;
}

/// One of the six "Know Your Rights" topic cards.
class RightsTopic {
  const RightsTopic({
    required this.title,
    required this.subtitle,
    required this.question,
  });

  final String title;
  final String subtitle;

  /// Sent to `/api/rights-chat` exactly as the website's `onclick` sends it.
  final String question;
}

/// One of the home page's quick actions (citizen_dashboard.html:328-351).
///
/// A null [question] is the fourth action, which opens Missing Persons rather
/// than asking anything.
class QuickAction {
  const QuickAction({required this.label, this.question});

  final String label;
  final String? question;
}

/// One stage of the complaint timeline.
class TimelineStep {
  const TimelineStep({required this.status, required this.description});

  /// The server's status string, exactly — the timeline index is found by
  /// matching it, as `steps.indexOf(data.status)` does.
  final String status;
  final String description;
}

abstract final class CitizenContent {
  const CitizenContent._();

  /// The nine cards of the Emergency Contacts section
  /// (citizen_dashboard.html:672-734), in the website's order.
  static const emergencyContacts = [
    EmergencyContact(
      number: '100',
      title: 'Police',
      description: 'All-purpose police emergency',
    ),
    EmergencyContact(
      number: '112',
      title: 'National Emergency',
      description: 'Police + Ambulance + Fire combined',
    ),
    // See the class comment: 108, not the website's tel:102 (decision D-2).
    EmergencyContact(
      number: '108',
      title: 'Ambulance',
      description: 'Medical emergency, free transport',
    ),
    EmergencyContact(
      number: '101',
      title: 'Fire Brigade',
      description: 'Fire and rescue operations',
    ),
    EmergencyContact(
      number: '1091',
      title: 'Women Helpline',
      description: 'Harassment, domestic violence, assault',
    ),
    EmergencyContact(
      number: '1930',
      title: 'Cyber Crime',
      description: 'Online fraud, hacking, digital crime',
    ),
    EmergencyContact(
      number: '1098',
      title: 'Child Helpline',
      description: 'Child abuse, missing children',
    ),
    EmergencyContact(
      number: '14567',
      title: 'Senior Citizen',
      description: 'Elder abuse, elder helpline',
    ),
    EmergencyContact(
      number: '15100',
      title: 'Legal Aid',
      description: 'Free legal advice from NALSA',
    ),
  ];

  /// The home page's emergency strip (citizen_dashboard.html:363-380). Its own
  /// six numbers and its own labels — not a subset of [emergencyContacts]'
  /// wording.
  static const homeStrip = [
    (label: 'Police 100', number: '100'),
    (label: 'Women 1091', number: '1091'),
    (label: 'Emergency 112', number: '112'),
    (label: 'Cyber 1930', number: '1930'),
    (label: 'Child 1098', number: '1098'),
    (label: 'Legal Aid 15100', number: '15100'),
  ];

  /// "Safety Tips" (citizen_dashboard.html:743-752).
  static const safetyTips = [
    'Save these numbers in your phone now, before an emergency.',
    'You can file a cyber crime complaint online at cybercrime.gov.in',
    'You have the right to a free lawyer if you cannot afford one — just ask '
        'the court.',
    'Police must give you a copy of your FIR for free within 7 days of '
        'filing.',
    'A woman cannot be arrested after sunset and before sunrise without a '
        'female officer present.',
  ];

  /// The six topic cards of Know Your Rights (citizen_dashboard.html:581-622).
  static const rightsTopics = [
    RightsTopic(
      title: 'If You Are Arrested',
      subtitle: 'Right to bail, lawyer, silence',
      question: 'What are my rights when I am arrested?',
    ),
    RightsTopic(
      title: 'Right to Bail',
      subtitle: 'Bailable vs non-bailable',
      question: 'What is my right to bail under Indian law?',
    ),
    RightsTopic(
      title: 'Right to Lawyer',
      subtitle: 'Free legal aid, when to call',
      question: 'What is the right to a lawyer when arrested in India?',
    ),
    RightsTopic(
      title: 'FIR Refused?',
      subtitle: "Steps if police won't register",
      question: 'What to do if police refuses to file my FIR?',
    ),
    RightsTopic(
      title: "Women's Rights",
      subtitle: 'POCSO, domestic violence',
      question: 'Rights of women under Indian law when filing a complaint',
    ),
    RightsTopic(
      title: 'Free Legal Aid',
      subtitle: 'Who qualifies, how to apply',
      question: 'What is free legal aid and how to get it in India?',
    ),
  ];

  /// The home page's Quick Actions (citizen_dashboard.html:328-351).
  static const quickActions = [
    QuickAction(
      label: 'Arrest Rights',
      question: 'What are my rights when I am arrested?',
    ),
    QuickAction(
      label: 'FIR Refused?',
      question: 'What to do if police refuses to file my FIR?',
    ),
    QuickAction(
      label: 'Free Legal Aid',
      question: 'What is free legal aid and how to get it in India?',
    ),
    QuickAction(label: 'Missing Persons'),
  ];

  /// The first message in the rights chat (citizen_dashboard.html:633-634).
  static const rightsGreeting =
      "Hello! I'm here to help you understand your legal rights under Indian "
      'law. Ask me anything — or click one of the topics above to get started.';

  /// The complaint timeline (citizen_dashboard.html:907-909).
  static const timeline = [
    TimelineStep(status: 'Pending', description: 'Complaint received'),
    TimelineStep(
      status: 'Under Review',
      description: 'Officer reviewing details',
    ),
    TimelineStep(
      status: 'FIR Filed',
      description: 'FIR registered with police',
    ),
    TimelineStep(status: 'Closed', description: 'Case closed'),
  ];

  /// `steps.indexOf(data.status)` — -1 for a status the website does not
  /// know, which highlights no step at all.
  static int timelineIndex(String status) =>
      timeline.indexWhere((step) => step.status == status);
}
