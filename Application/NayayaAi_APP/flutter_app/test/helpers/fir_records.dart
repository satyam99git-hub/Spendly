import 'package:nayaya_app/features/fir/domain/entities/fir_record.dart';

/// A stored FIR for tests, in the shape the *app* files one: the required
/// entries answered and the optional ones left blank.
///
/// Defaults deliberately, so a test that cares about one field says so by
/// passing it and everything else stays out of the way. [aDeskFiledRecord] is
/// the other half — the shape only the website can produce.
FirRecord aFirRecord({
  String firNo = 'FIR001',
  String district = 'Delhi',
  String policeStation = 'North Delhi PS',
  String firDate = '2026-08-09',
  String actSections = 'IPC 379',
  String occurrenceDate = '2026-08-07',
  String placeOfOccurrence = 'Sector 14 market',
  String complainantName = 'A. Sharma',
  String statement = 'Two-wheeler taken from outside the market at noon.',
  String createdAt = 'Sun, 09 Aug 2026 06:30:00 GMT',
  String pdfFile = 'FIR_FIR001.pdf',
}) {
  return FirRecord(
    firNo: firNo,
    firId: '17549023114567',
    district: district,
    policeStation: policeStation,
    year: firDate.length >= 4 ? firDate.substring(0, 4) : '',
    firDate: firDate,
    actSections: actSections,
    occurrenceDay: 'Friday',
    occurrenceDate: occurrenceDate,
    placeOfOccurrence: placeOfOccurrence,
    complainantName: complainantName,
    statement: statement,
    pdfFile: pdfFile,
    createdAt: createdAt,
    status: 'Saved to Police Records',
  );
}

/// An FIR with the eighteen entries the app never asks for, as a record filed
/// from the website's console carries them.
///
/// The viewer has to show these — that is the whole argument for [FirRecord]
/// holding all 27 — so a test of "does the viewer drop what the desk recorded"
/// needs a record only the desk could have written.
FirRecord aDeskFiledRecord({String firNo = 'FIR900'}) {
  return FirRecord(
    firNo: firNo,
    firId: '17549023199999',
    district: 'Maharashtra',
    policeStation: 'Colaba PS',
    year: '2026',
    firDate: '2026-07-02',
    actSections: 'IPC 420, IPC 468',
    occurrenceDay: 'Wednesday',
    occurrenceDate: '2026-07-01',
    occurrenceTime: '21:15',
    infoReceivedDate: '2026-07-02',
    infoReceivedTime: '08:40',
    gdrEntryNo: 'GD 114/2026',
    typeOfInformation: 'Written',
    placeOfOccurrence: 'Near the fishermen’s colony',
    complainantName: 'R. Iyer',
    fatherHusbandName: 'S. Iyer',
    dob: '1988-03-14',
    nationality: 'Indian',
    passportNo: 'Z1234567',
    dateOfIssue: '2019-05-20',
    placeOfIssue: 'Mumbai',
    occupation: 'Shopkeeper',
    address: '14, Colaba Causeway, Mumbai',
    detailsOfAccused: 'Two men, one known to the complainant',
    reasonsForDelay: 'Complainant was travelling',
    propertyParticulars: 'Cash, ₹40,000',
    statement: 'Payment was taken against goods that were never delivered.',
    pdfFile: 'FIR_FIR900.pdf',
    createdAt: 'Thu, 02 Jul 2026 03:10:00 GMT',
    status: 'Saved to Police Records',
  );
}
