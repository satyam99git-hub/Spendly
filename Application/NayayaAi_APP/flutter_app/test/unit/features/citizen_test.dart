import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nayaya_app/core/error/failure.dart';
import 'package:nayaya_app/features/citizen/data/datasources/citizen_remote_data_sources.dart';
import 'package:nayaya_app/features/citizen/data/models/case_client_status.dart';
import 'package:nayaya_app/features/citizen/data/models/citizen_complaint_models.dart';
import 'package:nayaya_app/features/citizen/domain/entities/citizen_content.dart';
import 'package:nayaya_app/features/citizen/presentation/controllers/complaint_controllers.dart';
import 'package:nayaya_app/features/citizen/presentation/widgets/citizen_widgets.dart';

/// The Citizen Portal's contract with the website: the same requests, the same
/// words, the same handling of what comes back. Every expectation here cites
/// the line of `citizen_dashboard.html` or `app.py` it reproduces.
void main() {
  group('complaint validation (submitComplaint, lines 818-832)', () {
    test('name and description are both required', () {
      expect(
        validateComplaint(name: '', phone: '', description: 'x'),
        'Name and incident description are required.',
      );
      expect(
        validateComplaint(name: 'Asha', phone: '', description: '  '),
        'Name and incident description are required.',
      );
    });

    test('a name is letters and spaces only', () {
      expect(
        validateComplaint(name: 'Asha 2', phone: '', description: 'x'),
        'Name should only contain letters and spaces.',
      );
    });

    // Decision D-1: the rule the website's code states, not its broken box.
    test('a phone, when given, is exactly ten digits', () {
      expect(
        validateComplaint(name: 'Asha', phone: '98765', description: 'x'),
        'Phone number must be exactly 10 digits.',
      );
      expect(
        validateComplaint(name: 'Asha', phone: '9876543210', description: 'x'),
        isNull,
      );
      expect(
        validateComplaint(name: 'Asha', phone: '', description: 'x'),
        isNull,
      );
    });

    test('the checks run in the website order', () {
      // A bad name and a bad phone: the name is reported, as on the website.
      expect(
        validateComplaint(name: 'A1', phone: '1', description: 'x'),
        'Name should only contain letters and spaces.',
      );
    });
  });

  group('the complaint payload (lines 841-847)', () {
    test('sends the five keys, trimmed, with empty optionals as ""', () {
      const submission = ComplaintSubmission(
        fullName: ' Asha Rao ',
        incidentDescription: ' Stolen phone ',
        location: ' Andheri ',
      );
      expect(submission.toJson(), {
        'full_name': 'Asha Rao',
        'phone': '',
        'incident_date': '',
        'location': 'Andheri',
        'incident_description': 'Stolen phone',
      });
    });

    test('reads the receipt of app.py:617-622', () {
      final receipt = ComplaintReceipt.fromJson({
        'tracking_id': 'CMP-1A2B3C4D',
        'status': 'Pending',
        'category': 'Theft / Robbery',
        'can_file_fir': true,
      });
      expect(receipt.trackingId, 'CMP-1A2B3C4D');
      expect(receipt.canFileFir, isTrue);
    });
  });

  group('CitizenComplaintRemoteDataSource', () {
    test('posts to /api/complaint and returns the tracking ID', () async {
      final server = _Server()
        ..reply = (201, jsonEncode({'tracking_id': 'CMP-9'}));
      final receipt = await CitizenComplaintRemoteDataSource(server.dio).file(
        const ComplaintSubmission(fullName: 'Asha', incidentDescription: 'x'),
      );
      expect(receipt.trackingId, 'CMP-9');
      expect(server.lastPath, '/api/complaint');
      expect(server.lastMethod, 'POST');
      expect(server.lastBody, containsPair('full_name', 'Asha'));
    });

    test("a JSON error shows the server's own error", () async {
      final server = _Server()
        ..reply = (
          400,
          jsonEncode({'error': 'Name and incident description are required'})
        );
      await expectLater(
        CitizenComplaintRemoteDataSource(server.dio).file(
          const ComplaintSubmission(fullName: 'A', incidentDescription: 'x'),
        ),
        throwsA(
          isA<Failure>().having(
            (f) => f.message,
            'message',
            'Name and incident description are required',
          ),
        ),
      );
    });

    test('a JSON body with no error falls back to "Submission failed."',
        () async {
      final server = _Server()..reply = (500, jsonEncode({'oops': 1}));
      await expectLater(
        CitizenComplaintRemoteDataSource(server.dio).file(
          const ComplaintSubmission(fullName: 'A', incidentDescription: 'x'),
        ),
        throwsA(
          isA<Failure>().having((f) => f.message, 'm', 'Submission failed.'),
        ),
      );
    });

    // `res.json()` throws on an HTML page, and the website's catch says this.
    test('a non-JSON body reads as the network error', () async {
      final server = _Server()..reply = (500, '<html>Traceback</html>');
      await expectLater(
        CitizenComplaintRemoteDataSource(server.dio).file(
          const ComplaintSubmission(fullName: 'A', incidentDescription: 'x'),
        ),
        throwsA(
          isA<NetworkFailure>().having(
            (f) => f.message,
            'message',
            'Network error. Please try again.',
          ),
        ),
      );
    });

    test('track reads GET /api/complaint/<id> and its 404 text', () async {
      final server = _Server()
        ..reply = (
          404,
          jsonEncode({'error': 'Complaint not found. Check your tracking ID.'})
        );
      await expectLater(
        CitizenComplaintRemoteDataSource(server.dio).track('CMP-X'),
        throwsA(
          isA<Failure>().having(
            (f) => f.message,
            'message',
            'Complaint not found. Check your tracking ID.',
          ),
        ),
      );
      expect(server.lastPath, '/api/complaint/CMP-X');
    });
  });

  group('RightsChatRemoteDataSource (askRightsQuestion, lines 984-1015)', () {
    test('returns the answer', () async {
      final server = _Server()..reply = (200, jsonEncode({'answer': 'Yes.'}));
      final answer = await RightsChatRemoteDataSource(server.dio).ask('bail?');
      expect(answer, 'Yes.');
      expect(server.lastBody, {'question': 'bail?'});
    });

    // The website never checks res.ok: a 400 {answer} is shown as an answer.
    test('shows the answer of a 400 like any other', () async {
      final server = _Server()
        ..reply = (
          400,
          jsonEncode({'answer': 'Please ask a question about your rights.'})
        );
      expect(
        await RightsChatRemoteDataSource(server.dio).ask(' '),
        'Please ask a question about your rights.',
      );
    });

    test('a JSON body with no answer is "No answer received."', () async {
      final server = _Server()..reply = (200, jsonEncode({}));
      expect(
        await RightsChatRemoteDataSource(server.dio).ask('q'),
        'No answer received.',
      );
    });

    // Limitation L2: the handler's no-match path is an HTML 500.
    test('an HTML 500 is "Could not connect…"', () async {
      final server = _Server()..reply = (500, '<html>UnboundLocalError</html>');
      await expectLater(
        RightsChatRemoteDataSource(server.dio).ask('something unmatched'),
        throwsA(
          isA<NetworkFailure>().having(
            (f) => f.message,
            'message',
            'Could not connect. Check your server is running and try again.',
          ),
        ),
      );
    });
  });

  group('CaseStatusRemoteDataSource (checkCaseStatus, lines 1080-1109)', () {
    test('encodes the FIR number and reads the four values', () async {
      final server = _Server()
        ..reply = (
          200,
          jsonEncode({
            'fir_no': 'FIR/41',
            'status': 'Trial',
            'next_hearing_date': null,
            'client_note': 'Bring ID',
            'client_note_updated_at': '2026-09-01T10:00:00+00:00',
          }),
        );
      final status =
          await CaseStatusRemoteDataSource(server.dio).lookup('FIR/41');
      expect(server.lastPath, '/api/case/FIR%2F41/client-status');
      expect(status.statusLabel, 'Trial');
      expect(status.hearingLabel, 'Not scheduled');
      expect(status.hasNote, isTrue);
    });

    test("a 404 shows the server's sentence", () async {
      final server = _Server()
        ..reply =
            (404, jsonEncode({'error': 'Status not available for this FIR'}));
      await expectLater(
        CaseStatusRemoteDataSource(server.dio).lookup('FIR0'),
        throwsA(
          isA<Failure>().having(
            (f) => f.message,
            'm',
            'Status not available for this FIR',
          ),
        ),
      );
    });

    test('an empty status reads "Active"', () {
      expect(const CaseClientStatus(firNo: 'F').statusLabel, 'Active');
    });
  });

  group('formatRelativeTime (lines 1054-1071)', () {
    final now = DateTime.utc(2026, 9, 20, 12);
    String at(Duration ago) =>
        formatRelativeTime(now.subtract(ago).toIso8601String(), now: now);

    test('uses the website thresholds and words', () {
      expect(at(const Duration(seconds: 30)), 'just now');
      expect(at(const Duration(minutes: 5)), 'Updated 5 min ago');
      expect(at(const Duration(hours: 1)), 'Updated 1 hr ago');
      expect(at(const Duration(hours: 3)), 'Updated 3 hrs ago');
      expect(at(const Duration(days: 1)), 'Updated 1 day ago');
      expect(at(const Duration(days: 6)), 'Updated 6 days ago');
      expect(at(const Duration(days: 30)), startsWith('Updated on '));
    });

    test('an empty or unreadable value is blank', () {
      expect(formatRelativeTime(''), '');
      expect(formatRelativeTime('not a date'), '');
    });
  });

  group('the timeline (lines 906-923)', () {
    test('matches the four statuses by exact string', () {
      expect(CitizenContent.timelineIndex('Pending'), 0);
      expect(CitizenContent.timelineIndex('Under Review'), 1);
      expect(CitizenContent.timelineIndex('FIR Filed'), 2);
      expect(CitizenContent.timelineIndex('Closed'), 3);
    });

    test('an unknown status highlights nothing', () {
      expect(CitizenContent.timelineIndex('Escalated'), -1);
    });
  });

  group('formatAnswer (lines 936-953)', () {
    String plain(List<InlineSpan> spans) =>
        spans.map((s) => (s as TextSpan).text).join();

    test('bold, bullets and line breaks', () {
      final spans =
          RightsAnswerText.spansFor('**Bail** is a right\n- one\n• two');
      expect(plain(spans), 'Bail is a right\n  • one\n  • two');
      final bold = spans.first as TextSpan;
      expect(bold.text, 'Bail');
      expect(bold.style?.fontWeight, FontWeight.w700);
    });
  });

  group('static content', () {
    // Decision D-2: the Ambulance card shows and dials 108.
    test('the ambulance is 108', () {
      final ambulance = CitizenContent.emergencyContacts
          .singleWhere((c) => c.title == 'Ambulance');
      expect(ambulance.number, '108');
    });

    test('nine helplines, six on the home strip, six topics, five tips', () {
      expect(CitizenContent.emergencyContacts, hasLength(9));
      expect(CitizenContent.homeStrip, hasLength(6));
      expect(CitizenContent.rightsTopics, hasLength(6));
      expect(CitizenContent.safetyTips, hasLength(5));
    });
  });
}

/// A server that answers every request with [reply] and remembers the last one.
class _Server {
  _Server() {
    dio.httpClientAdapter = _Adapter(this);
  }

  final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost:5000'));
  (int, String) reply = (200, '{}');

  String? lastPath;
  String? lastMethod;
  Object? lastBody;
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.server);

  final _Server server;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    server
      ..lastPath = options.uri.path.isEmpty ? options.path : options.uri.path
      ..lastMethod = options.method
      ..lastBody = options.data;
    final (status, body) = server.reply;
    final isJson =
        body.trimLeft().startsWith('{') || body.trimLeft().startsWith('[');
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [
          isJson ? Headers.jsonContentType : 'text/html; charset=utf-8',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
