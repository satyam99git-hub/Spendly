/// Where an escalated complaint is being sent.
///
/// ---------------------------------------------------------------------------
/// WHY THIS IS A LIST IN THE APP AND NOT A COLUMN ON THE SERVER
///
/// `citizen_complaints` has eleven columns and none of them is an assignee. The
/// PATCH handler writes a status, an FIR number and a block of notes, and that
/// is the whole of what a client can record — so an escalation cannot be stored
/// as a relationship, only as a sentence.
///
/// Given that, the choice is between a free-text box and a fixed list. It is a
/// fixed list, because the sentence is the only searchable trace the escalation
/// leaves: every entry reads "Escalated to <label>. Reason: …", so an inbox can
/// be searched for "SP office" and find them. A typed destination would spell the
/// same desk four ways in a week and be findable by none of them.
///
/// The honest limit: nothing is *sent* anywhere. There is no routing, no queue
/// and no notification — the complaint moves to Under Review and the note says
/// where it should go. Whoever reads the inbox is the routing. That is what the
/// server supports today, and the escalate sheet says so in as many words rather
/// than letting an officer believe a message left the building.
/// ---------------------------------------------------------------------------
enum EscalationDesk {
  sho(
    'Station House Officer',
    'The officer in charge of this station',
  ),

  /// The rank above the station, whichever local title it goes by. Both are
  /// listed because the two systems are not used in the same states.
  subdivision(
    'Circle Inspector / SDPO',
    'The sub-division above this station',
  ),

  superintendent(
    'Superintendent of Police',
    'District level — for complaints against police, or serious offences',
  ),

  /// Kept separate from a general escalation because these complaints are
  /// routed by statute rather than by seniority.
  womenAndChild(
    'Women & Child Desk',
    'Offences against women or children',
  ),

  cyber(
    'Cyber Cell',
    'Online fraud, impersonation, or offences using a device',
  );

  const EscalationDesk(this.label, this.description);

  /// Goes into the note verbatim, which is what makes escalations searchable.
  /// Changing one of these strings does not rewrite the notes already stored
  /// under the old wording — so treat them as data, not as copy.
  final String label;

  /// One line on the escalation sheet explaining who this is for. An officer
  /// picking a desk from a list of five titles should not have to know the local
  /// convention to choose correctly.
  final String description;
}
