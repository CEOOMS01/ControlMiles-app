// Olympus Mont Systems LLC - ControlMiles
// lib/utils/invite_validation.dart
//
// What the fleet roster's "Invite driver" dialog checks before it calls the
// server, and how a server rejection is shown. Kept free of Flutter so it can
// be tested on its own.
//
// The server is the real gate (create_driver_invite re-validates all of this,
// plus who may invite whom); this only saves a round trip and turns a raw
// exception into a sentence the admin can act on.

/// Same shape create_driver_invite enforces: something@something.tld.
final RegExp _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isPlausibleEmail(String email) => _emailShape.hasMatch(email.trim());

/// null when the inputs can be sent, otherwise which field is wrong. The
/// caller maps the field to its own translated message.
enum InviteInputProblem { firstName, lastName, email }

InviteInputProblem? validateInviteInput({
  required String firstName,
  required String lastName,
  required String email,
}) {
  if (firstName.trim().isEmpty) return InviteInputProblem.firstName;
  if (lastName.trim().isEmpty) return InviteInputProblem.lastName;
  if (!isPlausibleEmail(email)) return InviteInputProblem.email;
  return null;
}

/// The text of a server rejection without the wrapper noise. The RPC's own
/// exceptions are already user-facing sentences ("This person is already a
/// member of this organization", "Too many invites created recently..."), but
/// they reach the app as e.g.
/// `PostgrestException(message: This person ..., code: P0001, details: ...)`,
/// which is not something to show a person.
String inviteErrorMessage(Object error) {
  final text = error.toString();

  final match = RegExp(r'message:\s*(.*?)(?:,\s*code:|,\s*details:|\)$|$)', dotAll: true)
      .firstMatch(text);
  final extracted = match?.group(1)?.trim();
  if (extracted != null && extracted.isNotEmpty) return extracted;

  return text.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
}
