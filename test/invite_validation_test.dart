// The invite dialog is the admin's first contact with the fleet flow: it must
// stop obvious mistakes before a round trip and show server rejections as
// plain sentences, never as a raw exception.

import 'package:flutter_test/flutter_test.dart';
import 'package:controlmiles/utils/invite_validation.dart';

void main() {
  group('isPlausibleEmail', () {
    test('accepts ordinary addresses, trimming spaces', () {
      expect(isPlausibleEmail('jane@example.com'), isTrue);
      expect(isPlausibleEmail('  jane.doe+fleet@mail.example.co '), isTrue);
    });
    test('rejects what the server would reject', () {
      expect(isPlausibleEmail(''), isFalse);
      expect(isPlausibleEmail('jane'), isFalse);
      expect(isPlausibleEmail('jane@'), isFalse);
      expect(isPlausibleEmail('@example.com'), isFalse);
      expect(isPlausibleEmail('jane@example'), isFalse);
      expect(isPlausibleEmail('ja ne@example.com'), isFalse);
    });
  });

  group('validateInviteInput', () {
    test('valid input passes', () {
      expect(
          validateInviteInput(firstName: 'Jane', lastName: 'Doe', email: 'jane@example.com'),
          isNull);
    });
    test('names the first wrong field, in form order', () {
      expect(validateInviteInput(firstName: ' ', lastName: 'Doe', email: 'jane@example.com'),
          InviteInputProblem.firstName);
      expect(validateInviteInput(firstName: 'Jane', lastName: '', email: 'jane@example.com'),
          InviteInputProblem.lastName);
      expect(validateInviteInput(firstName: 'Jane', lastName: 'Doe', email: 'nope'),
          InviteInputProblem.email);
      // nothing filled: the first field is reported, not the last
      expect(validateInviteInput(firstName: '', lastName: '', email: ''),
          InviteInputProblem.firstName);
    });
  });

  group('inviteErrorMessage', () {
    test('unwraps a PostgREST-style exception to its sentence', () {
      const raw =
          'PostgrestException(message: This person is already a member of this organization, code: P0001, details: null, hint: null)';
      expect(inviteErrorMessage(raw), 'This person is already a member of this organization');
    });

    test('keeps a sentence that contains a comma', () {
      const raw =
          'PostgrestException(message: Only an org admin, owner, or operator can invite drivers, code: P0001, details: null, hint: null)';
      expect(inviteErrorMessage(raw), 'Only an org admin, owner, or operator can invite drivers');
    });

    test('a plain exception loses only its prefix', () {
      expect(inviteErrorMessage(Exception('Network down')), 'Network down');
    });

    test('an empty message falls back to the raw text; nothing at all stays empty', () {
      expect(inviteErrorMessage('PostgrestException(message: , code: 1)'), isNotEmpty);
      expect(inviteErrorMessage(''), isEmpty); // nothing to say is honest, not invented
    });
  });
}
